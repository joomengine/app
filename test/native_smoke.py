#!/usr/bin/env python3
"""Exercise hosted JCB in the native QA build, with an isolated durable profile."""

import argparse
import hashlib
import json
import os
import re
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time
import uuid
from zipfile import BadZipFile, ZipFile


def contains_marker_table(sql, identifier):
    # Playground's SQL exporter writes text cells as MariaDB hex literals.
    # Checking the INSERT associates this run's marker with its own table.
    value = identifier.encode('ascii').hex().encode('ascii')
    required = {
        b'CREATE TABLE `desktop_smoke` (',
        b"INSERT INTO `desktop_smoke` (`value`) VALUES (X'" + value + b"');",
    }
    overlap = max(map(len, required)) - 1
    tail = b''
    while chunk := sql.read(64 * 1024):
        window = tail + chunk
        required = {fragment for fragment in required if fragment not in window}
        if not required:
            return True
        tail = window[-overlap:]
    return False


def exported(path, identifier):
    """Only permit shutdown once the native download is a readable site bundle."""
    try:
        with ZipFile(path) as archive:
            required = {'site/configuration.php', 'export.json', 'database.sql'}
            missing = required.difference(archive.namelist())
            if missing:
                raise ValueError(f'Complete site ZIP is missing {sorted(missing)}')
            with archive.open('database.sql') as sql:
                if not contains_marker_table(sql, identifier):
                    raise ValueError('The exported SQL is missing the desktop_smoke table or its saved marker row')
            if not archive.read('site/configuration.php').strip() or not json.loads(archive.read('export.json')):
                raise ValueError('Exported site configuration or metadata is empty')
        return True
    except (FileNotFoundError, PermissionError, BadZipFile):
        # Some native downloaders stream into the chosen filename before rename.
        return False


def public_site_file(bundle):
    """Match a small asset served from the imported site to its actual ZIP member."""
    with ZipFile(bundle) as archive:
        for member in archive.infolist():
            if (re.fullmatch(r'site/media/(?:[A-Za-z0-9_-]+/)+[A-Za-z0-9_.-]+\.(?:css|svg|png)', member.filename)
                    and 0 < member.file_size <= 65536):
                return {'path': member.filename.removeprefix('site/'),
                        'digest': hashlib.sha256(archive.read(member)).hexdigest()}
    raise ValueError('The exported Joomla site contains no small public media fixture')


class InitialNavigationTimeout(TimeoutError):
    """The first macOS renderer produced no QA command in a fresh profile."""


def require_probe_volume(directory):
    """Ensure the temporary profile volume has room and supports sparse files."""
    gib = 1024 ** 3
    disk = shutil.disk_usage(directory)
    if os.name != 'posix' or disk.total < 20 * gib or disk.free < 12 * gib:
        raise RuntimeError('The requested 10 GiB probe needs a POSIX volume with 20 GiB total and 12 GiB free.')
    with tempfile.TemporaryFile(dir=directory) as probe:
        probe.seek(8 * 1024 ** 2 - 1)
        probe.write(b'x')
        probe.flush()
        if os.fstat(probe.fileno()).st_blocks * 512 > 64 * 1024:
            raise RuntimeError('The requested 10 GiB probe needs a volume that supports sparse files.')


def exercise(binary, work, identifier, mode, *, native_chooser=False, import_key=None, check_storage=False):
    write = mode == 'write'
    log = work / (mode + '.log')
    gate = work / (mode + '.ready')
    script = work / (mode + '.js')
    bundle = work / 'complete-site.zip'
    config = json.dumps({'id': identifier, 'phase': mode, 'nativeChooser': native_chooser, 'checkStorage': check_storage,
                         'asset': None if write else public_site_file(bundle), 'importKey': import_key})
    template = Path(__file__).with_name('native-playground.js').read_text(encoding='utf-8')
    script.write_text(template.replace('__JOOMENGINE_QA_CONFIGURATION__', config), encoding='utf-8')
    if not write:
        gate.touch()
    env = os.environ.copy()
    env.update({
        'JOOMENGINE_QA_ID': identifier,
        'JOOMENGINE_QA_PHASE': mode,
        'JOOMENGINE_QA_SCRIPT': str(script),
        'JOOMENGINE_QA_PROFILE': str(work / 'profile'),
        'JOOMENGINE_QA_EXPORT': str(bundle),
        'JOOMENGINE_QA_GATE': str(gate),
        'JOOMENGINE_QA_LOG': str(log),
    })
    print(f'Launching the native {mode} check.', flush=True)
    process = subprocess.Popen([str(binary)], env=env)
    started = time.monotonic()
    deadline = started + 900
    lines_seen = 0
    chooser_used = False
    imported = None
    download_complete = sys.platform != 'win32'
    try:
        while True:
            if write and download_complete and not gate.exists() and exported(bundle, identifier):
                print('Verified the delivered ZIP, Joomla configuration, saved SQL marker and export metadata.', flush=True)
                gate.touch()
            status = process.poll()
            lines = []
            if log.exists():
                lines = log.read_text(encoding='utf-8', errors='replace').splitlines()
                for line in lines[lines_seen:]:
                    print(line, flush=True)
                    if line.startswith('download-complete '):
                        download_complete = True
                    if line.startswith('choose-import '):
                        if mode != 'import' or not native_chooser or chooser_used:
                            raise RuntimeError('Unexpected native file chooser request')
                        from linux_file_chooser import select_archive
                        chooser_used = True
                        select_archive(bundle, process)
                    if mode == 'import' and line.startswith('pass '):
                        match = re.fullmatch(r'pass (import-[0-9a-f-]{36}) [0-9]+', line)
                        if match:
                            imported = match[1]
                lines_seen = len(lines)
            if status is not None:
                if status or not any(line.startswith('pass ') for line in lines):
                    raise RuntimeError(f'Native {mode} check exited with status {status} before the pass signal.')
                if mode == 'restore' and not any(line.startswith('reload ') for line in lines):
                    raise RuntimeError('The restored project did not receive a native Reload action.')
                if mode == 'import' and (not imported or (native_chooser and not chooser_used)):
                    raise RuntimeError('Upload did not complete in a new workspace')
                return imported
            now = time.monotonic()
            if (sys.platform == 'darwin' and write and not lines_seen and not bundle.exists()
                    and now - started >= 120):
                raise InitialNavigationTimeout('No QA command from the first macOS document in 120 seconds.')
            if now >= deadline:
                raise TimeoutError(f'Native {mode} check timed out; last state: {lines[-3:]}.')
            time.sleep(0.4)
    finally:
        if process.poll() is None:
            process.terminate()
            try:
                process.wait(timeout=8)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('executable', type=Path, help='Separate native QA build executable')
    parser.add_argument('--native-file-chooser', action='store_true',
                        help='Drive the installed Linux desktop file chooser in the isolated X11 session')
    parser.add_argument('--check-storage-capacity', action='store_true',
                        help='Verify 10 GiB of logical origin storage on a suitable temporary profile volume')
    args = parser.parse_args()
    # Keep /snap/bin/<app> and Windows execution aliases intact. Launching the
    # resolved symlink would invoke snap itself without the application's name.
    binary = args.executable.absolute()
    if not binary.exists():
        parser.error(f'Native QA executable does not exist: {binary}')
    # macOS may canonicalize /var paths to /private/var. Share one real path.
    # Keep Windows downloads and the test profile on the same kind of user
    # storage as the installed app, outside the OS's temporary-download folder.
    parent = os.environ['LOCALAPPDATA'] if sys.platform == 'win32' else None
    work = Path(tempfile.mkdtemp(prefix='joomengine-native-', dir=parent)).resolve()
    try:
        active = work
        identifier = str(uuid.uuid4())
        (active / 'profile').mkdir()
        check_storage = args.check_storage_capacity
        if check_storage:
            require_probe_volume(active / 'profile')
        try:
            exercise(binary, active, identifier, 'write', check_storage=check_storage)
        except InitialNavigationTimeout as error:
            # An Intel macOS runner kept a live host with no responsive document.
            # Start Chromium once more with a new test profile and marker. Once
            # any command arrives (including the required select-all before SQL),
            # errors and timeouts fail the run instead of replaying the scenario.
            print(f'{error} Starting one independent cold launch.', flush=True)
            active = work / 'second-launch'
            (active / 'profile').mkdir(parents=True)
            identifier = str(uuid.uuid4())
            exercise(binary, active, identifier, 'write', check_storage=check_storage)
        import_key = exercise(binary, active, identifier, 'import', native_chooser=args.native_file_chooser)
        exercise(binary, active, identifier, 'restore', import_key=import_key)
        print('Passed real JCB startup, external HTTPS, detached tool, complete site export and upload, restart and native reload.')
    finally:
        # WebView2 may release its profile files shortly after the host exits.
        for attempt in range(20):
            try:
                shutil.rmtree(work)
                break
            except PermissionError:
                if attempt == 19:
                    raise
                time.sleep(0.25)


if __name__ == '__main__':
    main()

#!/usr/bin/env python3
"""Exercise hosted JCB in the native QA build, with an isolated durable profile."""

import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time
import uuid
from zipfile import BadZipFile, ZipFile


def exported(path):
    """Only permit shutdown once the native download is a readable site bundle."""
    try:
        with ZipFile(path) as archive:
            required = {'site/configuration.php', 'export.json', 'database.sql'}
            missing = required.difference(archive.namelist())
            if missing:
                raise ValueError(f'Complete site ZIP is missing {sorted(missing)}')
            with archive.open('database.sql') as sql:
                if not sql.read(8192).strip():
                    raise ValueError('The exported database is empty')
            if not archive.read('site/configuration.php').strip() or not json.loads(archive.read('export.json')):
                raise ValueError('Exported site configuration or metadata is empty')
        return True
    except (FileNotFoundError, PermissionError, BadZipFile):
        # Some native downloaders stream into the chosen filename before rename.
        return False


def exercise(binary, work, identifier, write):
    mode = 'write' if write else 'restore'
    log = work / (mode + '.log')
    gate = work / (mode + '.ready')
    script = work / (mode + '.js')
    bundle = work / 'complete-site.zip'
    config = json.dumps({'id': identifier, 'write': write})
    template = Path(__file__).with_name('native-playground.js').read_text(encoding='utf-8')
    script.write_text(template.replace('__JOOMENGINE_QA_CONFIGURATION__', config), encoding='utf-8')
    if not write:
        gate.touch()
    env = os.environ.copy()
    env.update({
        'JOOMENGINE_QA_ID': identifier,
        'JOOMENGINE_QA_SCRIPT': str(script),
        'JOOMENGINE_QA_PROFILE': str(work / 'profile'),
        'JOOMENGINE_QA_EXPORT': str(bundle),
        'JOOMENGINE_QA_GATE': str(gate),
        'JOOMENGINE_QA_LOG': str(log),
    })
    print(f'Launching the native {mode} check.', flush=True)
    process = subprocess.Popen([str(binary)], env=env)
    deadline = time.monotonic() + 900
    lines_seen = 0
    try:
        while True:
            if write and not gate.exists() and exported(bundle):
                print('Verified the delivered ZIP, Joomla configuration, SQL and export metadata.', flush=True)
                gate.touch()
            status = process.poll()
            lines = []
            if log.exists():
                lines = log.read_text(encoding='utf-8', errors='replace').splitlines()
                for line in lines[lines_seen:]:
                    print(line, flush=True)
                lines_seen = len(lines)
            if status is not None:
                if status or not any(line.startswith('pass ') for line in lines):
                    raise RuntimeError(f'Native {mode} check exited with status {status} before the pass signal.')
                if not write and not any(line.startswith('reload ') for line in lines):
                    raise RuntimeError('The restored project did not receive a native Reload action.')
                return
            if time.monotonic() >= deadline:
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
    args = parser.parse_args()
    # Keep /snap/bin/<app> and Windows execution aliases intact. Launching the
    # resolved symlink would invoke snap itself without the application's name.
    binary = args.executable.absolute()
    if not binary.exists():
        parser.error(f'Native QA executable does not exist: {binary}')
    # macOS may canonicalize /var paths to /private/var. Share one real path.
    work = Path(tempfile.mkdtemp(prefix='joomengine-native-')).resolve()
    try:
        (work / 'profile').mkdir()
        identifier = str(uuid.uuid4())
        exercise(binary, work, identifier, write=True)
        exercise(binary, work, identifier, write=False)
        print('Passed real JCB startup, external HTTPS, detached tool, site export, process restart and native reload.')
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

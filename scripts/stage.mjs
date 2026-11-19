import { cp, mkdir, mkdtemp, readFile, rename, rm, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { packager } from '@electron/packager';

const root = fileURLToPath(new URL('../', import.meta.url));
const manifest = JSON.parse(await readFile(path.join(root, 'package.json'), 'utf8'));
const dist = path.join(root, 'dist');
const staged = path.join(dist, 'staged');
await mkdir(dist, { recursive: true });
const temporary = await mkdtemp(path.join(dist, '.build-'));

try {
  const source = path.join(temporary, 'app');
  await mkdir(source);
  const { name, productName, version, description, main, license, author, homepage } = manifest;
  await writeFile(path.join(source, 'package.json'), JSON.stringify({
    name, productName, version, description, main, license, author, homepage
  }, null, 2) + '\n');

  for (const file of ['src', 'LICENSE', 'NOTICE', 'assets/joomengine.png']) {
    await cp(path.join(root, file), path.join(source, file), { recursive: true });
  }

  const [output] = await packager({
    dir: source,
    out: path.join(temporary, 'output'),
    name: productName,
    executableName: process.platform === 'linux' ? name : productName,
    platform: process.platform,
    arch: process.arch,
    electronVersion: manifest.config.electronVersion,
    appVersion: version,
    appBundleId: 'org.joomengine.app',
    appCategoryType: 'public.app-category.developer-tools',
    icon: path.join(root, 'assets', name),
    win32metadata: { CompanyName: author, FileDescription: description, ProductName: productName },
    asar: false,
    prune: false
  });
  // The Windows and Linux executable lives in the release root. On macOS the
  // release root contains the app bundle and the upstream Electron notices.
  await rm(staged, { recursive: true, force: true });
  await rename(output, staged);
  console.log('Staged ' + productName + ' in ' + staged);
} finally {
  await rm(temporary, { recursive: true, force: true });
}

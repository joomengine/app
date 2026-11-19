import { spawn } from 'node:child_process';
import { existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const binary = {
  darwin: 'JoomEngine.app/Contents/MacOS/JoomEngine',
  win32: 'JoomEngine.exe',
  linux: 'joomengine'
}[process.platform];
if (!binary) throw new Error('Unsupported desktop platform: ' + process.platform);
const executable = fileURLToPath(new URL('../dist/staged/' + binary, import.meta.url));
if (!existsSync(executable)) await import('./stage.mjs');
const child = spawn(executable, { stdio: 'inherit' });
child.on('error', error => { console.error(error.message); process.exitCode = 1; });
child.on('exit', code => { process.exitCode = code ?? 1; });

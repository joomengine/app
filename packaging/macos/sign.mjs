import path from 'node:path';
import { sign } from '@electron/osx-sign';

const app = path.resolve(process.argv[2]);
const identity = process.env.APPLE_SIGNING_IDENTITY || '-';
const adHoc = identity === '-';

// Electron includes native frameworks and independent helper apps. Sign those
// inside-out before sealing the outer bundle. V8 needs JIT for JS and Wasm.
await sign({
  app,
  platform: 'darwin',
  identity,
  identityValidation: !adHoc,
  keychain: process.env.APPLE_SIGNING_KEYCHAIN || undefined,
  preEmbedProvisioningProfile: false,
  optionsForFile: () => ({
    entitlements: ['com.apple.security.cs.allow-jit'],
    hardenedRuntime: !adHoc,
    timestamp: adHoc ? 'none' : undefined,
  }),
});

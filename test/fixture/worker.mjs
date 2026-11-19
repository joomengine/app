self.onmessage = async ({ data: { memory, nested } }) => {
  if (!self.crossOriginIsolated || !(memory.buffer instanceof SharedArrayBuffer)) throw Error('Worker lost isolation');
  Atomics.add(new Int32Array(memory.buffer), 0, 1);
  if (nested) {
    const child = new Worker(new URL('./worker.mjs', import.meta.url), { type: 'module' });
    await new Promise((resolve, reject) => {
      child.onmessage = resolve;
      child.onerror = event => reject(Error(event.message));
      child.postMessage({ memory, nested: false });
    });
    child.terminate();
  }
  self.postMessage('ready');
};

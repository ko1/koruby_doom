import { Worker, isMainThread, workerData } from 'node:worker_threads';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
const W = 64, H = 32, FRAME = W * H;
const HERE = fileURLToPath(new URL('.', import.meta.url));
if (!isMainThread) {
  const { mod, rom, src, argv, ctlBuf, fbBuf, palBuf } = workerData;
  const { runGuest } = await import('../run.js');
  await runGuest({ mod, rom, src, argv, mount: '/c8', romName: 'rom.ch8', frameBytes: FRAME,
                   ctlBuf, fbBuf, palBuf, log: l => console.log('[guest]', l) });
} else {
  const frames = Number(process.argv[2] || 150);
  const kind = process.argv[3] || 'new';
  const romFile = process.argv[4] || 'outlaw.ch8';
  const B = {
    new:    { wasm: 'c8.wasm' },
    interp: { wasm: '../koruby-interp.wasm', src: 'c8_web.rb', argv: ['koruby', '--plain', '/c8/c8_web.rb'] },
    ruby:   { wasm: '../ruby.wasm', src: 'c8_web.rb', argv: ['ruby', '/c8/c8_web.rb'] },
  }[kind];
  const mod = await WebAssembly.compile(readFileSync(HERE + B.wasm));
  const rom = readFileSync(HERE + 'roms/' + romFile);
  const src = B.src ? readFileSync(HERE + B.src) : null;
  const ctlBuf = new SharedArrayBuffer(16), fbBuf = new SharedArrayBuffer(FRAME), palBuf = new SharedArrayBuffer(768);
  const ctl = new Int32Array(ctlBuf), fb = new Uint8Array(fbBuf);
  new Worker(new URL(import.meta.url), { workerData: {
    mod, rom: rom.buffer.slice(rom.byteOffset, rom.byteOffset + rom.byteLength),
    src: src ? src.buffer.slice(src.byteOffset, src.byteOffset + src.byteLength) : null,
    argv: B.argv, ctlBuf, fbBuf, palBuf } }).on('error', e => { console.error(e); process.exit(1); });
  const t0 = Date.now();
  for (let i = 0; i < frames; i++) {
    Atomics.store(ctl, 1, 0); Atomics.add(ctl, 0, 1); Atomics.notify(ctl, 0);
    for (let g = 0; g < 2000000 && Atomics.load(ctl, 2) < i + 1; g++) await new Promise(r => setImmediate(r));
    if (Atomics.load(ctl, 2) < i + 1) { console.error('timeout'); process.exit(1); }
  }
  let lit = 0; for (let p = 0; p < FRAME; p++) lit += fb[p];
  console.log(`${kind} ${romFile}: ${frames} frames in ${((Date.now() - t0)/1000).toFixed(2)}s, 点灯 ${lit}/${FRAME}`);
  if (lit === 0) { console.error('画面が空'); process.exit(1); }
  process.exit(0);
}

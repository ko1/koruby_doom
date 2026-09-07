import { Worker, isMainThread, workerData } from 'node:worker_threads';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
const W = 384, H = 736, FRAME = W * H * 3;
const HERE = fileURLToPath(new URL('.', import.meta.url));
if (!isMainThread) {
  const { mod, rom, src, argv, ctlBuf, fbBuf, palBuf } = workerData;
  const { runGuest } = await import('../run.js');
  await runGuest({ mod, rom, src, argv, mount: '/t', romName: 'unused.bin', frameBytes: FRAME,
                   ctlBuf, fbBuf, palBuf, log: l => console.log('[guest]', l) });
} else {
  const frames = Number(process.argv[2] || 20);
  const kind = process.argv[3] || 'new';
  const B = {
    new:    { wasm: 'tetris.wasm' },
    interp: { wasm: '../koruby-interp.wasm', src: 'tetris_web.rb', argv: ['koruby', '--plain', '/t/tetris_web.rb'] },
    ruby:   { wasm: '../ruby.wasm', src: 'tetris_web.rb', argv: ['ruby', '/t/tetris_web.rb'] },
  }[kind];
  const mod = await WebAssembly.compile(readFileSync(HERE + B.wasm));
  const src = B.src ? readFileSync(HERE + B.src) : null;
  const ctlBuf = new SharedArrayBuffer(16), fbBuf = new SharedArrayBuffer(FRAME), palBuf = new SharedArrayBuffer(768);
  const ctl = new Int32Array(ctlBuf), fb = new Uint8Array(fbBuf);
  new Worker(new URL(import.meta.url), { workerData: {
    mod, rom: new ArrayBuffer(0),
    src: src ? src.buffer.slice(src.byteOffset, src.byteOffset + src.byteLength) : null,
    argv: B.argv, ctlBuf, fbBuf, palBuf } }).on('error', e => { console.error(e); process.exit(1); });
  const t0 = Date.now();
  for (let i = 0; i < frames; i++) {
    Atomics.store(ctl, 1, i === 3 ? (1 << 4) : 0);   // 開始のため Space を 1 回
    Atomics.add(ctl, 0, 1); Atomics.notify(ctl, 0);
    for (let g = 0; g < 4000000 && Atomics.load(ctl, 2) < i + 1; g++) await new Promise(r => setImmediate(r));
    if (Atomics.load(ctl, 2) < i + 1) { console.error('timeout'); process.exit(1); }
  }
  const cols = new Set();
  for (let p = 0; p < FRAME; p += 3) cols.add(fb[p] << 16 | fb[p+1] << 8 | fb[p+2]);
  console.log(`${kind}: ${frames} frames in ${((Date.now()-t0)/1000).toFixed(2)}s, 色数 ${cols.size}`);
  if (cols.size < 2) { console.error('画面が単色'); process.exit(1); }
  process.exit(0);
}

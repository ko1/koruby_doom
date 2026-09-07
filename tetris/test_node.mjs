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
  // 落下中のミノの一番下の行。block_size は 32 (`30 + 2 * margin = 1` は
  // margin に 1 を代入してから足す)、盤面は y=64 から 20 行。枠は gray、背景は黒。
  const BLOCK = 32, TOP = BLOCK * 2;
  const lowestBlockRow = () => {
    let low = -1;
    for (let y = TOP; y < TOP + BLOCK * 20; y++) {
      const base = y * W * 3;
      for (let x = 0; x < W; x++) {
        const o = base + x * 3, r = fb[o], g = fb[o + 1], b = fb[o + 2];
        if ((r | g | b) === 0) continue;                       // 背景
        if (r === 128 && g === 128 && b === 128) continue;     // 枠
        low = y; break;
      }
    }
    return low;
  };

  const tick = async (i, k) => {
    Atomics.store(ctl, 1, k);
    Atomics.add(ctl, 0, 1); Atomics.notify(ctl, 0);
    for (let g = 0; g < 4000000 && Atomics.load(ctl, 2) < i + 1; g++) await new Promise(r => setImmediate(r));
    if (Atomics.load(ctl, 2) < i + 1) { console.error('timeout'); process.exit(1); }
  };

  const t0 = Date.now();
  let i = 0;
  // 何も押さない。rbtris は起動時に reset を呼ぶので開始のキーは要らず、
  // Space はむしろポーズになる (画面全体が半透明の板で覆われる)。
  for (; i < frames; i++) await tick(i, 0);
  const elapsed = (Date.now() - t0) / 1000;

  const cols = new Set();
  for (let p = 0; p < FRAME; p += 3) cols.add(fb[p] << 16 | fb[p+1] << 8 | fb[p+2]);
  console.log(`${kind}: ${frames} frames in ${elapsed.toFixed(2)}s, 色数 ${cols.size}`);
  if (cols.size < 2) { console.error('画面が単色'); process.exit(1); }

  // 下キー。rbtris がこれを見るのは :key_held だけなので、ホストが 2 フレーム
  // 続けて同じビットを渡せていないと 1 行も落ちない (run.js の TickStdin が
  // 1 バイトのゲストに上位バイトを混ぜていた時がそれ)。
  const before = lowestBlockRow();
  for (let n = 0; n < 5; n++, i++) await tick(i, 1 << 3);
  const after = lowestBlockRow();
  console.log(`  下キー 5 フレーム: 最下行 ${before} → ${after} (${((after - before) / BLOCK).toFixed(1)} 行)`);
  if (before < 0 || after - before < BLOCK * 3) {
    console.error('下キーでミノが落ちていない'); process.exit(1);
  }
  process.exit(0);
}

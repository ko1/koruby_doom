# koruby DOOM — pure Ruby, AOT-compiled, in the browser

Pure-Ruby DOOM (the renderer from ASTro の `sample/rubyharness/apps/doom`) を
koruby_precise が単一の `.wasm` に焼いたもの。prelude・プログラム・全メソッド本体が
埋め込んであり、Worker で動いて canvas に描く。ラジオボタンで 3 構成を切り替えられる。

操作: `W`/`S` 前後、`A`/`D` 横移動、`←`/`→` 旋回。

## ローカルで見る

```sh
python3 serve.py            # http://127.0.0.1:8000/
```

`python3 -m http.server` では動かない。COOP/COEP が要るため (下記)。

## アップロードするとき

**必要な条件は 1 つだけ: ページが cross-origin isolated であること。**
ゲストは次のフレームを待つのに `Atomics.wait` で止まる。そのために
`SharedArrayBuffer` が要り、そのために COOP/COEP が要る。

3 通りの手当てを同梱してある。どれか 1 つが効けばよい。

| 置き場所 | 効くもの |
|---|---|
| Netlify / Cloudflare Pages | `_headers` |
| Vercel | `vercel.json` |
| Apache | `.htaccess` |
| GitHub Pages など、ヘッダを設定できない静的ホスト | `coi-serviceworker.js` (index.html が読み込む。https 必須。初回だけ自動でリロードする) |

うまくいっていれば画面が出る。駄目なら「SharedArrayBuffer が使えません」と表示される。

### GitHub Pages

使える。ヘッダを設定できないので `coi-serviceworker.js` の経路になる (https なので条件は満たす)。
そのまま push すればよい。確認したこと:

- 最大ファイルは `doom.wasm` 16.1 MB。GitHub の警告 (50 MB) にも上限 (100 MB) にも遠い
- **Git LFS は使わないこと。** GitHub Pages は LFS のファイルを配信せず、ポインタが返る
- `.wasm` の Content-Type は問題にならない。`WebAssembly.compile(arrayBuffer)` で読んでいて
  `compileStreaming` を使っていないため
- service worker の scope は置いたディレクトリ配下になるので、`user.github.io/repo/` に
  丸ごと置けばページを覆う
- `.nojekyll` を同梱済み (`_headers` のような下線始まりを Jekyll に無視させないため)

**未確認**: ブラウザが手元に無いので、service worker が実際に cross-origin isolation を
成立させるところだけは目で見ていない。駄目な場合は上記のメッセージが出る。

`.wasm` は `Content-Type: application/wasm` で配れると起動が速い
(`WebAssembly.compileStreaming` の条件)。合計 78 MB あるので、gzip や brotli を
有効にしておくとよい (`.wasm` は 3 割ほどに縮む)。

## 4 つの構成

同じ Ruby のプログラムを 4 つのランタイムで動かす。切り替えると Worker を
作り直して最初から走る。

| 選択肢 | ファイル | 中身 |
|---|---|---|
| koruby AOT 新（穴 + pool） | `doom.wasm` 16.1 MB | site 固有値をノードごとの表から読む |
| koruby AOT 旧（穴なし） | `doom-old.wasm` 15.3 MB | 実行のたびにノードを辿る |
| koruby インタプリタ | `koruby-interp.wasm` 4.3 MB | 木を辿るだけ |
| ruby.wasm (CRuby 3.4) | `ruby.wasm` 23.8 MB | 比較対象 |

AOT の 2 つはプログラムを埋め込んである。インタプリタと ruby.wasm は外から
渡すので `doom_web.rb` も要る。

実測 (DOOM 30 フレーム, wasmtime, 事前コンパイル, 専有機):

| | 実行時間 |
|---|---|
| ruby.wasm 3.4.1 | 4,393 ms |
| koruby インタプリタ | 1,948 ms |
| koruby AOT | 582 ms |

ruby.wasm 比 7.5 倍、インタプリタ比 3.3 倍。AOT の新旧差は 588 → 582 ms で
ばらつきの中 (L1d ミスは 18.8% 減るが、wasm では命令が詰まっていて
サイクルに変わらない。ネイティブでは 610 → 510 ms、−16.4%)。

## 仕組み

```
page (main thread)                         Worker
  requestAnimationFrame                      koruby_precise.wasm
    ├─ SAB からフレームを読んで canvas へ      stdin  ← tick ごとに 1 バイト
    └─ tick: キー + Atomics.notify   ──▶      stdout → 320x240 のパレット indices
```

ゲストはただの WASI プログラムで、ブラウザのことを何も知らない。Worker 側は
その 2 つの fd だけ (`doom_run.js`)。ペースは host が握るので、ページが
レンダラを追い越すことも、レンダラがページを溢れさせることもない。
worker はブロックしてよく main thread はブロックできない、というのが
ゲストを worker で動かす理由。

## ファイル

| | |
|---|---|
| `index.html` | canvas、キー、パレット → RGB、tick ループ、構成の切り替え |
| `doom_run.js` | 2 つの fd と WASI の設定 (ブラウザと Node で共有) |
| `worker.js` | ブラウザ側の glue |
| `shim/` | [@bjorn3/browser_wasi_shim](https://github.com/bjorn3/browser_wasi_shim) |
| `coi-serviceworker.js` | ヘッダを設定できないホスト向け |
| `serve.py` | ローカル用 (COOP/COEP を返す) |
| `test_node.mjs` | ブラウザ無しの確認 |
| `ruby.wasm` | [ruby/ruby.wasm](https://github.com/ruby/ruby.wasm) 2.10.1 の wasip1-minimal ビルド |

## ブラウザ無しで確かめる

```sh
node test_node.mjs 20 new      # AOT 新
node test_node.mjs 20 old      # AOT 旧
node test_node.mjs 20 interp   # koruby インタプリタ
node test_node.mjs 20 ruby     # ruby.wasm
```

`doom_run.js` をブラウザと同じ経路で駆動し、フレームが空でないこととパレットが
届くことを確認する。

## 既知の不具合

wasm32 では 64 ビットの符号なしリテラルが負になる
(`0xffff_ffff_ffff_ffff` → `-1`)。シフトも乗算も正しいので描画は一致するが、
ヘッドレス版の checksum だけが native と食い違う。koruby のインタプリタでも
旧 AOT でも同じなので、この移植とは別の既存バグ。

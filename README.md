# koruby DOOM

**Ruby で書かれたゲームを、AST の部分評価で C に落とし、wasm にして、ブラウザで遊ぶ。**

同じ 1 本の Ruby プログラムを複数のランタイムで走らせ、その場で切り替えて
比べられます。

| | 遊ぶ | 中身 |
|---|---|---|
| **DOOM** | 👉 **[遊ぶ](https://ko1.github.io/koruby_doom/)** | [khasinski/doom](https://github.com/khasinski/doom) — DOOM (1993) の純 Ruby 移植 |
| **Game Boy** | 👉 **[遊ぶ](https://ko1.github.io/koruby_doom/gb/)** | [sacckey/rubyboy](https://github.com/sacckey/rubyboy) — 純 Ruby の Game Boy エミュレータ |
| **NES** | 👉 **[見る](https://ko1.github.io/koruby_doom/nes/)** | [r7kamura/rnes](https://github.com/r7kamura/rnes) — 純 Ruby の NES エミュレータ (3 fps、遊べる速さではない) |
| **CHIP-8** | 👉 **[遊ぶ](https://ko1.github.io/koruby_doom/c8/)** | このリポジトリで書いた解釈系。ROM 10 本を切り替えられる |
| **rbTris** | 👉 **[遊ぶ](https://ko1.github.io/koruby_doom/tetris/)** | [Nakilon/rbtris](https://github.com/Nakilon/rbtris) — Ruby2D のゲームを SDL 抜きで |

DOOM: `W` `S` 前後 / `A` `D` 横移動 / `←` `→` 旋回
Game Boy: `←` `→` `↑` `↓` 十字 / `Z` A / `X` B / `Enter` Start / `Shift` Select

当たり判定・壁ずり・床の高さはエンジン側の `Doom::Game::PlayerPhysics` を
そのまま使っています (Gosu window から切り出されているので、窓が無くても動く)。
敵も武器もドアも動きません — 動かしているのはプレイヤーの移動だけです。

---

## 何がどうなっているか

レンダラは [khasinski/doom](https://github.com/khasinski/doom) — DOOM (1993) の
エンジンを純粋な Ruby に移植したもので、BSP 探索もテクスチャマッピングも
Ruby で書かれています。

それを [ASTro](https://github.com/ko1/astro) の `koruby_precise` が処理します。
ASTro は **AST インタプリタの部分評価**で速くする言語実装フレームワークです。
プログラムの構文木の各部分に対して、その形に特化した C 関数
(specialized dispatcher, SD) を生成し、コンパイルして差し替えます。ディスパッチも
型判定もインライン展開も、その形に対して 1 回だけ済ませてしまう、という考え方です。

DOOM の場合、それが 2000 個ほどの C 関数になり、wasm32-wasip1 に
クロスコンパイルされて 1 本の `.wasm` に収まります。prelude も、プログラムも、
全メソッドの本体も入っているので、実行時のコンパイルは何も起きません。

## 4 つのランタイム

| 選択肢 | ファイル | 中身 |
|---|---|---|
| **koruby AOT 新** | `doom.wasm` 16.1 MB | 部分評価済み。site 固有値はノードごとの表 (pool) から読む |
| koruby AOT 旧 | `doom-old.wasm` 15.3 MB | 部分評価済み。site 固有値は実行のたびにノードを辿って読む |
| koruby インタプリタ | `koruby-interp.wasm` 4.3 MB | 木を辿るだけ。特殊化しない |
| ruby.wasm | `ruby.wasm` 23.8 MB | CRuby 3.4 (比較対象) |

AOT の 2 つはプログラムを埋め込んであります。インタプリタと ruby.wasm は
`doom_web.rb` を外から渡します。**4 つとも同じ Ruby のソースを実行しています。**

### 速さ

DOOM を固定視点で 30 フレーム、wasmtime、全モジュール事前コンパイル済み、
専有機で best of 3:

| | 実行時間 | fps 換算 | ブラウザ (V8) 実測 |
|---|---|---|---|
| ruby.wasm 3.4.1 | 4,393 ms | 6.8 | — |
| koruby インタプリタ | 1,948 ms | 15.4 | 約 30 |
| **koruby AOT** | **582 ms** | **51.5** | **60**（上限に当たっている） |

ruby.wasm 比 **7.5 倍**、koruby インタプリタ比 **3.3 倍**。
ブラウザの 60 fps は `requestAnimationFrame` の上限なので、実力はそれ以上です。
V8 は wasmtime のおよそ 2 倍速いことになります。

### 「穴 (hole) と pool」— AOT 新旧の違い

C にコンパイルすると、構造は同じでもプロセスごとに違う値が残ります。intern 済みの
シンボル ID、inline cache のアドレス、子ノードのポインタ。**旧**はそれを実行の
たびにノードを辿って読んでいました。**新**は、特殊化した関数からそれらを「穴」として
括り出し、ノードごとの密な表 (pool) に集めて `P[k]` で読みます。テンプレート側は
プログラムに依存しなくなるので、別のプログラム間でも共有できます。

ネイティブでは効きます。wasm では効きません:

| DOOM 30 フレーム | L1d ミス | cycles | 実行時間 |
|---|---|---|---|
| ネイティブ x86-64 | −32.9% | −10.4% | 610 → 510 ms |
| wasm32 | −18.8% | −0.9% | 588 → 582 ms |

**pool は wasm でも狙いどおり働いています** — L1d ミスは 18.8% 減ります。
効かないのはその先で、減ったミスがサイクルに変わりません。wasm は 1 フレーム
あたりの命令が 9.64G (ネイティブは 5.49G)、ロードも 2.4 倍で、境界検査と
アドレス計算がそのぶん増えています。命令が詰まっている状態ではメモリ待ちが
アウトオブオーダ実行に隠れてしまい、ミスを減らしても取り出せる時間がありません。
ネイティブは逆に、命令数がほぼ同じ (+1.0%) なのに cycles が 10.4% 減っていて、
待ち時間が実際に律速だったことを示しています。

ネイティブにはさらに「ローダ経路」もあります。同じ C を非 PIC でコンパイルし、
穴を未解決の再配置として残した `.o` を、ノードごとにコピーして実値で埋める
copy-and-patch です。wasm には `dlopen` も実行時 C コンパイラも無いので、
そちらは使えません。設計は ASTro の `docs/idea_code_store.md` §7 にあります。

## 仕組み

```
page (main thread)                          Worker
  requestAnimationFrame                       koruby_precise.wasm
    ├─ SAB からフレームを読んで canvas へ       stdin  ← tick ごとに 1 バイト
    └─ tick: キー + Atomics.notify   ────▶     stdout → 320x240 のパレット indices
```

ゲストは**ただの WASI プログラム**です。1 フレームにつき stdin から 1 バイト読み、
320×240 のパレット indexed フレームを stdout に書く。ブラウザのことは何も
知りません。Worker 側はその 2 つのファイルディスクリプタだけ (`doom_run.js`)。
だから同じコードを Node からも駆動できます (`test_node.mjs`)。

**ペースは host が握ります。** ゲストの stdin read は `Atomics.wait` で止まり、
ページの `requestAnimationFrame` が tick を進めたときだけ 1 フレーム進みます。
ページがレンダラを追い越すことも、レンダラがページを溢れさせることもありません。
worker はブロックしてよく main thread はブロックできない、というのがゲストを
worker で動かす理由です。

## 動かす

### ローカル

```sh
python3 serve.py            # http://127.0.0.1:8000/
```

`python3 -m http.server` では動きません。COOP/COEP が要るためです (下記)。

### ブラウザ無しで確かめる

```sh
node test_node.mjs 20 new      # koruby AOT 新
node test_node.mjs 20 old      # koruby AOT 旧
node test_node.mjs 20 interp   # koruby インタプリタ
node test_node.mjs 20 ruby     # ruby.wasm
```

`doom_run.js` をブラウザと同じ経路で駆動し、フレームが空でないことと
パレットが届くことを確認します。

### どこかに置く

**必要な条件は 1 つ: ページが cross-origin isolated であること。**
`Atomics.wait` に `SharedArrayBuffer` が要り、それに COOP/COEP が要ります。
4 通り同梱してあるので、どれか 1 つが効けば動きます。

| 置き場所 | 効くもの |
|---|---|
| Netlify / Cloudflare Pages | `_headers` |
| Vercel | `vercel.json` |
| Apache | `.htaccess` |
| GitHub Pages などヘッダを設定できないホスト | `coi-serviceworker.js` (https 必須、初回だけ自動リロード) |

駄目なら画面に「SharedArrayBuffer が使えません」と出ます。黙って壊れることは
ありません。

GitHub Pages で確認済み (2026-09-07)。注意点:

- 最大ファイルは `doom.wasm` 16.1 MB。GitHub の警告 (50 MB) にも上限 (100 MB) にも遠い
- **Git LFS は使わないこと。** GitHub Pages は LFS のファイルを配信せず、ポインタが返る
- `.wasm` の Content-Type は問題にならない (`WebAssembly.compile(arrayBuffer)` で読んでいる)
- `.nojekyll` 同梱 (`_headers` のような下線始まりを Jekyll に消させない)
- 合計 78 MB。gzip / brotli を有効にすると `.wasm` は 3 割ほどに縮む

## ビルドし直す

[ASTro](https://github.com/ko1/astro) のチェックアウトが要ります。

```sh
cd sample/koruby_precise
make                                     # ネイティブの koruby_precise
make -C wasi                             # インタプリタの wasm

# エンジンをバンドルする (koruby に require が無いので 1 ファイルに連結する)
WAD_PATH=/doom/doom1.wad OUT=/tmp/doom_web.rb sh ../rubyharness/tools/doom_web.sh

# 全埋め込みの AOT wasm
make -C wasi aot PROG=/tmp/doom_web.rb
cp wasi/build/doom_web.wasm <このディレクトリ>/doom.wasm
cp ../rubyharness/apps/doom/doom1.wad <このディレクトリ>/
```

`doom_web.sh` はヘッドレスの `doom.sh` と同じエンジン一式をバンドルし、末尾だけを
「固定レンダ + checksum」から「フレームループ」に差し替えます。

他の 4 つも同じ形です (バンドラは `sample/koruby_precise/tools/`)。

```sh
ROM=/gb/rom.gb  OUT=/tmp/gb_web.rb  sh tools/rubyboy_web.sh
ROM=/nes/rom.nes OUT=/tmp/nes_web.rb sh tools/rnes_web.sh
ROM=/c8/rom.ch8 OUT=/tmp/c8_web.rb  sh tools/chip8_web.sh
RBTRIS=/path/to/rbtris OUT=/tmp/rbt_web.rb sh tools/rbtris_web.sh
```

## ファイル

| | |
|---|---|
| `index.html` | canvas、キー、パレット → RGB、tick ループ、ランタイムの切り替え |
| `worker.js` | ブラウザ側の glue |
| `doom_web.rb` | バンドル済みの DOOM (インタプリタと ruby.wasm 用) |
| `run.js` | 2 つの fd と WASI の設定 (DOOM と Game Boy で共有) |
| `gb/` | Game Boy 版 (rubyboy + Tobu Tobu Girl) |
| `nes/` | NES 版 (rnes + Lan Master) |
| `c8/` | CHIP-8 版 (自前の解釈系 + Octo の examples) |
| `tetris/` | rbTris (Ruby2D shim) |
| `shim/` | [@bjorn3/browser_wasi_shim](https://github.com/bjorn3/browser_wasi_shim) |
| `coi-serviceworker.js` | ヘッダを設定できないホスト向け |
| `serve.py` | ローカル用 (COOP/COEP を返す) |
| `test_node.mjs` | ブラウザ無しの確認 |

## デプロイ後に古いものが出るとき

ページは `.wasm` と WAD を `fetch(..., { cache: 'no-cache' })` で取ります。
GitHub Pages が `max-age=600` を返すので、素の `fetch` だとデプロイ後 10 分は
古い 16 MB のモジュールが返り得るためです。ETag があるので、変わっていなければ
304 で済みます。

それでも古いままなら service worker が残っています。DevTools の
Application → Service Workers で Unregister、Storage → Clear site data、
そのあとリロードしてください。`Ctrl+Shift+R` は、ページが JS の `fetch()` で
取っているぶんには効かないことがあります。

## 既知の不具合

wasm32 では 64 ビットの符号なしリテラルが負になります
(`0xffff_ffff_ffff_ffff` → `-1`)。シフトも乗算も 64 ビット超の値も正しいので
描画は一致しますが、ヘッドレス版の checksum だけが native と食い違います。
koruby のインタプリタでも旧 AOT でも同じなので、この移植とは別の既存バグです。

## Game Boy 版 (`gb/`)

[rubyboy](https://github.com/sacckey/rubyboy) (MIT) はもともと `EmulatorWasm` を
持っていて、`step(direction_key, action_key)` が 1 フレーム進めて 160x144 の
バッファを返します。DOOM のときのように当たり判定を繋ぐ必要はなく、同じ
「1 バイト入れて 1 フレーム出す」の口を付けるだけで済みました。Worker 側の
ランナー (`run.js`) は DOOM と共有しています。

ROM は [Tobu Tobu Girl](https://github.com/SimonLarsen/tobu-tobu-girl)、
自由に配布できる homebrew です。

フレームはパレット indexed ではなく 32bit 色 (`0xAARRGGBB`) がそのまま並ぶので、
ページ側は `ImageData` にコピーするだけです。

実測 (headless, 30〜40 フレーム):

| | Game Boy | DOOM |
|---|---|---|
| koruby AOT | 40 フレーム 0.83 s (48 fps) | 30 フレーム 0.58 s |
| koruby インタプリタ | 40 フレーム 2.53 s (16 fps) | — |
| ruby.wasm | 30 フレーム 1.23 s (24 fps) | — |

Game Boy では **ruby.wasm がインタプリタより速い**という逆転が出ています。
DOOM とは逆で、まだ理由を追っていません。

## NES 版 (`nes/`) — 動くが遅い

エミュレータは [rnes](https://github.com/r7kamura/rnes) (MIT)。
[optcarrot](https://github.com/mame/optcarrot) ではありません。**optcarrot の PPU は
Fiber で CPU と協調していて、koruby の wasm 移植は Fiber を持たない**からです
(`Fiber.new` で即落ちる)。ネイティブなら optcarrot も AOT で動きます。

rnes 側に要ったのは小さなフックだけです。`PartsFactory#renderer` が返す
オブジェクトの `render` は PPU が 1 フレームにつき 1 回呼ぶので、そこにフラグを
立てるだけでフレームの完成を捕まえられます。`Keypad#check` は STDIN を直接
読むので無効化し、代わりに `@buffer` へビットを直接入れます。

罠: rnes は Ruby 2 時代のコードで、`Operation.build` が `new(record)` と書いて
Hash の自動キーワード展開に頼っています。Ruby 3 では通らないのでバンドル側で
当て直しています。

**速度**: AOT で 40 フレーム 12.09 秒 = **3.3 fps**。rnes は optcarrot と違って
最適化されていないので、遊べる速さではありません。出力が CRuby と
バイト単位で完全一致することは確認済みです。

## CHIP-8 版 (`c8/`)

解釈系はこのリポジトリで書きました。CHIP-8 は 4 KB のメモリ、16 本の 8 bit
レジスタ、64x32 の白黒画面、2 本の 60 Hz タイマ、16 キーのキーパッドだけなので、
借りてくるより書くほうが早く、由来も単純になります。SUPER-CHIP は未実装です。

ROM は [Octo](https://github.com/JohnEarnest/Octo) (MIT) の `examples/` を
Octo 自身のアセンブラで組んだものです。ページ上で 10 本を切り替えられます。

入力だけ他と違って 16 ビットあるので、ホストは 1 tick に 2 バイト渡します
(`run.js` の stdin が 2 回目の read で上位バイトを返す)。

**速度**: 150 フレームで AOT 0.27 s、インタプリタ 0.17 s、ruby.wasm 0.23 s。
**インタプリタが AOT より速い**のは、CHIP-8 が軽すぎてモジュールの
インスタンス化 (13 MB 対 4.3 MB) が支配的になるためです。

## rbTris (`tetris/`) — Ruby2D を Canvas に載せ替える

ここまでの 4 つは「Ruby で書かれた別のプログラムを動かすもの」でしたが、
これは **Ruby で書かれたゲームそのもの**です。

[rbTris](https://github.com/Nakilon/rbtris) (MIT、196 行) は
[Ruby2D](https://www.ruby2d.com/) のゲームです。Ruby2D は SDL に C 拡張で繋ぐので、
koruby (C 拡張なし) でも wasm (dlopen なし) でもロードできません。ただし
**API 自体はネイティブではありません** — 図形のリストを描画側が走査するだけです。

そこで `tools/ruby2d_shim.rb` に同名の純 Ruby モジュールを置き、図形を
フレームバッファにラスタライズしています。実装したのは `set`、`Window.update`、
`Window.on(:key_down / :key_held / :key_up)`、`Window.width / height / frames`、
`Rectangle`、`Square`、`Text`、`Font.path`、`show` だけで、rbTris が触るのは
この 8 種類でした。文字は 5x7 のビットマップフォントを内蔵しています。

**ゲーム本体は 1 行も変えていません。** バンドラが外すのは、先頭のフォント
ダウンロード (`open-uri` と `zip` が要る) と `require "ruby2d"` の 2 行だけです。
`Mutex` と `Dir.home` は shim 側で用意しています (wasm に HOME は無い)。

**速度** (`tetris/test_node.mjs` で 20 フレーム、Node 上):

| | 20 フレーム | fps 換算 |
|---|---|---|
| koruby インタプリタ | 5.38 s | 3.7 |
| ruby.wasm 3.4.1 | 4.89 s | 4.1 |
| **koruby AOT** | **0.97 s** | **20.6** |

ここだけ ruby.wasm が koruby インタプリタより速いのは、負荷の中身が
DOOM とは違うためです。画面が 384x736 と大きく、時間のほとんどは shim の
ラスタライズ (`fill_rect` の素の Ruby ループ) に行きます。AOT はそこが
効いて 5.5 倍。

## 出どころ

| | |
|---|---|
| DOOM エンジン (Ruby) | [khasinski/doom](https://github.com/khasinski/doom) — GPL-2.0 |
| koruby_precise / ASTro | [ko1/astro](https://github.com/ko1/astro) |
| WASI shim | [@bjorn3/browser_wasi_shim](https://github.com/bjorn3/browser_wasi_shim) — MIT / Apache-2.0 (`shim/` に同梱) |
| ruby.wasm | [ruby/ruby.wasm](https://github.com/ruby/ruby.wasm) 2.10.1 の wasip1-minimal ビルド |
| Game Boy エミュレータ | [sacckey/rubyboy](https://github.com/sacckey/rubyboy) — MIT |
| `gb/rom.gb` | [Tobu Tobu Girl](https://github.com/SimonLarsen/tobu-tobu-girl) — 自由に配布できる homebrew |
| NES エミュレータ | [r7kamura/rnes](https://github.com/r7kamura/rnes) — MIT |
| `nes/rom.nes` | [Lan Master](http://www.romhacking.net/homebrew/2/) — Public domain |
| `c8/roms/*.ch8` | [Octo](https://github.com/JohnEarnest/Octo) の examples — MIT |
| rbTris | [Nakilon/rbtris](https://github.com/Nakilon/rbtris) — MIT |
| `doom1.wad` | id Software の DOOM シェアウェア WAD (Episode 1) |

# 3. 安定版 `Docker image` をローカルで正しく構成して使うための総合手順書

## この文書の立場

この文書は、あなたが**最終的に読む 1 本**として書いています。

目的は、現在手元にある OSS の**安定版** `Docker image` を、

- 何も設定しないまま雑に起動して偶然動くことを期待する使い方

から、

- 状態の置き場
- 設定の置き場
- 翻訳サービスの選び方
- ローカル `Docker` から外部 API / proxy / `Ollama` へ到達する構成
- 実験経路と安定経路の切り分け

までを意識した**再現性のある運用**へ移すことです。

今回の中心は**実装改修ではありません**。  
中心は、**正しい利用方法と構成を先に押さえること**です。

---

## 0. まず結論

今回のように、

- `docker pull byaidu/pdf2zh`
- `docker run -d -p 7860:7860 byaidu/pdf2zh`

だけで起動し、

- GUI に PDF を投げ
- experimental な経路に触れ
- そのまま例外を見る

という使い方は、**最小起動の確認**としては意味がありますが、  
**本番的なローカル利用の構成**としては不足しています。

最初に押さえるべき本質は次の 7 点です。

1. 安定版 image と `next` / `v2` ドキュメントを混同しない。
2. `config.json` と cache の保存先をコンテナ外へ明示的に逃がす。
3. `GUI` は操作面であり、構成面の唯一の真実ではない。
4. まずは `Google` / `Bing` などの単純経路で smoke test を通す。
5. その後、まず `OpenAI API` を主系統として構成し、作業を完了できる状態を作る。
6. 次に `BabelDOC` / `precise` / 実験経路を、別レーンとして評価する。
7. 最後に `Ollama` を、ローカル LLM と Docker network の設計を伴う別レーンとしてまとめる。

この順序を守るだけで、今回のような「何が足りないのか分からないまま experimental path に入る」混乱と、「OpenAI で先に終えられる作業まで local LLM や実験経路で複雑化してしまう」混乱を同時に減らせます。

---

## 1. どのドキュメントをどう信じるべきか

今回あなたが提示した資料は量が多く、しかも世代差があります。  
したがって、最初に**文書の優先順位**を固定するのが本質的です。

### 1.1 最優先で使う文書

安定版 `byaidu/pdf2zh` の local container 運用について、まず基準にすべきなのは次です。

- root `README.md`
- root `docs/ADVANCED.md`
- root `docs/README_GUI.md`
- root `docs/PROXY_CONFIGURATION.md`

この 4 つが、今回の stable image の利用と設定の中心です。

### 1.2 補助的に使う文書

次は、そのままコピーして使うというより、**概念理解の補助**として使うのが妥当です。

- `pdf2zh/kernel/PDFMathTranslate-next.git/README.md`
- `pdf2zh/kernel/PDFMathTranslate-next.git/docs/ja/getting-started/*`
- `pdf2zh/kernel/PDFMathTranslate-next.git/docs/ja/advanced/advanced.md`
- `pdf2zh/kernel/PDFMathTranslate-next.git/docs/ja/advanced/Language-Codes.md`

これらは 2.x / `next` 側の構成思想を知るには役立ちます。

ただし、そのまま stable image に適用すると危険です。

### 1.3 今回の local Docker 構成では主対象ではない文書

以下は今回の中心からは外れます。

- root `docs/APIS.md`
  - これは API / Redis / backend 利用寄りであり、今の WebUI ローカルコンテナ運用とは別レーンです。
- root `docs/CODE_OF_CONDUCT.md`
  - 重要なコミュニティ文書ですが、利用構成の手順書としては無関係です。

### 1.4 明示的に注意して扱うべき文書

以下は、そのまま権威資料として使うべきではありません。

- `pdf2zh/kernel/PDFMathTranslate-next.git/docs/ja/APIS.md`
  - 文書自体に「古くなっているので参照しないでください」と明示されています。
- `pdf2zh/kernel/PDFMathTranslate-next.git/docs/ja/advanced/Documentation-of-Translation-Services.md`
  - 情報量は多いですが、AI 生成由来の揺れや重複、内部不整合がかなり混ざっています。

したがって、今回の構成判断では

- stable docs を一次資料
- next docs を二次資料
- outdated / AI-generated noise の多い docs は参考程度

という秩序で扱うのが最も安全です。

---

## 2. 今手元にあるものは何か

今回あなたが手元で動かしているのは、まず**安定版 1.x 系**の `Docker image` です。

stable root `README.md` から読み取れる重要点は次の通りです。

- stable project は `Byaidu/PDFMathTranslate`
- Docker image は `byaidu/pdf2zh`
- GUI 起動は `pdf2zh -i`
- `BabelDOC` は experimental backend として言及されている
- 近年は `--mode precise` で v2 kernel を隔離環境で使う流れが導入されつつある
- 2.0 は別 repository `PDFMathTranslate/PDFMathTranslate-next` へ移った

つまり、**stable 1.x の器の中に、2.x への橋が差し込まれ始めている状態**です。

このため、

- stable image を使っているのに
- next docs のオプション体系をそのまま当てる

と混乱しやすいのです。

---

## 3. 今回のエラーをどう理解すべきか

まず重要なのは、今回のエラーを

- 「単純に設定不足」
- 「API key 入れ忘れ」
- 「Docker 起動失敗」

だけで説明しないことです。

今回あなたが示した GUI 状況では

- `Service = Bing`
- PDF は渡っている
- `Parse Page Layout` までは進んでいる
- その後で `file_mono` 周りの例外が見えている

という順です。

この流れから見て、本質的な意味は次のように読むのが妥当です。

### 3.1 何が起きているか

- 入力受理までは出来ている
- GUI 自体の起動は出来ている
- レイアウト解析フェーズには入っている
- しかし experimental な翻訳経路が最後まで正常完了できていない

### 3.2 何を意味しないか

この例外は直ちに

- root 設定が全く足りない
- 必須 env が不足している
- stable image が丸ごと使えない

ことを意味しません。

### 3.3 今回の運用判断

今回のような状況では、

- まず stable image の**標準経路**
- つぎに再現性のある `config.json`
- その後、まず `OpenAI API`
- 次に `BabelDOC` / `precise`
- 最後に `Ollama`

という順序で整理し直すのが正しいです。

要するに、今回の例外は「設定の必要性」を示す一方で、  
同時に「experimental path を最初の動作確認に使うべきではない」ことも示しています。

---

## 4. 安定版 local Docker 運用の基本設計

ここからが本題です。

安定版 `Docker image` をローカルで本当に使える形にするには、最低でも次の 2 つの状態を明示的に持つべきです。

### 4.1 アプリ状態

これは「翻訳サービス設定や cache など、アプリの記憶」です。

主に含まれるもの:

- `~/.config/PDFMathTranslate/config.json`
- `~/.cache/pdf2zh/cache.v1.db`

### 4.2 作業状態

これは「今回翻訳した PDF や生成物」です。

主に含まれるもの:

- GUI でアップロードした元 PDF
- mono PDF
- dual PDF
- そのセッション中に作られた中間ファイル群

stable image では GUI 作業ファイルは典型的に `/app/pdf2zh_files` 側へ寄ります。

---

## 5. まず決めるべき運用レーン

いきなり全部を有効化しないことが重要です。  
先に自分がどの運用レーンにいるかを決めます。

### レーン A: まず stable に動くことを確認する

使うもの:

- `Google`
- `Bing`

特徴:

- API key 不要
- smoke test に向く
- 最初の 1 ページ確認に最適

### レーン B: 先に `OpenAI API` で作業を完了する

使うもの:

- `OpenAI`

特徴:

- endpoint / model / key を明示的に構成できる
- 今回の「先に完了させる」主系統に最も向く

### レーン C: `BabelDOC` / `precise` を第二段階で試す

使うもの:

- `Use BabelDOC`
- `--babeldoc`
- `--mode precise`
- `next` / `v2`

特徴:

- OpenAI baseline のあとに試すべき
- 最初の基準系にしてはいけない

### レーン D: 最後に `Ollama` をローカルで組み込む

使うもの:

- `Ollama`
- `OpenAI-liked`
- 必要に応じて host gateway / Docker network

特徴:

- local-first な構成を作りやすい
- ただし Docker network の理解が必要

今回のあなたの状況では、**まず A、つぎに B、その後に C、最後に D** という順で進めるのが最も健全です。

---

## 6. ドキュメントを踏まえた推奨ディレクトリ設計

ホスト側では、最低でも次のように分けるのがよいです。

```text
project-root/
  config/
    config.json
  state/
    home/
  work/
    pdf2zh_files/
```

意味は次の通りです。

- `config/config.json`
  - あなたが明示的に管理する設定ファイル
- `state/home`
  - コンテナ内 `HOME`
  - `config.json` と cache の基準ディレクトリ
- `work/pdf2zh_files`
  - GUI が生成する作業ファイル群

こうしておくと、

- コンテナを作り直しても設定が消えにくい
- cache を維持できる
- 生成物の場所が明確
- 実験設定と成果物が混ざりにくい

という利点があります。

---

## 7. `config.json` を最初に外出しする

今回は「何も初期設定を行わないまま使っていた」ことが混乱の根本なので、  
まず `config.json` を**ホスト側で管理する**形に移すべきです。

### 7.1 最小構成の `config.json`

まずは以下のような最小版から始めるのが安全です。

この repo には、次の実ファイルを既に置いてあります。

- `config/config.json`
  - まず使う `OpenAI` 主系統
- `config/config.precise.json`
  - `OpenAI` を保ったまま、第二段階で `BabelDOC / precise` を試すための設定
- `config/config.ollama.json`
  - 最後に `Ollama` をローカルで組み込むための設定

まずは `config/config.json` を編集して使うのが最短です。

```json
{
  "PDF2ZH_LANG_FROM": "English",
  "PDF2ZH_LANG_TO": "Japanese",
  "translators": []
}
```

この段階では、

- API key
- `ENABLED_SERVICES`
- `HIDDEN_GRADIO_DETAILS`
- `NOTO_FONT_PATH`

を無理に入れません。

理由は単純で、**最初の目的は stable baseline の確認**だからです。

### 7.2 `NOTO_FONT_PATH` を最初から入れない理由

stable docs の例には `NOTO_FONT_PATH` が出てきますが、  
そのパスはイメージや同梱資産の実体と噛み合っていることを確認してから使うべきです。

つまり、

- docs にサンプルがある
- だから必須

とは読まない方がよいです。

`NOTO_FONT_PATH` は**必須初期設定ではなく、必要時の明示的 override**として扱う方が安全です。

### 7.3 数学論文では `PDF2ZH_VFONT` が実務上かなり重要

今回のように GUI だけで使う場合、stable 1.x で実際に前もって仕込める数式保護系の persistent 設定として重要なのが `PDF2ZH_VFONT` です。

これは GUI の

- `Custom formula font regex (vfont)`

の初期値として使われます。  
今回 `config/config.json`・`config/config.precise.json`・`config/config.ollama.json` に入れた強めの regex は、このためです。

意味としては、

- `CM`
- `MS`
- `TeX`
- `Mono`
- `Code`
- `Ital`
- `Sym`
- `Math`

など、数式や記号に寄りやすいフォント系を、翻訳テキストではなく**式として保持しやすくする**方向の補助です。

ここで重要なのは、stable GUI では

- `formular_font_pattern` 相当は実質触りやすい
- `formular_char_pattern` 相当は GUI-only では触りにくい

という非対称性があることです。

したがって、GUI-only で数式保持の精度を上げたいなら、まず `PDF2ZH_VFONT` を明示的に持つことが、本質的な一歩になります。

### 7.4 `PDF2ZH_VFONT` を変えたら cache を疑う

数式フォント regex を変えたのに結果が変わらない場合、  
「設定が効いていない」と即断する前に、GUI で `Ignore cache` を有効にした次の検証を行うべきです。

理由は、翻訳 cache が前回の挙動を残して見かけを鈍らせるからです。

---

## 8. 実運用では `docker run` より `compose` を推奨する

`docker run` 単発は最小確認には向いています。  
しかし今回のように、構成をきちんと持たせたい場合は、`docker compose` の方が再現性が高いです。

理由:

- `HOME`
- `volume`
- `config`
- `env`
- `port`
- `extra_hosts`

を宣言的に固定できるからです。

### 8.1 安定版 image を前提にした推奨 `compose`

以下は、**すでに image を持っている**前提の stable local 構成です。

```yaml
services:
  pdf2zh:
    image: byaidu/pdf2zh:latest
    container_name: pdf2zh-stable
    ports:
      - "7860:7860"
    environment:
      HOME: /state/home
      PYTHONUNBUFFERED: "1"
      # モデル取得が不安定な環境のみ:
      # HF_ENDPOINT: "https://hf-mirror.com"
    volumes:
      - ./state/home:/state/home
      - ./work/pdf2zh_files:/app/pdf2zh_files
      - ./config/config.json:/state/home/.config/PDFMathTranslate/config.json
    command:
      - pdf2zh
      - -i
      - --config
      - /state/home/.config/PDFMathTranslate/config.json
    restart: unless-stopped
```

### 8.2 この構成の意味

- `HOME=/state/home`
  - `config.json` と cache の基準場所を固定
- `./state/home:/state/home`
  - app state を永続化
- `./work/pdf2zh_files:/app/pdf2zh_files`
  - GUI 作業ファイルを永続化
- `--config /state/home/.config/PDFMathTranslate/config.json`
  - どの設定ファイルを読むかを明示

この形にしておけば、`docker run` の都度「今回はどこに設定が書かれたのか」を悩まずに済みます。

---

## 9. まず通すべき初回確認

この段階では、まだ API 系や `Ollama` に進みません。

### 9.1 初回確認の目的

見るべきは、次の 4 点だけです。

- GUI が正常に開く
- PDF を投入できる
- 1 ページだけ翻訳できる
- 出力ファイルがホスト側 `work/pdf2zh_files` に残る

### 9.2 初回確認の推奨条件

- `Service`: `Google` を第一候補
- `Translate from`: `English`
- `Translate to`: `Japanese`
- `Pages`: `First` あるいは最小ページ範囲
- `number of threads`: `1` か `2`
- `Use BabelDOC` / `precise` / experimental path: 触らない

### 9.3 なぜ `Google` を第一候補にするか

stable docs では `Google` と `Bing` が無認証で使いやすいですが、  
`next` 側の整理では `Google` / `DeepL` がより中心的に扱われ、`Bing` はやや弱い位置づけです。

今回すでに `Bing` で例外を見ている以上、

- 同じ条件で `Bing` に固執する

よりも、

- まず `Google` で stable baseline を取り直す

方が運用判断として自然です。

### 9.4 なぜ `threads` は小さくするか

stable 1.x docs では `-t` しか露出していません。  
`next` docs のような `--qps` / `--pool-max-workers` は stable image の主たる調整面ではありません。

したがって stable image では、

- まず `threads=1`
- 次に `2`
- それで十分通るなら必要に応じて増やす

という保守的な運用が妥当です。

---

## 10. stable で使える主要オプションの意味

stable docs を基準に、local Docker 運用で意味が大きいものを整理します。

### 10.1 `-p`

部分翻訳です。  
最初の動作確認には非常に重要です。

使い所:

- 大きい論文の全部をいきなり流さない
- 問題のある PDF で first page / small range だけ確認する

### 10.2 `-t`

threads 数です。  
stable では rate limiting 設計の代理パラメータとして扱うのが現実的です。

使い所:

- 上流 API が弱いときは下げる
- ローカル smoke test は低めで始める

### 10.3 `--skip-subset-fonts`

出力互換性に効く安定版の重要オプションです。

使い所:

- 出力 PDF の表示がおかしい
- フォント周りの相性が疑わしい

### 10.4 `--ignore-cache`

キャッシュを無視して再翻訳します。

使い所:

- 設定を変えたのに結果が同じで混乱する
- cache を意図的に使いたくない

### 10.5 `--prompt`

LLM 系 translator に対する custom prompt 用です。  
`Google` / `Bing` smoke test では優先度が低いです。

### 10.6 `--config`

今回もっとも重要な安定化オプションです。  
「どの設定ファイルを読むのか」を明示できます。

### 10.7 `--authorized users.txt [auth.html]`

stable 1.x の認証付き WebUI はこの形です。  
`next` docs の `--auth-file` / `--welcome-page` とは別物です。

### 10.8 `--share`

ローカル専用なら通常不要です。  
外部露出面を増やすので、最初の local setup では使わない方がよいです。

### 10.9 `--mode precise` / `--babeldoc`

これは stable baseline のあとに試すものです。  
最初から運用の中心に置いてはいけません。

---

## 11. API ベースの translator を stable image に足す方法

stable docs の `ADVANCED.md` と `PROXY_CONFIGURATION.md` を踏まえると、  
API 系 translator の設定は**基本的に `config.json` へ書く**のが最も整理しやすいです。

### 11.1 `OpenAI` を使う場合

```json
{
  "PDF2ZH_LANG_FROM": "English",
  "PDF2ZH_LANG_TO": "Japanese",
  "translators": [
    {
      "name": "openai",
      "envs": {
        "OPENAI_BASE_URL": "https://api.openai.com/v1",
        "OPENAI_API_KEY": "your-api-key",
        "OPENAI_MODEL": "gpt-4o-mini"
      }
    }
  ],
  "ENABLED_SERVICES": [
    "OpenAI"
  ],
  "HIDDEN_GRADIO_DETAILS": true
}
```

### 11.2 ここで重要な注意

`ENABLED_SERVICES` には、stable docs の public-service 例にならって、  
**GUI 表示名**を使う方が安全です。

つまり:

- `OpenAI`
- `Grok`
- `Ollama`
- `OpenAI-liked`

のように書く方が自然です。

`PROXY_CONFIGURATION.md` の末尾には lowercase の例もありますが、  
stable GUI との整合を重視するなら display name を採る方が混乱が少ないです。

### 11.3 `OpenAI API` で先に作業を完了するための実行順序

今回の優先順位では、ここが最重要です。

まず行うべき順序は次です。

1. `config.json` に `OpenAI` だけを明示的に入れる
2. `ENABLED_SERVICES` を使うなら、まず `OpenAI` だけに寄せる
3. stable image を `--config` 付きで起動する
4. GUI では `OpenAI` を選び、`First` page、threads `1`、experimental path off で通す
5. 問題がなければ page range を広げる
6. 全文へ進める

つまり、今回の「まず作業を完了する」という目的に対しては、`OpenAI` を**唯一の主系統として一旦固定する**のが最も重要です。

### 11.4 `OpenAI` フェーズでまだやらないこと

この段階では、次をまだ混ぜない方がよいです。

- `BabelDOC`
- `precise`
- `Ollama`
- `OpenAI` 以外の local LLM 実験

理由は、今ほしいのが「まず成果を出すこと」であり、「複数の不確定要素を同時に増やすこと」ではないからです。

### 11.5 ただし最終的な数学論文の本番レーンは `OpenAI + precise`

今回の要件が

- 数学論文
- 数式・記号・図表・レイアウトを崩したくない
- 日本語での最終成果物の品質を優先したい

である以上、最終的な本番レーンとして自然なのは

- translator: `OpenAI`
- pipeline: `precise`

です。

したがってこの `OpenAI` フェーズの役割は、

- `OpenAI` 自体の translator 設定を固める
- API key / endpoint / model の問題を先に消す

ことであり、  
本番品質の最終形そのものは、その次の `precise` フェーズで完成させる、という理解が適切です。

---

## 12. `OpenAI` フェーズで OpenAI 互換 proxy を使う場合

ここは `PROXY_CONFIGURATION.md` が主資料です。

本質は次の 3 点です。

1. `BASE_URL` の末尾に `/v1` を必ず付ける
2. stream 非互換 proxy では `*_STREAM=false`
3. model 名は proxy 側が実際に提供するものに合わせる

### 12.1 `OpenAI-liked` の例

```json
{
  "PDF2ZH_LANG_FROM": "English",
  "PDF2ZH_LANG_TO": "Japanese",
  "translators": [
    {
      "name": "openailiked",
      "envs": {
        "OPENAILIKED_BASE_URL": "http://your-proxy:8000/v1",
        "OPENAILIKED_API_KEY": "your-api-key",
        "OPENAILIKED_MODEL": "grok-4",
        "OPENAILIKED_STREAM": "false"
      }
    }
  ],
  "ENABLED_SERVICES": [
    "OpenAI-liked"
  ],
  "HIDDEN_GRADIO_DETAILS": true
}
```

### 12.2 `Grok` custom proxy の例

```json
{
  "translators": [
    {
      "name": "grok",
      "envs": {
        "GROK_BASE_URL": "http://your-proxy:8000/v1",
        "GROK_API_KEY": "your-api-key",
        "GROK_MODEL": "grok-4",
        "GROK_STREAM": "false"
      }
    }
  ]
}
```

### 12.3 失敗しやすい点

- `/v1` を落とす
- model 名が proxy 側と合っていない
- proxy が streaming 形式を返すのに `STREAM=true` のまま

この 3 つは、実際には「接続できているのに変なエラーが出る」形を作るので、先に潰すべきです。

---

## 13. `OpenAI` 完了後に `BabelDOC` / `precise` を第二段階として試す

ここは、`OpenAI` で一度作業を完了できたあとに進む段階です。

### 13.1 基本原則

`BabelDOC` / `precise` は、今回の主系統ではありません。

位置付けは次の通りです。

- `OpenAI` 主系統で成果を得たあと
- 比較評価したい場合
- より高い品質や別 backend を試したい場合
- 失敗しても stable lane に戻れる状態で

試すものです。

ただし、今回の要件が「fast に寄らず、数学論文を高精度に扱いたい」である以上、  
**本番品質に最終的に寄せる中心はこのレーン**です。

つまり順序としては

- 先に `OpenAI` 単体を安定化
- その後、最終成果物を高品質化するために `precise` へ上げる

となります。

### 13.2 今回のような失敗を避ける試し方

次を同時に変えないことが重要です。

1. translator
2. page range
3. threads
4. `BabelDOC` / `precise`
5. proxy / local LLM

したがって、`OpenAI` が stable に通っているなら、第二段階では

- translator はまず同じ `OpenAI`
- page は `First`
- threads は `1`
- 変更は `BabelDOC` または `precise` のみ

とするのが本質的です。

さらに数学論文では、ここで次も併せて守る方がよいです。

- `PDF2ZH_VFONT` は先に強めの数式保護 regex にしておく
- `Ignore cache` を on にして、mode 変更の差が実際に観測されるようにする
- 最初の比較は、式・脚注・添字・図表注記が多いページで行う

### 13.3 GUI が古い表現を出す場合

stable image やその GUI 世代によっては、

- `Use BabelDOC`

という表現が見える場合と、

- `Translation Mode`
- `fast` / `precise`

のような表現に移っている場合があります。

この差は、stable image と現行 main / `next` 系との世代差に由来し得ます。  
ここでは UI の見た目に引きずられ過ぎず、

- stable baseline の後で
- 実験 backend を 1 つだけ足す

という原則で扱う方が安全です。

### 13.4 失敗したときの戻り先

ここで失敗しても、判断は単純です。

- その experimental path を一旦保留
- `OpenAI` stable lane に戻る

これでよいです。

`BabelDOC` / `precise` の失敗は、`OpenAI` 主系統まで巻き込んで崩す理由にはなりません。

### 13.5 日本語ターゲットについての読み方

`BabelDOC` の supported languages 文書では、日本語は

- `JA`
- ligature dependency: `None`

として列挙されています。  
これは構造的には不利なターゲットではない、という意味で前向きです。

一方で `BabelDOC` README には、歴史的には英中系が主な焦点であった旨の記述もあります。  
したがって、

- 日本語は構造上は比較的扱いやすい
- しかし実運用では first-page 検証を省略しない

という慎重な読みが適切です。

---

## 14. 最後に `Ollama` を使う場合

ここが local Docker 運用で最も誤解されやすいところです。

### 14.1 stable docs のデフォルト値をそのまま信じてはいけない理由

stable `ADVANCED.md` では `OLLAMA_HOST` のデフォルトが `http://127.0.0.1:11434` です。  
しかし、**コンテナ内の `127.0.0.1` はコンテナ自身**です。

したがって、ホストマシン上で `Ollama` を動かしている場合、

- `OLLAMA_HOST=http://127.0.0.1:11434`

では、普通はホストの `Ollama` へ到達できません。

### 14.2 `next` docs がくれる重要なヒント

`next` の `USAGE_webui.md` では、Docker で `Ollama` を backend LLM とする場合、

- `http://host.docker.internal:11434`

を `Ollama host` に入れるよう案内しています。

これは stable image でも**概念的にはそのまま重要**です。

### 14.3 host 上の `Ollama` を使う構成

```json
{
  "PDF2ZH_LANG_FROM": "English",
  "PDF2ZH_LANG_TO": "Japanese",
  "translators": [
    {
      "name": "ollama",
      "envs": {
        "OLLAMA_HOST": "http://host.docker.internal:11434",
        "OLLAMA_MODEL": "gemma2"
      }
    }
  ],
  "ENABLED_SERVICES": [
    "Ollama"
  ]
}
```

### 14.4 OpenAI 互換 endpoint として `Ollama` を使う構成

```json
{
  "translators": [
    {
      "name": "openailiked",
      "envs": {
        "OPENAILIKED_BASE_URL": "http://host.docker.internal:11434/v1",
        "OPENAILIKED_API_KEY": "ollama",
        "OPENAILIKED_MODEL": "llama3",
        "OPENAILIKED_STREAM": "false"
      }
    }
  ],
  "ENABLED_SERVICES": [
    "OpenAI-liked"
  ]
}
```

### 14.5 Linux での注意

`host.docker.internal` は、環境によってはそのまま解決されないことがあります。

その場合は Docker 側で host gateway へ名前解決を追加する構成を検討します。

例:

```yaml
extra_hosts:
  - "host.docker.internal:host-gateway"
```

これは `Docker` 側のネットワーク補助であり、  
アプリ設定だけでは補えない層の問題です。

### 14.6 別コンテナの `Ollama` を使う構成

もし `Ollama` も compose に入れるなら、同一 Docker network 上で

- `http://ollama:11434`

のように service 名で参照する方が自然です。

この方式は host 依存性を減らせるので、長期的にはよりきれいです。

### 14.7 数学論文の本番系としては `Ollama` は最後に評価する

`Ollama` は local-first で魅力的ですが、今回の要件では

- translator 品質の揺れ
- local model ごとの差
- Docker network 設計

という追加変数を持ち込みます。

したがって、

- 数学論文の最終成果物をまず取りたい

という状況では、`Ollama` は依然として最後に評価するレーンです。

---

## 15. stable image で public / semi-public に近づける場合

今回はローカル運用が中心ですが、少なくとも

- 同一 LAN 内
- 自宅サーバ
- 限定共有

のような使い方まで見据えるなら、次も押さえておくとよいです。

### 15.1 stable 1.x の制御面

stable docs が与える主要な制御は次です。

- `ENABLED_SERVICES`
- `HIDDEN_GRADIO_DETAILS`
- `--authorized users.txt [auth.html]`
- `--share`

### 15.2 まず使うべきもの

- `ENABLED_SERVICES`
  - 使わせるサービス候補を絞る
- `HIDDEN_GRADIO_DETAILS`
  - API key などを GUI 上で露出しにくくする
- `--authorized`
  - 認証を付ける

### 15.3 まだ使わない方がよいもの

- `--share`

これは local setup の初期段階では不要です。  
最初はローカル閉域で構成を安定させる方が先です。

### 15.4 `next` docs から借りられる考え方

`next` docs では public deployment 時に

- sensitive input を無効化
- config auto save を無効化

といった方針が示されています。

stable image では同じ CLI そのものは持たなくても、

- GUI で秘密情報を極力触らせない
- 重要設定はサーバ側 `config.json` で固定する

という思想自体は非常に有益です。

---

## 16. `BabelDOC` / `precise` / `next` をどう位置付けるべきか

ここが今回もっとも誤りやすい部分です。

### 16.1 stable 利用の原則

安定版 image の構成を固めたいなら、

- `Use BabelDOC`
- `--babeldoc`
- `--mode precise`

は**最初の動作確認から外す**べきです。

### 16.2 理由

stable root docs 自体が、

- `--babeldoc` を experimental
- `--mode precise` を v2 / isolated environment

として扱っています。

つまりこれは「使えるなら使ってよいが、最初の baseline ではない」機能です。

### 16.3 今回のエラーとの関係

今回の例外は、まさにこの experimental path に早い段階で触れたことと整合的です。

したがって、今やるべき順序は

1. stable baseline を通す
2. 構成を固定する
3. translator を選ぶ
4. その後に experimental を別テストとして試す

です。

### 16.4 どうしても試すなら

その場合でも次を守るのがよいです。

- `Google` / `Bing` baseline が先に通っている
- 作業対象は first page だけ
- threads は低くする
- 生成物の保存先と logs の観測先が固定されている
- 失敗しても stable lane に戻れる

---

## 17. next docs から何を借り、何を借りないか

### 借りてよいもの

- `Docker` で `WebUI` を使う発想
- `host.docker.internal` を介した `Ollama` 接続の発想
- `pages` / `glossary` / `auth` / `welcome page` の概念
- レート制限は保守的に始めるという思想

### 借りてはいけないもの

- `pdf2zh_next --gui` を stable image でそのまま使う
- `config.v3.toml` を stable image の設定形式だと思う
- `next` 側の全 CLI オプションが stable でも使えると思う
- `next` の translation-service doc の tier 分類や大量の engine 名を stable そのままの権威リストとみなす

### 特に注意する差分

| 項目 | stable 1.x | next / 2.x |
| --- | --- | --- |
| 主 image | `byaidu/pdf2zh` | `awwaawwa/pdfmathtranslate-next` など |
| GUI 起動 | `pdf2zh -i` | `pdf2zh_next --gui` / `pdf2zh --gui` 系 |
| 設定ファイル | JSON | TOML |
| 設定保存先 | `~/.config/PDFMathTranslate` | `~/.config/pdf2zh` |
| キャッシュ | `~/.cache/pdf2zh` | `~/.cache/pdf2zh_next` |

---

## 18. 今回のための推奨ロードマップ

ここまでを踏まえると、あなたの現在位置に対する最適な進め方は次です。

### Phase 1: baseline 復旧

- stable image をそのまま使う
- `config.json` をホスト管理へ移す
- `HOME` と `/app/pdf2zh_files` を volume 化する
- experimental path を触らず
- `Google`
- `First` page
- threads `1`

で通す

### Phase 2: `OpenAI API` で先に作業を完了させる

- `OpenAI` を主系統に固定する
- `config.json` に translator 設定を固定
- `ENABLED_SERVICES` と `HIDDEN_GRADIO_DETAILS` を入れる

### Phase 3: `BabelDOC` / `precise` を別レーンで評価する

- `OpenAI` baseline を崩さずに experimental path を試す
- page は first page のまま
- threads は低く保つ

### Phase 4: 最後に `Ollama` をローカルで組み込む

- host 上の `Ollama` か別コンテナ `Ollama` かを決める
- `host.docker.internal` または Docker network を設計する
- 必要なら `OpenAI-liked` 経由も使う

### Phase 5: 実務的な使い方へ広げる

- page range
- low threads
- `--skip-subset-fonts`
- `--ignore-cache`
- `--authorized`

などを使い分ける

---

## 19. 今回すぐに変えるべき運用習慣

最後に、今回のケースに即して最重要だけを短くまとめます。

### やめるべきこと

- 素の `docker run` だけを状態管理の本体にする
- GUI にだけ設定を持たせる
- stable baseline が無いまま `BabelDOC` を触る
- host の `Ollama` に対してコンテナ内から `127.0.0.1` を使う
- OpenAI 互換 proxy で `/v1` を曖昧にする

### 先にやるべきこと

- `config.json` をホストで管理する
- `HOME` を volume 化する
- `/app/pdf2zh_files` を volume 化する
- `Google` の first page で stable baseline を取る
- その後にまず `OpenAI` を主系統として固定する
- 次に `BabelDOC` / `precise` を試す
- 最後に `Ollama` を組み込む

### 今回のエラーに対する判断

今回の例外は「だから stable image 全体が駄目」という話ではありません。  
むしろ、

- stable 利用の導線
- 設定の置き場
- experimental 機能の位置付け
- `OpenAI` を先に終わらせる順序

を整理し直すべきだ、というシグナルです。

---

## 20. GUI-only 実操作チェックリスト

ここでは、**実際にあなたが GUI だけを触る**前提で、  
数学論文向けに品質と安定性を最大化するための操作順を固定します。

### 20.1 最初に選ぶ構成

最初の本命は次です。

- 設定ファイル: `config/config.precise.json`
- translator: `OpenAI`
- pipeline: `precise`
- target: `Japanese`

ただし、いきなり全文を流さず、まず first page で検証します。

### 20.2 GUI を開いたら最初に見る場所

次を上から順に確認します。

1. `Service`
   - `OpenAI` を選ぶ
2. `Translate from`
   - `English`
3. `Translate to`
   - `Japanese`
4. `Pages`
   - 最初は `First`
5. `Open for More Experimental Options!`
   - `number of threads`: 最初は `1`
   - `Ignore cache`: mode や regex を変えた検証時は on
   - `Custom formula font regex (vfont)`: `config` に入れた強めの regex が出ているか確認
   - `Translation Mode`: `precise`

### 20.3 first-page 精査の目的

この段階の目的は「翻訳できたか」だけでは足りません。  
見るべきは次です。

- 数式が途中で自然言語化されて壊れていないか
- 添字・上付き・記号列が崩れていないか
- 図表キャプションの位置が極端に崩れていないか
- 箇条書き・定理・証明ブロックの段落構造が破綻していないか
- 英語原文と日本語出力の二言語対応が視覚的に追えるか

数学論文では、ここを見ずに「最後まで走ったからよい」と判断してはいけません。

### 20.4 first-page で壊れたときの分岐

#### ケース A: 数式や記号が翻訳されて壊れる

見るべき順:

1. `Translation Mode` が本当に `precise` か
2. `Custom formula font regex (vfont)` が意図した値か
3. `Ignore cache` を on にして再試行したか
4. 問題ページが特殊フォントや特殊記号を多用していないか

この系統では、まず `vfont` と cache を疑うのが本質的です。

#### ケース B: レイアウトや段組が崩れる

見るべき順:

1. まず same page / first page で再現するか
2. `precise` で起きるか、`fast` でも起きるか
3. 問題が図表・脚注・式周辺に集中しているか

ここでは translator より pipeline 側の問題であることが多いです。

#### ケース C: 出力が前回と変わらない

これは cache を疑うべきです。

- `Ignore cache` を on
- same page で再試行

を先に行います。

#### ケース D: `precise` でだけ壊れる

この場合の判断は単純です。

- `OpenAI` 自体の translator 設定は維持
- `precise` 側を保留
- `fast` 側を比較対象として残す

です。

### 20.5 全文へ上げる条件

次を満たしたときだけ、`First` から全文へ上げるのがよいです。

1. first page の数式保持が許容範囲
2. 記号列が壊れていない
3. 図表周辺のレイアウトが致命的に崩れていない
4. キャプションや脚注の可読性が保たれている
5. `precise` で stable に最後まで完走できる見込みがある

### 20.6 全文時の運用

全文時も、最初から極端に攻めない方がよいです。

- `Translation Mode`: `precise`
- translator: `OpenAI`
- `number of threads`: まず `1`
- 問題がなければ `2`
- `Ignore cache`: 通常 off、ただし設定変更直後は on

ここで重要なのは、今回の要件では**速さよりも壊れないこと**が上位だということです。

### 20.7 `fast` をどう扱うか

今回の目的では `fast` を本番系に据えません。  
ただし完全に不要でもありません。

`fast` の役割は次です。

- 比較対照
- `precise` だけで壊れるかの切り分け
- pipeline 依存の失敗と translator 依存の失敗を分ける補助

したがって、`fast` は「戻る先」や「比較対象」として残しますが、  
最終成果物をそこへ寄せる必要はありません。

### 20.8 `Ollama` を GUI-only で触るタイミング

これは最後です。

順序としては

1. `OpenAI + precise` で acceptable な first-page を得る
2. その same page を benchmark にする
3. その後に `Ollama` を同じ page で比較する

です。

数学論文では、いきなり `Ollama` を本番に使うのではなく、  
まず `OpenAI + precise` を品質基準面として確立しておく方が本質的に強いです。

### 20.9 GUI-only で見逃しやすい本質

最後に、GUI-only 運用で特に見逃しやすい本質を短くまとめます。

- config で固定できるものと、GUI で毎回選ぶものは違う
- `precise` は config だけでは on にならず、GUI の mode 切り替えが必要
- `vfont` は persistent に効く重要ノブ
- `Ignore cache` は検証の信頼性に直結する
- 高品質の中心は translator 単体ではなく、`OpenAI + precise + formula protection` の組み合わせ

---

## 21. 最終提案

今回の目的が

- ローカル `Docker` で
- stable image を
- 実際に使える構成で
- なるべく迷わず
- 将来的に API / proxy / `Ollama` まで拡張可能な形で

使うことなら、最初の正解は次です。

1. stable image を基準に据える
2. docs は root stable docs を一次資料にする
3. `config.json` を明示的に外へ出す
4. `HOME` と作業ディレクトリを volume 化する
5. `Google` first-page baseline を先に通す
6. その後、まず `OpenAI` で作業を完了する
7. 次に `BabelDOC` / `precise` を別レーンで試す
8. 最後に `Ollama` を組み込む

この順序は地味ですが、  
今回のような「どこが悪いのか分からないまま複雑な経路に入る」状態を避けるうえで、本質的に強いです。
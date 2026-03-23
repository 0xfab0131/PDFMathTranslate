# 2. 安定版 Docker ローカル運用における設定面の全体地図

## この文書の役割

この文書は、安定版 `byaidu/pdf2zh` を `Docker` でローカル運用する際に、

- どこで設定するのか
- 何がどこへ保存されるのか
- どの設定が stable v1 に属し
- どの設定が `next` / `v2` 文脈に属するのか

を、一つの地図として整理するための補助文書です。

最終手順書では `plan/3` を読むだけで足りるようにする予定ですが、  
その手順書の根拠を支える構造図として、この文書を用意します。

---

## まず結論

安定版 `Docker` 運用では、設定面は大きく次の五層に分かれます。

1. `docker run` / `docker compose` によるコンテナ起動設定
2. コンテナ内の `HOME` と volume 構成
3. アプリ設定ファイル `config.json`
4. 翻訳サービス接続用の環境変数
5. GUI 上の一時的な選択

この五層のうち、再現性に最も効くのは 2 と 3 です。

特に重要なのは次の三点です。

- `config.json` と `cache` は `HOME` に依存して保存先が決まる
- `Docker` で何も volume を張らないと、それらはコンテナの writable layer に閉じる
- `GUI` だけに依存すると、設定の再現性も、複雑なサービス設定の透明性も落ちやすい

---

## 設定面の一覧

| 設定面 | 主な役割 | 永続性 | Docker 運用での重要度 |
| --- | --- | --- | --- |
| `docker run` / `compose` | port, volume, env, command, network | ホスト側定義として永続 | 非常に高い |
| `HOME` | `config.json` と `cache` の基準ディレクトリを決める | volume 化しないと脆い | 非常に高い |
| `config.json` | 翻訳サービス設定、既定言語、GUI 表示制御 | 永続可能 | 非常に高い |
| 環境変数 | translator ごとの endpoint / API key / model 指定 | 起動定義に依存 | 高い |
| GUI の選択 | 実行時のサービス、言語、ページ範囲、実験オプション | その場では効くが再現性は低い | 中程度 |

---

## 安定版 v1 における実際の保存先

root 実装から見ると、安定版 v1 の保存先は概ね次のようになります。

### 1. 設定ファイル

- 既定パス: `~/.config/PDFMathTranslate/config.json`

これは `pdf2zh/config.py` の `ConfigManager` が使います。

### 2. 翻訳 cache

- 既定パス: `~/.cache/pdf2zh/cache.v1.db`

これは `pdf2zh/cache.py` で初期化される `SQLite` DB です。

### 3. GUI 経由の入出力ファイル

- 相対パス: `pdf2zh_files`
- root `Dockerfile` の `WORKDIR` は `/app`

したがって、安定版 image をそのまま動かすと、GUI でアップロードされた PDF や生成物は典型的には `/app/pdf2zh_files` 配下へ入ります。

---

## ここで重要になる `HOME`

`config.json` と `cache` は、どちらも `~` を基準にしています。  
つまり `Docker` で何も工夫しない場合、実際の保存先はコンテナ内の `HOME` に依存します。

root `Dockerfile` は `HOME` を明示していません。  
そのため、一般的にはベース image の既定 `HOME` が使われます。

この状態で `docker run` だけすると、

- `config.json` の作成場所が暗黙的になる
- `cache` の保持がコンテナ内部に閉じる
- 同じ container を `stop/start` する限り残ることはあっても、`rm` した時点で失われる

という運用になります。

この曖昧さを避けるには、`HOME` 自体を明示的に設定し、そのディレクトリを volume 化するのがもっとも本質的です。

---

## 推奨する Docker 設計思想

安定版 image をローカルで丁寧に扱うなら、次の二層を分けて持つのが分かりやすいです。

### 層 A: アプリ状態

- `HOME` に紐づく設定
- `config.json`
- `cache`

### 層 B: 作業ファイル

- GUI upload / output
- 手元の論文 PDF
- 生成された mono / dual PDF

この分離がよい理由は、

- translator 設定と出力ファイルを別々に管理できる
- image を更新しても状態の意味が崩れにくい
- `OpenAI` / `Ollama` / `proxy` 構成を差し替えても作業ディレクトリを汚しにくい

からです。

---

## 実務上おすすめの volume 方針

### 方針 1: `HOME` ごと固定する

例:

- ホスト: `./state/home`
- コンテナ: `/state/home`
- 環境変数: `HOME=/state/home`

この方式にすると、既定の

- `~/.config/PDFMathTranslate/config.json`
- `~/.cache/pdf2zh/cache.v1.db`

がそのまま volume 配下に収まります。

### 方針 2: GUI 作業ファイルを `/app/pdf2zh_files` ごと固定する

例:

- ホスト: `./pdf2zh_files`
- コンテナ: `/app/pdf2zh_files`

こうしておくと、

- GUI でアップロードされた元ファイル
- 生成された mono / dual PDF

をサーバー側でも追跡しやすくなります。

### 方針 3: 入力専用の論文置き場を別 mount してもよい

GUI 中心運用なら必須ではありません。  
ただし CLI 併用や、コンテナ内からローカルディレクトリを直接見せたい場合は有効です。

---

## `config.json` の役割

安定版 v1 において `config.json` は、単なる補助設定ではなく、運用の中心です。

主に次を持てます。

- `PDF2ZH_LANG_FROM`
- `PDF2ZH_LANG_TO`
- `translators`
- `ENABLED_SERVICES`
- `HIDDEN_GRADIO_DETAILS`
- `NOTO_FONT_PATH`
- その他の設定キー

特に `translators` は重要で、translator ごとの `envs` を JSON として持てます。

例:

```json
{
  "translators": [
    {
      "name": "openai",
      "envs": {
        "OPENAI_BASE_URL": "https://api.openai.com/v1",
        "OPENAI_API_KEY": "your-api-key",
        "OPENAI_MODEL": "gpt-4o-mini"
      }
    }
  ]
}
```

---

## 安定版 v1 の環境変数の考え方

安定版 v1 では、translator 用の環境変数は概ねそのままのキー名で読みます。

例えば:

- `OPENAI_BASE_URL`
- `OPENAI_API_KEY`
- `OPENAI_MODEL`
- `OLLAMA_HOST`
- `OLLAMA_MODEL`
- `GROK_BASE_URL`
- `GROK_API_KEY`
- `GROK_MODEL`

などです。

ここで重要なのは、`next` / `v2` 系内部橋渡しに出てくる `PDF2ZH_` 接頭辞付き env と混同しないことです。  
安定版 v1 の通常運用では、translator env は `OPENAI_*` や `OLLAMA_*` そのものです。

---

## 設定の優先順位

安定版資料と実装から見る限り、概念上は次の順で上書きされます。

1. GUI でその場入力された値
2. 環境変数
3. `config.json`
4. 実装のデフォルト

ただし注意点として、安定版 v1 の `ConfigManager` は

- 環境変数から値を読み
- それを `config.json` に書き戻す

という挙動を取ります。

つまり `env` は一時的 override であると同時に、  
起動中に `config.json` を更新して次回へ持ち越すことがあります。

この性質は便利でもありますが、再現性を重んじるなら

- 「何を `compose` で固定し」
- 「何を `config.json` に明示するか」

を意識的に分ける方がよいです。

---

## `ENABLED_SERVICES` の微妙だが重要な性質

GUI 側の実装を見ると、`ENABLED_SERVICES` は display name ベースで照合されます。

つまり `translators[].name` のような

- `openai`
- `ollama`
- `grok`

ではなく、GUI 表示名の

- `OpenAI`
- `Ollama`
- `Grok`

を意識して書く方が自然です。

さらに実装上、`ENABLED_SERVICES` を使っても `Google` と `Bing` はデフォルトで残るように組まれています。  
したがって、「厳密に OpenAI だけに絞る」というよりは、「追加で見せたいサービスを指定しつつ、Google/Bing は残る」と理解しておく方が実態に近いです。

---

## `HIDDEN_GRADIO_DETAILS` の意味

これは GUI 上で API key などの値を隠すための設定です。

ただし、この設定は

- 値を GUI 上で見えにくくする
- `API_KEY` 表示を `***` にする

ためのものであり、秘密情報を暗号化するわけではありません。

本当の値は依然として `config.json` 側に存在し得ます。  
したがって、

- ローカル限定利用なら便利
- 公開 UI にするなら最低限の露出抑制
- それでもコンテナ filesystem へのアクセス管理は別問題

という理解が必要です。

---

## サービス種別ごとの構成差

設定はサービスによって意味がかなり違います。  
これを混同しないことが重要です。

### 1. 無認証系

- `Google`
- `Bing`

長所:

- まず動作確認しやすい
- API key 準備が不要

短所:

- 品質や安定性が API 直結型より必ずしも高くない
- 外部サイト側の挙動に影響されやすい

### 2. 公式 API 系

- `OpenAI`
- `DeepL`
- `Grok`
- `Gemini`
- `DeepSeek`

長所:

- モデル指定や品質制御がしやすい
- 長期運用で再現性を持ちやすい

短所:

- API key 管理が必要
- endpoint 設計を正確にしないと失敗する

### 3. OpenAI 互換 proxy 系

- `OpenAI-liked`
- 独自 proxy 経由 `OpenAI` / `Grok`

ここでは特に `BASE_URL` の `/v1` が重要です。  
`docs/PROXY_CONFIGURATION.md` でもここは繰り返し強調されています。

### 4. ローカル LLM / Ollama 系

- `Ollama`
- `OpenAI-liked` としての `Ollama`

ここでは `Docker` からホストや別 container の `Ollama` にどう到達するかが最重要になります。

---

## Docker から外部サービスへ出る時のネットワーク

### OpenAI などのインターネット上の API

これは通常、コンテナが外向き通信できれば足ります。

### ホスト上の `Ollama`

ここでは `127.0.0.1` をそのまま使ってはいけません。  
コンテナ内の `127.0.0.1` はコンテナ自身だからです。

典型的には次のように考えます。

- Docker Desktop 系: `http://host.docker.internal:11434`
- Linux: `host.docker.internal` を使うために `extra_hosts` を追加するか、別の到達方法を取る

### OpenAI 互換 endpoint としての `Ollama`

その場合は:

- `OPENAILIKED_BASE_URL=http://host.docker.internal:11434/v1`
- `OPENAILIKED_API_KEY=ollama`
- `OPENAILIKED_STREAM=false`

のような構成が自然です。

### 別コンテナ上の proxy / Ollama

同じ Docker network 上であれば、

- `http://ollama:11434`
- `http://proxy:8000/v1`

のように service 名で参照する構成も可能です。

---

## `/v1` が本質的に重要なケース

次のような OpenAI 互換 endpoint では、`BASE_URL` の末尾 `/v1` を落とすと失敗しやすいです。

- `OPENAI_BASE_URL`
- `OPENAILIKED_BASE_URL`
- `GROK_BASE_URL`

これは単なる書式の問題ではなく、実際に

- `404`
- `connection error`
- `model not found` と見えるが実際は path 不整合

のような紛らわしい失敗に繋がります。

---

## GUI と `config.json` の役割分担

安定版 Docker 運用では、次の役割分担が実務的です。

### GUI に任せるもの

- PDF の投入
- その場のページ範囲
- その場の比較的小さなパラメータ調整

### `config.json` に固定するもの

- 既定の翻訳サービス群
- API key
- model 名
- endpoint
- 既定言語
- 公開時の表示制御

この分け方をすると、GUI は「操作面」、`config.json` は「構成面」として安定します。

---

## 安定版 v1 と `next` / `v2` のズレ

今回の資料には `pdf2zh/kernel/PDFMathTranslate-next.git` のドキュメントが多く含まれています。  
これらは非常に有益ですが、安定版 image とは次の点で別物です。

| 項目 | stable v1 | next / v2 |
| --- | --- | --- |
| 主 image | `byaidu/pdf2zh` | `awwaawwa/pdfmathtranslate-next` など |
| 既定 GUI 起動 | `pdf2zh -i` | `pdf2zh --gui` 系 |
| 既定 config | `~/.config/PDFMathTranslate/config.json` | `~/.config/pdf2zh/config.v3.toml` |
| cache | `~/.cache/pdf2zh/cache.v1.db` | `~/.cache/pdf2zh_next/...` |
| 実験機能 | stable 側では experimental 扱い | next 側では本流実装 |

したがって、

- 安定版 image を使うのに、next docs をそのままコピペ運用する
- next docs の CLI と stable image をそのまま混在させる

のは危険です。

ただし概念的には、

- `Ollama host`
- port `7860`
- Docker での WebUI
- 認証や welcome page

など、流用できる考え方もあります。

---

## この文書から最終手順書へ持ち込むべき原則

最終手順書 `plan/3` には、少なくとも次を反映すべきです。

1. `HOME` を volume 化して状態を固定する
2. `config.json` を構成の中核に置く
3. GUI は操作面であり、構成面の唯一の真実ではない
4. `Google/Bing` と `OpenAI/Ollama/proxy` を同じ難易度で扱わない
5. `stable v1` と `next / v2` を別レーンとして整理する
6. `Use BabelDOC` あるいは `precise` は、最初の動作確認より後ろに置く

要するに、`Docker` によるローカル利用で本当に重要なのは、  
単にコンテナを立ち上げることではなく、

- 状態の置き場
- 構成の置き場
- ネットワーク到達性
- 機能レーンの切り分け

を設計することです。

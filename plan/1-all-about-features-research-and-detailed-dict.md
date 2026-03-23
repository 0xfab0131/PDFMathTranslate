# 1. 安定版 `Docker image` の機能調査と詳細辞書

## この文書の役割

この文書は、安定版 `byaidu/pdf2zh` をローカル `Docker` で利用する際に、

- 何の機能があり
- それぞれがどの層に属し
- どれが stable な主系統で
- どれが experimental / 別レーンで
- どれを今すぐ使うべきか

を、辞書的に整理した文書です。

最終的に読む中心は `plan/3-finaly-updating-documents-deploy-guideline-step-by-step.md` ですが、  
そこで使う判断軸を先に一覧化しておくために、この文書を置きます。

---

## まず結論

安定版 `Docker image` の機能は、全部を同じ安定度で扱ってはいけません。

今回の local container 運用で、まず意識すべきレーンは次です。

1. baseline 確認レーン
   - `Google`
   - `Bing`
2. 作業完了レーン
   - `OpenAI`
3. 実験レーン
   - `BabelDOC`
   - `precise`
   - `next` に繋がる機能群
4. ローカル LLM レーン
   - `Ollama`
   - `OpenAI-liked` としての `Ollama`

今回の優先順位は、あなたの要望通り

- 先に `OpenAI`
- 次に `BabelDOC / precise`
- 最後に `Ollama`

です。

---

## 1. 文書ソースごとの信頼度

### Tier A: stable 構成の一次資料

- root `README.md`
- root `docs/ADVANCED.md`
- root `docs/README_GUI.md`
- root `docs/PROXY_CONFIGURATION.md`

### Tier B: stable ではないが、概念理解に有益

- `pdf2zh/kernel/PDFMathTranslate-next.git/README.md`
- `pdf2zh/kernel/PDFMathTranslate-next.git/docs/ja/getting-started/*`
- `pdf2zh/kernel/PDFMathTranslate-next.git/docs/ja/advanced/advanced.md`
- `pdf2zh/kernel/PDFMathTranslate-next.git/docs/ja/advanced/Language-Codes.md`

### Tier C: 参考止まり

- root `docs/APIS.md`
- `pdf2zh/kernel/PDFMathTranslate-next.git/docs/ja/APIS.md`
- `pdf2zh/kernel/PDFMathTranslate-next.git/docs/ja/advanced/Documentation-of-Translation-Services.md`

理由:

- API 文書は今回の local GUI/Docker 主目的から外れる
- 一部は古いことが明示されている
- 一部は AI 生成や重複・揺れが強く、そのまま権威資料にしにくい

---

## 2. 機能を層で分ける

| 層 | 役割 | 具体例 | 今回の重要度 |
| --- | --- | --- | --- |
| 起動層 | コンテナをどう立ち上げるか | `docker run`, `compose`, port, volume | 非常に高い |
| 状態層 | 設定や cache をどこへ置くか | `HOME`, `config.json`, cache DB | 非常に高い |
| 操作層 | 日々どのように使うか | GUI, page range, service selection | 高い |
| 翻訳層 | どの engine/service で翻訳するか | `Google`, `OpenAI`, `Ollama` | 高い |
| 実験層 | 本流とは別に試す機能 | `BabelDOC`, `precise` | 中〜高 |

---

## 3. 安定版 local Docker で使える主な入口

### 3.1 GUI

- 起動方法: `pdf2zh -i`
- 用途:
  - PDF を手元から投げる
  - translator を選ぶ
  - page range を選ぶ
  - experimental オプションを触る
- 特徴:
  - もっとも直感的
  - ただし設定の再現性は `config.json` より弱い

### 3.2 CLI

- 起動方法: `pdf2zh ...`
- 用途:
  - 固定的なバッチ利用
  - 再現性の高い運用
  - translator / output / partial pages の明示
- 特徴:
  - GUI より構成を固定しやすい
  - ただし今回の主目的はまず Docker GUI を安定運用すること

### 3.3 API / backend

- `docs/APIS.md` にある
- ただし今回の local container GUI 運用の中心ではない

---

## 4. 翻訳サービス辞書

### 4.1 baseline 用

| サービス | 認証 | 特徴 | 今回の位置づけ |
| --- | --- | --- | --- |
| `Google` | 不要 | 無認証、まず確認しやすい | smoke test の第一候補 |
| `Bing` | 不要 | 無認証、使いやすいが今回一度失敗している | second baseline |

### 4.2 作業完了用

| サービス | 認証 | 特徴 | 今回の位置づけ |
| --- | --- | --- | --- |
| `OpenAI` | 必要 | 安定的に model / endpoint / key を構成できる | 先に完了させる主系統 |
| `DeepL` | 必要 | 高品質寄り | 代替候補 |
| `Grok` | 必要 | proxy 運用も可能 | 次候補 |
| `DeepSeek` | 必要 | API ベースの候補 | 次候補 |
| `Gemini` | 必要 | API ベースの候補 | 次候補 |

### 4.3 proxy / OpenAI 互換用

| サービス | 認証 | 特徴 | 注意 |
| --- | --- | --- | --- |
| `OpenAI-liked` | 通常必要 | OpenAI 互換 endpoint に広く対応 | `/v1` と stream 設定が重要 |
| `Grok` custom proxy | 必要 | `GROK_BASE_URL` 差し替えで利用可能 | `/v1` 必須 |

### 4.4 ローカル LLM 用

| サービス | 認証 | 特徴 | Docker 注意 |
| --- | --- | --- | --- |
| `Ollama` | 不要または簡易 | ローカルでモデル運用 | `127.0.0.1` をそのまま使わない |
| `OpenAI-liked` + `Ollama` | 簡易 | `Ollama` を OpenAI 互換 endpoint として使う | `host.docker.internal` や network 設計が必要 |

### 4.5 実験・別レーン

| 機能 | 意味 | 扱い |
| --- | --- | --- |
| `BabelDOC` | experimental backend | baseline の後 |
| `--mode precise` | v2 kernel / isolated env | baseline の後 |
| `PDFMathTranslate-next` | 2.x 本流 | stable image と混同しない |

---

## 5. 設定面辞書

### 5.1 `config.json`

- 既定位置: `~/.config/PDFMathTranslate/config.json`
- 役割:
  - translator 設定
  - 既定言語
  - GUI 表示制御
  - public / semi-public 利用向け制御
- 今回の重要度:
  - 最重要

### 5.2 環境変数

主なもの:

- `PDF2ZH_LANG_FROM`
- `PDF2ZH_LANG_TO`
- `OPENAI_BASE_URL`
- `OPENAI_API_KEY`
- `OPENAI_MODEL`
- `OLLAMA_HOST`
- `OLLAMA_MODEL`
- `GROK_BASE_URL`
- `GROK_API_KEY`
- `OPENAILIKED_BASE_URL`
- `OPENAILIKED_STREAM`
- `HF_ENDPOINT`

役割:

- translator の endpoint / key / model
- ネットワークや mirror の補助

### 5.3 GUI 入力

主なもの:

- service dropdown
- page range
- threads
- `Skip font subsetting`
- `Ignore cache`
- experimental options

役割:

- 実行時の一時選択

### 5.4 volume

重要な mount 先:

- `HOME` 相当
- `/app/pdf2zh_files`

役割:

- 設定の永続化
- cache の永続化
- 入出力ファイルの永続化

---

## 6. オプション辞書

### `-p`

- 部分翻訳
- 大きい論文で first page だけ確認する時に重要

### `-t`

- threads 指定
- stable ではまず小さく始める

### `--skip-subset-fonts`

- 出力 PDF の互換性調整
- フォント周りの問題時に使う

### `--ignore-cache`

- cache を使わず再翻訳
- 設定変更後の検証時に有効

### `--prompt`

- LLM 系 translator 用 custom prompt
- `Google` / `Bing` baseline では優先度低

### `--config`

- 読み込む `config.json` を明示
- Docker 運用では非常に重要

### `--authorized`

- stable 1.x の認証付き GUI
- `users.txt` と任意の `auth.html` を使う

### `--share`

- 公開リンク寄り
- ローカル初期構成では通常不要

### `--babeldoc`

- experimental backend
- 最後に別レーンで試す

### `--mode precise`

- v2 / isolated environment
- stable baseline の後に試す

---

## 7. 状態と出力の辞書

### 設定ファイル

- `~/.config/PDFMathTranslate/config.json`

### cache

- `~/.cache/pdf2zh/cache.v1.db`

### GUI 作業ファイル

- 典型的には `/app/pdf2zh_files`

### stable と next の差

| 項目 | stable | next |
| --- | --- | --- |
| 設定形式 | JSON | TOML |
| 設定ディレクトリ | `~/.config/PDFMathTranslate` | `~/.config/pdf2zh` |
| cache | `~/.cache/pdf2zh` | `~/.cache/pdf2zh_next` |

---

## 8. Docker での重要な罠の辞書

### 罠 1: `127.0.0.1`

コンテナ内の `127.0.0.1` は、ホストではなくコンテナ自身です。

### 罠 2: `/v1` 抜け

OpenAI 互換 endpoint では `BASE_URL` 末尾の `/v1` 抜けが非常に多い失敗原因です。

### 罠 3: GUI に設定を持たせ過ぎる

再現性が落ちます。  
重要設定は `config.json` に寄せる方が本質的に強いです。

### 罠 4: stable と next を混同する

`pdf2zh -i` と `pdf2zh_next --gui` は同じではありません。

### 罠 5: experimental path を最初に使う

今回のような混乱に直結しやすいです。

---

## 9. 今回の優先順位に基づく推奨読解順

1. `OpenAI` で作業完了する構成
2. `BabelDOC / precise` を別レーンで試す構成
3. `Ollama` をローカルで動かしながら使う構成

この順序は、

- まず安定的に成果を得る
- つぎに experimental を切り出す
- 最後に local LLM 連携のネットワーク設計へ進む

という意味で合理的です。

---

## 10. この文書の要点

機能をたくさん知ること自体よりも、

- どの機能が主系統か
- どの機能が実験的か
- どの設定が再現性を支配するか

を理解することの方が、今回の local Docker 構成では本質的です。

今回のあなたのケースでは、

- まず `OpenAI`
- 次に `BabelDOC / precise`
- 最後に `Ollama`

という順序で深めるのがもっとも自然です。
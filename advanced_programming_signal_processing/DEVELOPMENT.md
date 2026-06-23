# 開発ガイド

## アーキテクチャ

```
run.sh                  共通パイプライン（画像読込 → 前処理 → マッチング → 結果選択）
preprocess/
  base.sh               ベースモジュール（変換なし、インターフェース定義）
  rotate.sh             回転モジュール（0, 90, 180, 270度）
  scale.sh              スケールモジュール（未実装）
  denoise.sh            ノイズ除去モジュール（未実装）
main.c                  テンプレートマッチング本体（SSD）
imageUtil.c             画像I/O・描画ユーティリティ
```

### 役割分担

| レイヤー | 役割 | 担当 |
|----------|------|------|
| `preprocess/*.sh` | テンプレート・画像の変換（回転、リサイズ、ノイズ除去等） | シェル + ImageMagick |
| `main.c` | 1枚の入力と1枚のテンプレートに対するマッチング | C |
| `run.sh` | モジュールの読み込みとパイプライン制御 | シェル |

## 前処理モジュールの追加方法

### 1. モジュールファイルの作成

`preprocess/` に新しいシェルスクリプトを作成する。以下の3関数を実装すること。

```sh
# preprocess/<module_name>.sh

# 一度だけ呼ばれる。テンプレートの変換画像を事前生成する。
# $1: レベルディレクトリ（例: level5）
prepare_templates_<name>() {
    local src_dir="$1"
    # ${PREP_TMPDIR} 以下に変換済みテンプレートを生成
}

# テンプレート1つに対して、全バリアントを "パス 回転角度" の形式で出力する。
# $1: テンプレートファイルパス
get_template_variants_<name>() {
    local template="$1"
    echo "${template} 0"          # オリジナル
    echo "<variant_path> <rot>"   # 変換済み
}

# 一時ファイルの削除。
cleanup_<name>() {
    # ${PREP_TMPDIR} 以下の自分が作ったファイルを削除
}
```

関数名の `<name>` はファイル名と一致させること（例: `scale.sh` → `prepare_templates_scale`）。

### 2. run.sh にフラグを追加

`run.sh` のフラグ解析部分に1行追加する。

```sh
-s)
    . ./preprocess/scale.sh
    MODULES="${MODULES} scale"
    ;;
```

### 3. テスト

```sh
# 単一モジュール
time sh run.sh level5 -s
sh answer.sh result level5

# モジュール組み合わせ
time sh run.sh level8 -r -s
sh answer.sh result level8
```

## 並行開発のルール

- 各モジュールは独立したファイル。他のモジュールを編集する必要はない。
- `run.sh` への変更はフラグ追加の数行のみ。コアパイプラインは変更しない。
- `base.sh` のインターフェース（3関数）を守ること。
- 変換済みテンプレートは `${PREP_TMPDIR}` 以下に配置し、cleanup で削除すること。
- テンプレートのファイル名は元のまま保持すること（`answer.sh` がテンプレート名で正解判定するため）。

## 実行例

```sh
# level 1: 基本マッチング
sh run.sh level1

# level 6: 回転対応
sh run.sh level6 -r

# level 8: 回転 + スケール（scale.sh 実装後）
sh run.sh level8 -r -s
```

## レベル一覧

| レベル | 内容 | 必要なフラグ |
|--------|------|-------------|
| 1 | テンプレートの中から1つ | (なし) |
| 2 | 画像にノイズが混入 | (画像前処理) |
| 3 | 画像コントラスト変化 | (画像前処理) |
| 4 | テンプレートの背景透過 | (未定) |
| 5 | テンプレートサイズ可変 | `-s` |
| 6 | テンプレート回転 | `-r` |
| 7 | 1〜6のシャッフル | `-r` (他も必要に応じて) |
| 8 | 全部入り | `-r -s` (他も必要に応じて) |

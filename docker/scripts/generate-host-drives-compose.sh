#!/usr/bin/env bash
#
# generate-host-drives-compose.sh
#
# WSL Debian 側で実行し、ホストの各ドライブ(Windows の C:, D: 等、WSL が
# DrvFS/virtiofs 経由で自動マウント済み)を動的に検出して、ドライブごとに
# 個別のバインドマウントを定義する docker compose override ファイル
# (compose.host-drives.yaml)を生成する。start-dev-container.bat から
# 呼び出される。何度実行しても安全(実行のたびに検出結果で上書きする)。
#
# なぜ /mnt を丸ごとバインドマウントしないのか:
# 以前は WSL_HOST_DRIVES_SOURCE(既定 /mnt)をコンテナの /mnt/host-drives へ
# まるごとバインドマウントしていたが、/mnt はその配下に /mnt/c, /mnt/d ...
# という個別のマウントポイントがネストされたディレクトリである。この状態の
# ディレクトリをそのままバインドマウントすると、コンテナ再作成時に Rancher
# Desktop 側のアンマウント処理がネストされたマウントポイントを含む
# ディレクトリを一括アンマウントしようとして失敗し、以下のエラーで
# start-dev-container.bat が失敗することがあった:
#   Error response from daemon: failed to modify the response from the
#   backend: munger failed for /containers/.../start: could not unmount
#   bind mount ...: invalid argument
# これを避けるため、/mnt 配下で実際にマウントされているドライブ1つずつを
# 個別にバインドマウントする方式に変更した(ネストマウントを含まない末端の
# ディレクトリだけをバインドマウントすれば、この問題は起きない)。
#
set -euo pipefail

log() {
    echo "[generate-host-drives-compose] $*"
}

CONFIG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../config" && pwd)"
cd "${CONFIG_DIR}"

if [ -f .env ]; then
    set -a
    # shellcheck disable=SC1091
    source .env
    set +a
fi

BASE="${WSL_HOST_DRIVES_SOURCE:-/mnt}"
# 末尾スラッシュがあると awk 側の "base + /" 前方一致判定がずれて
# 何もマッチしなくなる(例: /mnt/ を指定すると /mnt//c と比較され不一致に
# なる)ため、比較前に正規化しておく(ルート "/" 自体は特殊扱いで残す)。
if [ "${BASE}" != "/" ]; then
    BASE="${BASE%/}"
fi
OUT_FILE="${CONFIG_DIR}/compose.host-drives.yaml"

# /proc/mounts から、BASE 直下に個別マウントされているドライブ(1文字の
# ディレクトリ名。例: /mnt/c, /mnt/d)を検出する。/mnt/wsl, /mnt/wslg のような
# WSL 内部用の tmpfs マウントは対象外(ドライブ名は1文字という前提で除外される)。
mapfile -t DRIVES < <(
    awk -v base="${BASE}" '
        {
            target = $2
            if (index(target, base "/") == 1) {
                rest = substr(target, length(base) + 2)
                if (rest ~ /^[a-zA-Z]$/) {
                    print tolower(rest)
                }
            }
        }
    ' /proc/mounts | sort -u
)

log "Detected drives under ${BASE}: ${DRIVES[*]:-(none)}"

{
    echo "# このファイルは generate-host-drives-compose.sh により自動生成される。"
    echo "# 手動編集しないこと(次回起動時に上書きされる)。"
    echo "services:"
    echo "  dev:"
    if [ "${#DRIVES[@]}" -eq 0 ]; then
        echo "    volumes: []"
    else
        echo "    volumes:"
        for d in "${DRIVES[@]}"; do
            echo "      - ${BASE}/${d}:/mnt/host-drives/${d}"
        done
    fi
} > "${OUT_FILE}"

log "Wrote ${OUT_FILE}"

#!/usr/bin/env bash
#
# setup-dev-container.sh
#
# WSL Debian 側で実行する初回セットアップ処理。setup-dev-container.bat から
# 呼び出される。何度実行しても安全(idempotent)。
#
#   - docker credential helper を無効化する(credsStore=none)
#   - .env が無ければ .env.example から作成する(デフォルト値のまま使える)
#   - .env に書かれたバインドマウント元のディレクトリ/ファイルを作成し、
#     コンテナ内ユーザー(USER_UID:USER_GID)に所有権を合わせる
#     (事前に作成しないと Docker が root 所有で自動作成してしまい、
#     コンテナ内の非 root ユーザーが書き込めずクラッシュする。
#     詳細は ../docs/TROUBLESHOOTING.md 参照)
#
set -euo pipefail

log() {
    echo "[setup] $*"
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../config" && pwd)"
cd "${SCRIPT_DIR}"

log "Disabling docker credential helper (credsStore=none)..."
mkdir -p ~/.docker
DOCKER_CONFIG_FILE="${HOME}/.docker/config.json"
if [ ! -f "${DOCKER_CONFIG_FILE}" ]; then
    # 新規作成: そのまま書き込んでよい。
    printf '{\n  "credsStore": "none"\n}\n' > "${DOCKER_CONFIG_FILE}"
elif grep -Eq '"credsStore"[[:space:]]*:[[:space:]]*"none"' "${DOCKER_CONFIG_FILE}"; then
    log "  -> ${DOCKER_CONFIG_FILE} already has credsStore=none, leaving it untouched."
elif grep -q '"credsStore"' "${DOCKER_CONFIG_FILE}"; then
    # Rancher Desktop の WSL Integration 再有効化などで credsStore が
    # wincred.exe 等(Windows 用バイナリ)に書き戻されることがある。
    # Windows PATH interop により Linux 側から実行できず exec format error に
    # なるため、値を強制的に none へ上書きする。
    log "  -> ${DOCKER_CONFIG_FILE} has a non-none credsStore, forcing it to none."
    cp "${DOCKER_CONFIG_FILE}" "${DOCKER_CONFIG_FILE}.bak"
    sed -i -E 's/"credsStore"[[:space:]]*:[[:space:]]*"[^"]*"/"credsStore": "none"/' "${DOCKER_CONFIG_FILE}"
else
    # 既存ファイル(Rancher Desktop が書き込んだ cliPluginsExtraDirs 等)を
    # 壊さないよう、丸ごと上書きはせず先頭の "{" の直後に1行だけ追記する。
    # 例: {"cliPluginsExtraDirs":[...]} -> {"credsStore": "none","cliPluginsExtraDirs":[...]}
    log "  -> merging credsStore into existing ${DOCKER_CONFIG_FILE}"
    cp "${DOCKER_CONFIG_FILE}" "${DOCKER_CONFIG_FILE}.bak"
    sed -i '0,/{/s//{"credsStore": "none",/' "${DOCKER_CONFIG_FILE}"
fi

if [ ! -f .env ]; then
    log "Creating .env from .env.example (using defaults)..."
    # .env.example の $HOME は実際のホームディレクトリへ展開しておく
    # (docker compose の .env ファイルはシェル変数展開をサポートしないため)。
    sed "s|\$HOME|${HOME}|g" .env.example > .env
else
    log ".env already exists, keeping it as-is."
fi

log "Loading .env..."
set -a
# shellcheck disable=SC1091
source .env
set +a

UID_VAL="${USER_UID:-1000}"
GID_VAL="${USER_GID:-1000}"

DIRS=(
    "${WSL_MOUNT_SOURCE:-}"
    "${WSL_JCODE_HOME:-}"
    "${WSL_GH_CONFIG_HOME:-}"
    "${WSL_CLAUDE_HOME:-}"
    "${WSL_SSH_HOME:-}"
    "${WSL_GIT_CONFIG_HOME:-}"
    "${WSL_HERDR_CONFIG_HOME:-}"
    "${WSL_HERDR_STATE_HOME:-}"
)
FILES=(
    "${WSL_NPMRC_FILE:-}"
)

for d in "${DIRS[@]}"; do
    [ -z "${d}" ] && continue
    log "mkdir -p ${d}"
    mkdir -p "${d}"
done

for f in "${FILES[@]}"; do
    [ -z "${f}" ] && continue
    log "touch ${f}"
    touch "${f}"
done

log "Fixing ownership to ${UID_VAL}:${GID_VAL} ..."
for path in "${DIRS[@]}" "${FILES[@]}"; do
    [ -z "${path}" ] && continue
    sudo chown -R "${UID_VAL}:${GID_VAL}" "${path}"
done

log "Done. Next: run start-dev-container.bat."

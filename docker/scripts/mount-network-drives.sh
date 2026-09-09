#!/usr/bin/env bash
#
# mount-network-drives.sh
#
# WSL Debian 側で **root として** 実行するスクリプト(start-dev-container.bat
# から `wsl.exe -u root` 経由で呼び出される。sudo ではなく wsl.exe の -u root
# オプションでroot権限を取得するため、ユーザーに事前の sudoers 設定等を
# 要求しない)。
#
# Windows でドライブ文字にマップされたネットワークドライブ(Z: など)を動的に
# 検出し、まだ WSL 側にマウントされていなければ <base>/<ドライブ文字> に
# drvfs としてマウントする(<base> は .env の WSL_HOST_DRIVES_SOURCE、既定
# /mnt。generate-host-drives-compose.sh と同じ変数を使い、検出/マウント先を
# 一致させている)。C:, D: のようなローカル/固定ドライブは WSL が起動時に
# 自動マウント済みのため対象外(list-network-drives.ps1 が EnumNetworkDrives
# でネットワークドライブのみを返す)。
#
# これにより、generate-host-drives-compose.sh が /proc/mounts から
# /mnt 配下の全ドライブ(ローカル+ネットワーク)を検出してコンテナへ
# バインドマウントできるようになる(ネットワークドライブの割り当ては
# 環境ごとに異なるため、ドライブ文字をハードコーディングしない)。
#
# 何度実行しても安全(idempotent): 既にマウント済みのドライブはスキップする。
#
set -uo pipefail

log() {
    echo "[mount-network-drives] $*"
}

if [ "$(id -u)" -ne 0 ]; then
    echo "[mount-network-drives] ERROR: this script must run as root (invoked via wsl.exe -u root)." >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$(cd "${SCRIPT_DIR}/../config" && pwd)"
PS1_SCRIPT="${SCRIPT_DIR}/list-network-drives.ps1"

if [ -f "${CONFIG_DIR}/.env" ]; then
    set -a
    # shellcheck disable=SC1091
    source "${CONFIG_DIR}/.env"
    set +a
fi
UID_VAL="${USER_UID:-1000}"
GID_VAL="${USER_GID:-1000}"
# generate-host-drives-compose.sh と同じ base を使う(既定 /mnt)。
# .env で WSL_HOST_DRIVES_SOURCE をカスタマイズした場合でも両スクリプトの
# 検出/マウント先が食い違わないようにするため。
DRIVES_BASE="${WSL_HOST_DRIVES_SOURCE:-/mnt}"
# generate-host-drives-compose.sh と同様に末尾スラッシュを正規化する
# (両スクリプトの生成/検出結果を一致させるため。ルート "/" は例外)。
if [ "${DRIVES_BASE}" != "/" ]; then
    DRIVES_BASE="${DRIVES_BASE%/}"
fi

if ! command -v powershell.exe >/dev/null 2>&1; then
    log "powershell.exe not found in PATH; skipping network drive detection."
    exit 0
fi

PS1_WIN_PATH="$(wslpath -w "${PS1_SCRIPT}")"

# list-network-drives.ps1 は "ドライブ文字:|UNCパス" の行を1マウントにつき
# 1行出力する(例: "Z:|\\server\share")。PowerShell 側で UTF-8 出力に
# 設定しているが、改行コードが CRLF になることがあるため tr で除去する。
# stderr は握りつぶさず変数に保持しておく。WSL の Windows バイナリ実行
# (interop)自体が壊れている場合(例: binfmt_misc の WSLInterop 未登録によ
# り "cannot execute binary file: Exec format error" になる)、"ネットワーク
# ドライブが0件だった"のと区別がつかないと、実際にはマウントできる状態
# なのに気づかず起動を続けてしまう。そのため exit code を明示的に見て
# 実行自体が失敗した場合は警告し、この後の処理を打ち切る(致命的エラーには
# しない。C:, D: 等の通常起動は継続できるようにするため)。
PS1_STDERR_FILE="$(mktemp)"
MAPPINGS="$(powershell.exe -NoProfile -ExecutionPolicy Bypass -File "${PS1_WIN_PATH}" 2>"${PS1_STDERR_FILE}" | tr -d '\r')"
# パイプの左側(powershell.exe)の終了コードを見る。$? だけだとパイプ最後の
# tr の終了コードになってしまうため PIPESTATUS を使う。
PS1_EXIT="${PIPESTATUS[0]}"
if [ "${PS1_EXIT}" -ne 0 ]; then
    log "WARNING: powershell.exe exited with status ${PS1_EXIT}; could not query mapped network drives."
    log "  This usually means WSL's Windows-binary interop is broken (unrelated to this repo)."
    log "  stderr: $(tr '\n' ' ' < "${PS1_STDERR_FILE}")"
    log "  Try restarting the WSL distro (wsl -t Debian) or Rancher Desktop, then re-run this script."
    rm -f "${PS1_STDERR_FILE}"
    exit 0
fi
rm -f "${PS1_STDERR_FILE}"

if [ -z "${MAPPINGS}" ]; then
    log "No mapped network drives detected."
    exit 0
fi

while IFS='|' read -r drive_letter unc_path; do
    [ -z "${drive_letter}" ] && continue
    # "Z:" -> "z"
    letter="$(echo "${drive_letter}" | tr -d ':' | tr '[:upper:]' '[:lower:]')"
    target="${DRIVES_BASE}/${letter}"

    if mountpoint -q "${target}" 2>/dev/null; then
        log "${target} is already mounted, skipping (${unc_path})."
        continue
    fi

    log "Mounting ${unc_path} at ${target} ..."
    mkdir -p "${target}"
    if mount -t drvfs "${unc_path}" "${target}" -o "metadata,uid=${UID_VAL},gid=${GID_VAL}"; then
        log "  -> OK"
    else
        log "  -> FAILED (network drive may be unavailable; continuing without it)"
        rmdir "${target}" 2>/dev/null || true
    fi
done <<< "${MAPPINGS}"

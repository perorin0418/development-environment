#!/usr/bin/env bash
#
# entrypoint.sh
#
# コンテナ起動時のエントリーポイント。参考にした install-dev-tools.sh では
# jcode/herdr/code-server を systemd サービスとして常駐させていたが、
# コンテナ内には systemd が存在しない(PID 1 は本スクリプト)ため、
# 環境変数フラグでオプトインした常駐プロセスをバックグラウンドで起動してから
# 渡されたコマンド(デフォルト: `sleep infinity`)を PID 1 として実行する。
#
# コンテナへの接続は SSH ではなく `docker exec -it dev-container bash` を使う
# 方針のため、sshd は起動しない(README.md 参照)。
#
# 有効化フラグ (デフォルトはすべて無効。docker run -e START_CODE_SERVER=true 等で指定):
#   START_CODE_SERVER=true  code-server (127.0.0.1:8153 → 0.0.0.0:8153) を起動する
#   START_JCODE=true        jcode serve を起動する
#   START_HERDR=true        herdr server を起動する
#
set -euo pipefail

log() {
    echo "[entrypoint] $*"
}

# --- 永続化ボリュームの初期化 ---
# compose.yaml で ~/.jcode 等をバインドマウントしている場合、初回は空の
# ホスト側ディレクトリで上書きされ、イメージビルド時に焼き込んだデフォルト
# 設定が隠れてしまう。マウント後にファイルが存在しなければ再生成する。

# ~/.jcode: check_updates=false のデフォルト設定を再生成
JCODE_CONFIG_FILE="${HOME}/.jcode/config.toml"
if [ ! -f "${JCODE_CONFIG_FILE}" ]; then
    log "Initializing ${JCODE_CONFIG_FILE} (first run on this persisted volume)"
    mkdir -p "${HOME}/.jcode"
    printf '[features]\ncheck_updates = false\n' > "${JCODE_CONFIG_FILE}"
fi

# ~/.ssh: sshd/ssh クライアントはディレクトリ・鍵ファイルのパーミッションが
# 緩いと使用を拒否するため、バインドマウント後(ホスト側 WSL のパーミッションが
# そのまま反映される)に毎回強制し直す。
if [ -d "${HOME}/.ssh" ]; then
    chmod 700 "${HOME}/.ssh"
    find "${HOME}/.ssh" -maxdepth 1 -type f -name '*.pub' -exec chmod 644 {} +
    find "${HOME}/.ssh" -maxdepth 1 -type f ! -name '*.pub' -exec chmod 600 {} +
fi

# --- code-server ---
if [ "${START_CODE_SERVER:-false}" = "true" ]; then
    log "Starting code-server"
    nohup code-server >/tmp/code-server.log 2>&1 &
fi

# --- jcode ---
if [ "${START_JCODE:-false}" = "true" ]; then
    log "Starting jcode serve"
    nohup jcode --no-update --quiet serve >/tmp/jcode.log 2>&1 &
fi

# --- herdr ---
if [ "${START_HERDR:-false}" = "true" ]; then
    log "Starting herdr server"
    # entrypoint.sh は nohup/バックグラウンド起動のため SHELL 環境変数が
    # 設定されておらず、herdr が pane 生成時のデフォルトシェルとして
    # readline 非対応の /bin/sh(dash) にフォールバックしてしまう。
    # これにより pane 内で矢印キー等の行編集が事実上効かなくなる
    # (矢印キーがエスケープシーケンスのまま表示される)ため、明示的に
    # /bin/bash を指定する。
    export SHELL=/bin/bash
    nohup herdr server >/tmp/herdr.log 2>&1 &
fi

log "exec: $*"
exec "$@"

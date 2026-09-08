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
# compose.yaml で ~/.jcode-data 等をバインドマウントしている場合、初回は空の
# ホスト側ディレクトリで上書きされ、イメージビルド時に焼き込んだデフォルト
# 設定が隠れてしまう。マウント後にファイルが存在しなければ再生成する。
#
# jcode の実行ファイル本体(~/.jcode/builds/...)はイメージに焼き込んだままで、
# バインドマウントの対象にしていない(JCODE_HOME=~/.jcode-data に認証情報等の
# 永続化データだけを分離しているため。Dockerfile 参照)。

# ~/.jcode-data ($JCODE_HOME): check_updates=false のデフォルト設定を再生成
JCODE_CONFIG_FILE="${JCODE_HOME:-${HOME}/.jcode-data}/config.toml"
if [ ! -f "${JCODE_CONFIG_FILE}" ]; then
    log "Initializing ${JCODE_CONFIG_FILE} (first run on this persisted volume)"
    mkdir -p "$(dirname "${JCODE_CONFIG_FILE}")"
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

# --- ホスト Docker ソケット ---
# compose.yaml で /var/run/docker.sock をバインドマウントしている場合、
# ソケットの所有 GID はホスト(Rancher Desktop の VM)側の docker グループの
# GID であり、コンテナ内の developer ユーザーとは通常一致しない。そのため
# 起動のたびにソケットの GID を確認し、コンテナ内に同じ GID のグループを
# 用意して developer を所属させ、以後 sudo なしで `docker` コマンドを
# 使えるようにする(既存の docker グループの GID とホスト側が異なる場合は
# 作り直す)。ソケットが無い(バインドマウントしていない)場合は何もしない。
DOCKER_SOCK="/var/run/docker.sock"
if [ -S "${DOCKER_SOCK}" ]; then
    SOCK_GID="$(stat -c '%g' "${DOCKER_SOCK}")"
    EXISTING_GROUP="$(getent group "${SOCK_GID}" | cut -d: -f1 || true)"
    if [ -z "${EXISTING_GROUP}" ]; then
        log "Creating group 'docker-host' (gid ${SOCK_GID}) for ${DOCKER_SOCK}"
        sudo groupadd --gid "${SOCK_GID}" docker-host
        EXISTING_GROUP="docker-host"
    fi
    if ! id -nG "$(id -un)" 2>/dev/null | grep -qw "${EXISTING_GROUP}"; then
        log "Adding $(id -un) to group '${EXISTING_GROUP}' for docker socket access"
        sudo usermod -aG "${EXISTING_GROUP}" "$(id -un)"
        # usermod は現在のログインシェルのグループ一覧には反映されないため、
        # このプロセス(と exec で置き換わる子プロセス)にだけ反映させたい場合は
        # sg/exec で再実行する必要がある。ここでは以降の nohup 起動プロセスに
        # 反映させるため、このシェル自体を新しいグループ込みで再実行する。
        exec sg "${EXISTING_GROUP}" -c "$(printf '%q ' "$0" "$@")"
    fi
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

#!/usr/bin/env bash
#
# entrypoint.sh
#
# コンテナ起動時のエントリーポイント。参考にした install-dev-tools.sh では
# herdr を systemd サービスとして常駐させていたが、コンテナ内には systemd が
# 存在しない(PID 1 は本スクリプト)ため、環境変数フラグでオプトインした
# 常駐プロセスをバックグラウンドで起動してから渡されたコマンド
# (デフォルト: `sleep infinity`)を PID 1 として実行する。
#
# コンテナへの接続は SSH ではなく `docker exec -it general-develop bash` を使う
# 方針のため、sshd は起動しない(README.md 参照)。
#
# 有効化フラグ (デフォルトはすべて無効。docker run -e START_HERDR=true 等で指定):
#   START_HERDR=true        herdr server を起動する
#
set -euo pipefail

log() {
    echo "[entrypoint] $*"
}

# ~/.ssh: sshd/ssh クライアントはディレクトリ・鍵ファイルのパーミッションが
# 緩いと使用を拒否するため、バインドマウント後(ホスト側 WSL のパーミッションが
# そのまま反映される)に毎回強制し直す。
if [ -d "${HOME}/.ssh" ]; then
    chmod 700 "${HOME}/.ssh"
    # find の結果をパイプで xargs に渡す(-exec より安全にヌル区切りで処理する)。
    find "${HOME}/.ssh" -maxdepth 1 -type f -name '*.pub' -print0 | xargs -0 -r chmod 644
    find "${HOME}/.ssh" -maxdepth 1 -type f ! -name '*.pub' -print0 | xargs -0 -r chmod 600
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

# --- Claude Code statusline ---
# statusline スクリプト本体はイメージの /opt/statusline.sh に焼き込み済み
# (Dockerfile 参照)。~/.claude はホスト側にバインドマウントされ内容が
# 起動ごとに変わり得るため、settings.json の statusLine 設定はここで
# 毎回マージして最新のイメージ側パスを指すようにする(他のキーは温存する)。
#
# ~/.claude はコンテナ起動直後の時点では、ホスト側(WSL)からのバインド
# マウントがまだ確立しておらず、コンテナ内の空ディレクトリのままである
# ことがある(Rancher Desktop は WSL ディストロ間の中継マウントを都度
# 生成するため、確立に遅延が生じ得る)。その状態で settings.json を
# 書き込むと、後からマウントが確立しても認証情報(.credentials.json 等
# 本来ホスト側に永続化されているファイル)が隠れて見えなくなる恐れがある
# ため、~/.claude が実際にバインドマウント済みであることを /proc/mounts
# で確認できるまで待ってから書き込む。一定時間待っても確立しない場合は
# 書き込みをスキップする(誤って未マウントの一時領域に書いて、後続の
# クラッシュ調査を難しくしないため)。
CLAUDE_SETTINGS="${HOME}/.claude/settings.json"
if [ -d "${HOME}/.claude" ]; then
    CLAUDE_MOUNT_WAIT=0
    CLAUDE_MOUNT_WAIT_MAX=10
    while ! grep -q " ${HOME}/.claude " /proc/mounts && [ "${CLAUDE_MOUNT_WAIT}" -lt "${CLAUDE_MOUNT_WAIT_MAX}" ]; do
        sleep 1
        CLAUDE_MOUNT_WAIT=$((CLAUDE_MOUNT_WAIT + 1))
    done

    if grep -q " ${HOME}/.claude " /proc/mounts; then
        if [ ! -f "${CLAUDE_SETTINGS}" ]; then
            echo '{}' > "${CLAUDE_SETTINGS}"
        fi
        CLAUDE_SETTINGS_TMP="$(mktemp)"
        jq '.statusLine = {"type": "command", "command": "/opt/statusline.sh"}' \
            "${CLAUDE_SETTINGS}" > "${CLAUDE_SETTINGS_TMP}"
        mv "${CLAUDE_SETTINGS_TMP}" "${CLAUDE_SETTINGS}"
    else
        log "WARNING: ${HOME}/.claude is not a bind mount after ${CLAUDE_MOUNT_WAIT_MAX}s; skipping statusLine merge"
    fi
fi

# --- herdr ---
# SHELL は Dockerfile の ENV で /bin/bash に固定済み(herdr が pane 生成時の
# デフォルトシェルとして readline 非対応の /bin/sh(dash) にフォールバックし、
# pane 内で矢印キー等の行編集が効かなくなるのを防ぐため)。
if [ "${START_HERDR:-false}" = "true" ]; then
    log "Starting herdr server"
    nohup herdr server >/tmp/herdr.log 2>&1 &
fi

log "exec: $*"
exec "$@"

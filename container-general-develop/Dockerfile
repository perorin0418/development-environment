# syntax=docker/dockerfile:1
#
# 開発用コンテナイメージ
#
# WSL2 Debian 上のディレクトリ(ext4)をボリュームとしてマウントし、
# コンテナ内で開発作業を行うためのイメージ。Rancher Desktop で起動する
# コンテナから WSL Debian 側のパスをマウントする運用を想定している
# (詳細は ../README.md 参照)。
#
# ツール構成は以下を参考にしている:
#   D:\GitWorkspace\github\wsl2-debian-dev-setup\main\scripts\install-dev-tools.sh
#
# 参考スクリプトから除外した項目とその理由:
#   - Windows PATH interop 無効化 / systemd 有効化 (/etc/wsl.conf)
#       → WSL ディストリビューション固有の設定であり、コンテナには存在しない。
#         コンテナ内のサービス起動は entrypoint.sh がフォアグラウンドの
#         子プロセスとして直接管理する(systemd は使わない)。
#   - Docker Engine (docker-ce 一式)
#       → コンテナランタイムはホスト側の Rancher Desktop が担う。
#         コンテナ内で Docker-in-Docker は動かさない。その代わり、
#         docker-ce-cli(クライアントのみ)をインストールし、ホストの
#         docker ソケットを compose.yaml 経由でバインドマウントすることで、
#         コンテナ内から `docker` コマンドでホスト側の Docker を操作できる
#         ようにしている(詳細は下記セクション 3c、および compose.yaml 参照)。
#
FROM debian:bookworm-slim

ARG USERNAME=developer
ARG USER_UID=1000
ARG USER_GID=1000
ARG NVM_VERSION=v0.40.1
ARG NODE_VERSION=--lts

ENV DEBIAN_FRONTEND=noninteractive \
    USERNAME=${USERNAME} \
    HOME=/home/${USERNAME} \
    NVM_DIR=/home/${USERNAME}/.nvm \
    PATH=/home/${USERNAME}/.local/bin:/usr/local/go/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    SHELL=/bin/bash

# nvm/uv のインストーラースクリプトは bash 依存(dash非互換)のため、
# 以降の RUN は bash で実行する。
SHELL ["/bin/bash", "-c"]

# ---------------------------------------------------------------------------
# 1. apt base packages
# ---------------------------------------------------------------------------
RUN apt-get update -y \
    && apt-get upgrade -y \
    && apt-get install -y --no-install-recommends \
        build-essential \
        curl \
        wget \
        git \
        ca-certificates \
        gnupg \
        lsb-release \
        sudo \
        unzip \
        openssh-client \
        procps \
        less \
        vim \
        ripgrep \
        jq \
        python3 \
        python3-pip \
        python3-venv \
        pkg-config \
        libssl-dev \
        fzf \
        fd-find \
        locales \
        fonts-noto-cjk \
        xclip \
    && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# 2. Japanese locale (ja_JP.UTF-8)
# ---------------------------------------------------------------------------
RUN sed -i 's/^# *ja_JP.UTF-8 UTF-8/ja_JP.UTF-8 UTF-8/' /etc/locale.gen \
    && grep -q '^ja_JP.UTF-8 UTF-8' /etc/locale.gen || echo 'ja_JP.UTF-8 UTF-8' >> /etc/locale.gen \
    && locale-gen ja_JP.UTF-8 \
    && update-locale LANG=ja_JP.UTF-8 LC_ALL=ja_JP.UTF-8
ENV LANG=ja_JP.UTF-8 \
    LC_ALL=ja_JP.UTF-8

# ---------------------------------------------------------------------------
# 3. GitHub CLI (gh)
# ---------------------------------------------------------------------------
RUN mkdir -p -m 755 /etc/apt/keyrings \
    && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        -o /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update -y \
    && apt-get install -y --no-install-recommends gh \
    && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# 3b. glow (Markdown を CLI で読むためのビューア, Charm 公式 apt リポジトリ)
# ---------------------------------------------------------------------------
RUN mkdir -p -m 755 /etc/apt/keyrings \
    && curl -fsSL https://repo.charm.sh/apt/gpg.key \
        | gpg --dearmor -o /etc/apt/keyrings/charm.gpg \
    && chmod go+r /etc/apt/keyrings/charm.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" \
        > /etc/apt/sources.list.d/charm.list \
    && apt-get update -y \
    && apt-get install -y --no-install-recommends glow \
    && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# 3c. docker-ce-cli (クライアントのみ。デーモンはホスト側 Rancher Desktop)
# ---------------------------------------------------------------------------
# コンテナ内から `docker` コマンドを使えるようにするため、Docker 公式 apt
# リポジトリから docker-ce-cli(および docker compose v2 プラグイン)だけを
# インストールする。docker-ce(デーモン本体)や containerd はインストールしない
# (Docker-in-Docker は行わない方針。上記コメント参照)。
# 実際にホストの Docker を操作するには、compose.yaml で
# `/var/run/docker.sock` をコンテナにバインドマウントする必要がある。
RUN mkdir -p -m 755 /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/debian/gpg \
        | gpg --dearmor -o /etc/apt/keyrings/docker.gpg \
    && chmod go+r /etc/apt/keyrings/docker.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" \
        > /etc/apt/sources.list.d/docker.list \
    && apt-get update -y \
    && apt-get install -y --no-install-recommends docker-ce-cli docker-compose-plugin \
    && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# 4. Go (latest stable, official tarball)
# ---------------------------------------------------------------------------
RUN GO_ARCH="$(dpkg --print-architecture)" \
    && GO_VERSION="$(curl -fsSL 'https://go.dev/VERSION?m=text' | head -n1)" \
    && GO_TARBALL="${GO_VERSION}.linux-${GO_ARCH}.tar.gz" \
    && curl -fsSL "https://go.dev/dl/${GO_TARBALL}" -o "/tmp/${GO_TARBALL}" \
    && tar -C /usr/local -xzf "/tmp/${GO_TARBALL}" \
    && rm -f "/tmp/${GO_TARBALL}"

# ---------------------------------------------------------------------------
# 4b. AWS CLI v2 (公式インストーラー)
# ---------------------------------------------------------------------------
RUN AWS_ARCH="$(dpkg --print-architecture)" \
    && case "${AWS_ARCH}" in \
         amd64) AWS_CLI_ARCH="x86_64" ;; \
         arm64) AWS_CLI_ARCH="aarch64" ;; \
         *) echo "Unsupported architecture for AWS CLI: ${AWS_ARCH}" >&2; exit 1 ;; \
       esac \
    && curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-${AWS_CLI_ARCH}.zip" -o /tmp/awscliv2.zip \
    && unzip -q /tmp/awscliv2.zip -d /tmp \
    && /tmp/aws/install \
    && rm -rf /tmp/awscliv2.zip /tmp/aws

# ---------------------------------------------------------------------------
# 4d. Terraform (HashiCorp apt リポジトリ)
# ---------------------------------------------------------------------------
RUN mkdir -p -m 755 /etc/apt/keyrings \
    && curl -fsSL https://apt.releases.hashicorp.com/gpg \
        | gpg --dearmor -o /etc/apt/keyrings/hashicorp-archive-keyring.gpg \
    && chmod go+r /etc/apt/keyrings/hashicorp-archive-keyring.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
        > /etc/apt/sources.list.d/hashicorp.list \
    && apt-get update -y \
    && apt-get install -y --no-install-recommends terraform \
    && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# 4e2. fresh (ターミナル向けエディタ/IDE, 公式リリースの tarball)
# ---------------------------------------------------------------------------
# Debian の apt には存在しないため、GitHub リリースのビルド済み musl(静的
# リンク)版 tarball からバイナリだけを取り出して /usr/local/bin に置く。
# アーカイブ内は <target名>/fresh という構成なので --strip-components=1 で
# 取り出す。
RUN FRESH_ARCH="$(dpkg --print-architecture)" \
    && case "${FRESH_ARCH}" in \
         amd64) FRESH_TARGET="x86_64-unknown-linux-musl" ;; \
         arm64) FRESH_TARGET="aarch64-unknown-linux-musl" ;; \
         *) echo "Unsupported architecture for fresh: ${FRESH_ARCH}" >&2; exit 1 ;; \
       esac \
    && curl -fsSL "https://github.com/sinelaw/fresh/releases/latest/download/fresh-editor-${FRESH_TARGET}.tar.gz" \
        -o /tmp/fresh.tar.gz \
    && tar -C /usr/local/bin -xzf /tmp/fresh.tar.gz --strip-components=1 \
        "fresh-editor-${FRESH_TARGET}/fresh" \
    && chmod +x /usr/local/bin/fresh \
    && rm -f /tmp/fresh.tar.gz

# ---------------------------------------------------------------------------
# 5. 非rootユーザー
# ---------------------------------------------------------------------------
# WSL Debian 側のディレクトリをボリュームマウントした際にファイル所有権が
# 一致するよう、UID/GID はビルド時に --build-arg で調整できるようにする。
# 例: docker build --build-arg USER_UID=$(id -u) --build-arg USER_GID=$(id -g) ...
#
# コンテナへの接続は SSH ではなく `docker exec` を使う方針のため、ログイン
# パスワードは設定しない(README.md の「コンテナへの接続」セクション参照)。
RUN groupadd --gid ${USER_GID} ${USERNAME} \
    && useradd --uid ${USER_UID} --gid ${USER_GID} --create-home --shell /bin/bash ${USERNAME} \
    && echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USERNAME} \
    && chmod 0440 /etc/sudoers.d/${USERNAME} \
    && mkdir -p /workspace \
    && chown ${USERNAME}:${USERNAME} /workspace

WORKDIR /workspace
USER ${USERNAME}

# ---------------------------------------------------------------------------
# 6. nvm + Node.js LTS + npm
# ---------------------------------------------------------------------------
RUN curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh" | bash \
    && . "${NVM_DIR}/nvm.sh" \
    && nvm install ${NODE_VERSION} \
    && nvm alias default 'lts/*' \
    && nvm use --lts

# ---------------------------------------------------------------------------
# 7. pnpm, Vue CLI, Claude Code CLI, herdr
# ---------------------------------------------------------------------------
# nvm はシェル関数ベースで Node を切り替えるため、npm install -g で入れた
# コマンド(pnpm/vue/claude 等)の実体は $NVM_DIR/versions/node/<version>/bin
# 配下に置かれるだけで、通常の PATH(先頭 ENV で設定済みの ~/.local/bin 等)
# からは見えない。systemd を使わないコンテナでは .bashrc/nvm.sh を経由しない
# 非対話シェルからの呼び出しも多いため、そのディレクトリの実行ファイルを
# 起動時に固定された ~/.local/bin へシンボリックリンクしておく。
RUN mkdir -p "${HOME}/.local/bin" \
    && . "${NVM_DIR}/nvm.sh" \
    && npm install -g pnpm @vue/cli @anthropic-ai/claude-code aws-cdk \
    && curl -fsSL https://herdr.dev/install.sh | sh \
    && NODE_BIN_DIR="$(dirname "$(nvm which default)")" \
    && ln -sf "${NODE_BIN_DIR}"/* "${HOME}/.local/bin/"

# ---------------------------------------------------------------------------
# 7a. uv + headroom (トークン圧縮プロキシ / コンテキスト最適化レイヤー)
# ---------------------------------------------------------------------------
# uv (Python パッケージマネージャ) をまず入れ、その `uv tool install` で
# headroom を CLI 用の独立環境にインストールする。
#
# headroom は Claude Code / Codex 等コーディングエージェントの API リクエストを
# ローカルプロキシ(headroom wrap <tool>)経由に通し、ツール出力・ログ・
# ファイル読み込み内容などを LLM に送る前に圧縮する(トークン削減)。
# `ANTHROPIC_BASE_URL` を書き換えるだけで認証情報(claude.ai の OAuth ログイン等)
# には一切触れない(公式ドキュメント: docs.headroomlabs.ai/docs/vscode-claude-code
# 「Headroom does not store or replace your Anthropic credentials」)。
RUN curl -LsSf https://astral.sh/uv/install.sh | sh \
    && "${HOME}/.local/bin/uv" tool install --python 3.11 "headroom-ai[proxy]"

# ---------------------------------------------------------------------------
# 7b. claude コマンドを headroom 経由 + システムプロンプト追記に差し替える
# ---------------------------------------------------------------------------
# `claude` を直接実行する代わりに `headroom wrap claude` を挟み、トークン圧縮
# プロキシ経由で起動する alias を ~/.bashrc に登録する。`headroom wrap claude`
# は認識しないフラグをすべてそのまま claude 本体へパススルーする仕様
# (`headroom wrap claude --help` 参照)なので、
# config/claude-system-prompt-addition.md の内容を --append-system-prompt で
# 追記する既存の運用もそのまま維持できる。
# ファイルは /opt (イメージに焼き込み、compose.yaml で永続化対象にしていない
# 領域)に置く。内容を変更したい場合はこのファイルを編集してイメージを
# 再ビルドする。
COPY config/claude-system-prompt-addition.md /opt/claude-system-prompt-addition.md
RUN { \
        echo ''; \
        echo '# claude コマンドを headroom 経由 + システムプロンプト追記で起動する alias'; \
        echo '# (Dockerfile が生成。/opt/claude-system-prompt-addition.md 参照)'; \
        echo 'alias claude='"'"'headroom wrap claude --append-system-prompt "$(cat /opt/claude-system-prompt-addition.md)"'"'"''; \
    } >> "${HOME}/.bashrc"

# ---------------------------------------------------------------------------
# 7c. Claude Code statusline
# ---------------------------------------------------------------------------
# ~/.claude は compose.yaml で WSL 側にバインドマウントされ、ホームディレクトリ
# 配下に焼き込んでも起動時にマウントで隠れてしまう。そのため、スクリプト本体は
# /opt (イメージ焼き込み領域、上記 7b と同じ理由)に置き、~/.claude/settings.json
# 側からそれを参照させる。settings.json はマウントされる既存ファイルのため、
# ここでは書き込まず、entrypoint.sh が起動のたびに statusLine 設定をマージする。
COPY --chmod=0755 scripts/statusline.sh /opt/statusline.sh

# ---------------------------------------------------------------------------
# 11. 便利コマンドのシンボリックリンク (Debian の fd-find は fdfind という名前になる)
# ---------------------------------------------------------------------------
RUN mkdir -p "${HOME}/.local/bin" \
    && ln -sf "$(command -v fdfind)" "${HOME}/.local/bin/fd"

# ---------------------------------------------------------------------------
# 12. entrypoint 設定
# ---------------------------------------------------------------------------
USER root
COPY --chmod=0755 scripts/entrypoint.sh /usr/local/bin/entrypoint.sh

USER ${USERNAME}

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["sleep", "infinity"]

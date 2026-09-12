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
    CARGO_HOME=/home/${USERNAME}/.cargo \
    RUSTUP_HOME=/home/${USERNAME}/.rustup \
    PATH=/home/${USERNAME}/.local/bin:/home/${USERNAME}/.cargo/bin:/usr/local/go/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# jcode の実行ファイル本体(~/.jcode/builds/...)はイメージビルド時に焼き込まれる。
# compose.yaml で ~/.jcode をそのままバインドマウントすると、その焼き込んだ
# builds/ がホスト側の空ディレクトリで隠れてしまい、`jcode: command not found`
# になる(~/.local/bin/jcode はシンボリックリンクで実体は ~/.jcode/builds 配下)。
# jcode は認証情報等の保存先を JCODE_HOME で変更できるため、認証情報の永続化用
# ディレクトリをバイナリの実体とは別の ~/.jcode-data に分離する。
# 永続化対象は compose.yaml で ~/.jcode-data のみをマウントし、
# ~/.jcode(builds 本体)はイメージに焼き込んだままにする。
ENV JCODE_HOME=/home/${USERNAME}/.jcode-data

# nvm/rustup/uv のインストーラースクリプトは bash 依存(dash非互換)のため、
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
        default-jdk \
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
# 4c. AWS SAM CLI (公式インストーラー)
# ---------------------------------------------------------------------------
RUN SAM_ARCH="$(dpkg --print-architecture)" \
    && case "${SAM_ARCH}" in \
         amd64) SAM_CLI_ARCH="x86_64" ;; \
         arm64) SAM_CLI_ARCH="arm64" ;; \
         *) echo "Unsupported architecture for AWS SAM CLI: ${SAM_ARCH}" >&2; exit 1 ;; \
       esac \
    && curl -fsSL "https://github.com/aws/aws-sam-cli/releases/latest/download/aws-sam-cli-linux-${SAM_CLI_ARCH}.zip" -o /tmp/aws-sam-cli.zip \
    && unzip -q /tmp/aws-sam-cli.zip -d /tmp/sam-installation \
    && /tmp/sam-installation/install \
    && rm -rf /tmp/aws-sam-cli.zip /tmp/sam-installation

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
# 4e. Neovim (公式リリースの最新安定版 tarball)
# ---------------------------------------------------------------------------
# Debian の apt にある neovim パッケージ (bookworm 時点で 0.7 系) は古く、
# 後述のプラグイン (lazy.nvim, telescope.nvim, nvim-lspconfig 等) が要求する
# 最新安定版の機能を満たせないため、公式ビルド済み tarball を /opt/nvim に
# 展開し、シンボリックリンクで /usr/local/bin/nvim から参照する。
RUN NVIM_ARCH="$(dpkg --print-architecture)" \
    && case "${NVIM_ARCH}" in \
         amd64) NVIM_TARBALL_ARCH="x86_64" ;; \
         arm64) NVIM_TARBALL_ARCH="arm64" ;; \
         *) echo "Unsupported architecture for Neovim: ${NVIM_ARCH}" >&2; exit 1 ;; \
       esac \
    && curl -fsSL "https://github.com/neovim/neovim/releases/latest/download/nvim-linux-${NVIM_TARBALL_ARCH}.tar.gz" \
        -o /tmp/nvim.tar.gz \
    && tar -C /opt -xzf /tmp/nvim.tar.gz \
    && rm -f /tmp/nvim.tar.gz \
    && mv "/opt/nvim-linux-${NVIM_TARBALL_ARCH}" /opt/nvim \
    && ln -sf /opt/nvim/bin/nvim /usr/local/bin/nvim

# ---------------------------------------------------------------------------
# 4f. rtk (Rust Token Killer) / lean-ctx: jcode エージェント用コンテキスト圧縮CLI
# ---------------------------------------------------------------------------
# どちらも「シェルコマンドの出力をLLMに見せる前に圧縮する」CLI。lean-ctx は
# シェルフック方式に加えて MCP サーバーも提供する(後述のセクション参照)。
# lean-ctx は x86_64/arm64 とも musl(静的リンク)版があるが、rtk の arm64 版は
# musl 提供が無く gnu(動的リンク, glibc依存)版のみのため、アーキテクチャごとに
# 別々にファイル名を組み立てる。
RUN DPKG_ARCH="$(dpkg --print-architecture)" \
    && case "${DPKG_ARCH}" in \
         amd64) RTK_ARCH="x86_64-unknown-linux-musl"; LC_ARCH="x86_64-unknown-linux-musl" ;; \
         arm64) RTK_ARCH="aarch64-unknown-linux-gnu"; LC_ARCH="aarch64-unknown-linux-musl" ;; \
         *) echo "Unsupported architecture for rtk/lean-ctx: ${DPKG_ARCH}" >&2; exit 1 ;; \
       esac \
    && curl -fsSL "https://github.com/rtk-ai/rtk/releases/latest/download/rtk-${RTK_ARCH}.tar.gz" \
        -o /tmp/rtk.tar.gz \
    && tar -C /usr/local/bin -xzf /tmp/rtk.tar.gz rtk \
    && chmod +x /usr/local/bin/rtk \
    && rm -f /tmp/rtk.tar.gz \
    && curl -fsSL "https://github.com/yvgude/lean-ctx/releases/latest/download/lean-ctx-${LC_ARCH}.tar.gz" \
        -o /tmp/lean-ctx.tar.gz \
    && tar -C /usr/local/bin -xzf /tmp/lean-ctx.tar.gz lean-ctx \
    && chmod +x /usr/local/bin/lean-ctx \
    && rm -f /tmp/lean-ctx.tar.gz

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
# 7. pnpm, Vue CLI, Claude Code CLI, herdr, jcode
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
    && curl -fsSL https://jcode.sh/install | bash \
    && NODE_BIN_DIR="$(dirname "$(nvm which default)")" \
    && ln -sf "${NODE_BIN_DIR}"/* "${HOME}/.local/bin/"

# jcode の自動アップデートチェックを無効化(コンテナ内で毎起動チェックさせない)
# jcode は config.toml を ~/.jcode ではなく $JCODE_HOME から読むため、
# JCODE_HOME(= ~/.jcode-data)側に書く。
RUN mkdir -p "${JCODE_HOME}" \
    && printf '[features]\ncheck_updates = false\n' > "${JCODE_HOME}/config.toml"

# ---------------------------------------------------------------------------
# 7a. lean-ctx: jcode 用シェルフック + MCP サーバー登録
# ---------------------------------------------------------------------------
# lean-ctx はエイリアス方式のシェルフック(git/cargo/npm 等の出力を圧縮する)
# と MCP サーバー(ctx_read 等のツール)の両方を提供する。
#
# シェルフック: `lean-ctx init --global` は ~/.bashrc にフック読み込み1行を
# 追記し、本体は ~/.config/lean-ctx/{env.sh,shell-hook.bash} に生成する。
# これらは compose.yaml で永続化対象にしていない(bashrc 等はイメージに
# 焼き込んだツールチェーン群と同様、ビルド時に確定させる方針。README.md の
# 「認証情報・設定の永続化」参照)ため、ここで実行して問題ない。
#
# ただし alias ベースのフックは非対話シェル(`bash -c "..."`。jcode の Bash
# ツールがコマンドを実行する形)では `shopt -s expand_aliases` が既定 off
# のため素通りしてしまう。jcode 用に、先に expand_aliases を立ててから本体の
# env.sh を読み込むラッパー(jcode-env.sh)を用意し、compose.yaml の
# `BASH_ENV`/`LEAN_CTX_AGENT` でこれを使わせる(対話シェルには影響しない)。
#
# MCP サーバー登録: mcp.json は config.toml と同じく JCODE_HOME 配下にあり、
# 初回のバインドマウントでビルド時の内容が隠れてしまうため、
# entrypoint.sh 側でも同じ内容を(存在しなければ)補完する
# (docker/scripts/entrypoint.sh 参照)。
RUN lean-ctx init --global >/tmp/lean-ctx-init.log 2>&1 \
    && { \
        echo '# jcode 用ラッパー(entrypoint.sh からは触らない。Dockerfile が生成)。'; \
        echo '# 非対話シェル(bash -c)でも alias ベースのフックが効くよう expand_aliases を'; \
        echo '# 先に有効化してから本体の env.sh を読み込む。'; \
        echo 'shopt -s expand_aliases'; \
        echo '. "$HOME/.config/lean-ctx/env.sh"'; \
    } > "${HOME}/.config/lean-ctx/jcode-env.sh"

RUN mkdir -p "${JCODE_HOME}" \
    && printf '{\n  "mcpServers": {\n    "lean-ctx": {\n      "command": "lean-ctx"\n    }\n  }\n}\n' \
        > "${JCODE_HOME}/mcp.json"

# rtk/lean-ctx の使い方を jcode エージェントに知らせる指示ファイル
# (config/preferred-tools.md)。jcode はこれを $JCODE_HOME/preferred-tools.md
# から読み、システムプロンプトに追加する(docs/SYSTEM_PROMPT_CONFIG.md 参照)。
# JCODE_HOME 配下は初回のバインドマウントで空になるため、雛形を
# /opt/ctx-tools-preferred-tools.md にも置いておき、entrypoint.sh が
# (ファイルが無ければ)そこからコピーして補完する
# (docker/scripts/entrypoint.sh 参照)。
COPY config/preferred-tools.md /opt/ctx-tools-preferred-tools.md
RUN cp /opt/ctx-tools-preferred-tools.md "${JCODE_HOME}/preferred-tools.md"

# ---------------------------------------------------------------------------
# 7b. Neovim 設定 (lazy.nvim + プラグイン群)
# ---------------------------------------------------------------------------
# 参考: https://zenn.dev/forcia_tech/articles/202411_deguchi_neovim
# config/nvim/ 配下の設定一式 (init.lua, lua/config/lazy.lua, lua/plugins/*.lua)
# を ~/.config/nvim にそのまま配置する。プラグイン本体はビルド時に
# `nvim --headless "+Lazy! sync" +qa` で事前インストールしておくことで、
# コンテナ起動後の初回 nvim 起動時にダウンロード待ちが発生しないようにする。
COPY --chown=${USERNAME}:${USERNAME} config/nvim/ "${HOME}/.config/nvim/"
RUN nvim --headless "+Lazy! sync" +qa || true \
    && nvim --headless "+Lazy! sync" +qa

# ---------------------------------------------------------------------------
# 8. Python: uv
# ---------------------------------------------------------------------------
RUN curl -LsSf https://astral.sh/uv/install.sh | sh

# ---------------------------------------------------------------------------
# 9. Rust (rustup, cargo)
# ---------------------------------------------------------------------------
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

# ---------------------------------------------------------------------------
# 10. code-server (VS Code in the browser)
# ---------------------------------------------------------------------------
RUN curl -fsSL https://code-server.dev/install.sh | sh \
    && mkdir -p "${HOME}/.config/code-server" \
    && printf 'bind-addr: 0.0.0.0:8153\nauth: none\ncert: false\n' > "${HOME}/.config/code-server/config.yaml"

# ---------------------------------------------------------------------------
# 11. 便利コマンドのシンボリックリンク (Debian の fd-find は fdfind という名前になる)
# ---------------------------------------------------------------------------
RUN mkdir -p "${HOME}/.local/bin" \
    && ln -sf "$(command -v fdfind)" "${HOME}/.local/bin/fd"

# ---------------------------------------------------------------------------
# 11b. jcode Claude ログイン用ヘルパー(ブラウザなし環境向け)
# ---------------------------------------------------------------------------
# コンテナには GUI ブラウザが無いため `jcode login` の通常の OAuth
# ループバック認証は使えない。`docker exec -it dev-container jcode-login-claude`
# で --no-browser 付きの login を呼び出せるようにしておく
# (詳細はスクリプト内コメントおよび README.md 参照)。
USER root
COPY --chmod=0755 scripts/jcode-login-claude.sh /usr/local/bin/jcode-login-claude
USER ${USERNAME}

# ---------------------------------------------------------------------------
# 12. entrypoint 設定
# ---------------------------------------------------------------------------
USER root
COPY --chmod=0755 scripts/entrypoint.sh /usr/local/bin/entrypoint.sh

USER ${USERNAME}

# 8153: code-server
EXPOSE 8153

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["sleep", "infinity"]

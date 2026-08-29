# 認証情報・設定の永続化

`docker compose down`(コンテナ削除)や `docker rm` を行うと、コンテナのファイル
システムは消える。`jcode login` や `gh auth login` などでコンテナ内に入れた
認証情報も一緒に消え、再ログインが必要になる。

これを避けるため、`compose.yaml` は以下のディレクトリ/ファイルを個別に
WSL Debian 側へバインドマウントする(`~/` 配下を丸ごとマウントはしない。
理由は Dockerfile の nvm/cargo/rustup 等ビルド時に焼き込んだツールチェーンが
空のホスト側ディレクトリで上書きされ壊れるため)。

| コンテナ内パス | 内容 | `.env` の変数 |
| --- | --- | --- |
| `~/.jcode-data` (`$JCODE_HOME`) | `jcode login` の認証情報 (`auth.json` 等) | `WSL_JCODE_HOME` |
| `~/.config/gh` | `gh auth login` の認証情報 | `WSL_GH_CONFIG_HOME` |
| `~/.claude` | Claude Code CLI の認証情報 (`.credentials.json` 等) | `WSL_CLAUDE_HOME` |
| `~/.ssh` | SSH 鍵 | `WSL_SSH_HOME` |
| `~/.config/git` | git のユーザー設定(ディレクトリ) | `WSL_GIT_CONFIG_HOME` |
| `~/.npmrc` | npm の認証・レジストリ設定(ファイル) | `WSL_NPMRC_FILE` |
| `~/.aws` | AWS CLI の認証情報・設定(`credentials`, `config` 等) | `WSL_AWS_HOME` |
| `~/.config/herdr` | herdr の設定・セッション状態(`config.toml`, `session.json` 等) | `WSL_HERDR_CONFIG_HOME` |
| `~/.local/state/herdr` | herdr のエージェント検出状態(`agent-detection/` 配下) | `WSL_HERDR_STATE_HOME` |

`~/.config/git` は `~/.gitconfig` をファイル単体でマウントするのではなく
ディレクトリマウントにしている。`~/.gitconfig` をファイルとしてバインド
マウントすると、`gh auth login` 等が設定書き込み時に一時ファイル作成 →
rename で置き換えようとして `Device or resource busy` になるため
(bind mount されたファイルは rename によるすり替えができない)。
git はグローバル設定として `~/.gitconfig` が無ければ `~/.config/git/config`
を読むため、ディレクトリ側をマウントすることで同じ書き込みパターンでも
問題が起きないようにしている。

`~/.jcode-data` を `~/.jcode` そのものではなく別ディレクトリにしているのは、
jcode の実行ファイル本体(`~/.jcode/builds/...`、`~/.local/bin/jcode` から
シンボリックリンクされている)がイメージビルド時に焼き込まれているため。
`~/.jcode` を丸ごとバインドマウントすると、その `builds/` がホスト側の空
ディレクトリで隠れて `jcode: command not found` になる。jcode は認証情報等の
保存先ディレクトリを `JCODE_HOME` 環境変数で変更できるため、Dockerfile で
`JCODE_HOME=/home/developer/.jcode-data` を設定し、認証情報だけをこちらに
分離して永続化している。

## 事前準備

`setup-dev-container.bat`(内部で `setup-dev-container.sh` を実行)が、
上記すべてのディレクトリ/ファイルの作成と、コンテナ内ユーザー(既定 UID/GID
1000:1000)への所有権の設定を自動的に行う。手動での `mkdir`/`chown` は不要。

マウント元を事前に作成せず所有権も合わせないまま `docker compose up` すると、
Docker がディレクトリを自動作成するが所有者が `root` になり、コンテナ内から
書き込めずクラッシュする(詳細は [TROUBLESHOOTING.md](./TROUBLESHOOTING.md))。
`setup-dev-container.bat` はこれを避けるために存在する。

`.env` のパスを変更した場合は、`setup-dev-container.bat` を再実行すること
(何度実行しても安全)。

`~/.ssh` に既存の鍵を使いたい場合は、`setup-dev-container.bat` 実行後に
WSL Debian 側の該当フォルダー(`WSL_SSH_HOME` に指定したパス)へホストの
`~/.ssh/id_ed25519` 等をコピーしておく。パーミッションは `entrypoint.sh` が
起動のたびに `700`(ディレクトリ)/`600`(秘密鍵)/`644`(`*.pub`)へ強制するため、
コピー後に手動で `chmod` する必要はない。

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
| `~/.jcode` | `jcode login` の認証情報 (`auth.json` 等) | `WSL_JCODE_HOME` |
| `~/.config/gh` | `gh auth login` の認証情報 | `WSL_GH_CONFIG_HOME` |
| `~/.claude` | Claude Code CLI の認証情報 (`.credentials.json` 等) | `WSL_CLAUDE_HOME` |
| `~/.ssh` | SSH 鍵 | `WSL_SSH_HOME` |
| `~/.gitconfig` | git のユーザー設定(ファイル) | `WSL_GITCONFIG_FILE` |
| `~/.npmrc` | npm の認証・レジストリ設定(ファイル) | `WSL_NPMRC_FILE` |

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

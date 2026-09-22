# 認証情報・設定の永続化

`docker compose down`(コンテナ削除)や `docker rm` を行うと、コンテナのファイル
システムは消える。`claude` や `gh auth login` などでコンテナ内に入れた
認証情報も一緒に消え、再ログインが必要になる。

これを避けるため、`compose.yaml` は以下のディレクトリ/ファイルを個別に
WSL Debian 側へバインドマウントする(`~/` 配下を丸ごとマウントはしない。
理由は Dockerfile の nvm/cargo/rustup 等ビルド時に焼き込んだツールチェーンが
空のホスト側ディレクトリで上書きされ壊れるため)。

| コンテナ内パス | 内容 | `.env` の変数 |
| --- | --- | --- |
| `~/.config/gh` | `gh auth login` の認証情報 | `WSL_GH_CONFIG_HOME` |
| `~/.claude` | Claude Code CLI の認証情報 (`.credentials.json` 等) | `WSL_CLAUDE_HOME` |
| `~/.claude.json` | Claude Code CLI のアカウント状態 (`oauthAccount`, `userID` 等)。`~/.claude` ディレクトリとは別の `$HOME` 直下の単一ファイル | `WSL_CLAUDE_JSON_FILE` |
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

## `~/.claude.json` の rename 上書きに関する注意

`~/.claude` ディレクトリのマウントは既存のリレー経由バインドマウントで、
既存ファイルへの `mv`(rename)上書きが失敗する既知の問題がある
(`settings.json` の statusLine/permissions 書き込みで実際に発生し、
`cat`+`rm` による直接書き込みに変更して回避した。Dockerfile 7c/7d 参照)。
`~/.claude.json` は Claude Code CLI 自身が(このリポジトリのスクリプトではなく
CLI 内部のロジックで)書き込むファイルのため、同じ理由で書き込みが
失敗している場合はこちら側では回避できない。その場合は CLI のログや
`strace` 等で実際の書き込み方式(rename か in-place 上書きか)を確認すること。

## ホストの全ドライブのマウント

上記の認証情報とは別に、ホストの全ドライブ(Windows の C:, D: 等)は
`start.bat`/`stop.bat` 実行時に
`scripts/generate-host-drives-compose.sh` が `WSL_HOST_DRIVES_SOURCE`
(既定値 `/mnt`。WSL が自動マウント済み)配下を動的検出し、ドライブごとに
`container-general-develop/config/compose.host-drives.yaml`(自動生成物)へ
バインドマウント定義を生成、コンテナの `/mnt/host-drives` 配下へマウントする。
これは認証情報の永続化とは目的が異なり(コンテナ削除後もホスト側にデータは
残り続ける)、`setup.sh` の `mkdir`/`chown` 対象にも含めていない。
`/mnt` を丸ごとマウントせずドライブ単位にしている理由は
[BACKGROUND.md](./BACKGROUND.md) 参照。

## 事前準備

`setup.bat`(内部で `setup.sh` を実行)が、
上記すべてのディレクトリ/ファイルの作成と、コンテナ内ユーザー(既定 UID/GID
1000:1000)への所有権の設定を自動的に行う。手動での `mkdir`/`chown` は不要。

マウント元を事前に作成せず所有権も合わせないまま `docker compose up` すると、
Docker がディレクトリを自動作成するが所有者が `root` になり、コンテナ内から
書き込めずクラッシュする(詳細は [TROUBLESHOOTING.md](./TROUBLESHOOTING.md))。
`setup.bat` はこれを避けるために存在する。

`.env` のパスを変更した場合は、`setup.bat` を再実行すること
(何度実行しても安全)。

`~/.ssh` に既存の鍵を使いたい場合は、`setup.bat` 実行後に
WSL Debian 側の該当フォルダー(`WSL_SSH_HOME` に指定したパス)へホストの
`~/.ssh/id_ed25519` 等をコピーしておく。パーミッションは `entrypoint.sh` が
起動のたびに `700`(ディレクトリ)/`600`(秘密鍵)/`644`(`*.pub`)へ強制するため、
コピー後に手動で `chmod` する必要はない。

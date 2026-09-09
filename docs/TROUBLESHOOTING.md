# トラブルシューティング

## コンテナ内で `jcode: command not found` になる

**原因**: jcode の実行ファイル本体は `~/.jcode/builds/...` に配置され、
`~/.local/bin/jcode` はそこへのシンボリックリンクに過ぎない。以前の
`compose.yaml` は `~/.jcode` を丸ごとバインドマウントしていたため、イメージ
ビルド時に焼き込んだ `builds/` がホスト側の空ディレクトリで隠れてしまい、
シンボリックリンクの参照先が存在しない状態になっていた。

**対処**: jcode は認証情報等の保存先を `JCODE_HOME` 環境変数で変更できる。
本リポジトリでは Dockerfile で `JCODE_HOME=/home/developer/.jcode-data` を
設定し、`compose.yaml` も `WSL_JCODE_HOME` のマウント先を
`/home/developer/.jcode-data` に変更済み。認証情報 (`auth.json` 等) は
`~/.jcode-data` 側に永続化され、`~/.jcode`(バイナリ本体)はイメージに
焼き込んだまま保たれる。

既に古い設定で `~/.jcode` をマウントしたまま運用していた場合は、
`docker\config\.env` の `WSL_JCODE_HOME` はそのままで構わない(マウント先の変更は
`compose.yaml` 側で行うため)。`docker compose up -d --build` でイメージと
コンテナを作り直せば解消する。

## `exec-dev-container.bat` が `The dev-container is not running.` と出る

`docker compose ps` でコンテナが `Restarting` を繰り返していないか確認する
(WSL Debian のシェルで):

```bash
docker ps -a --filter name=dev-container
docker logs --tail 50 dev-container
```

ログに以下が出ている場合、`.env` で指定したマウント元ディレクトリ/ファイルの
所有権が原因である:

```text
/usr/local/bin/entrypoint.sh: line NN: /home/developer/.jcode/config.toml: Permission denied
```

**原因**: マウント元(`WSL_JCODE_HOME` 等で指定したパス)を事前に作成しないまま
`docker compose up` すると、Docker がディレクトリを自動作成するが所有者が
`root:root` になる。コンテナ内の非 root ユーザー(既定 UID/GID 1000:1000)から
書き込めず、`entrypoint.sh` が失敗してクラッシュループ(`restart: always`)する。

**対処**: `setup-dev-container.bat` を実行して所有権を直してから、
`stop-dev-container.bat` → `start-dev-container.bat` の順に実行してください。

## `setup-dev-container.bat` で `mkdir: cannot create directory '/workspace': Permission denied` が出る

**原因**: `.env` の `WSL_MOUNT_SOURCE` 等が `/workspace` のように WSL Debian の
ルート直下(root 所有)を指すパスになっている。一般ユーザーは root 所有ディレクトリ
配下に `mkdir`/`chown` できないため失敗する(既定値は `$HOME/workspace/...` に
なっているが、古い `.env` を使い回している場合や手動でパスを書き換えた場合に
発生し得る)。

**対処**: `docker\config\.env` を開き、`WSL_MOUNT_SOURCE` などのパスを
`$HOME/workspace/...`(WSL Debian 側の自分のホームディレクトリ配下)のような
書き込み権限のある場所に書き換えてから、`setup-dev-container.bat` を再実行する。
`.env` は docker compose がそのまま読むファイルのため `$HOME` は展開されない。
WSL Debian のシェルで `echo $HOME` を実行して実際のパス(例: `/home/ユーザー名`)
に置き換えること。

## `docker build`/`docker compose up` で credential helper エラーが出る

`docker-credential-wincred.exe: exec format error` や
`docker-credential-secretservice: error while loading shared libraries:
libsecret-1.so.0` が出る場合は、[BACKGROUND.md](./BACKGROUND.md) の
「Windows PATH interop による docker credential helper の破損」を参照。

## `-v \\wsl$\...` を指定した `docker run`/`docker compose` が失敗する

`docker: ... includes invalid characters for a local volume name ...` は
Rancher Desktop の既知の制限。Windows の PowerShell から直接実行せず、
WSL Debian のシェルに入ってネイティブパスで実行すること。詳細は
[BACKGROUND.md](./BACKGROUND.md) を参照。

## コンテナ内で `docker` コマンドが `permission denied` になる/そもそも動かない

まず WSL Debian 側で `/var/run/docker.sock` が存在するか確認する:

```bash
ls -l /var/run/docker.sock
```

**存在しない場合**: Rancher Desktop の `Preferences > WSL > Integrations` で
`Debian` が有効になっているか確認する(手順2)。有効化直後は再起動が
必要な場合がある。

**存在するが権限エラーになる場合**: `entrypoint.sh` がコンテナ起動時に
ソケットの GID に合わせてグループを自動作成し、`developer` ユーザーを
追加する処理を行っている(詳細は
[BACKGROUND.md](./BACKGROUND.md) の「コンテナ内から `docker` コマンドを
使う」参照)。それでも失敗する場合は、コンテナ内で以下を実行してソケットの
所有者/権限を確認する:

```bash
ls -l /var/run/docker.sock
id
```

上記グループにユーザーが含まれていない場合は、一度
`stop-dev-container.bat` → `start-dev-container.bat` でコンテナを再作成する
(`entrypoint.sh` は毎起動時にグループ調整を行うため、多くの場合これで解消する)。

## `start-dev-container.bat` で `munger failed ... could not unmount bind mount ... invalid argument` が出る

**原因**: 以前のバージョンではホストの全ドライブを `/mnt` ごとコンテナへ
バインドマウントしていたが、`/mnt` はその配下に `/mnt/c`, `/mnt/d` ... という
個別のマウントポイントがネストされたディレクトリであるため、コンテナ再作成時に
Rancher Desktop 側のアンマウント処理が失敗することがあった。

**対処**: 現在は `scripts/generate-host-drives-compose.sh` がドライブごとに
個別のバインドマウントを動的生成する方式に変更済み(詳細は
[BACKGROUND.md](./BACKGROUND.md) の「ホストの全ドライブをコンテナにマウントする」
参照)。このエラーが出る場合、リポジトリを最新化した上で
`stop-dev-container.bat` → `start-dev-container.bat` を実行し、コンテナを
作り直してください。それでも解消しない場合は `wsl --shutdown` で WSL 全体を
再起動してから Rancher Desktop を再起動し、再度試してください。

## コンテナ内でネットワークドライブ(Z: など)が `/mnt/host-drives/z` に見えない

**原因候補1**: そのネットワークドライブが Windows 側で切断されている
(VPN 未接続、共有サーバーに到達できない等)。`start-dev-container.bat` の
ログに `[mount-network-drives] ... -> FAILED` と出ていないか確認する。

**原因候補2**: WSL Debian のシェルで手動マウントしていた古い `/mnt/<文字>`
が残っていて、`mount-network-drives.sh` が「既にマウント済み」と判断して
スキップしている。WSL Debian のシェルで以下を実行して状態を確認する:

```bash
cat /proc/mounts | grep /mnt/z
```

期待と異なるパスがマウントされている場合、`wsl --shutdown` で WSL を
完全に再起動してから `start-dev-container.bat` を再実行する
(WSL 再起動により全マウントがリセットされる)。

**原因候補3**: WSL Debian 側で Windows 実行ファイルを呼び出す機能
(interop)自体が壊れている。`start-dev-container.bat` のログに
`[mount-network-drives] WARNING: powershell.exe exited with status ...`
と出ていないか確認する。WSL Debian のシェルで以下を実行して確認できる:

```bash
cat /proc/sys/fs/binfmt_misc/WSLInterop
```

`No such file or directory` の場合、interop が無効化されている
(`cannot execute binary file: Exec format error` の原因)。本リポジトリの
スクリプトの問題ではなく WSL 側の状態異常のため、`wsl --shutdown` で
WSL 全体を再起動する必要がある(WSL Debian だけの再起動(`wsl -t Debian`)
では直らないことがある)。ただし `wsl --shutdown` は Rancher Desktop の
内部 VM(`rancher-desktop`)も巻き込んで停止させる可能性があるため、
実行後に `docker compose up` が
`Cannot connect to the Docker daemon at unix:///var/run/docker.sock` で
失敗する場合は、Rancher Desktop を手動で再起動すること。

**対処**: いずれの場合も `start-dev-container.bat` を再実行すれば
`scripts/mount-network-drives.sh` が再検出・再マウントを試みる。
ネットワークドライブが利用できない状態でも `start-dev-container.bat` 自体は
失敗せず、警告を出してそのまま起動を続ける。


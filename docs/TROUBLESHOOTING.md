# トラブルシューティング

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

**対処**: `docker\.env` を開き、`WSL_MOUNT_SOURCE` などのパスを
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

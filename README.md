# development-environment

WSL と コンテナランタイム(Rancher Desktop) を組み合わせた開発環境を構築するスクリプト群。

**以下の手順を上から順番に実行するだけで環境構築が完了します。
手順2以降はすべて、フォルダー内の `.bat` ファイルをダブルクリックするだけです。**

構成や各判断の理由は [docs/BACKGROUND.md](./docs/BACKGROUND.md) を、詰まった場合は
[docs/TROUBLESHOOTING.md](./docs/TROUBLESHOOTING.md) を参照してください。

---

## 手順1: WSL Debian のインストール

PowerShell を開き、次のコマンドをそのまま貼り付けて実行してください。

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\scripts\Install-DebianWSL.ps1 -Force
```

実行すると、初回のみ画面に `Enter new UNIX username` のような表示が出ます。
任意のユーザー名を入力して Enter を押し、続けてパスワードを入力してください。
(パスワード入力中は画面に文字が表示されませんが、そのまま入力を続けて Enter を押してください)

> このマシンで初めて WSL をインストールする場合、この後 **再起動が必要になることがあります**。
> 再起動を促すメッセージが表示された場合は、Windows を再起動してから手順2に進んでください。

## 手順2: Rancher Desktop の WSL Integration を有効化する

Rancher Desktop を開き、`Preferences > WSL > Integrations` で `Debian` をオンにしてください。

## 手順3: 初回セットアップ

`create-dockerfile\docker` フォルダーにある **`setup-dev-container.bat`** を
ダブルクリックしてください。

これだけで、docker の設定・`.env` の作成・保存用フォルダーの準備が自動的に
行われます(何を作っているかは [docs/PERSISTENCE.md](./docs/PERSISTENCE.md) 参照)。
実行中に WSL Debian のパスワード入力を求められることがあります。

> 開発用ファイルを置く場所を変更したい場合は、`docker\.env` をテキストエディタで
> 開いて `WSL_MOUNT_SOURCE` を書き換えてから、もう一度 `setup-dev-container.bat`
> を実行してください(何度実行しても安全です)。

## 手順4: 起動

同じフォルダーの **`start-dev-container.bat`** をダブルクリックしてください。
初回はイメージのビルドが走るため数分かかります。

## 手順5: 接続

同じフォルダーの **`exec-dev-container.bat`** をダブルクリックすると、
コンテナ内のシェルに入れます。

---

## よく使う操作(すべて `create-dockerfile\docker` フォルダー内)

| やりたいこと | ファイル |
| --- | --- |
| 起動 | `start-dev-container.bat` |
| 削除(イメージは残る) | `stop-dev-container.bat` |
| コンテナに接続 | `exec-dev-container.bat` |
| `.env` 編集後の再セットアップ | `setup-dev-container.bat` |

コンテナは `restart: always` の設定により、Rancher Desktop が起動している限り
自動起動・自動復帰し続けます(異常終了時も再起動されます)。停止したい場合は
`stop-dev-container.bat` でコンテナごと削除してください。プロジェクトファイルや
認証情報は WSL Debian 側に永続化されているため、`start-dev-container.bat` で
作り直しても失われません(詳細は [docs/PERSISTENCE.md](./docs/PERSISTENCE.md))。

## さらに詳しく

- [docs/BACKGROUND.md](./docs/BACKGROUND.md): なぜこの構成なのか、設計判断の理由
- [docs/PERSISTENCE.md](./docs/PERSISTENCE.md): 認証情報・設定を永続化する仕組み
- [docs/TROUBLESHOOTING.md](./docs/TROUBLESHOOTING.md): 起動しない/エラーになる場合の対処

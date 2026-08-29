# jcode の認証(ブラウザなしログイン)

コンテナには GUI ブラウザが無いため、`jcode login` の通常のブラウザ認証
(ローカルブラウザを起動してのループバック OAuth)は使えない。

## `jcode-login-claude`

Dockerfile がコンテナ内の `/usr/local/bin/jcode-login-claude` に配置する
ヘルパースクリプト(実体は `docker/scripts/jcode-login-claude.sh`)。中身は
以下と同じ:

```bash
jcode login --provider claude --no-browser
```

`--no-browser`(エイリアス `--headless`)を付けることで、jcode はブラウザを
起動する代わりに認証 URL を表示する。表示された URL を手元の PC やスマホの
ブラウザで開いてサインインし、表示されたコードをそのシェルに貼り付けると
ログインが完了する。

### 使い方

1. `exec-dev-container.bat` でコンテナ内のシェルに入る。
2. シェルで次を実行する。

   ```bash
   jcode-login-claude
   ```

3. 表示された URL を別のブラウザで開いてサインインし、表示されたコードを
   このシェルに貼り付ける。

ログイン後の認証情報 (`auth.json` 等) は `JCODE_HOME`(`~/.jcode-data`)配下に
保存され、WSL Debian 側へ永続化される(詳細は
[PERSISTENCE.md](./PERSISTENCE.md) 参照)。コンテナを作り直しても再ログイン
は不要。

## 名前について

コマンド名を `login-claude` ではなく `jcode-login-claude` にしているのは、
`login-claude` だと Claude Code CLI (`claude`) へのログインだと誤解される
ため。このコマンドはあくまで jcode の Claude プロバイダーへのログインを
行う。

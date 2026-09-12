# コンテキスト圧縮ツール: rtk / lean-ctx

このコンテナには、シェルコマンドの出力をあなた(jcode エージェント)に見せる前に
圧縮する2つの CLI がインストールされている。目的は同じ(トークン消費削減)だが、
経路が異なるので使い分けること。

## lean-ctx (MCP ツール経由、推奨)

`lean-ctx` は MCP サーバーとして登録済み(`ctx_read` / `ctx_shell` / `ctx_search` /
`ctx_tree` などのツールが使える)。ファイル読み込み・検索・ディレクトリ一覧・
シェルコマンド実行では、可能な限り以下を優先する:

- ファイル読み込み: 組み込みの `Read` の代わりに `ctx_read`
- コード検索: `agentgrep`/`grep` の代わりに `ctx_search`
- ディレクトリ一覧: `ls`/`find` の代わりに `ctx_tree`
- シェルコマンド全般: `Bash` で直接実行する代わりに `ctx_shell` を使うと、
  git/cargo/npm/pytest 等の出力が自動的に要約される

`Write`/`edit`/`Glob` には lean-ctx の代替がないため、そのまま組み込みツールを使う。

## rtk (シェルコマンドの出力圧縮)

`rtk` は `Bash` ツールでシェルコマンドを直接実行する場合の圧縮レイヤー。
出力が長くなりがちなコマンド(git log/diff/status, cargo test/build, npm/pnpm,
pytest, docker ps 等)は、素のコマンドの代わりに `rtk <command>` を頭に付けて
実行すると、失敗箇所やサマリーだけが返り、大量の生ログを読まずに済む。

```bash
rtk git status
rtk git log
rtk cargo test
rtk npm test
```

出力が省略された場合、末尾に `[full output: rtk recall <hash>]` のようなヒントが
付くので、本当に全文が必要なときだけ `rtk recall <hash>` で復元できる。

## 使い分けの目安

- ファイル読み込み・検索・ディレクトリ一覧 → lean-ctx の MCP ツール
  (`ctx_read`/`ctx_search`/`ctx_tree`)
- シェルコマンドを直接実行する必要がある場合 → `rtk <command>` でラップする
  (`ctx_shell` でも代替可能)
- どちらのツールも入っていない/使えない場合は、これまで通り組み込みツールに
  フォールバックしてよい(このガイダンスは提案であり強制ではない)

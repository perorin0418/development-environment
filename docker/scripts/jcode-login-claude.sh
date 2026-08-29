#!/usr/bin/env bash
#
# jcode-login-claude.sh
#
# コンテナ内には GUI ブラウザが無いため、`jcode login` の通常の OAuth
# ループバック認証(ローカルブラウザを起動しようとするフロー)は使えない。
# --no-browser (エイリアス --headless) を付けて実行することで、jcode が
# ブラウザを起動する代わりに認証 URL を表示するようにする。表示された URL を
# 手元の PC やスマホのブラウザで開いてサインインし、表示されたコードを
# このシェルに貼り付けること。
#
# コンテナ内で直接呼び出す:
#   docker exec -it dev-container jcode-login-claude
#
set -euo pipefail

exec jcode login --provider claude --no-browser "$@"

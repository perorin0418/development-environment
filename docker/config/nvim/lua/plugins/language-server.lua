-- lua/plugins/language-server.lua
--
-- Language Server: nvim-lspconfig, mason.nvim, mason-lspconfig.nvim
-- 参考: https://zenn.dev/forcia_tech/articles/202411_deguchi_neovim
return {
  {
    "williamboman/mason.nvim",
    event = "VeryLazy",
    config = true,
  },
  {
    "williamboman/mason-lspconfig.nvim",
    event = "VeryLazy",
    dependencies = {
      "williamboman/mason.nvim",
      "neovim/nvim-lspconfig",
    },
    opts = {
      -- lua-language-server は Neovim 自体の設定編集に便利なため、代表例
      -- として最初からインストールしておく。他の言語の LS は必要に応じて
      -- :Mason から追加でインストールする。
      ensure_installed = { "lua_ls" },
    },
    config = function(_, opts)
      -- mason-lspconfig v2 以降は setup_handlers が廃止され、
      -- インストール済み LS は自動で有効化される。共通設定は
      -- vim.lsp.config("*", ...) で与える。
      vim.lsp.config("*", {
        capabilities = require("cmp_nvim_lsp").default_capabilities(),
      })

      require("mason-lspconfig").setup(opts)

      -- LS から受け取ったエラーなどの診断情報を表示する。
      vim.diagnostic.config({ virtual_text = true })
    end,
  },
}

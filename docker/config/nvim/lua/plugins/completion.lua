-- lua/plugins/completion.lua
--
-- 自動補完エンジン: nvim-cmp
-- 参考: https://zenn.dev/forcia_tech/articles/202411_deguchi_neovim
--
-- Copilot 由来の補完ソース ("copilot") は copilot.lua (lua/plugins/copilot.lua)
-- によって提供される。LSP の補完が邪魔して Copilot が出ないのも、Copilot の
-- 補完が邪魔して buffer の補完が出ないのも困るため、参考記事同様 group 化はせず
-- 単純にソースを列挙している。
return {
  {
    "hrsh7th/nvim-cmp",
    event = { "InsertEnter", "CmdlineEnter" },
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
      "hrsh7th/cmp-cmdline",
    },
    config = function()
      local cmp = require("cmp")
      cmp.setup({
        mapping = cmp.mapping.preset.insert({
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<CR>"] = cmp.mapping.confirm({ select = true }),
        }),
        sources = cmp.config.sources({
          { name = "copilot" },
          { name = "nvim_lsp" },
        }, {
          { name = "buffer" },
          { name = "path" },
        }),
      })

      cmp.setup.cmdline({ "/", "?" }, {
        mapping = cmp.mapping.preset.cmdline(),
        sources = {
          { name = "buffer" },
        },
      })

      cmp.setup.cmdline(":", {
        mapping = cmp.mapping.preset.cmdline(),
        sources = {
          { name = "cmdline" },
        },
      })
    end,
  },
}

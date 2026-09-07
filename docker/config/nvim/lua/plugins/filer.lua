-- lua/plugins/filer.lua
--
-- ファイラ: nvim-tree
-- 参考: https://zenn.dev/forcia_tech/articles/202411_deguchi_neovim
return {
  {
    "nvim-tree/nvim-tree.lua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    keys = {
      { "<Leader>ee", "<cmd>NvimTreeToggle<cr>", desc = "Toggle nvim-tree" },
    },
    opts = {},
  },
}

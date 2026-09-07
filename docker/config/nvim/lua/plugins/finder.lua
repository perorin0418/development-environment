-- lua/plugins/finder.lua
--
-- ファインダ: telescope.nvim
-- 参考: https://zenn.dev/forcia_tech/articles/202411_deguchi_neovim
return {
  {
    "nvim-telescope/telescope.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
    },
    keys = {
      { "<Leader>ff", "<cmd>Telescope find_files<cr>", desc = "Find files" },
      { "<Leader>fg", "<cmd>Telescope live_grep<cr>", desc = "Live grep" },
      { "<Leader>fb", "<cmd>Telescope buffers<cr>", desc = "Buffers" },
      { "<Leader>fh", "<cmd>Telescope help_tags<cr>", desc = "Help tags" },
    },
  },
}

-- lua/config/lazy.lua
--
-- 参考: https://zenn.dev/forcia_tech/articles/202411_deguchi_neovim
--       https://lazy.folke.io/installation
--
-- mapleader/maplocalleader は lazy.nvim を読み込む前に設定しておく必要がある
-- (マッピングが正しく登録されるため)。
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- クリップボード連携 ("+ レジスタを介さず y/p がそのまま OS クリップボードと
-- 連携するようにする)。コンテナ内では xclip を利用する (Dockerfile 参照)。
vim.opt.clipboard = "unnamedplus"

-- insert モードから normal モードへ <Esc> の代わりに jk で戻れるようにする。
vim.keymap.set("i", "jk", "<Esc>")

-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

-- Setup lazy.nvim
require("lazy").setup({
  spec = {
    -- lua/plugins/*.lua を読み込む
    { import = "plugins" },
  },
  install = { colorscheme = { "habamax" } },
  checker = { enabled = false },
})

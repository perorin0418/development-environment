-- lua/plugins/copilot.lua
--
-- GitHub Copilot: copilot.lua, copilot-cmp
-- 参考: https://zenn.dev/forcia_tech/articles/202411_deguchi_neovim
--
-- 初回利用時は Neovim 内で :Copilot auth を実行し、GitHub アカウントの
-- デバイスコード認証を行う必要がある(GitHub Copilot のサブスクリプションが
-- 別途必要)。copilot-cmp と併用するため copilot.lua 自体の UI (suggestion/panel)
-- は無効化している。
return {
  {
    "zbirenbaum/copilot.lua",
    cmd = { "Copilot" },
    event = { "InsertEnter" },
    opts = {
      suggestion = {
        enabled = false,
      },
      panel = {
        enabled = false,
      },
    },
  },
  {
    "zbirenbaum/copilot-cmp",
    dependencies = { "zbirenbaum/copilot.lua" },
    opts = {},
  },
}

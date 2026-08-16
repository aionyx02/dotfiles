-- =====================================================================
--  gitsigns — 在左邊那一欄標出這個檔案改了哪幾行
--
--  ★ 只綁 ]c / [c 兩個鍵，跳到下一處 / 上一處改動。
--    這兩個是 vim 原生 diff 模式的跳轉鍵，在非 diff 模式下本來就沒有作用，
--    所以借用它們不覆蓋任何東西 —— 而且語意一模一樣，是最自然的接法。
--    (在真正的 diff 模式裡我們把它還回去，見下方的 vim.wo.diff 判斷。)
-- =====================================================================

return {
  plugin = { src = 'https://github.com/lewis6991/gitsigns.nvim' },

  config = function()
    require('gitsigns').setup({
      on_attach = function(bufnr)
        local gs = require('gitsigns')

        -- gitsigns 在 v1.0 把 next_hunk/prev_hunk 換成了 nav_hunk。
        -- 兩個都試，將來哪一邊被拿掉都不會壞。
        local function nav(direction, fallback)
          return function()
            if vim.wo.diff then
              -- 真的在 diff 模式時，把鍵還給 vim 原生行為
              vim.cmd.normal({ args = { direction == 'next' and ']c' or '[c' }, bang = true })
              return
            end
            if type(gs.nav_hunk) == 'function' then
              gs.nav_hunk(direction)
            else
              gs[fallback]()
            end
          end
        end

        vim.keymap.set('n', ']c', nav('next', 'next_hunk'),
          { buffer = bufnr, desc = 'git: 下一處改動' })
        vim.keymap.set('n', '[c', nav('prev', 'prev_hunk'),
          { buffer = bufnr, desc = 'git: 上一處改動' })
      end,
    })
  end,
}

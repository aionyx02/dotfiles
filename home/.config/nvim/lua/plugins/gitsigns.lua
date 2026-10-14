-- =====================================================================
--  gitsigns：在左側標記欄顯示目前檔案有變更的行
--
--  只綁定 ]c / [c，跳至下一處／上一處變更。
--    這兩個是 vim 原生 diff 模式的跳轉鍵，在非 diff 模式下沒有作用，
--    因此借用它們不會覆蓋任何功能，且語意相同。
--    在 diff 模式中仍保留原生行為，見下方的 vim.wo.diff 判斷。
-- =====================================================================

return {
  plugin = { src = 'https://github.com/lewis6991/gitsigns.nvim' },

  config = function()
    require('gitsigns').setup({
      on_attach = function(bufnr)
        local gs = require('gitsigns')

        -- gitsigns v1.0 以 nav_hunk 取代 next_hunk / prev_hunk。
        -- 兩者都支援，日後任一方被移除時仍可運作。
        local function nav(direction, fallback)
          return function()
            if vim.wo.diff then
              -- 在 diff 模式中使用 vim 原生行為
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

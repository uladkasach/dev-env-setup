-- wrap vim.treesitter.start to silently handle absent parsers
local orig_ts_start = vim.treesitter.start
vim.treesitter.start = function(bufnr, lang)
  pcall(orig_ts_start, bufnr, lang)
end

-- bootstrap lazy.nvim plugin manager
local lazypath = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    'git', 'clone', '--filter=blob:none',
    'https://github.com/folke/lazy.nvim.git',
    '--branch=stable', lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- shared diff boundary navigation
local function navigate_diff_boundary(direction, get_chunks, fallback)
  local chunks = get_chunks()
  if not chunks or #chunks == 0 then
    if fallback then fallback() end
    return
  end
  local cursor = vim.api.nvim_win_get_cursor(0)[1]
  if direction == 'down' then
    for i, c in ipairs(chunks) do
      if cursor >= c.start and cursor < c.fin then
        vim.api.nvim_win_set_cursor(0, { c.fin, 0 })
        print('chunk ' .. i .. ' bot')
        return
      elseif cursor == c.fin then
        local next_idx = chunks[i + 1] and (i + 1) or 1
        vim.api.nvim_win_set_cursor(0, { chunks[next_idx].start, 0 })
        print('chunk ' .. next_idx .. ' top')
        return
      end
    end
    -- not in chunk: find next chunk below cursor
    for i, c in ipairs(chunks) do
      if c.start > cursor then
        vim.api.nvim_win_set_cursor(0, { c.start, 0 })
        print('chunk ' .. i .. ' top')
        return
      end
    end
    -- wrap to first
    vim.api.nvim_win_set_cursor(0, { chunks[1].start, 0 })
    print('chunk 1 top')
  else -- up
    for i, c in ipairs(chunks) do
      if cursor > c.start and cursor <= c.fin then
        vim.api.nvim_win_set_cursor(0, { c.start, 0 })
        print('chunk ' .. i .. ' top')
        return
      elseif cursor == c.start then
        local prev_idx = chunks[i - 1] and (i - 1) or #chunks
        vim.api.nvim_win_set_cursor(0, { chunks[prev_idx].fin, 0 })
        print('chunk ' .. prev_idx .. ' bot')
        return
      end
    end
    -- not in chunk: find prev chunk above cursor
    for i = #chunks, 1, -1 do
      if chunks[i].fin < cursor then
        vim.api.nvim_win_set_cursor(0, { chunks[i].fin, 0 })
        print('chunk ' .. i .. ' bot')
        return
      end
    end
    -- wrap to last
    vim.api.nvim_win_set_cursor(0, { chunks[#chunks].fin, 0 })
    print('chunk ' .. #chunks .. ' bot')
  end
end

-- find file path from codediff-explorer line (searches changed/staged files)
local function get_codediff_explorer_file()
  local line = vim.api.nvim_get_current_line()
  -- strip status indicator (M, A, D, etc) at end
  line = line:gsub('%s+[MADRCU?!]%s*$', '')
  -- match filename with brackets, dots, dashes, underscores
  local filename = line:match('([%w_%-%.%[%]]+%.[%w]+)%s*$') or line:match('([%w_%-%.%[%]]+%.[%w]+)')
  if not filename then return nil end
  local cmd = 'git diff --name-only HEAD 2>/dev/null; git diff --cached --name-only 2>/dev/null; git ls-files --others --exclude-standard 2>/dev/null'
  local changed = vim.fn.systemlist(cmd)
  for _, p in ipairs(changed) do
    if p:match(vim.pesc(filename) .. '$') then
      return p
    end
  end
  return filename  -- fallback to just filename
end

-- check if line has diff highlight (works for both vimdiff and codediff)
local function line_has_diff_hl(lnum)
  -- first try native diff_hlID (for vimdiff)
  if vim.fn.diff_hlID(lnum, 1) > 0 then return true end
  -- check extmarks (for codediff.nvim)
  local bufnr = vim.api.nvim_get_current_buf()
  local lnum0 = lnum - 1  -- 0-indexed
  for _, ns_id in pairs(vim.api.nvim_get_namespaces()) do
    local marks = vim.api.nvim_buf_get_extmarks(bufnr, ns_id, { lnum0, 0 }, { lnum0, -1 }, { details = true })
    for _, mark in ipairs(marks) do
      local details = mark[4]
      if details and details.hl_group then
        local hl = details.hl_group
        if hl:match('Diff') or hl:match('Add') or hl:match('Remove') or hl:match('Change') then
          return true
        end
      end
    end
  end
  -- fallback: check syntax highlight
  for col = 1, math.min(10, vim.fn.col({ lnum, '$' })) do
    local hl_id = vim.fn.synID(lnum, col, true)
    local name = vim.fn.synIDattr(hl_id, 'name')
    if name:match('^Diff') then return true end
  end
  return false
end

-- get chunks from diff highlights (for codediff boundary nav)
local function get_diff_hl_chunks()
  local chunks = {}
  local lines = vim.api.nvim_buf_line_count(0)
  local in_chunk = false
  local chunk_start = nil
  for lnum = 1, lines do
    local is_diff = line_has_diff_hl(lnum)
    if is_diff and not in_chunk then
      in_chunk = true
      chunk_start = lnum
    elseif not is_diff and in_chunk then
      table.insert(chunks, { start = chunk_start, fin = lnum - 1 })
      in_chunk = false
    end
  end
  if in_chunk then
    table.insert(chunks, { start = chunk_start, fin = lines })
  end
  return chunks
end

-- plugins
require('lazy').setup({
  {
    'lewis6991/gitsigns.nvim',
    config = function()
      local gs = require('gitsigns')
      gs.setup({
        signs_staged_enable = true,
        attach_to_untracked = true,
        signs = {
          untracked = { text = '┃' },
        },
      })
      -- get chunks from gitsigns hunks
      local function get_gitsigns_chunks()
        local hunks = gs.get_hunks()
        if not hunks then return {} end
        local chunks = {}
        for _, h in ipairs(hunks) do
          table.insert(chunks, {
            start = h.added.start,
            fin = h.added.start + math.max(h.added.count - 1, 0),
          })
        end
        return chunks
      end
      -- ctrl+d alone shows hint
      vim.keymap.set('n', '<C-d>', function()
        print('diff: j/k=nav s/a=stage u=unstage x=discard')
      end, { desc = 'Diff navigation hint' })
      -- ctrl+d j/k to navigate diff boundaries
      local function boundary_down()
        navigate_diff_boundary('down', get_gitsigns_chunks, function()
          gs.next_hunk({ navigation_message = false })
        end)
      end
      local function boundary_up()
        navigate_diff_boundary('up', get_gitsigns_chunks, function()
          gs.prev_hunk({ navigation_message = false })
        end)
      end
      vim.keymap.set('n', '<C-d>j', boundary_down, { desc = 'Next diff boundary' })
      vim.keymap.set('n', '<C-d>k', boundary_up, { desc = 'Prev diff boundary' })
      vim.keymap.set('n', '<C-d><C-j>', boundary_down, { desc = 'Next diff boundary' })
      vim.keymap.set('n', '<C-d><C-k>', boundary_up, { desc = 'Prev diff boundary' })
      -- ctrl+d s = stage, u = unstage, x = discard
      local function stage_buffer()
        gs.stage_buffer()
        print('+stage 🤙')
      end
      local function unstage_buffer()
        gs.reset_buffer_index()
        print('-stage 👋')
      end
      local function discard_buffer()
        gs.reset_buffer()
        print('discarded 🗑️')
      end
      vim.keymap.set('n', '<C-d>s', stage_buffer, { desc = 'Stage buffer' })
      vim.keymap.set('n', '<C-d><C-s>', stage_buffer, { desc = 'Stage buffer' })
      vim.keymap.set('n', '<C-d>a', stage_buffer, { desc = 'Stage buffer' })
      vim.keymap.set('n', '<C-d><C-a>', stage_buffer, { desc = 'Stage buffer' })
      vim.keymap.set('n', '<C-d>u', unstage_buffer, { desc = 'Unstage buffer' })
      vim.keymap.set('n', '<C-d><C-u>', unstage_buffer, { desc = 'Unstage buffer' })
      vim.keymap.set('n', '<C-d>x', discard_buffer, { desc = 'Discard unstaged changes' })
      vim.keymap.set('n', '<C-d><C-x>', discard_buffer, { desc = 'Discard unstaged changes' })
    end,
  },
  {
    'nvim-treesitter/nvim-treesitter',
    version = false,
    lazy = false,  -- CRITICAL: nvim-treesitter does NOT support lazy load
    build = ':TSUpdate',
    config = function()
      local ok, configs = pcall(require, 'nvim-treesitter.configs')
      if ok then
        configs.setup({
          ensure_installed = { 'lua', 'vim', 'vimdoc', 'query', 'markdown', 'bash' },
          auto_install = true,
          highlight = { enable = true },
        })
      end
    end,
  },
  {
    'Isrothy/neominimap.nvim',
    lazy = false,
    init = function()
      vim.g.neominimap = {
        auto_enable = true,
        layout = 'split',  -- use split instead of float
        split = {
          direction = 'right',
          minimap_width = 13,
        },
        exclude_filetypes = { 'neo-tree', 'oil', 'help', 'lazy', 'codediff-explorer' },
        exclude_buftypes = {},  -- allow virtual buffers (for codediff)
        git = {
          enabled = true,
          mode = 'line',
        },
        diagnostic = { enabled = false },
      }
    end,
    config = function()
      -- helper to update minimap from "after" pane
      _G.update_minimap_from_after = function()
        local after_win = nil
        local max_col = -1
        for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
          local buf = vim.api.nvim_win_get_buf(win)
          local name = vim.api.nvim_buf_get_name(buf)
          if name:match('codediff:%d') then
            local col = vim.api.nvim_win_get_position(win)[2]
            if col > max_col then
              max_col = col
              after_win = win
            end
          end
        end
        if after_win then
          local cur_win = vim.api.nvim_get_current_win()
          vim.api.nvim_set_current_win(after_win)
          vim.cmd('Neominimap refresh')
          vim.defer_fn(function()
            if vim.api.nvim_win_is_valid(cur_win) then
              vim.api.nvim_set_current_win(cur_win)
            end
          end, 30)
        end
      end

      -- attach gitsigns to codediff buffers for minimap git integration
      vim.api.nvim_create_autocmd('BufEnter', {
        pattern = 'codediff:*',
        callback = function()
          local bufnr = vim.api.nvim_get_current_buf()
          local name = vim.api.nvim_buf_get_name(bufnr)
          -- extract real path from codediff:N/path
          local realpath = name:match('codediff:%d/(.+)$')
          if realpath and vim.fn.filereadable(realpath) == 1 then
            local gs = require('gitsigns')
            -- attach gitsigns with the real file path
            pcall(function()
              gs.attach(bufnr, { file = realpath })
            end)
          end
        end,
      })

      -- update minimap to show "after" pane when in tree
      vim.api.nvim_create_autocmd('BufEnter', {
        callback = function()
          if vim.bo.filetype == 'codediff-explorer' then
            vim.defer_fn(_G.update_minimap_from_after, 100)
          end
        end,
      })
      -- ctrl+m to toggle
      vim.keymap.set('n', '<C-m>', '<cmd>Neominimap toggle<cr>', { desc = 'Toggle minimap' })

      -- make minimap unfocusable — immediately redirect focus away
      vim.api.nvim_create_autocmd('WinEnter', {
        callback = function()
          local ft = vim.bo.filetype
          if ft ~= 'neominimap' then return end
          -- find previous window or any other valid window
          local cur_win = vim.api.nvim_get_current_win()
          local prev_win = vim.fn.win_getid(vim.fn.winnr('#'))
          -- try previous window first
          if prev_win ~= 0 and prev_win ~= cur_win and vim.api.nvim_win_is_valid(prev_win) then
            local buf = vim.api.nvim_win_get_buf(prev_win)
            local pft = vim.api.nvim_get_option_value('filetype', { buf = buf })
            if pft ~= 'neominimap' then
              vim.api.nvim_set_current_win(prev_win)
              return
            end
          end
          -- fallback: find any non-minimap window
          for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
            if win ~= cur_win then
              local buf = vim.api.nvim_win_get_buf(win)
              local wft = vim.api.nvim_get_option_value('filetype', { buf = buf })
              if wft ~= 'neominimap' then
                vim.api.nvim_set_current_win(win)
                return
              end
            end
          end
          -- no other windows — quit nvim
          vim.cmd('quit!')
        end,
      })

      -- register custom handler for diff panes (vim diff + codediff extmarks)
      vim.defer_fn(function()
        local ok, handlers = pcall(require, 'neominimap.map.handlers')
        if not ok then return end

        local ns = vim.api.nvim_create_namespace('neominimap_vdiff')
        handlers.register({
          name = 'vdiff',
          mode = 'line',
          namespace = ns,
          init = function() end,
          autocmds = {
            {
              event = { 'BufEnter', 'DiffUpdated', 'TextChanged' },
              opts = {
                callback = function(apply, args)
                  apply(args.buf)
                end,
              },
            },
          },
          get_annotations = function(bufnr)
            local annotations = {}
            if not vim.api.nvim_buf_is_valid(bufnr) then return annotations end

            -- check if this is a codediff buffer
            local bufname = vim.api.nvim_buf_get_name(bufnr)
            local is_codediff = bufname:match('codediff:')

            -- for native vim diff, check window diff mode
            local win = vim.fn.bufwinid(bufnr)
            local is_vimdiff = win ~= -1 and vim.wo[win].diff

            if not is_codediff and not is_vimdiff then return annotations end

            local line_count = vim.api.nvim_buf_line_count(bufnr)
            local id_map = { DiffAdd = 1, DiffChange = 2, DiffDelete = 3, DiffText = 2 }
            local hl_map = {
              DiffAdd = 'NeominimapDiffAddLine',
              DiffChange = 'NeominimapDiffChangeLine',
              DiffDelete = 'NeominimapDiffDeleteLine',
              DiffText = 'NeominimapDiffChangeLine',
            }

            for lnum = 1, line_count do
              local found_hl = nil

              -- try native diff_hlID first
              local hl_id = vim.fn.diff_hlID(lnum, 1)
              if hl_id > 0 then
                found_hl = vim.fn.synIDattr(hl_id, 'name')
              end

              -- if not found and codediff buffer, check extmarks
              if not found_hl and is_codediff then
                local lnum0 = lnum - 1
                for _, ns_id in pairs(vim.api.nvim_get_namespaces()) do
                  local marks = vim.api.nvim_buf_get_extmarks(bufnr, ns_id, { lnum0, 0 }, { lnum0, -1 }, { details = true })
                  for _, mark in ipairs(marks) do
                    local details = mark[4]
                    if details and details.hl_group then
                      local hl = details.hl_group
                      -- codediff uses CodeDiffLineInsert/CodeDiffLineDelete
                      if hl == 'CodeDiffLineInsert' or hl == 'DiffAdd' or hl:match('Insert') or hl:match('Add') then
                        found_hl = 'DiffAdd'
                      elseif hl == 'CodeDiffLineDelete' or hl == 'DiffDelete' or hl:match('Delete') then
                        found_hl = 'DiffDelete'
                      elseif hl:match('Change') or hl:match('Modify') then
                        found_hl = 'DiffChange'
                      end
                      if found_hl then break end
                    end
                  end
                  if found_hl then break end
                end
              end

              if found_hl and hl_map[found_hl] then
                table.insert(annotations, {
                  lnum = lnum,
                  end_lnum = lnum,
                  id = id_map[found_hl],
                  priority = 50,
                  highlight = hl_map[found_hl],
                })
              end
            end
            return annotations
          end,
        })
      end, 100)
    end,
  },
  {
    'esmuellert/codediff.nvim',
    keys = {
      { '<C-g>', function()
        local codediff_loaded, codediff = pcall(require, 'codediff')
        -- check if in codediff buffer
        local bufname = vim.api.nvim_buf_get_name(0)
        local ft = vim.bo.filetype
        local in_codediff = bufname:match('codediff://') or ft:match('^codediff')
        if in_codediff then
          -- in codediff: go to last file tab or previous tab
          if _G.last_file_tab and vim.api.nvim_tabpage_is_valid(_G.last_file_tab) then
            vim.api.nvim_set_current_tabpage(_G.last_file_tab)
          else
            vim.cmd('tabprevious')
          end
        else
          -- not in codediff: save current tab, find or open codediff
          _G.last_file_tab = vim.api.nvim_get_current_tabpage()
          -- find codediff tab
          local found_tab = nil
          for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
            local wins = vim.api.nvim_tabpage_list_wins(tab)
            for _, win in ipairs(wins) do
              local buf = vim.api.nvim_win_get_buf(win)
              local name = vim.api.nvim_buf_get_name(buf)
              local bft = vim.api.nvim_get_option_value('filetype', { buf = buf })
              if name:match('codediff://') or bft:match('^codediff') then
                found_tab = tab
                break
              end
            end
            if found_tab then break end
          end
          if found_tab then
            vim.api.nvim_set_current_tabpage(found_tab)
          else
            vim.cmd('CodeDiff')
          end
          -- focus the tree pane
          vim.defer_fn(function()
            for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
              local buf = vim.api.nvim_win_get_buf(win)
              local bft = vim.api.nvim_get_option_value('filetype', { buf = buf })
              if bft == 'codediff-explorer' then
                vim.api.nvim_set_current_win(win)
                break
              end
            end
          end, 50)
        end
      end, desc = 'Toggle diff view' },
    },
    cmd = 'CodeDiff',
    config = function()
      require('codediff').setup({
        keymaps = {
          -- navigation
          next_change = ']c',
          prev_change = '[c',
          next_file = ']f',
          prev_file = '[f',
          -- stage with - (codediff default)
          stage = '-',
          quit = 'q',
        },
      })
      -- codediff buffer keymaps
      vim.api.nvim_create_autocmd('BufEnter', {
        pattern = '*',
        callback = function()
          local bufname = vim.api.nvim_buf_get_name(0)
          local ft = vim.bo.filetype
          -- only apply to codediff buffers (explorer or diff panes)
          local is_codediff = bufname:match('[Cc]ode[Dd]iff') or ft:match('codediff')
          -- also check if any window in this tab has codediff buffer
          if not is_codediff then
            for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
              local wbuf = vim.api.nvim_win_get_buf(win)
              local wft = vim.api.nvim_get_option_value('filetype', { buf = wbuf })
              local wname = vim.api.nvim_buf_get_name(wbuf)
              if wft:match('codediff') or wname:match('[Cc]ode[Dd]iff') then
                is_codediff = true
                break
              end
            end
          end
          if not is_codediff then return end
          -- ctrl+d j/k for diff boundary navigation
          local function boundary_down()
            navigate_diff_boundary('down', get_diff_hl_chunks, function()
              vim.cmd('normal! ]c')
            end)
          end
          local function boundary_up()
            navigate_diff_boundary('up', get_diff_hl_chunks, function()
              vim.cmd('normal! [c')
            end)
          end
          vim.keymap.set('n', '<C-d>j', boundary_down, { buffer = true, desc = 'Next diff boundary' })
          vim.keymap.set('n', '<C-d>k', boundary_up, { buffer = true, desc = 'Prev diff boundary' })
          vim.keymap.set('n', '<C-d><C-j>', boundary_down, { buffer = true, desc = 'Next diff boundary' })
          vim.keymap.set('n', '<C-d><C-k>', boundary_up, { buffer = true, desc = 'Prev diff boundary' })
          -- 'o' to open file in new tab
          vim.keymap.set('n', 'o', function()
            local bufname = vim.api.nvim_buf_get_name(0)
            local ft = vim.bo.filetype
            local path = nil
            if ft == 'codediff-explorer' then
              path = get_codediff_explorer_file()
            else
              -- in file pane: bufname is the actual file path or virtual codediff:// path
              if vim.fn.filereadable(bufname) == 1 then
                path = bufname
              elseif bufname:match('codediff:') then
                -- extract relative path from virtual buffer name
                local relpath = bufname:match(':%d/(.+)$')
                if relpath then
                  path = relpath
                end
              end
            end
            if path then
              vim.cmd('tabnew ' .. vim.fn.fnameescape(path))
            else
              print('no path')
            end
          end, { buffer = true, desc = 'Open file in new tab' })
          -- resize old pane to 1/3, new pane to 2/3
          vim.defer_fn(function()
            local dominated = vim.api.nvim_tabpage_list_wins(0)
            local diff_wins = {}
            for _, win in ipairs(dominated) do
              local wbuf = vim.api.nvim_win_get_buf(win)
              local wname = vim.api.nvim_buf_get_name(wbuf)
              -- codediff file panes have pattern codediff:N/path
              if wname:match('codediff:%d') then
                table.insert(diff_wins, { win = win, name = wname })
              end
            end
            -- if we have 2 diff panes (old + new), resize
            if #diff_wins == 2 then
              table.sort(diff_wins, function(a, b)
                return vim.api.nvim_win_get_position(a.win)[2] < vim.api.nvim_win_get_position(b.win)[2]
              end)
              local total = vim.o.columns
              local explorer_width = 30  -- approximate
              local avail = total - explorer_width
              local old_width = math.floor(avail / 3)
              vim.api.nvim_win_set_width(diff_wins[1].win, old_width)
            end
          end, 50)
        end,
      })
    end,
  },
  {
    'nvim-lualine/lualine.nvim',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    opts = {
      options = {
        theme = {
          normal = {
            a = { fg = '#333333', bg = '#F5DEB3', gui = 'bold' },
            b = { fg = '#FFFFFF', bg = '#555555' },
            c = { fg = '#F5DEB3', bg = '#333333' },
          },
          insert = { a = { fg = '#333333', bg = '#98FB98', gui = 'bold' } },
          visual = { a = { fg = '#333333', bg = '#F0E68C', gui = 'bold' } },
          replace = { a = { fg = '#333333', bg = '#FF2B2B', gui = 'bold' } },
          inactive = {
            a = { fg = '#777777', bg = '#333333' },
            b = { fg = '#777777', bg = '#333333' },
            c = { fg = '#777777', bg = '#333333' },
          },
        },
        component_separators = { left = '│', right = '│' },
        section_separators = { left = '', right = '' },
        globalstatus = true,
      },
      sections = {
        lualine_a = { { 'mode', fmt = string.lower } },
        lualine_b = { 'branch', 'diff' },
        lualine_c = { {
          'filename',
          fmt = function()
            local ft = vim.bo.filetype
            local bufname = vim.api.nvim_buf_get_name(0)
            -- codediff explorer: show relative path of file under cursor
            if ft == 'codediff-explorer' then
              return get_codediff_explorer_file() or 'diff'
            end
            -- codediff file pane: extract relative path
            if bufname:match('codediff:') then
              local relpath = bufname:match(':%d/(.+)$')
              if relpath then return relpath end
              -- can't determine path, show ???/filename
              local filename = bufname:match('([^/]+)$')
              return filename and ('???/' .. filename) or 'diff'
            end
            if ft == 'neo-tree' then return 'files' end
            if ft == 'oil' then return 'oil' end
            -- regular files: show path relative to git root or cwd
            local gitroot = vim.fn.system('git rev-parse --show-toplevel 2>/dev/null'):gsub('\n', '')
            if gitroot ~= '' and bufname:find(gitroot, 1, true) == 1 then
              return bufname:sub(#gitroot + 2)
            end
            return vim.fn.expand('%:.')
          end,
        } },
        lualine_x = { {
          'filetype',
          fmt = function(ft)
            if ft:match('^codediff') then return 'diff' end
            if ft == 'neo-tree' then return 'tree' end
            if ft == 'oil' then return 'oil' end
            return ft
          end,
        } },
        lualine_y = { { 'location', padding = { left = 2, right = 1 } } },
        lualine_z = { { 'progress', fmt = string.lower } },
      },
    },
  },
  {
    'mrjones2014/smart-splits.nvim',
    version = '>=1.0.0',
    config = function()
      local ss = require('smart-splits')
      ss.setup({
        at_edge = 'stop',  -- don't wrap navigation at window edges
      })
      -- navigate between windows
      vim.keymap.set('n', '<C-h>', ss.move_cursor_left)
      vim.keymap.set('n', '<C-j>', ss.move_cursor_down)
      vim.keymap.set('n', '<C-k>', ss.move_cursor_up)
      vim.keymap.set('n', '<C-l>', ss.move_cursor_right)
      -- resize windows with alt+hjkl
      vim.keymap.set('n', '<A-h>', ss.resize_left)
      vim.keymap.set('n', '<A-j>', ss.resize_down)
      vim.keymap.set('n', '<A-k>', ss.resize_up)
      vim.keymap.set('n', '<A-l>', ss.resize_right)
    end,
  },
  {
    'nvim-neo-tree/neo-tree.nvim',
    branch = 'v3.x',
    dependencies = {
      'nvim-lua/plenary.nvim',
      'nvim-tree/nvim-web-devicons',
      'MunifTanjim/nui.nvim',
    },
    opts = {
      window = {
        position = 'left',
        width = 30,
        mappings = {
          ['o'] = function(state)
            local node = state.tree:get_node()
            local path = node.type == 'directory' and node.path or vim.fn.fnamemodify(node.path, ':h')
            require('oil').open(path)
          end,
        },
      },
      filesystem = {
        filtered_items = {
          visible = true,
          hide_dotfiles = false,
          hide_gitignored = false,
        },
      },
    },
  },
  {
    'stevearc/oil.nvim',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    config = function()
      require('oil').setup({
        columns = { 'icon' },
        view_options = {
          show_hidden = true,
        },
        keymaps = {
          ['<C-h>'] = false,  -- don't override window nav
          ['<C-l>'] = false,
        },
      })
      -- `-` opens parent directory
      vim.keymap.set('n', '-', '<CMD>Oil<CR>', { desc = 'Open parent directory' })
    end,
  },
})

-- disable tabline
vim.opt.showtabline = 0

-- hide vertical window separators
vim.opt.fillchars:append({ vert = ' ' })

-- wrap lines for markdown files
vim.api.nvim_create_autocmd('FileType', {
  pattern = 'markdown',
  callback = function()
    vim.opt_local.wrap = true
    vim.opt_local.linebreak = true  -- wrap at word boundaries
  end,
})

-- colorscheme: ptyxis Desert palette
-- ref: https://github.com/Gogh-Co/Gogh/blob/master/themes/Desert.yml
vim.cmd('highlight clear')
local hi = function(group, opts) vim.api.nvim_set_hl(0, group, opts) end

-- ui
hi('Normal',       { fg = '#FFFFFF', bg = '#333333' })
hi('CursorLine',   { bg = '#4D4D4D' })
hi('CursorLineNr', { fg = '#F0E68C', bold = true })
hi('LineNr',       { fg = '#555555' })
hi('Visual',       { bg = '#555555' })
hi('Pmenu',        { fg = '#FFFFFF', bg = '#4D4D4D' })
hi('PmenuSel',     { fg = '#333333', bg = '#F0E68C' })
hi('StatusLine',   { fg = '#333333', bg = '#F5DEB3' })
hi('StatusLineNC', { fg = '#333333', bg = '#4D4D4D' })
hi('Search',       { fg = '#333333', bg = '#F0E68C' })
hi('MatchParen',   { fg = '#FFFFFF', bg = '#555555', bold = true })

-- syntax
hi('Comment',      { fg = '#777777', italic = true })
hi('String',       { fg = '#98FB98' })
hi('Number',       { fg = '#FFDEAD' })
hi('Boolean',      { fg = '#FFDEAD' })
hi('Float',        { fg = '#FFDEAD' })
hi('Keyword',      { fg = '#F0E68C' })
hi('Statement',    { fg = '#F0E68C' })
hi('Conditional',  { fg = '#F0E68C' })
hi('Repeat',       { fg = '#F0E68C' })
hi('Function',     { fg = '#C4A882' })
hi('Identifier',   { fg = '#FFA0A0' })
hi('Type',         { fg = '#FFD700' })
hi('Constant',     { fg = '#FFDEAD' })
hi('PreProc',      { fg = '#CD853F' })
hi('Include',      { fg = '#CD853F' })
hi('Operator',     { fg = '#F5DEB3' })
hi('Delimiter',    { fg = '#F5DEB3' })
hi('Special',      { fg = '#FFA0A0' })
hi('Error',        { fg = '#FF2B2B', bold = true })
hi('WarnMsg',      { fg = '#FF5555' })
hi('Todo',         { fg = '#333333', bg = '#F0E68C', bold = true })
hi('Title',        { fg = '#C4A882', bold = true })
hi('Directory',    { fg = '#C4A882' })

-- neo-tree
hi('NeoTreeDirectoryName',  { fg = '#F5DEB3' })
hi('NeoTreeDirectoryIcon',  { fg = '#C4A882' })
hi('NeoTreeFileName',       { fg = '#FFFFFF' })
hi('NeoTreeGitAdded',       { fg = '#98FB98' })
hi('NeoTreeGitDeleted',     { fg = '#FF2B2B' })
hi('NeoTreeGitModified',    { fg = '#F0E68C' })
hi('NeoTreeGitUntracked',   { fg = '#555555' })
hi('NeoTreeIndentMarker',   { fg = '#555555' })
hi('NeoTreeRootName',       { fg = '#F0E68C', bold = true })
hi('NeoTreeTitleBar',       { fg = '#333333', bg = '#F5DEB3' })
hi('NeoTreeFloatBorder',    { fg = '#555555' })
hi('NeoTreeCursorLine',     { bg = '#4D4D4D' })

-- oil
hi('OilDir',               { fg = '#C4A882' })
hi('OilDirIcon',           { fg = '#C4A882' })
hi('OilFile',              { fg = '#FFFFFF' })
hi('OilCreate',            { fg = '#98FB98' })
hi('OilDelete',            { fg = '#FF2B2B' })
hi('OilMove',              { fg = '#F0E68C' })
hi('OilCopy',              { fg = '#87CEFF' })
hi('OilChange',            { fg = '#F0E68C' })

-- diff (subtle tints to preserve syntax colors)
hi('DiffAdd',      { bg = '#3a4a3a' })  -- subtle green tint
hi('DiffDelete',   { bg = '#4a3a3a' })  -- subtle red tint
hi('DiffChange',   { bg = '#4a4a3a' })  -- subtle yellow tint
hi('DiffText',     { bg = '#5a5a4a' })  -- changed text within line

-- gitsigns unstaged (brighter - needs attention)
hi('GitSignsAdd',          { fg = '#98FB98' })  -- bright green
hi('GitSignsChange',       { fg = '#F0E68C' })  -- bright yellow
hi('GitSignsDelete',       { fg = '#FF8080' })  -- bright red
-- gitsigns staged (muted - already handled)
hi('GitSignsStagedAdd',       { fg = '#7a9a7a' })  -- muted sage
hi('GitSignsStagedChange',    { fg = '#a09a7a' })  -- muted khaki
hi('GitSignsStagedDelete',    { fg = '#9a7a7a' })  -- muted mauve

-- neominimap git unstaged (brighter bg - needs attention)
hi('NeominimapGitAddLine',    { bg = '#5a7a5a' })  -- bright pastel green
hi('NeominimapGitChangeLine', { bg = '#7a7a5a' })  -- bright pastel yellow
hi('NeominimapGitDeleteLine', { bg = '#7a5a5a' })  -- bright pastel red
-- neominimap vdiff handler (for gitdiff panes)
hi('NeominimapDiffAddLine',    { bg = '#5a7a5a' })  -- bright pastel green
hi('NeominimapDiffChangeLine', { bg = '#7a7a5a' })  -- bright pastel yellow
hi('NeominimapDiffDeleteLine', { bg = '#7a5a5a' })  -- bright pastel red



-- ctrl+c = copy (visual mode)
vim.keymap.set('v', '<C-c>', '"+y')

-- ctrl+v = paste (insert + normal mode)
vim.keymap.set('i', '<C-v>', '<C-r>+')
vim.keymap.set('n', '<C-v>', '"+p')

-- ctrl+s = save and exit to normal mode
vim.keymap.set('n', '<C-s>', ':w<CR>')
vim.keymap.set('i', '<C-s>', '<Esc>:w<CR>')

-- ctrl+e = smart file tree toggle
-- if neo-tree not open: open and focus it
-- if neo-tree open but not focused: focus it
-- if neo-tree open and focused: close it
vim.keymap.set('n', '<C-e>', function()
  local bufname = vim.api.nvim_buf_get_name(0)
  local filetype = vim.bo.filetype
  if filetype == 'neo-tree' then
    vim.cmd('Neotree close')
  else
    vim.cmd('Neotree focus')
  end
end, { noremap = true, silent = true })

-- ctrl+h/j/k/l = navigate between windows (configured in smart-splits plugin above)

-- ctrl+z = undo, ctrl+shift+z = redo (standard keybinds)
vim.keymap.set('n', '<C-z>', 'u', { noremap = true })
vim.keymap.set('i', '<C-z>', '<Esc>ui', { noremap = true })
vim.keymap.set('n', '<C-S-z>', '<C-r>', { noremap = true })
vim.keymap.set('i', '<C-S-z>', '<Esc><C-r>i', { noremap = true })

-- ctrl+r = copy relative path of current file to clipboard (relative to cwd)
vim.keymap.set('n', '<C-r>', function()
  local path = vim.fn.expand('%:.')
  vim.fn.setreg('+', path)
  print('copied: ' .. path)
end, { noremap = true, silent = false })

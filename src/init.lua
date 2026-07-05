-- wrap vim.treesitter.start to silently handle absent parsers
local orig_ts_start = vim.treesitter.start
vim.treesitter.start = function(bufnr, lang)
  pcall(orig_ts_start, bufnr, lang)
end

-- force truecolor so gui hex themes (e.g. lualine) render everywhere.
-- .why = auto-detection is at the mercy of the terminal/terminfo handshake,
--        which the kitty 0.32 -> 0.47.4 tarball swap broke -> statusline
--        collapsed to a flat fallback. pin it so it never depends on autodetect.
vim.o.termguicolors = true

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

-- global focus state (shared by treesitter, vdiff handler, etc.)
local nvim_focused = true
vim.api.nvim_create_autocmd('FocusLost', {
  callback = function() nvim_focused = false end,
})
vim.api.nvim_create_autocmd('FocusGained', {
  callback = function() nvim_focused = true end,
})

-- cache git root per buffer (avoids subprocess on every statusline render)
local git_root_cache = {}
local function get_git_root(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if git_root_cache[bufnr] == nil then
    local bufname = vim.api.nvim_buf_get_name(bufnr)
    local dir = vim.fn.fnamemodify(bufname, ':h')
    if dir == '' or not vim.fn.isdirectory(dir) then
      git_root_cache[bufnr] = false
    else
      local result = vim.fn.system('git -C ' .. vim.fn.shellescape(dir) .. ' rev-parse --show-toplevel 2>/dev/null'):gsub('\n', '')
      git_root_cache[bufnr] = (result ~= '' and result) or false
    end
  end
  return git_root_cache[bufnr]
end

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

-- get file path from codediff explorer node data (no git subprocess needed)
local function get_codediff_explorer_file()
  local lc_ok, lifecycle = pcall(require, 'codediff.ui.lifecycle')
  if not lc_ok then return nil end
  local tab = vim.api.nvim_get_current_tabpage()
  local explorer = lifecycle.get_explorer and lifecycle.get_explorer(tab)
  if not explorer or not explorer.tree then return nil end
  local node = explorer.tree:get_node()
  if node and node.data and node.data.path then
    return node.data.path
  end
  return nil
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
    'nvim-telescope/telescope.nvim',
    dependencies = { 'nvim-lua/plenary.nvim' },
    keys = {
      { '<C-p>', '<cmd>Telescope find_files<cr>', desc = 'Find files' },
      { '<C-f>', '<cmd>Telescope live_grep<cr>', desc = 'Search in files' },
      { '<C-S-f>', '<cmd>Telescope live_grep<cr>', desc = 'Search in files' },
    },
    config = function()
      local actions = require('telescope.actions')
      require('telescope').setup({
        defaults = {
          mappings = {
            i = {
              ['<Esc>'] = actions.close,
              ['<C-c>'] = actions.close,
            },
            n = {
              ['q'] = actions.close,
              ['<Esc>'] = actions.close,
            },
          },
        },
      })
      -- intercept :q and :qa in telescope buffers via abbreviation
      vim.api.nvim_create_autocmd('FileType', {
        pattern = 'TelescopePrompt',
        callback = function()
          vim.cmd('cnoreabbrev <buffer> q lua require("telescope.actions").close(vim.api.nvim_get_current_buf())')
          vim.cmd('cnoreabbrev <buffer> q! lua require("telescope.actions").close(vim.api.nvim_get_current_buf())')
          vim.cmd('cnoreabbrev <buffer> qa lua require("telescope.actions").close(vim.api.nvim_get_current_buf())')
          vim.cmd('cnoreabbrev <buffer> qa! lua require("telescope.actions").close(vim.api.nvim_get_current_buf())')
        end,
      })
    end,
  },
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
    lazy = false,
    build = ':TSUpdate',
    config = function()
      local ts = require('nvim-treesitter')
      -- install parsers
      local parsers = { 'lua', 'vim', 'vimdoc', 'query', 'markdown', 'markdown_inline', 'typescript', 'json', 'yaml', 'sql', 'bash' }
      for _, parser in ipairs(parsers) do
        pcall(ts.install, parser)
      end
      -- register language aliases for markdown code block injection
      vim.treesitter.language.register('typescript', 'ts')
      vim.treesitter.language.register('bash', 'sh')
      -- enable treesitter highlight on all filetypes (skip special buffers)
      vim.api.nvim_create_autocmd('FileType', {
        callback = function()
          if not nvim_focused then return end
          if vim.bo.buftype ~= '' then return end  -- skip virtual buffers
          if vim.bo.filetype == 'neominimap' then return end
          pcall(vim.treesitter.start)
        end,
      })
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
          fix_width = true,
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
      -- fix: O(1) cache lookup, debounced updates, lifecycle-bounded state
      vim.defer_fn(function()
        local ok, handlers = pcall(require, 'neominimap.map.handlers')
        if not ok then return end

        local ns = vim.api.nvim_create_namespace('neominimap_vdiff')

        -- state: bounded by buffer lifecycle
        local cache = {}    -- bufnr -> { tick, annotations }
        local queued = {}   -- bufnr -> timer_id

        -- cleanup on buffer delete
        vim.api.nvim_create_autocmd({'BufDelete', 'BufWipeout'}, {
          callback = function(args)
            cache[args.buf] = nil
            if queued[args.buf] then
              vim.fn.timer_stop(queued[args.buf])
              queued[args.buf] = nil
            end
          end,
        })

        -- find codediff namespace once
        local codediff_ns = nil
        local function get_codediff_ns()
          if codediff_ns then return codediff_ns end
          for name, id in pairs(vim.api.nvim_get_namespaces()) do
            if name:match('codediff') then
              codediff_ns = id
              return id
            end
          end
          return nil
        end

        handlers.register({
          name = 'vdiff',
          mode = 'line',
          namespace = ns,
          init = function() end,
          autocmds = {
            {
              event = { 'BufEnter', 'DiffUpdated' },
              opts = {
                callback = function(apply, args)
                  apply(args.buf)
                end,
              },
            },
            {
              event = { 'TextChanged' },
              opts = {
                callback = function(apply, args)
                  local buf = args.buf
                  -- cancel prior timer
                  if queued[buf] then
                    vim.fn.timer_stop(queued[buf])
                  end
                  -- schedule new (200ms debounce)
                  queued[buf] = vim.fn.timer_start(200, function()
                    queued[buf] = nil
                    if vim.api.nvim_buf_is_valid(buf) then
                      apply(buf)
                    end
                  end)
                end,
              },
            },
          },
          get_annotations = function(bufnr)
            if not nvim_focused then return {} end
            if not vim.api.nvim_buf_is_valid(bufnr) then return {} end

            -- fast path: not a diff buffer
            local bufname = vim.api.nvim_buf_get_name(bufnr)
            local is_codediff = bufname:match('codediff:')
            local win = vim.fn.bufwinid(bufnr)
            local is_vimdiff = win ~= -1 and vim.wo[win].diff

            if not is_codediff and not is_vimdiff then return {} end

            -- check cache
            local tick = vim.api.nvim_buf_get_changedtick(bufnr)
            local cached = cache[bufnr]
            if cached and cached.tick == tick then
              return cached.annotations
            end

            -- build annotations
            local annotations = {}
            local id_map = { DiffAdd = 1, DiffChange = 2, DiffDelete = 3, DiffText = 2 }
            local hl_map = {
              DiffAdd = 'NeominimapDiffAddLine',
              DiffChange = 'NeominimapDiffChangeLine',
              DiffDelete = 'NeominimapDiffDeleteLine',
              DiffText = 'NeominimapDiffChangeLine',
            }

            if is_vimdiff then
              -- vimdiff: use diff_hlID
              local line_count = vim.api.nvim_buf_line_count(bufnr)
              for lnum = 1, line_count do
                local hl_id = vim.fn.diff_hlID(lnum, 1)
                if hl_id > 0 then
                  local found_hl = vim.fn.synIDattr(hl_id, 'name')
                  if hl_map[found_hl] then
                    table.insert(annotations, {
                      lnum = lnum,
                      end_lnum = lnum,
                      id = id_map[found_hl],
                      priority = 50,
                      highlight = hl_map[found_hl],
                    })
                  end
                end
              end
            elseif is_codediff then
              -- codediff: single extmarks call for entire buffer
              local cd_ns = get_codediff_ns()
              if cd_ns then
                local marks = vim.api.nvim_buf_get_extmarks(bufnr, cd_ns, 0, -1, { details = true })
                for _, mark in ipairs(marks) do
                  local lnum = mark[2] + 1
                  local details = mark[4]
                  if details and details.hl_group then
                    local hl = details.hl_group
                    local found_hl = nil
                    if hl:match('Insert') or hl:match('Add') then
                      found_hl = 'DiffAdd'
                    elseif hl:match('Delete') then
                      found_hl = 'DiffDelete'
                    elseif hl:match('Change') then
                      found_hl = 'DiffChange'
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
                end
              end
            end

            -- cache result (bounded by BufDelete autocmd)
            cache[bufnr] = { tick = tick, annotations = annotations }

            return annotations
          end,
        })
      end, 100)
    end,
  },
  {
    'esmuellert/codediff.nvim',
    event = 'VeryLazy',  -- preload on startup so ctrl+g is instant
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
      local explorer_width = 30
      require('codediff').setup({
        explorer = {
          width = explorer_width,
          view_mode = "tree",
          flatten_dirs = true,
        },
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

      -- workaround: preserve user-set explorer width when codediff resets it
      -- root cause: codediff's layout.arrange() resets explorer width to config value
      --             on single-pane mode (new files without prior version to diff)
      -- fix: track width via resize keymaps (smart-splits), restore after arrange
      -- todo: contribute upstream — layout.arrange should preserve user-set widths
      _G.codediff_saved_explorer_width = explorer_width

      vim.defer_fn(function()
        local layout_ok, layout = pcall(require, 'codediff.ui.layout')
        if not layout_ok then return end

        local original_arrange = layout.arrange
        layout.arrange = function(tabpage)
          -- find explorer window
          local explorer_win = nil
          for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tabpage)) do
            local buf = vim.api.nvim_win_get_buf(win)
            local ft = vim.api.nvim_get_option_value('filetype', { buf = buf })
            if ft == 'codediff-explorer' then
              explorer_win = win
              break
            end
          end

          original_arrange(tabpage)

          -- restore saved width after arrange resets it
          if explorer_win and vim.api.nvim_win_is_valid(explorer_win) then
            vim.api.nvim_win_set_width(explorer_win, _G.codediff_saved_explorer_width)
          end
        end
      end, 100)

      -- todo: contribute upstream — fix tree jitter on refresh
      -- issue: codediff calls expand_all_dirs() on every refresh/render, user collapses lost
      -- root cause: expand_all_dirs has no memory of user intent
      -- fix: re-collapse user-collapsed nodes before each render
      -- ref: https://github.com/sindrets/diffview.nvim/issues/582
      _G.codediff_user_collapsed = _G.codediff_user_collapsed or {}

      -- build group-prefixed key to avoid collision between staged/unstaged
      local function get_collapse_key(tree, node)
        if not node or not node.data then return nil end
        local base = node.data.path or node.data.name
        if not base then return nil end
        -- groups are roots, no prefix needed
        if node.data.type == 'group' then return base end
        -- for directories, walk up to find parent group
        local parent_id = node._parent_id
        while parent_id do
          local parent = tree:get_node(parent_id)
          if not parent then break end
          if parent.data and parent.data.type == 'group' then
            return (parent.data.name or 'unknown') .. ':' .. base
          end
          parent_id = parent._parent_id
        end
        return base
      end

      -- re-collapse nodes that user had collapsed
      local function apply_user_collapses(tree)
        local function process_node(node)
          if not node or not node.data then return end
          local node_type = node.data.type
          if node_type == 'group' or node_type == 'directory' then
            local key = get_collapse_key(tree, node)
            if key and _G.codediff_user_collapsed[key] then
              node:collapse()
            end
            -- recurse into children
            if node:has_children() then
              for _, child_id in ipairs(node:get_child_ids()) do
                local child = tree:get_node(child_id)
                if child then process_node(child) end
              end
            end
          end
        end
        for _, root in ipairs(tree:get_nodes()) do
          process_node(root)
        end
      end

      vim.defer_fn(function()
        local ok, Tree = pcall(require, 'codediff.ui.lib.tree')
        if not ok then return end

        -- patch refresh module to use group-prefixed keys
        -- bug: codediff uses path alone as key, so staged/unstaged src/ collide
        local refresh_ok, refresh_mod = pcall(require, 'codediff.ui.explorer.refresh')
        if refresh_ok then
          -- store collapsed state globally by explorer tabpage with prefixed keys
          _G.codediff_collapsed_state = _G.codediff_collapsed_state or {}

          -- collect collapsed state (groups by name, dirs by path for sync)
          local function collect_state(tree)
            local collapsed = { groups = {}, dirs = {} }
            local function collect(node)
              if not node or not node.data then return end
              local t = node.data.type
              if t == 'group' then
                if not node:is_expanded() then
                  collapsed.groups[node.data.name] = true
                end
              elseif t == 'directory' then
                -- use path only (syncs across groups)
                if not node:is_expanded() then
                  collapsed.dirs[node.data.path] = true
                end
              end
              if node:has_children() then
                for _, cid in ipairs(node:get_child_ids()) do
                  collect(tree:get_node(cid))
                end
              end
            end
            for _, root in ipairs(tree:get_nodes()) do
              collect(root)
            end
            return collapsed
          end

          -- restore collapsed state (syncs dirs across groups)
          local function restore_state(tree, collapsed)
            local function restore(node)
              if not node or not node.data then return end
              local t = node.data.type
              if t == 'group' then
                if collapsed.groups[node.data.name] then
                  node:collapse()
                else
                  node:expand()
                end
              elseif t == 'directory' then
                if collapsed.dirs[node.data.path] then
                  node:collapse()
                else
                  node:expand()
                end
              end
              if node:has_children() then
                for _, cid in ipairs(node:get_child_ids()) do
                  restore(tree:get_node(cid))
                end
              end
            end
            for _, root in ipairs(tree:get_nodes()) do
              restore(root)
            end
          end

          -- track which tabs need restore after refresh
          _G.codediff_pending_restore = _G.codediff_pending_restore or {}

          -- replace refresh to use our collect/restore (original has bugs)
          local original_refresh = refresh_mod.refresh
          refresh_mod.refresh = function(explorer)
            if explorer.is_hidden or not vim.api.nvim_win_is_valid(explorer.winid) then
              return
            end
            -- collect state BEFORE refresh rebuilds tree
            local tab = explorer.tabpage
            _G.codediff_collapsed_state[tab] = collect_state(explorer.tree)
            _G.codediff_pending_restore[tab] = true
            -- call original (its restore is buggy, we fix after)
            return original_refresh(explorer)
          end

          -- patch Tree:render to apply our restore AFTER original render (only after refresh)
          local original_render = Tree.render
          Tree.render = function(self)
            -- render first
            local result = original_render(self)
            -- only restore if we just did a refresh (not on manual toggle)
            local lc_ok, lifecycle = pcall(require, 'codediff.ui.lifecycle')
            if lc_ok then
              for tab, _ in pairs(_G.codediff_pending_restore) do
                local exp = lifecycle.get_explorer and lifecycle.get_explorer(tab)
                if exp and exp.tree == self then
                  local collapsed = _G.codediff_collapsed_state[tab] or { groups = {}, dirs = {} }
                  restore_state(self, collapsed)
                  _G.codediff_pending_restore[tab] = nil
                  -- re-render to show correct collapsed state
                  original_render(self)
                  break
                end
              end
            end
            return result
          end
        end

        -- patch flatten_tree to use sorted iteration
        -- root cause: pairs() has undefined order, causes inconsistent dir merge
        local nodes_ok, nodes_mod = pcall(require, 'codediff.ui.explorer.nodes')
        if not nodes_ok then return end

        local config_ok, cfg = pcall(require, 'codediff.config')
        if not config_ok then return end

        -- replace create_tree_file_nodes with sorted flatten version
        nodes_mod.create_tree_file_nodes = function(files, git_root, group_name)
          -- build directory structure (same as original)
          local dir_tree = {}
          for _, file in ipairs(files) do
            local parts = {}
            for part in file.path:gmatch('[^/]+') do
              parts[#parts + 1] = part
            end
            local current = dir_tree
            for i = 1, #parts - 1 do
              local dir_name = parts[i]
              if not current[dir_name] then
                current[dir_name] = { _is_dir = true, _children = {} }
              end
              current = current[dir_name]._children
            end
            local filename = parts[#parts]
            current[filename] = { _is_dir = false, _file = file }
          end

          -- flatten with SORTED iteration (fix for pairs() order issue)
          local function flatten_tree_sorted(subtree)
            local keys = {}
            for k in pairs(subtree) do keys[#keys + 1] = k end
            table.sort(keys)
            for _, key in ipairs(keys) do
              local item = subtree[key]
              if item._is_dir then
                flatten_tree_sorted(item._children)
                local child_keys = {}
                for k in pairs(item._children) do child_keys[#child_keys + 1] = k end
                if #child_keys == 1 and item._children[child_keys[1]]._is_dir then
                  local child_key = child_keys[1]
                  local child = item._children[child_key]
                  local merged_key = key .. '/' .. child_key
                  subtree[merged_key] = child
                  subtree[key] = nil
                end
              end
            end
          end

          local explorer_config = cfg.options.explorer or {}
          if explorer_config.flatten_dirs ~= false then
            flatten_tree_sorted(dir_tree)
          end

          -- build nodes (same as original)
          local function build_nodes(subtree, parent_path, indent_state)
            local nodes_list = {}
            local sorted_keys = {}
            for key in pairs(subtree) do sorted_keys[#sorted_keys + 1] = key end
            table.sort(sorted_keys, function(a, b)
              local a_dir = subtree[a]._is_dir
              local b_dir = subtree[b]._is_dir
              if a_dir ~= b_dir then return a_dir end
              return a < b
            end)

            local total = #sorted_keys
            for idx, key in ipairs(sorted_keys) do
              local item = subtree[key]
              local full_path = parent_path ~= '' and (parent_path .. '/' .. key) or key
              local is_last = (idx == total)
              local node_indent = {}
              for i, v in ipairs(indent_state) do node_indent[i] = v end
              node_indent[#node_indent + 1] = is_last

              if item._is_dir then
                local children = build_nodes(item._children, full_path, node_indent)
                nodes_list[#nodes_list + 1] = Tree.Node({
                  text = key,
                  data = {
                    type = 'directory',
                    name = key,
                    path = full_path,
                    dir_path = full_path,
                    group = group_name,
                    indent_state = node_indent,
                  },
                }, children)
              else
                local file = item._file
                local icon, icon_color = nodes_mod.get_file_icon(file.path)
                local STATUS_SYMBOLS = {
                  M = { symbol = 'M', color = 'CodeDiffStatusModified' },
                  A = { symbol = 'A', color = 'CodeDiffStatusAdded' },
                  D = { symbol = 'D', color = 'CodeDiffStatusDeleted' },
                  ['??'] = { symbol = '??', color = 'CodeDiffStatusUntracked' },
                  ['!'] = { symbol = '!', color = 'CodeDiffStatusConflict' },
                }
                local status_info = STATUS_SYMBOLS[file.status] or { symbol = file.status, color = 'Normal' }
                nodes_list[#nodes_list + 1] = Tree.Node({
                  text = key,
                  data = {
                    path = file.path,
                    status = file.status,
                    old_path = file.old_path,
                    icon = icon,
                    icon_color = icon_color,
                    status_symbol = status_info.symbol,
                    status_color = status_info.color,
                    git_root = git_root,
                    group = group_name,
                    indent_state = node_indent,
                  },
                })
              end
            end
            return nodes_list
          end

          return build_nodes(dir_tree, '', {})
        end
      end, 50)

      -- patch codediff explorer keymaps to use our collapse state
      vim.defer_fn(function()
        local ok, keymaps_mod = pcall(require, 'codediff.ui.explorer.keymaps')
        if not ok then return end

        local original_setup = keymaps_mod.setup
        keymaps_mod.setup = function(explorer)
          -- call original to set up all keymaps
          original_setup(explorer)

          -- override the Enter keymap to sync collapse across groups for same path
          local tree = explorer.tree
          local split = explorer.split
          vim.keymap.set('n', '<CR>', function()
            local node = tree:get_node()
            if not node or not node.data then return end

            local node_type = node.data.type
            if node_type == 'group' then
              -- toggle group (no sync across groups)
              if node:is_expanded() then
                node:collapse()
              else
                node:expand()
              end
              tree:render()
            elseif node_type == 'directory' then
              -- toggle directory and sync same path across all groups
              local target_path = node.data.path
              local should_expand = not node:is_expanded()

              -- find all directory nodes with same path across all groups
              local function sync_dirs(n)
                if not n or not n.data then return end
                if n.data.type == 'directory' and n.data.path == target_path then
                  if should_expand then
                    n:expand()
                  else
                    n:collapse()
                  end
                end
                if n:has_children() then
                  for _, cid in ipairs(n:get_child_ids()) do
                    sync_dirs(tree:get_node(cid))
                  end
                end
              end
              for _, root in ipairs(tree:get_nodes()) do
                sync_dirs(root)
              end
              tree:render()
            else
              -- file node — default select
              if explorer.on_file_select then
                explorer.on_file_select(node.data)
              end
            end
          end, { buffer = split.bufnr, noremap = true, silent = true, nowait = true, desc = 'Toggle/select' })
        end
      end, 50)


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
          -- resize old pane to 1/3, new pane to 2/3 (only on first open)
          local tab = vim.api.nvim_get_current_tabpage()
          _G.codediff_initialized = _G.codediff_initialized or {}
          if not _G.codediff_initialized[tab] then
            _G.codediff_initialized[tab] = true
            vim.defer_fn(function()
              local diff_wins = {}
              for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
                local wbuf = vim.api.nvim_win_get_buf(win)
                local wname = vim.api.nvim_buf_get_name(wbuf)
                if wname:match('codediff:%d') then
                  table.insert(diff_wins, { win = win, name = wname })
                end
              end
              if #diff_wins == 2 then
                table.sort(diff_wins, function(a, b)
                  return vim.api.nvim_win_get_position(a.win)[2] < vim.api.nvim_win_get_position(b.win)[2]
                end)
                local total = vim.o.columns
                local explorer_width = 30
                local avail = total - explorer_width
                local old_width = math.floor(avail / 3)
                vim.api.nvim_win_set_width(diff_wins[1].win, old_width)
              end
            end, 50)
          end
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
            local gitroot = get_git_root()
            if gitroot and bufname:find(gitroot, 1, true) == 1 then
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
      -- helper: update codediff explorer width after manual resize
      local function update_codediff_explorer_width()
        if not _G.codediff_saved_explorer_width then return end
        -- only check if current buffer is in codediff context
        local ft = vim.bo.filetype
        local bufname = vim.api.nvim_buf_get_name(0)
        if not (ft:match('codediff') or bufname:match('codediff')) then return end
        -- find explorer and save its width
        for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
          local buf = vim.api.nvim_win_get_buf(win)
          local wft = vim.api.nvim_get_option_value('filetype', { buf = buf })
          if wft == 'codediff-explorer' then
            _G.codediff_saved_explorer_width = vim.api.nvim_win_get_width(win)
            break
          end
        end
      end
      -- resize windows with alt+hjkl (also track codediff explorer width)
      vim.keymap.set('n', '<A-h>', function()
        ss.resize_left()
        update_codediff_explorer_width()
      end)
      vim.keymap.set('n', '<A-j>', function()
        ss.resize_down()
        update_codediff_explorer_width()
      end)
      vim.keymap.set('n', '<A-k>', function()
        ss.resize_up()
        update_codediff_explorer_width()
      end)
      vim.keymap.set('n', '<A-l>', function()
        ss.resize_right()
        update_codediff_explorer_width()
      end)
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
  {
    '3rd/image.nvim',
    -- render images inline via kitty graphics protocol
    -- requires: kitty terminal + imagemagick cli (see install_env.pt4.terminal.sh)
    build = false,  -- magick_cli processor needs no build step
    config = function()
      require('image').setup({
        backend = 'kitty',
        processor = 'magick_cli',  -- imagemagick cli, avoids luarocks/magick rock
        -- fill terminal width by default
        -- width cap at 100% makes width the constraint that binds; raise height cap
        -- (default 50%) so tall images are not clamped before they reach full width
        max_width_window_percentage = 100,
        max_height_window_percentage = 100,
        integrations = {
          -- render images embedded in markdown documents
          markdown = {
            enabled = true,
            only_render_image_at_cursor = false,
          },
        },
        -- open image files directly as rendered images
        hijack_file_patterns = { '*.png', '*.jpg', '*.jpeg', '*.gif', '*.webp', '*.avif' },
      })
    end,
  },
})

-- disable tabline
vim.opt.showtabline = 0

-- prevent automatic window equalization on split/close
vim.opt.equalalways = false

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

-- wrap lines for markdown in codediff buffers (no filetype set)
-- skip if already set to avoid layout recalculation
vim.api.nvim_create_autocmd('BufEnter', {
  pattern = { 'codediff:*/*.md', '*.md' },
  callback = function()
    if not vim.wo.wrap then
      vim.opt_local.wrap = true
      vim.opt_local.linebreak = true
    end
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

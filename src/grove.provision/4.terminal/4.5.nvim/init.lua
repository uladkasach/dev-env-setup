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

--------------------------------------------------------------------
-- 🛑 a FILE may not configure the editor that opens it
--
-- .what = three options pinned OFF, before anything else loads: a file's own
--         `vim: set …` line, expressions inside one, and a `.nvimrc` picked up
--         from whatever directory nvim was started in.
--
-- .why  = each is remote-chosen configuration applied on OPEN. a grove is
--         ASSUMED COMPROMISED, `git.grove.pull` writes a tree the grove named,
--         and the human then opens a file in it to read what arrived. that is
--         the whole trigger — no second step.
--
-- ✔ .MEASURED on this box, nvim 0.12.3, 2026-08-31
--      a file whose last line is `# vim: shiftwidth=7 tabstop=7`:
--
--        as this config leaves it   → shiftwidth=7  tabstop=7   ← it BIT
--        with `--cmd set nomodeline`→ shiftwidth=8  tabstop=8   ← it STOPPED
--
--      and the defaults it found: modeline=true, modelines=5,
--      modelineexpr=false, exrc=false.
--
-- ⚠️ .two of these were ALREADY safe, and are pinned anyway
--      `modelineexpr=false` is what retired the old sandbox-escape class, and
--      `exrc=false` is nvim's default. a default is a choice nobody made and a
--      release may revisit; pinned, a flip has to be typed here on purpose.
--      this is the same reason `termguicolors` is pinned above.
--
-- ⚠️ .the COST, checked rather than assumed
--      a guard that breaks a workflow gets reverted. this tree carries ZERO
--      modeline-shaped lines, so `nomodeline` takes no capability from it.
--
-- ⚠️ .WHY HERE, and not in a `-c`
--      measured in the same run: `-c 'set nomodeline'` runs AFTER the file
--      argument loads, so the modeline had already applied and the guard read
--      as useless. init.lua runs during startup, before file arguments — so
--      this placement is the one that works.
--
-- ✔ .SEEN TO DISCRIMINATE, 2026-08-31 — this file, against itself
--      the option was proven above; that says none of whether THIS config sets
--      it early enough. so the same probe file was opened under `-u
--      src/init.lua`, and under a copy with only these three lines cut:
--
--        as shipped        → sw=8 ts=8 modeline=false   ← refused
--        guard lines cut   → sw=7 ts=7 modeline=true    ← obeyed
--
--      ⚠️ the second row is what earns the first. a control arm that is
--         already clean proves no repair, so the probe asserts the UNGUARDED
--         config was seen to obey the file before it credits the guard.
--------------------------------------------------------------------
vim.o.modeline = false
vim.o.modelineexpr = false
vim.o.exrc = false

--------------------------------------------------------------------
-- bootstrap lazy.nvim, AT THE COMMIT THE LOCKFILE NAMES
--
-- 🛑 .what changed and why — 2026-09-02
--      this block used `--branch=stable`, and `lazy.setup{}` below names 13
--      more repos with NO ref at all. so every clone took a default-branch
--      TIP, and `nvim-treesitter` carries `build = ':TSUpdate'` — the tip was
--      not merely fetched, it was EXECUTED. two boxes provisioned a day apart
--      ran different code from one checkout, and a push to any of the 14 was
--      code execution on the next nvim start, on the LAPTOP as well as a grove.
--
-- ⚠️ .why THIS repo cannot be pinned by lazy-lock.json
--      the lockfile pins the other 13, and lazy applies it on a first install
--      — measured; `4.5.nvim/configure.upsert.sh` carries the citations. but
--      LAZY READS THE LOCKFILE, so the fetch that puts lazy on the box
--      necessarily precedes any lockfile read. one repo sits outside its own
--      manager's reach, and it is the one whose code runs first.
--
-- ⚠️ .why the pin is READ from the lockfile, never typed here
--      a constant here plus the lockfile's own `lazy.nvim` entry would be two
--      holders of one fact, free to drift — the defect the lockfile exists to
--      remove, reintroduced one line above it. lazy authors that entry; this
--      reads it.
--
-- 🛑 .why an absent or unreadable pin REFUSES to clone
--      a fallback to an unpinned clone is the exact behaviour this block
--      retires, so a failure that fell through would run the code it had just
--      declined to trust (`rule.forbid.failhide`). it fails CLOSED: no clone,
--      no `setup`, nvim starts on its defaults, and `LAZY_PINNED` stays false
--      so the block at the end of this file can say so.
--
--      ⇒ this is also what makes `configure.verify`'s headless start SAFE on a
--        fresh box. that start sources this file inside a `--mode plan`, where
--        `configure.upsert` has been short-circuited and no lockfile is on
--        disk yet — so before this change, a plan cloned and executed 14 repos
--        (`rule.require.bounded-probes-in-verifies`).
--------------------------------------------------------------------
local lazypath = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'
local lockpath = vim.fn.stdpath('config') .. '/lazy-lock.json'

LAZY_PINNED = false
local lazy_why = 'no lockfile at ' .. lockpath

-- the pin, taken from lazy's own single declaration
local lazy_commit = nil
do
  local lf = io.open(lockpath, 'r')
  if lf then
    local raw = lf:read('*a')
    lf:close()
    local ok, lock = pcall(vim.json.decode, raw)
    if ok and type(lock) == 'table' and type(lock['lazy.nvim']) == 'table' then
      lazy_commit = lock['lazy.nvim'].commit
    end
    if type(lazy_commit) ~= 'string' or not lazy_commit:match('^%x%x%x%x%x%x%x%x+$') then
      lazy_commit = nil
      lazy_why = lockpath .. ' names no usable lazy.nvim commit'
    end
  end
end

if lazy_commit then
  if not vim.loop.fs_stat(lazypath) then
    vim.fn.system({
      'git', 'clone', '--filter=blob:none',
      'https://github.com/folke/lazy.nvim.git', lazypath,
    })
    if vim.v.shell_error ~= 0 then
      lazy_why = 'git clone of lazy.nvim failed'
    else
      -- ⚠️ a bare sha is not valid for `--branch`, so the pin is a second step.
      --    a tree left at tip by a failed checkout is exactly the unpinned code
      --    this block refuses, so it is REMOVED rather than loaded.
      vim.fn.system({ 'git', '-C', lazypath, 'checkout', '--detach', lazy_commit })
      if vim.v.shell_error ~= 0 then
        vim.fn.delete(lazypath, 'rf')
        lazy_why = 'lazy.nvim could not be pinned to ' .. lazy_commit:sub(1, 12)
      end
    end
  end

  if vim.loop.fs_stat(lazypath) then
    vim.opt.rtp:prepend(lazypath)
    LAZY_PINNED = true
  end
end

-- global focus state (shared by treesitter, vdiff handler, etc.)
local nvim_focused = true
vim.api.nvim_create_autocmd('FocusLost', {
  callback = function() nvim_focused = false end,
})
vim.api.nvim_create_autocmd('FocusGained', {
  callback = function() nvim_focused = true end,
})

-- ─────────────────────────────────────────────────────────────────
-- self-watchdog: cap runaway memory of THIS nvim core
-- .what = a low-freq timer that reads our own RSS, writes a trend log,
--         and trips a breaker (disable the heavy handlers + notify)
--         before the systemd MemoryHigh scope throttles us.
-- .why  = neovim 0.11+ runs the editor core as its own process. a
--         runaway plugin (treesitter / neominimap-vdiff / image) can
--         leak it to multi-GB and thrash swap until the box freezes.
--         self-heal, not auto-kill: we quiet the leak, keep the buffers.
-- .log  = stdpath('state')/selfwatch.log — grep it to see WHICH
--         subsystem grows (rss vs buffer-count vs treesitter-count).
-- ─────────────────────────────────────────────────────────────────
do
  local log_path = vim.fn.stdpath('state') .. '/selfwatch.log'
  local warn_rss_kb = 800 * 1024   -- 0.8 GB: start to log the trend
  local soft_rss_kb = 1200 * 1024  -- 1.2 GB: trip the breaker (below MemoryHigh=1.5G)
  local log_max_bytes = 2 * 1024 * 1024  -- 2 MB: cap the trend log, keep one rotation
  local tripped = false
  local cpu_last = nil

  -- read our own resident memory (kB) from /proc/self/status
  local function get_self_rss_kb()
    local f = io.open('/proc/self/status', 'r')
    if not f then return nil end
    for line in f:lines() do
      local kb = line:match('^VmRSS:%s+(%d+) kB')
      if kb then f:close() return tonumber(kb) end
    end
    f:close()
    return nil
  end

  -- read our own cumulative cpu ticks (utime+stime) from /proc/self/stat
  local function get_self_cpu_ticks()
    local f = io.open('/proc/self/stat', 'r')
    if not f then return nil end
    local data = f:read('*a')
    f:close()
    -- fields after the ")" that closes (comm), which may hold spaces
    local after = data and data:match('%)%s+(.*)$')
    if not after then return nil end
    local fields = {}
    for tok in after:gmatch('%S+') do fields[#fields + 1] = tok end
    -- post-")" indices: utime = 12, stime = 13
    return (tonumber(fields[12]) or 0) + (tonumber(fields[13]) or 0)
  end

  -- count buffers with an active treesitter highlighter
  local function count_ts_bufs()
    local n = 0
    local ok, active = pcall(function() return vim.treesitter.highlighter.active end)
    if ok and active then
      for _ in pairs(active) do n = n + 1 end
    end
    return n
  end

  -- .what = the lua gc heap, in kb
  --
  -- .why  = THE discriminator. rss is the sum of lua-managed memory and native
  --         allocations, and the two have opposite fixes. with only rss we can
  --         say a core leaks; we cannot say what leaks.
  --           lua climbs with rss -> a lua-side leak: a table, a closure, or a
  --             callback retained by a plugin. reachable, so findable.
  --           lua flat, rss climbs -> a NATIVE leak: image data, parser state,
  --             libuv handles, or a c extension. lua gc will never reclaim it,
  --             and `collectgarbage` in the breaker is pure ceremony.
  --         the trip log showed rss +17M with bufs and ts both flat, which is
  --         the unattributed case this number exists to split.
  local function get_lua_kb()
    local ok, kb = pcall(collectgarbage, 'count')
    if not ok then return 0 end
    return math.floor(kb)
  end

  -- .what = total extmarks across every buffer and namespace
  --
  -- .why  = extmarks are the classic invisible nvim leak: a plugin that sets a
  --         mark per line per refresh and never clears the prior batch grows
  --         without a single new buffer. gitsigns, neominimap, and diagnostics
  --         all set them heavily here, so this is the highest-prior suspect
  --         for growth while bufs stays flat.
  --
  -- .note = this SAMPLES; it is not a census. a full walk is buffers ×
  --         namespaces api calls, and this config has been observed at 14,691
  --         buffers — roughly 300k calls per tick, every 30s. that walk would
  --         cost more than the leak it hunts, and it would cost the most on
  --         precisely the core that leaks worst. the guard would become the
  --         load, which is the stampede failure in a new coat.
  --
  --         so: at most 40 loaded buffers, each capped at 5000 marks, and the
  --         total is scaled back up by the sample ratio. the number is an
  --         estimate and is used only as a trend, never as a true count.
  local sample_max = 40
  local function count_extmarks()
    local total, seen, loaded = 0, 0, 0
    local ok = pcall(function()
      local namespaces = vim.api.nvim_get_namespaces()
      local bufs = vim.api.nvim_list_bufs()
      for _, buf in ipairs(bufs) do
        if vim.api.nvim_buf_is_loaded(buf) then
          loaded = loaded + 1
          if seen < sample_max then
            seen = seen + 1
            for _, ns in pairs(namespaces) do
              total = total + #vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, { limit = 5000 })
            end
          end
        end
      end
    end)
    if not ok then return -1 end
    if seen == 0 then return 0 end
    -- scale the sample to the full loaded population
    return math.floor(total * (loaded / seen))
  end

  -- .what = live channels (jobs, rpc peers, ptys) and libuv handles
  --
  -- .why  = a job spawned per refresh and never closed leaks a channel plus its
  --         buffers, and shows up in neither bufs nor lua. gitsigns shells out
  --         to git per buffer per change, so a close that is missed on error
  --         accumulates here first.
  local function count_chans()
    local ok, chans = pcall(vim.api.nvim_list_chans)
    if not ok then return -1 end
    return #chans
  end

  local function append_log(line)
    -- rotate at the cap: a core that lives for days writes this log the whole
    -- time, and an unbounded trend log becomes its own disk + io burden
    -- (observed at 7.2MB, itself written amid a swap storm)
    local stat = vim.uv.fs_stat(log_path)
    if stat and stat.size > log_max_bytes then
      os.remove(log_path .. '.1')
      os.rename(log_path, log_path .. '.1')
    end
    local f = io.open(log_path, 'a')
    if not f then return end
    f:write(line .. '\n')
    f:close()
  end

  -- 🛑 .what = the buffers a wipe must NEVER touch, however well they match
  --
  -- .why  = a breaker RECLAIMS, so its predicate is a delete contract — and the
  --         set it may reclaim is NOT the set it is safe to reclaim. neominimap
  --         creates ONE scratch buffer at module load
  --         (`neominimap/buffer/internal.lua:25`), gives it the plugin's own
  --         filetype, and holds it as a bare integer for the life of the
  --         process. it is never recreated and never revalidated.
  --
  --         so it is indistinguishable from a leaked minimap buffer by any
  --         property visible from outside: same filetype, same buftype, equally
  --         unmodified. the wipe below matched it, and every later refresh threw
  --         for the whole session.
  --
  -- ✔ .MEASURED 2026-09-06, headless, BOTH arms, against the live config:
  --
  --      ARM=control  empty_buffer=2 valid_after=true   refresh_ok=true
  --      ARM=break    empty_buffer=2 valid_after=false  refresh_ok=false
  --                   err=…split/internal.lua:159: Invalid buffer id: 2
  --
  --      ⚠️ the control arm is what earns the break arm. a break arm alone
  --         proves the buffer went invalid; it says none of whether the config
  --         was already broken. the pair names the WIPE as the cause.
  --
  -- ⚠️ .this is a LIST, not a lookup, because the exclusion is a claim per
  --      plugin. a second plugin that caches a buffer needs its own line here,
  --      and its absence is the same defect again.
  local function get_buffers_unwipeable()
    local keep = {}
    local ok, internal = pcall(require, 'neominimap.buffer.internal')
    if ok and type(internal) == 'table' and type(internal.empty_buffer) == 'number' then
      keep[internal.empty_buffer] = true
    end
    return keep
  end

  -- disable the heaviest handlers to halt growth, then reclaim
  --
  -- .note = the reclaim is MEASURED, not assumed. `collectgarbage` frees only
  --         lua-managed memory, so on a native leak it reclaims 0MB while the
  --         notification still claims a remedy was applied. the before/after
  --         pair is recorded so the log states which happened, and a future
  --         reader can tell a breaker that works from a ceremonial one.
  -- 🛑 .`get_keep` is an INJECTED READER, and it is an argument on purpose
  --
  -- ⚠️ .it is deliberately NOT called a "seam"
  --      this repo already spends that word on one sense — the link BETWEEN two
  --      components, owned by neither (`rule.require.seam-claims-have-an-owner`,
  --      which carries an audit table of every one). the industry sense (feathers:
  --      a place to alter behavior without an edit there) is a DIFFERENT concept,
  --      and to spend one word on both is the overload the glossary exists to
  --      prevent (`rule.forbid.domain-term-ambiguity`).
  --
  --      ⇒ the extant vocabulary already had the right word: this is
  --        `rule.require.dependency-injection` — an injected dependency with a
  --        shipped default. cite, do not coin.
  --
  -- .what = an optional reader for the keep-set. the shipped caller (the timer,
  --         below) passes none, so the local `get_buffers_unwipeable` is what
  --         runs in anger, always.
  --
  -- .why  — a discrimination probe must neuter the EXCLUSION and change no other
  --         part of the trip, or several checks redden and none is implicated
  --         (`rule.forbid.repair-plays`, exception 2, condition 3). measured
  --         2026-09-07: the first break arm swapped
  --         `_G.nvim_selfwatch.get_buffers_unwipeable`, and BOTH arms went green.
  --         the `_G` field holds a COPY OF THE REFERENCE; the call below reads a
  --         local UPVALUE. so the break neutered a holder nobody reads, and the
  --         control arm's ✔ proved none of what it claimed (term=bite).
  --
  --         ⇒ the arm looked like evidence and was a false ✔. the injected reader
  --           is what makes the break reach the reader in anger.
  --
  -- ⚠️ .why NOT read through `_G` here
  --      that would make the two halves symmetric and one line shorter — and it
  --      would hand every plugin that shares this lua state a write handle on a
  --      DELETE contract. `_G` is writable by all of them, so a plugin that
  --      clobbers the table would silently empty the keep-set and the breaker
  --      would destroy the buffer this exclusion exists to spare.
  --
  --      an argument cannot be clobbered. the caller either passes a reader or
  --      does not, and the shipped caller does not.
  local function trip_breaker(rss_mb, get_keep)
    tripped = true
    _G.nvim_selfwatch_tripped = true

    -- the full census BEFORE the breaker acts. a trip is the single most
    -- valuable sample the watchdog ever takes, and it previously threw every
    -- dimension away — it logged only rss, which names no culprit.
    local lua_before = get_lua_kb()
    local marks_before = count_extmarks()
    local chans_before = count_chans()
    local ts_before = count_ts_bufs()
    local bufs_before = #vim.api.nvim_list_bufs()

    -- read the keep-set BEFORE the disable, while the module is still loaded.
    -- `get_keep` is the probe's injected reader (see the header); absent it, the
    -- shipped reader is what runs — which is every call the timer ever makes
    local keep = (get_keep or get_buffers_unwipeable)()

    pcall(vim.cmd, 'Neominimap Disable')
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      pcall(vim.treesitter.stop, buf)
    end

    -- .what = wipe the leaked minimap buffers
    --
    -- .why  = `Neominimap Disable` hides the minimap WINDOWS; it does not delete
    --         their buffers, so the memory the trip fired over stays held. the
    --         breaker therefore reported a remedy while the leak was untouched,
    --         which is why 63 trips accrued rather than one.
    --
    --         measured: 2,709 of 2,714 buffers in a tripped core were minimap
    --         buffers. they are the leak, so they are what a breaker must
    --         reclaim.
    --
    -- .note = ONLY buffers whose filetype is `neominimap`, only unmodified ones,
    --         and NEVER one the plugin caches (see `get_buffers_unwipeable`). a
    --         wipe is destructive, and the two things this breaker must not
    --         destroy are unsaved human work and unrebuildable plugin state.
    local wiped = 0
    pcall(function()
      for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        local ok, ft = pcall(function() return vim.bo[buf].filetype end)
        local ok2, mod = pcall(function() return vim.bo[buf].modified end)
        if ok and ok2 and ft == 'neominimap' and not mod and not keep[buf] then
          if pcall(vim.api.nvim_buf_delete, buf, { force = true, unload = false }) then
            wiped = wiped + 1
          end
        end
      end
    end)

    collectgarbage('collect')

    local rss_after = get_self_rss_kb()
    local reclaimed_mb = rss_after and (rss_mb - math.floor(rss_after / 1024)) or -1

    pcall(vim.fn.jobstart, {
      'notify-send', '-u', 'critical', '-a', 'nvim',
      'nvim self-watchdog tripped',
      ('rss %dMB, wiped %d minimaps, reclaimed %dMB — see %s')
        :format(rss_mb, wiped, reclaimed_mb, log_path),
    })
    append_log(('%s TRIP rss_mb=%d reclaimed_mb=%d wiped=%d kept=%d lua_kb=%d marks=%d chans=%d bufs=%d ts=%d pid=%d')
      :format(os.date('%Y-%m-%dT%H:%M:%S'), rss_mb, reclaimed_mb, wiped,
        vim.tbl_count(keep), lua_before, marks_before, chans_before,
        bufs_before, ts_before, vim.fn.getpid()))
  end

  -- 🛑 .the contract, made REACHABLE — because an unreachable one cannot be clamped
  --
  -- .what = the two halves of the breaker's delete contract, exposed on `_G` so a
  --         probe can call the SHIPPED code rather than restate it.
  --
  -- .why  — a `local` inside this `do` block is not merely inconvenient, it is
  --         STRUCTURALLY untestable. the round that shipped `get_buffers_unwipeable`
  --         proved it with a probe that rebuilt the keep-set inline, which is one set
  --         with two readers — and the half that runs in anger is the half no arm
  --         touched (`gotcha.a-check-that-cries-wolf-gets-silenced`, m.9).
  --
  --         so the probe went green while the shipped `require` path was unproven. a
  --         rename upstream, a typo in the module name, a `pcall` that swallows: each
  --         leaves the arm green and the box broken.
  --
  -- ⚠️ .`trip_breaker` is exposed for the same reason and it is the sharper gap
  --      no arm has ever crossed 1.2GB, so the ORDER claim above — read the keep-set
  --      BEFORE the disable — was reasoned and never measured. a probe that drives a
  --      real trip is the only route that settles it.
  --
  -- ⚠️ .this grants no privilege that was not already there
  --      every plugin shares this lua state and `_G` is writable by all of them. the
  --      exposure buys a testable contract at no isolation cost — and an untestable
  --      contract has already cost one measured defect.
  --
  -- .refs = `.play/permanent/prove.breaker-spares-cached-buffers.play.sh`
  _G.nvim_selfwatch = {
    get_buffers_unwipeable = get_buffers_unwipeable,
    trip_breaker = trip_breaker,
  }

  local timer = vim.uv.new_timer()
  local last_run_s = 0
  timer:start(30000, 30000, vim.schedule_wrap(function()
    -- guard the catch-up stampede. when the event loop is starved — the box
    -- deep in swap, this core unscheduled for minutes — libuv fires a repeat
    -- timer ONCE PER MISSED INTERVAL the moment it regains cpu. observed: 40
    -- fires inside a single second, each one a /proc read, a buffer walk, and
    -- a log append. the watchdog then piles work on the machine exactly when
    -- it can least afford it, so the guard against a leak becomes a load of
    -- its own. the wall clock is the truth; drop any fire that lands early.
    local now_s = os.time()
    if now_s - last_run_s < 25 then return end
    last_run_s = now_s

    local rss = get_self_rss_kb()
    if not rss then return end
    local cpu = get_self_cpu_ticks()
    local cpu_delta = (cpu and cpu_last) and (cpu - cpu_last) or 0
    cpu_last = cpu

    -- log a compact trend line once we cross the warn line (low volume)
    --
    -- .note = lua_kb, marks, and chans are recorded because rss ALONE cannot
    --         attribute a leak. a prior trend showed rss +17M with bufs and ts
    --         both flat, which named no culprit and left the breaker with no
    --         lever. each added field splits a distinct suspect:
    --           lua_kb : lua-side leak vs native leak (the primary split)
    --           marks  : an extmark leak (gitsigns/minimap/diagnostics)
    --           chans  : a job/channel leak (a shell-out never closed)
    if rss >= warn_rss_kb then
      append_log(('%s rss_mb=%d lua_kb=%d cpu_ticks=%d bufs=%d ts=%d marks=%d chans=%d tripped=%s cwd=%s')
        :format(os.date('%Y-%m-%dT%H:%M:%S'), math.floor(rss / 1024), get_lua_kb(),
          cpu_delta, #vim.api.nvim_list_bufs(), count_ts_bufs(),
          count_extmarks(), count_chans(), tostring(tripped),
          vim.fn.getcwd()))
    end

    -- trip the breaker once, when we cross the soft limit
    if not tripped and rss >= soft_rss_kb then
      trip_breaker(math.floor(rss / 1024))
    end
  end))
end

-- ─────────────────────────────────────────────────────────────────
-- error scribe: stream every error this nvim throws into one log
-- .what = capture errors from both channels — vim.notify (what a
--         plugin reports) and the message history (what the runtime
--         throws: "Error in coroutine", "Error executing ... callback",
--         E-codes) — and append them to a durable log, deduped by
--         signature with a repeat count.
-- .why  = errors scroll off the screen and die with the session, so a
--         flake seen once is unreviewable an hour later. one durable
--         log lets us rank by frequency and fix the loudest offender
--         instead of the most recently remembered one.
-- .log  = stdpath('state')/errors.log  (rotates at 2MB -> errors.log.1)
-- .read = rhx nvim.errors.review
-- ─────────────────────────────────────────────────────────────────
do
  local log_path = vim.fn.stdpath('state') .. '/errors.log'
  local rotate_bytes = 2 * 1024 * 1024
  local repeat_secs = 120  -- same signature within window just counts, no new line
  local pid = vim.fn.getpid()
  local seen = {}          -- signature -> { count, written, last }

  -- lines that mark the START of an error worth a record
  local error_heads = {
    '^E%d+:',                       -- E5108, E903, ...
    '^Error ',                      -- "Error in coroutine", "Error executing ..."
    'Error detected while',
    'Error executing',
    'Error in ',
    '^Vim%(.-%):',                  -- Vim(lua):E5108: ...
    '^%s*Vim:E%d+',
  }

  local function matches_any(line, patterns)
    for _, p in ipairs(patterns) do
      if line:match(p) then return true end
    end
    return false
  end

  -- collapse a message into a stable signature, so `buffer id: 15968` and
  -- `buffer id: 15970` count as one repeat of one error, not two novel ones
  local function as_signature(msg)
    return (msg:gsub('%d+', '#'):gsub('%s+', ' '):sub(1, 240))
  end

  local function rotate_if_big()
    local st = vim.uv.fs_stat(log_path)
    if st and st.size > rotate_bytes then
      pcall(vim.uv.fs_rename, log_path, log_path .. '.1')
    end
  end

  local function append(line)
    rotate_if_big()
    local f = io.open(log_path, 'a')
    if not f then return end
    f:write(line .. '\n')
    f:close()
  end

  -- record one error; writes at most one line per signature per window
  local function capture(source, msg)
    if type(msg) ~= 'string' or msg == '' then return end
    local sig = as_signature(msg)
    local entry = seen[sig] or { count = 0, written = 0, last = 0 }
    seen[sig] = entry
    entry.count = entry.count + 1
    -- keep the on-disk text of the first hit, so the exit tally writes text
    -- byte-identical to the live lines. otherwise the reader reads one fault
    -- as two, and the rank it exists to produce is wrong.
    entry.text = entry.text or msg:gsub('\n', ' \\n '):sub(1, 900)

    local now = os.time()
    if entry.written > 0 and (now - entry.last) < repeat_secs then return end
    entry.written = entry.count
    entry.last = now

    append(('%s pid=%d src=%s n=%d cwd=%s | %s'):format(
      os.date('%Y-%m-%dT%H:%M:%S'), pid, source, entry.count, vim.fn.getcwd(),
      entry.text))
  end
  _G.nvim_errorlog = { path = log_path, capture = capture }

  -- channel 1: vim.notify — what plugins report as their own failure
  local function wrap_notify(orig)
    return function(msg, level, opts)
      if (level or vim.log.levels.INFO) >= vim.log.levels.WARN then
        local src = (level or 0) >= vim.log.levels.ERROR and 'notify.error' or 'notify.warn'
        pcall(capture, src, type(msg) == 'string' and msg or vim.inspect(msg))
      end
      return orig(msg, level, opts)
    end
  end
  local our_notify = wrap_notify(vim.notify)
  vim.notify = our_notify
  -- re-wrap after plugins load: noice/nvim-notify replace vim.notify wholesale
  vim.api.nvim_create_autocmd('VimEnter', {
    callback = function()
      if vim.notify ~= our_notify then
        our_notify = wrap_notify(vim.notify)
        vim.notify = our_notify
      end
    end,
  })

  -- channel 2: message history — what the runtime throws past vim.notify
  -- .why = an error from a libuv timer or a decoration provider never
  --        touches vim.notify; it lands only in :messages. that is
  --        exactly the class that halts the ui, so it is the class we
  --        most need on record.
  -- the cursor anchors on CONTENT, not on a line index.
  -- .why = :messages is a fixed-size circular history (~500 lines). once it
  --        fills, the line COUNT holds steady while the content still rolls,
  --        so an index cursor pins past the end and the poll goes permanently
  --        deaf — precisely in the long sessions where errors matter most.
  --        an anchor on the last line's text survives the roll: we find that
  --        line again wherever it drifted to, and resume after it.
  local msgs_anchor = nil
  local function drain_messages()
    local ok, res = pcall(vim.api.nvim_exec2, 'messages', { output = true })
    if not ok or not res or not res.output then return end
    local lines = vim.split(res.output, '\n', { plain = true })

    -- resume just after the last line we processed. search backward so a
    -- repeated line resolves to its most recent occurrence. if the anchor is
    -- absent (history rolled entirely between polls), rescan from the top —
    -- over-capture is the safe direction; the dedup collapses the repeats,
    -- whereas a skip loses the error for good.
    local start = 1
    if msgs_anchor then
      for k = #lines, 1, -1 do
        if lines[k] == msgs_anchor then start = k + 1 break end
      end
    end
    if #lines > 0 then msgs_anchor = lines[#lines] end

    local i = start
    while i <= #lines do
      if matches_any(lines[i], error_heads) then
        -- gather the body that belongs to this head, so the record names
        -- the culprit file, not just the symptom.
        -- .why = the head is often a bare banner ("Error in command line:")
        --        whose payload sits on the NEXT lines. we take every
        --        non-blank line until the next head, bounded — an extra
        --        line of context is cheap; a lost traceback forfeits the
        --        whole point of the log.
        local chunk = { lines[i] }
        local j = i + 1
        while j <= #lines and #chunk < 10
          and lines[j] ~= ''
          and not matches_any(lines[j], error_heads) do
          chunk[#chunk + 1] = lines[j]
          j = j + 1
        end
        capture('messages', table.concat(chunk, '\n'))
        i = j
      else
        i = i + 1
      end
    end
  end

  local timer = vim.uv.new_timer()
  timer:start(5000, 5000, vim.schedule_wrap(drain_messages))

  -- flush at exit: drain what arrived since the last poll, then record the
  -- final tally of any storm that was collapsed by the repeat window
  vim.api.nvim_create_autocmd('VimLeavePre', {
    callback = function()
      pcall(drain_messages)
      for _, entry in pairs(seen) do
        if entry.count > entry.written then
          append(('%s pid=%d src=tally n=%d cwd=%s | %s'):format(
            os.date('%Y-%m-%dT%H:%M:%S'), pid, entry.count, vim.fn.getcwd(), entry.text))
        end
      end
    end,
  })
end

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

-- diff boundary repeat: lets ctrl stay down across emits
--
-- three input forms reach the same jump. see the behavior inventory:
-- .agent/repo=.this/role=any/briefs/inventory.of=behaviors.via=nvim.case=diff-boundary-nav.md
--   1. (ctrl+d, ctrl+j) -> emit, (ctrl+d, ctrl+j) -> emit, ...   ctrl free to lift
--   2. ctrl+( (d,j) -> emit, (d,j) -> emit, ... )                ctrl held, d+j re-tapped
--   3. ctrl+d+( j -> emit, j -> emit, ... )                      ctrl held, j alone repeats
--
-- forms 1 and 2 are ONE keystream — <C-d><C-j> either way, because a ctrl lift
-- between two chords leaves no trace in the keycodes. both always worked.
--
-- form 3 needs this arm: the ctrl-held chord re-points ctrl+j at another boundary
-- jump instead of its usual half page scroll, until a key outside the set ends it.
--
-- the disarm on ctrl lift costs no code: ctrl-held j arrives as <C-j> (kitty
-- rewrites it to <S-CR>), while a ctrl-lifted j arrives as plain `j`, which is
-- never rebound. so the moment ctrl comes up, `j` is a normal motion again.
--
-- 🛑 a ctrl RELEASE is UNREACHABLE here, and it is nvim that drops it, not tmux.
--    measured 2026-09-06 -- see howdoes.a-key-event-reaches-nvim.md:
--      · tmux relays `CSI 57442;1:3u` (ctrl release) byte for byte
--      · nvim decodes the PRESS of that same key to U+E062
--      · nvim yields NO key at all for any `:3u` release
--    so the arm cannot end on the lift. it ends on the VOCABULARY instead.
local BOUNDARY_REPEAT_KEEP = {}
for _, k in ipairs({ '<C-d>', '<C-j>', '<C-k>', '<S-CR>' }) do
  BOUNDARY_REPEAT_KEEP[#BOUNDARY_REPEAT_KEEP + 1] =
    vim.api.nvim_replace_termcodes(k, true, false, true)
end

-- ⚠️ on_key hands the WHOLE resolved chord as one string, never one key per call:
--    `<C-d><C-j>` arrives as `04 0a`, not as `04` then `0a`. so the test is whether
--    the string DECOMPOSES into vocabulary members, not whether it IS one.
--    no member is a prefix of another (04 / 0a / 0b / 80 fc 02 0d), so a greedy
--    walk is exact.
local function boundary_repeat_keeps(s)
  local i = 1
  while i <= #s do
    local step = nil
    for _, v in ipairs(BOUNDARY_REPEAT_KEEP) do
      if s:sub(i, i + #v - 1) == v then step = #v break end
    end
    if not step then return false end
    i = i + step
  end
  return true
end

local boundary_repeat = { live = false, bufnr = -1, down = nil, up = nil }

local function boundary_repeat_arm(down, up)
  boundary_repeat.down = down
  boundary_repeat.up = up
  boundary_repeat.bufnr = vim.api.nvim_get_current_buf()
  boundary_repeat.live = true
end

-- armed only while the vocabulary holds AND we are still in the buffer that armed it
local function boundary_repeat_armed()
  return boundary_repeat.live
    and boundary_repeat.bufnr == vim.api.nvim_get_current_buf()
end

-- ⚠️ the disarm is a KEY, never a clock. any key outside the four above ends the
--    arm, so `<C-d><C-j><C-j> w` leaves `w` normal and the next <C-j> a half page.
--    on_key runs BEFORE the keymap fires, so an arm survives the keys that set it.
--
-- 🛑 read `typed`, and NEVER fall back to `key`.
--    measured 2026-09-06: whenever a LUA keymap resolves, on_key reports
--    `key = 80 fd 67` -- K_LUA, nvim's internal "a callback runs" pseudo-key. it
--    carries no trace of which key was struck, so a fallback to it disarms on
--    every mapped key. a `key`-fallback draft broke exactly the form-3 repeat it
--    was meant to serve.
vim.on_key(function(_, typed)
  if not boundary_repeat.live then return end
  if not typed or typed == '' then return end
  if not boundary_repeat_keeps(typed) then boundary_repeat.live = false end
end)

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

-- image extensions that image.nvim renders via kitty graphics.
-- single source of truth: the codediff image-diff detect AND the image.nvim
-- hijack_file_patterns (see plugin config below) both derive from this.
-- headless-tested via .behavior/.../verify.image-diff.lua (mirror pattern —
-- that file re-declares this list + is_image_diff_path; update BOTH on change).
local IMAGE_DIFF_EXTS = {
  png = true, jpg = true, jpeg = true, gif = true, webp = true, avif = true,
}

-- glob form of IMAGE_DIFF_EXTS for image.nvim's hijack_file_patterns
local IMAGE_DIFF_GLOBS = {}
for ext in pairs(IMAGE_DIFF_EXTS) do
  IMAGE_DIFF_GLOBS[#IMAGE_DIFF_GLOBS + 1] = '*.' .. ext
end
table.sort(IMAGE_DIFF_GLOBS)

-- true if the path ends in a renderable image extension
local function is_image_diff_path(path)
  if not path then return false end
  local ext = path:match('%.([%w]+)$')
  if not ext then return false end
  return IMAGE_DIFF_EXTS[ext:lower()] == true
end

-- fill one pane: render an image, or show a text label on a blank pane
local function set_image_diff_pane(win, present, image_mod, img_path, label, winbar)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(win, buf)
  vim.bo[buf].bufhidden = 'wipe'
  vim.wo[win].winbar = winbar
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = 'no'
  if present then
    -- render the image into this specific window + buffer
    image_mod.hijack_buffer(img_path, win, buf)
  else
    -- absent side: a text label on a blank pane
    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { '', '  ' .. label, '' })
    vim.bo[buf].modifiable = false
  end
  return buf
end

-- open a side-by-side image diff: old (git base) vs new (worktree), rendered
-- INTO codediff's own diff windows so the explorer tree stays on the left —
-- exactly where a text diff shows. opts = { git_root, path, old_path, status,
-- base_revision }
local function open_codediff_image_diff(opts)
  local image_ok, image_mod = pcall(require, 'image')
  if not image_ok then
    vim.notify('image.nvim absent — cannot diff image', vim.log.levels.WARN)
    return
  end

  local git_root = opts.git_root
  local path = opts.path
  -- loud, not silent: a nil git_root/path would otherwise fail with no feedback
  if not git_root or not path then
    vim.notify('codediff-image-diff: no git_root/path for node — cannot diff image', vim.log.levels.WARN)
    return
  end
  local old_path = opts.old_path or path
  local base = opts.base_revision or 'HEAD'
  local status = opts.status or ''
  local ext = path:match('%.([%w]+)$') or 'png'

  -- which sides exist, from git status (A/?? = no old; D = no new)
  local has_old = not (status == 'A' or status == '??')
  local has_new = not (status == 'D')

  -- extract the old blob to a temp file, byte-safe (no text decode)
  local old_tmp = nil
  if has_old then
    local spec = base .. ':' .. old_path
    local res = vim.system({ 'git', '-C', git_root, 'show', spec }, { text = false }):wait()
    if res.code == 0 and res.stdout and #res.stdout > 0 then
      old_tmp = vim.fn.tempname() .. '.' .. ext
      local fh = io.open(old_tmp, 'wb')
      if fh then
        fh:write(res.stdout)
        fh:close()
      else
        old_tmp = nil
        has_old = false
      end
    else
      -- base blob absent (e.g. a rename edge) — treat as no old
      has_old = false
    end
  end

  -- absolute path of the on-disk new file
  local abs_new = git_root .. '/' .. path

  -- keep the codediff explorer tree visible: render into codediff's OWN diff
  -- windows (old = original_win, new = modified_win) in the current tab, exactly
  -- where a text diff shows. this preserves the staged/unstaged treestruct on
  -- the left instead of a dedicated tab that hides it.
  local tabpage = vim.api.nvim_get_current_tabpage()

  -- find the explorer window, so close can return focus to the tree
  local explorer_win = nil
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tabpage)) do
    local b = vim.api.nvim_win_get_buf(win)
    if vim.bo[b].filetype == 'codediff-explorer' then
      explorer_win = win
      break
    end
  end

  -- reuse codediff's diff windows: original=old (base), modified=new (worktree)
  local old_win, new_win = nil, nil
  local lc_ok, lifecycle = pcall(require, 'codediff.ui.lifecycle')
  if lc_ok then
    local orig_win, mod_win = lifecycle.get_windows(tabpage)
    if orig_win and vim.api.nvim_win_is_valid(orig_win)
      and mod_win and vim.api.nvim_win_is_valid(mod_win) then
      old_win, new_win = orig_win, mod_win
    end
  end

  -- fallbacks: split beside the explorer, or (no explorer) a dedicated tab
  local used_dedicated_tab = false
  if not old_win or not new_win then
    if explorer_win and vim.api.nvim_win_is_valid(explorer_win) then
      vim.api.nvim_set_current_win(explorer_win)
      vim.cmd('rightbelow vsplit')
      old_win = vim.api.nvim_get_current_win()
      vim.cmd('rightbelow vsplit')
      new_win = vim.api.nvim_get_current_win()
    else
      used_dedicated_tab = true
      vim.cmd('tabnew')
      new_win = vim.api.nvim_get_current_win()
      vim.cmd('aboveleft vsplit')
      old_win = vim.api.nvim_get_current_win()
    end
  end

  -- close handler: a dedicated tab closes; the in-explorer layout returns focus
  -- to the tree (the panes are reused by the next selection). temp removal is
  -- owned by the BufWipeout autocmd below, so every close path cleans up.
  local function close_image_diff()
    if used_dedicated_tab then
      vim.cmd('tabclose')
    elseif explorer_win and vim.api.nvim_win_is_valid(explorer_win) then
      vim.api.nvim_set_current_win(explorer_win)
    end
  end

  -- clear any stale image placement on the reused windows first. codediff's
  -- diff windows persist across selections, so a prior render (e.g. unstaged →
  -- then staged for the same file) would ghost/flicker under the new one. kitty
  -- graphics are placement-based, not buffer-bound, so an explicit clear is the
  -- root-cause fix, not a buffer swap.
  for _, w in ipairs({ old_win, new_win }) do
    if w and vim.api.nvim_win_is_valid(w) then
      for _, img in ipairs(image_mod.get_images({ window = w })) do
        pcall(function() img:clear(true) end)
      end
    end
  end

  local old_buf = set_image_diff_pane(
    old_win, has_old, image_mod, old_tmp,
    'no before version (added)', 'before (' .. base .. ')'
  )
  local new_buf = set_image_diff_pane(
    new_win, has_new, image_mod, abs_new,
    'no after version (deleted)', 'after (tree)'
  )

  -- delete the temp blob on any close path, not just q
  if old_tmp then
    vim.api.nvim_create_autocmd('BufWipeout', {
      buffer = old_buf,
      once = true,
      callback = function() pcall(os.remove, old_tmp) end,
    })
  end

  -- q leaves the image view: back to the tree (in-explorer) or shut the tab
  for _, b in ipairs({ old_buf, new_buf }) do
    vim.keymap.set('n', 'q', close_image_diff,
      { buffer = b, nowait = true, silent = true, desc = 'leave image diff' })
  end

  -- keep focus on the tree (like a text diff does), so the human can browse to
  -- the next file without a hop back. fall back to the new pane only when there
  -- is no explorer (dedicated-tab case).
  if explorer_win and vim.api.nvim_win_is_valid(explorer_win) then
    vim.api.nvim_set_current_win(explorer_win)
  elseif vim.api.nvim_win_is_valid(new_win) then
    vim.api.nvim_set_current_win(new_win)
  end
end

-- open the image diff for an explorer file node — single source of the
-- node.data → opts shape, shared by the <CR> and <2-LeftMouse> handlers so a
-- field change (e.g. a new_path field for renames) is a one-place edit
local function open_image_diff_for_node(node, explorer)
  open_codediff_image_diff({
    git_root = explorer.git_root or node.data.git_root,
    path = node.data.path,
    old_path = node.data.old_path,
    status = node.data.status,
    base_revision = explorer.base_revision,
  })
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
--
-- 🛑 .why the spec is a TABLE here and handed to lazy at the end of it
--      NONE of the specs below carries a ref, so `lazy.setup` takes each at
--      its default-branch tip UNLESS `lazy-lock.json` is on disk to override
--      the target. the lockfile is therefore a PRECONDITION of this call, not
--      a refinement of it — so the call is gated on `LAZY_PINNED` rather than
--      made unconditionally and hoped over. read the bootstrap block at the
--      top of this file for the measurement.
--
-- ⚠️ .why the gate is here and not only at the bootstrap
--      the bootstrap gate covers a FRESH box. a box that already holds lazy
--      and has lost its lockfile would sail past it and sync 13 repos at tip
--      — a smaller door to the same room.
local PLUGIN_SPEC = {
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
      -- the ctrl-HELD chords also arm the repeat, so a bare ctrl+j / ctrl+k goes
      -- on to emit jumps while ctrl stays down (form 3). the ctrl-LIFTED chords
      -- (<C-d>j / <C-d>k) do not arm — ctrl is already up, so form 3 is moot.
      local function boundary_down_arm()
        boundary_down()
        boundary_repeat_arm(boundary_down, boundary_up)
      end
      local function boundary_up_arm()
        boundary_up()
        boundary_repeat_arm(boundary_down, boundary_up)
      end
      vim.keymap.set('n', '<C-d>j', boundary_down, { desc = 'Next diff boundary' })
      vim.keymap.set('n', '<C-d>k', boundary_up, { desc = 'Prev diff boundary' })
      vim.keymap.set('n', '<C-d><C-j>', boundary_down_arm, { desc = 'Next diff boundary' })
      vim.keymap.set('n', '<C-d><C-k>', boundary_up_arm, { desc = 'Prev diff boundary' })
      -- kitty remaps ctrl+j -> shift+enter (the `map ctrl+j send_key shift+enter`
      -- line in grove.provision/4.terminal/4.3.kitty/4.3.2.emulator/kitty.conf),
      -- so ctrl-held <C-d><C-j> never delivers <C-j> to
      -- nvim — it arrives as <S-CR>. map that too so "ctrl held down" next-diff
      -- works. ctrl+k is untouched by kitty, so prev needs no equivalent.
      vim.keymap.set('n', '<C-d><S-CR>', boundary_down_arm, { desc = 'Next diff boundary' })
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
        -- .note = `neominimap` excludes ITSELF, and that clause is the whole
        --         guard against a self-amplified buffer leak.
        --
        --         a minimap is itself a `nofile` scratch buffer. neominimap's
        --         default `exclude_buftypes` holds `nofile`, so by default a
        --         minimap can never be given a minimap. the empty list below
        --         removes that guard on purpose — codediff's panes are `nofile`
        --         and must be mapped — and it thereby also makes every minimap
        --         eligible for a minimap of its own.
        --
        --         measured 2026-09-03: 2,709 of one core's 2,714 buffers were
        --         minimap buffers (1,367 typed `neominimap`, 1,342 not yet
        --         typed) — a near 1:1 ratio, which is the signature of a map
        --         made for each map. history showed 34,354 buffers in a worse
        --         core. this is the leak behind 63 watchdog trips.
        --
        --         so the filetype exclusion does the narrow job the buftype
        --         exclusion used to do broadly: minimaps stay off minimaps,
        --         while codediff's `nofile` panes still get theirs.
        exclude_filetypes = { 'neo-tree', 'oil', 'help', 'lazy', 'codediff-explorer', 'neominimap' },
        exclude_buftypes = {},  -- allow virtual buffers (for codediff)
        git = {
          enabled = true,
          mode = 'line',
        },
        diagnostic = { enabled = false },
      }
    end,
    config = function()
      -- defuse neominimap before nvim tears windows down on quit.
      -- why: neominimap's WinClosed/BufWinEnter autocmds vim.schedule() a
      --      refresh that calls nvim_win_set_buf on the minimap window. on
      --      :q those callbacks run mid-teardown against a half-destroyed
      --      window and throw, which floods the -- More -- pager. the queued
      --      callbacks each throw again, so the pager never clears -> permahang.
      -- fix: turn neominimap off first. the queued callbacks then re-check the
      --      enabled flag and take the harmless "no minimap" branch instead of
      --      the set_buf path. pcall + silent! so quit never blocks on this.
      vim.api.nvim_create_autocmd({ 'QuitPre', 'VimLeavePre' }, {
        callback = function()
          pcall(vim.cmd, 'silent! Neominimap Disable')
        end,
      })

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
          vim.cmd('Neominimap Refresh')
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
      vim.keymap.set('n', '<C-m>', '<cmd>Neominimap Toggle<cr>', { desc = 'Toggle minimap' })

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

      -- patch codediff explorer keymaps SYNCHRONOUSLY, before the first
      -- :CodeDiff builds the explorer. a deferred patch (vim.defer_fn) races the
      -- first explorer render and misses it — the image node then falls through
      -- to codediff's text diff, where binary bytes render as garbage and the
      -- virtual codediff:// png buffer errors. run inline via an iife so the
      -- `return` early-exits still work.
      ;(function()
        local ok, keymaps_mod = pcall(require, 'codediff.ui.explorer.keymaps')
        if not ok then return end

        local original_setup = keymaps_mod.setup
        keymaps_mod.setup = function(explorer)
          -- call original to set up all keymaps
          original_setup(explorer)

          -- divert image selections at the SINGLE funnel: every entry point
          -- (<CR>, double-click, ]f/[f file-nav, auto-open, reselect) routes
          -- through explorer.on_file_select. wrap it so an image node never
          -- reaches codediff's text/diff path. the keymaps below also divert
          -- directly; this wrapper covers the file-nav + programmatic entries.
          local original_on_file_select = explorer.on_file_select
          explorer.on_file_select = function(file_data, opts)
            if file_data and is_image_diff_path(file_data.path) then
              open_codediff_image_diff({
                git_root = explorer.git_root or file_data.git_root,
                path = file_data.path,
                old_path = file_data.old_path,
                status = file_data.status,
                base_revision = explorer.base_revision,
              })
              return
            end
            return original_on_file_select(file_data, opts)
          end

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
              -- file node
              if is_image_diff_path(node.data.path) then
                -- image node — divert to our side-by-side image diff, so the
                -- binary never reaches codediff's text/diff path (which errors)
                open_image_diff_for_node(node, explorer)
              elseif explorer.on_file_select then
                -- non-image file — codediff default
                explorer.on_file_select(node.data)
              end
            end
          end, { buffer = split.bufnr, noremap = true, silent = true, nowait = true, desc = 'Toggle/select' })

          -- double-click mirrors <CR> for file nodes: codediff binds
          -- <2-LeftMouse> straight to on_file_select, which would feed an image
          -- into the text/diff path and error. divert image nodes here too.
          vim.keymap.set('n', '<2-LeftMouse>', function()
            local node = tree:get_node()
            if not node or not node.data then return end
            local node_type = node.data.type
            if node_type == 'group' or node_type == 'directory' then return end
            if is_image_diff_path(node.data.path) then
              open_image_diff_for_node(node, explorer)
            elseif explorer.on_file_select then
              explorer.on_file_select(node.data)
            end
          end, { buffer = split.bufnr, noremap = true, silent = true, nowait = true, desc = 'Select file' })
        end
      end)()


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
          -- ctrl-HELD chords arm the repeat (form 3); ctrl-lifted ones do not.
          -- see the gitsigns block above for the full rationale.
          local function boundary_down_arm()
            boundary_down()
            boundary_repeat_arm(boundary_down, boundary_up)
          end
          local function boundary_up_arm()
            boundary_up()
            boundary_repeat_arm(boundary_down, boundary_up)
          end
          vim.keymap.set('n', '<C-d>j', boundary_down, { buffer = true, desc = 'Next diff boundary' })
          vim.keymap.set('n', '<C-d>k', boundary_up, { buffer = true, desc = 'Prev diff boundary' })
          vim.keymap.set('n', '<C-d><C-j>', boundary_down_arm, { buffer = true, desc = 'Next diff boundary' })
          vim.keymap.set('n', '<C-d><C-k>', boundary_up_arm, { buffer = true, desc = 'Prev diff boundary' })
          -- kitty remaps ctrl+j -> shift+enter, so ctrl-held <C-d><C-j> reaches
          -- nvim as <S-CR>; map it so next-diff works with ctrl held (see the
          -- gitsigns block above for the full rationale). ctrl+k is untouched.
          vim.keymap.set('n', '<C-d><S-CR>', boundary_down_arm, { buffer = true, desc = 'Next diff boundary' })
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
      -- navigate between windows. only left/right — ctrl+j/ctrl+k are half-page
      -- scroll (see the scroll keymaps near the bottom of this file).
      vim.keymap.set('n', '<C-h>', ss.move_cursor_left)
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
    -- requires: kitty terminal + imagemagick cli
    -- kitty  is installed by grove.provision/4.terminal/4.3.kitty/
    -- magick is installed by grove.provision/4.terminal/4.5.nvim/ — with THIS file,
    --   not with the terminal, because the bundle that needs a dependency is the
    --   bundle that owns it (rule.require.bundles-own-their-dependencies)
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
        -- derived from IMAGE_DIFF_EXTS (top of file) — one source of truth,
        -- shared with the codediff image-diff detect
        hijack_file_patterns = IMAGE_DIFF_GLOBS,
      })
    end,
  },
}

--------------------------------------------------------------------
-- hand the spec to lazy — ONLY with the pin in place
--
-- ⚠️ .the outcome is PUBLISHED, not merely acted on
--      `vim.g.lazy_pinned` lets `4.5.nvim/configure.verify` read this decision
--      out of a running editor, in the same start that already reports
--      modeline/exrc. a verify that greps this file instead could go green on
--      a checkout whose next line flips the flag back — the same argument that
--      block already makes for reading the EFFECT rather than the text.
--
-- ⚠️ .why the notice is a plain `nvim_echo`, sent at once
--      on this path no plugin has loaded, so no `notify` handler is
--      guaranteed. and a `vim.schedule` would not flush before a headless
--      `+q`, which is exactly the caller that most needs to see it.
--------------------------------------------------------------------
vim.g.lazy_pinned = LAZY_PINNED
vim.g.lazy_why = lazy_why

if LAZY_PINNED then
  require('lazy').setup(PLUGIN_SPEC)
else
  vim.api.nvim_echo({
    { 'nvim: plugins are OFF — ' .. lazy_why .. '\n', 'WarningMsg' },
    { 'a pin is required before any plugin is fetched, so none was fetched.\n', 'None' },
    { 'fix: rhx grove.provision --what 4.5.nvim --mode apply\n', 'None' },
  }, true, {})
end

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

-- colorscheme: the Desert palette (see theme.desert.md for the hexes)
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



-- ctrl+c / ctrl+shift+c = copy (visual mode)
-- kitty grabs ctrl+c and forwards ctrl+shift+c (CSI 99;6u) downstream, so
-- <C-S-c> is the path that fires under kitty; <C-c> stays as the fallback for
-- non-kitty terminals that pass ctrl+c straight through.
vim.keymap.set('v', '<C-c>', '"+y')
vim.keymap.set('v', '<C-S-c>', '"+y')

-- show a copied status on clipboard yanks (mirrors the +stage 🤙 status), so
-- every copy path (<C-c>, <C-S-c>, "+y) confirms the copy in one place. gated on
-- the + register so an ordinary yy into the unnamed register stays quiet.
vim.api.nvim_create_autocmd('TextYankPost', {
  callback = function()
    local ev = vim.v.event
    if ev.operator == 'y' and ev.regname == '+' then
      print('+copied 🤙')
      -- desktop toast. through tmux the copy happens in nvim, not kitty, so
      -- kitty's copy_notify.py toast never fires (it only toasts when kitty
      -- owns the selection). dispatch it here so a clipboard yank confirms with
      -- the same toast on every path. gated on the binary so a host that lacks
      -- notify-send stays quiet instead of an E903 error.
      if vim.fn.executable('notify-send') == 1 then
        vim.fn.jobstart({ 'notify-send', '-t', '1200', '-a', 'kitty', 'copied to clipboard' })
      end
    end
  end,
})

-- ctrl+v = paste (insert + normal mode)
vim.keymap.set('i', '<C-v>', '<C-r>+')
vim.keymap.set('n', '<C-v>', '"+p')

-- ctrl+s = save and exit to normal mode
vim.keymap.set('n', '<C-s>', ':w<CR>')
vim.keymap.set('i', '<C-s>', '<Esc>:w<CR>')

-- ctrl+q = force quit ALL windows, no save prompt (:qa!). the escape hatch for
-- when :q wedges on a modified buffer or a stubborn split. bound in normal,
-- insert, and visual so it fires from any mode without a hop to normal first.
-- note: this only helps while nvim still reads input; a fully hung nvim needs a
-- kill from outside the process (see the tmux force-reboot keymap).
vim.keymap.set('n', '<C-q>', '<Cmd>qa!<CR>', { noremap = true })
vim.keymap.set('i', '<C-q>', '<Cmd>qa!<CR>', { noremap = true })
vim.keymap.set('v', '<C-q>', '<Cmd>qa!<CR>', { noremap = true })

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

-- ctrl+h/l = navigate between windows left/right (smart-splits plugin above)

-- ctrl+j / ctrl+k = half page down / up in normal mode. vim's native <C-d>/<C-u>
-- are taken by the gitsigns diff prefix, so the home-row pair carries the scroll.
-- zz recenters so the cursor stays mid-screen across repeats.
-- note: kitty remaps ctrl+j -> shift+enter (the `map ctrl+j send_key
-- shift+enter` line in
-- grove.provision/4.terminal/4.3.kitty/4.3.2.emulator/kitty.conf),
-- so under kitty a bare ctrl+j arrives as <S-CR>. bind
-- both so this works in kitty and in terminals that pass ctrl+j through.
-- the <C-d>j / <C-d><C-j> diff-boundary chords are unaffected: they start with
-- <C-d>, so nvim resolves them as their own mappings before ctrl+j is seen.
-- while a diff-boundary repeat is armed (a ctrl-held <C-d><C-j> fired in this
-- buffer, with no off-vocabulary key since), these keys emit the next/prev
-- boundary instead — that is form 3, `ctrl+d+( j -> emit, j -> emit, ... )`. the
-- scroll is LENT to the repeat, and any key outside {<C-d> <C-j> <C-k> <S-CR>}
-- returns it. a lifted ctrl sends plain `j`, which both disarms and never reaches
-- here at all. see the boundary_repeat block near navigate_diff_boundary.
local function half_page(dir)
  return function()
    if boundary_repeat_armed() then
      local go = dir == 'down' and boundary_repeat.down or boundary_repeat.up
      if go then
        go()
        boundary_repeat_arm(boundary_repeat.down, boundary_repeat.up)
        return
      end
    end
    vim.cmd('normal! ' .. (dir == 'down' and vim.keycode('<C-d>') or vim.keycode('<C-u>')) .. 'zz')
  end
end
vim.keymap.set('n', '<C-j>', half_page('down'), { noremap = true, desc = 'Half page down' })
vim.keymap.set('n', '<S-CR>', half_page('down'), { noremap = true, desc = 'Half page down' })
vim.keymap.set('n', '<C-k>', half_page('up'), { noremap = true, desc = 'Half page up' })

-- ctrl+z = undo, ctrl+shift+z = redo (standard keybinds)
vim.keymap.set('n', '<C-z>', 'u', { noremap = true })
vim.keymap.set('i', '<C-z>', '<Esc>ui', { noremap = true })
vim.keymap.set('n', '<C-S-z>', '<C-r>', { noremap = true })
vim.keymap.set('i', '<C-S-z>', '<Esc><C-r>i', { noremap = true })

-- ctrl+r = copy relative path of current file to clipboard (relative to cwd).
-- also bind the ctrl+alt+r and ctrl+super+r variants: with the kitty keyboard
-- protocol on, those held-modifier combos reach nvim as distinct keycodes
-- (<C-A-r> / <C-D-r>), so point all three at the same copy so muscle memory works.
local function copy_relpath()
  local path = vim.fn.expand('%:.')
  vim.fn.setreg('+', path)
  print('copied: ' .. path)
end
vim.keymap.set('n', '<C-r>', copy_relpath, { noremap = true, silent = false })
vim.keymap.set('n', '<C-A-r>', copy_relpath, { noremap = true, silent = false })
vim.keymap.set('n', '<C-D-r>', copy_relpath, { noremap = true, silent = false })

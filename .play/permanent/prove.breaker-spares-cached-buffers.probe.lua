-- .what = the probe body driven by prove.breaker-spares-cached-buffers.play.sh
--
-- .why  = it lives in its OWN file, beside the play, because the alternative
--         was measured: the body sat in a heredoc inside the play, and every
--         hand-driven arm needed a SECOND copy under .play/temporary/ to run
--         at all. two copies of one probe, free to drift — the exact m.9 shape
--         ("one set, two readers") this probe exists to close.
--
--         ⇒ one body, one holder. `rhx nvim.test.headless --probe <this file>`
--           drives it, so no caller ever restates it.
--
-- .the contract with its driver
--   PROBE_ARM  which arm to drive: 'control' | 'old'
--   PROBE_OUT  where to write the rows
--
--   ⚠️ PROBE_OUT, never a fixed $HOME path. two runs at once on one box would
--      otherwise read each other's rows
--      (`rule.forbid.fixed-paths-in-a-shared-tmp`).
--
-- 🛑 .it waits on the WORLD'S OWN PRESENCE — never a clock, and never
--    `User LazyDone` either. that distinction was MEASURED, 2026-09-06:
--
--      a first cut hooked `User LazyDone` (lazy/init.lua:115), which is a
--      genuine plugin-load-complete signal. it reported
--      `world=absent reason=LazyDone_never_fired`, every run.
--
--      the cause is the HOOK POINT, not the signal: `-c luafile` runs AFTER
--      init.lua returns, so `lazy.setup` has already fired LazyDone by the
--      time this file registers for it, and a `once=true` autocmd waits
--      forever for an event that is already past.
--
--    ⇒ so the equivalent signal is the condition `measure` actually needs —
--      "is the module loadable AND the contract exposed?" — and `vim.wait`
--      returns the instant it holds. that is step 3 of
--      rule.prefer.deterministic-signal-over-timer: when the direct signal is
--      unreachable, hunt an EQUIVALENT one. here the equivalent is strictly
--      better, because it is the question rather than a proxy for it.
--
--    ⚠️ and note WHAT CAUGHT IT: the read-back. a `vim.defer_fn(…, 1500)`
--      would have run `measure` against a half-loaded editor and reported a
--      verdict; the read-back reported that it asked no question at all
--      (gotcha.a-check-that-cries-wolf-gets-silenced, q5).
--
--    the 20s below is a BOUND on the hang, not a proxy for the signal. it
--    writes `world=absent` rather than a verdict.

local arm = os.getenv('PROBE_ARM') or 'control'
local out = os.getenv('PROBE_OUT')

if not out then
  -- refuse rather than pick a path. a probe that invents its own out path is
  -- how a fixed $HOME write gets reintroduced
  io.stderr:write('probe: PROBE_OUT is unset; it refuses to pick a path\n')
  os.exit(1)
end

local function say(t) vim.fn.writefile(t, out) end

-- the EQUIVALENT signal: the exact condition `measure` needs. `vim.wait`
-- returns the instant it holds, so no clock stands in for it.
local function ready()
  local ok, internal = pcall(require, 'neominimap.buffer.internal')
  return ok
    and type(internal) == 'table'
    and type(internal.empty_buffer) == 'number'
    and type(_G.nvim_selfwatch) == 'table'
    and type(_G.nvim_selfwatch.trip_breaker) == 'function'
    and type(_G.nvim_selfwatch.get_buffers_unwipeable) == 'function'
end

local function measure()
  local rows = { 'arm=' .. arm }

  -- read the world back before any verdict. a probe that waits owes proof
  -- its fixture took (gotcha.a-check-that-cries-wolf-gets-silenced, q5)
  if not vim.wait(20000, ready, 50) then
    rows[#rows + 1] = 'world=absent reason=contract_never_became_ready'
    say(rows); os.exit(1)
  end
  local internal = require('neominimap.buffer.internal')
  local cached = internal.empty_buffer
  rows[#rows + 1] = 'world=present cached_buf=' .. cached

  -- the SHIPPED predicate, CALLED — never restated (m.9)
  local keep = _G.nvim_selfwatch.get_buffers_unwipeable()
  rows[#rows + 1] = 'keep_count=' .. vim.tbl_count(keep)
  rows[#rows + 1] = 'keep_holds_cached=' .. vim.inspect(keep[cached] == true)

  -- ⚠️ the BREAK arm neuters the EXCLUSION only, so the wipe still runs and
  --    the trip is otherwise identical. a wider break would redden several
  --    checks and implicate none (rule.forbid.repair-plays, exception 2,
  --    condition 3)
  --
  -- 🛑 it is passed as trip_breaker's `get_keep` ARGUMENT, and this shape was
  --    earned. a first cut assigned
  --    `_G.nvim_selfwatch.get_buffers_unwipeable = function() return {} end`
  --    and BOTH arms went green, 2026-09-07: that field is a copy of the
  --    reference, while `trip_breaker` reads a local UPVALUE. the break landed
  --    on a holder nobody reads.
  --
  --    ⇒ so a green `old` arm carried no information and the control ✔ proved
  --      none of what it claimed. m.9 — one set, two readers — committed inside
  --      the probe written to close m.9. the argument reaches the real reader.
  local get_keep = nil
  if arm == 'old' then
    get_keep = function() return {} end
    rows[#rows + 1] = 'break=exclusion_neutered'
  end

  -- open a real file so neominimap has a window to attach to, then let it
  -- build its minimaps. this is what gives the wipe a subject.
  vim.cmd('edit ' .. vim.fn.stdpath('config') .. '/init.lua')
  pcall(vim.cmd, 'Neominimap enable')
  vim.wait(3000, function() return false end)

  rows[#rows + 1] = 'bufs_before=' .. #vim.api.nvim_list_bufs()

  -- 🛑 the census the wipe itself keys on — `ft == 'neominimap'`.
  --
  --    it is here because its ABSENCE let both arms go green, 2026-09-07: the
  --    break arm neutered the exclusion and the cached buffer survived anyway,
  --    which can only mean the wipe never reached it. with only `bufs_before`
  --    to read, the rows could not say WHY — a fixture that built no minimap
  --    buffer and an exclusion that is dead code look identical.
  --
  --    ⇒ so the probe reports the wipe's own match key. a `cached_ft` that is
  --      not `neominimap`, or a `minimap_bufs=0`, names the cause on the row
  --      rather than leaving a reader to guess
  --      (gotcha.a-check-that-cries-wolf-gets-silenced, q1 — print what you
  --      observed, not only what you concluded).
  local ok_ft, cached_ft = pcall(function() return vim.bo[cached].filetype end)
  rows[#rows + 1] = 'cached_ft=' .. (ok_ft and vim.inspect(cached_ft) or 'unreadable')

  local minimap_bufs = 0
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    local ok_b, ft = pcall(function() return vim.bo[buf].filetype end)
    if ok_b and ft == 'neominimap' then minimap_bufs = minimap_bufs + 1 end
  end
  rows[#rows + 1] = 'minimap_bufs=' .. minimap_bufs

  -- 🛑 the SHIPPED trip, driven for real. this is the first arm in the repo's
  --    history to execute it (see the play header, gap 1)
  local ok_trip, trip_err = pcall(_G.nvim_selfwatch.trip_breaker, 1200, get_keep)
  rows[#rows + 1] = 'trip_ran=' .. vim.inspect(ok_trip)
  if not ok_trip then rows[#rows + 1] = 'trip_err=' .. vim.inspect(trip_err) end

  -- the two questions the contract exists to answer
  rows[#rows + 1] = 'cached_valid_after=' .. vim.inspect(vim.api.nvim_buf_is_valid(cached))

  local ok_refresh, refresh_err = pcall(vim.cmd, 'Neominimap refresh')
  rows[#rows + 1] = 'refresh_ok=' .. vim.inspect(ok_refresh)
  if not ok_refresh then
    rows[#rows + 1] = 'refresh_err=' .. vim.inspect(refresh_err):gsub('\n', ' ')
  end

  say(rows)
  os.exit(0)
end

measure()

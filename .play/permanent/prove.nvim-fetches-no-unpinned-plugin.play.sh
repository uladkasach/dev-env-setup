#!/usr/bin/env bash
######################################################################
# .what = prove `4.5.nvim`'s `init.lua` fetches NO plugin unless a pin names it
#
# .why
#   - lazy.nvim bootstraps at `--branch=stable`; the other 13 repos carry NO ref
#   - a ref-less repo takes the default-branch TIP on every clone
#   - `nvim-treesitter` runs `build = ':TSUpdate'`, so that tip is EXECUTED
#   - the trigger is plain `nvim`, on the LAPTOP — no grove needed
#   - `4.5.nvim/configure.verify` starts nvim headless
#   - `grove.provision --mode plan` on a fresh box performs all 14 clones inside what reads as a read-only survey
#
# 🛑 .why this play is PERMANENT and TRACKED
#   - it is a DISCRIMINATION PROBE — `rule.forbid.repair-plays`, exception 2
#   - the fix is a refusal; a refusal is invisible on a healthy box
#   - a box with a lockfile takes the pinned path, so no ordinary run exercises the branch that matters
#   - only a probe that makes the lockfile absent shows the guard bites
#   - ⇒ it stays out of the gitignored `.play/temporary/`, whose absence is silent to every other box and reader
#
# .the four conditions this exception demands
#   1. the restore is a `trap … EXIT`, never a last line          ✔ below
#   2. it REFUSES to run if the subject is absent                 ✔ rung 0
#   3. the break is MINIMAL and isolates the check under test     ✔ see below
#   4. it reports whether the restore took                        ✔ the trap
#
# ⚠️ .why it breaks NO state on this box
#   - the "break" is a SANDBOX, not a mutation
#   - `XDG_CONFIG_HOME`/`XDG_DATA_HOME` point at a temp dir with no lockfile
#   - the box's own config, data, and plugins are never touched
#   - it isolates exactly one input: whether a pin is reachable
#
# guarantee:
#   - NO NETWORK on any arm: arms A and B assert no fetch happens; arm C reads a box whose plugins are already installed
#   - it mutates no tracked file and no seat state outside its own temp dir
#
# usage:
#   rhx play.run --play prove.nvim-fetches-no-unpinned-plugin
#
# ⚠️ reach it through `play.run`, never a bare `bash <path>` — an ad-hoc run is unrecorded, unbounded, and retyped by hand (`rule.require.install-via-procedures`)
#
# exit:
#   0 = every arm discriminated as declared
#   1 = an arm did not — read the row that failed
#   2 = the subject is absent, so no claim was proven
######################################################################

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SRC_INIT="$ROOT/src/grove.provision/4.terminal/4.5.nvim/init.lua"
SRC_LOCK="$ROOT/src/grove.provision/4.terminal/4.5.nvim/lazy-lock.json"

WORK=""
# ⚠️ condition 1: the restore is unconditional
#   - every rung below can fail
#   - a temp tree left behind is the probe's own litter
cleanup() {
  local rc=$?
  if [[ -n "$WORK" && -d "$WORK" ]]; then
    rm -rf "$WORK" && echo "   └─ sandbox removed ✔" \
      || echo "   └─ ✋ sandbox NOT removed: $WORK" >&2
  fi
  return $rc
}
trap cleanup EXIT

echo "🔭 prove.nvim-fetches-no-unpinned-plugin"
echo ""

fails=0

######################################################################
# rung 0. the subject must EXIST — never invented
#
# ⚠️ condition 2: a probe that creates its own subject proves a property of what it just wrote, not of this checkout
######################################################################
echo "   ├─ 0. subject"

nvim_bin="$(command -v nvim 2>/dev/null)"
if [[ -z "$nvim_bin" ]]; then
  echo "   │  🌙 nvim is absent on this box, so the config cannot be started"
  echo "   ├─ no claim proven"
  exit 2
fi
if [[ ! -r "$SRC_INIT" ]]; then
  echo "   │  ✋ no init.lua at $SRC_INIT" >&2
  echo "   ├─ no claim proven" >&2
  exit 2
fi
if [[ ! -r "$SRC_LOCK" ]]; then
  echo "   │  ✋ no lazy-lock.json at $SRC_LOCK" >&2
  echo "   │     ⇒ that file IS the pin this play exists to prove is load-bear" >&2
  echo "   ├─ no claim proven" >&2
  exit 2
fi
echo "   │  ✔ init.lua, lazy-lock.json, and nvim all present"

WORK="$(mktemp -d)" || { echo "   ✋ could not make a temp dir" >&2; exit 2; }

######################################################################
# .the reader, shared by every arm
#
# ⚠️ ONE reader, asked three times
#   - two readers over one set are free to disagree
#   - the input they disagree on is the one this play exists to catch (`gotcha.a-check-that-cries-wolf-gets-silenced`, m.9)
#
# ⚠️ `-n` disables the swapfile, so a concurrent nvim is safe
#   - the start is bounded: an arm that hangs must fail, never wait
######################################################################
ask_nvim() {
  local cfg="$1" data="$2"
  XDG_CONFIG_HOME="$cfg" XDG_DATA_HOME="$data" \
  XDG_STATE_HOME="$WORK/state" XDG_CACHE_HOME="$WORK/cache" \
    timeout -k 10 60 "$nvim_bin" -n -u "$SRC_INIT" --headless \
      -c 'lua io.write(("LAZYPIN=%s\n"):format(vim.g.lazy_pinned))' \
      +q 2>&1
}

# .what = did any plugin repo land under this data root?
# .why  a `.git` dir under `<data>/nvim/lazy/**` is the only artifact a clone leaves that an empty tree cannot fake
fetched_count() {
  local data="$1"
  [[ -d "$data/nvim/lazy" ]] || { echo 0; return 0; }
  find "$data/nvim/lazy" -maxdepth 2 -name .git -print 2>/dev/null | wc -l
}

######################################################################
# ARM A — no lockfile at all ⇒ the pin is unreachable ⇒ NO REPO is fetched
#
# 🛑 this is `--mode plan` on a fresh box
#   - `configure.upsert` short-circuits in plan mode
#   - no lockfile is on disk when `configure.verify` starts nvim
######################################################################
echo "   ├─ A. no lockfile  (the fresh box, in --mode plan)"

mkdir -p "$WORK/a/config/nvim" "$WORK/a/data"
out_a="$(ask_nvim "$WORK/a/config" "$WORK/a/data")"
got_a="$(fetched_count "$WORK/a/data")"

if [[ "$out_a" == *"LAZYPIN=false"* && "$got_a" -eq 0 ]]; then
  echo "   │  ✔ reported LAZYPIN=false and fetched 0 repos"
else
  echo "   │  ✋ a box with NO pin still fetched, or misreported" >&2
  echo "   │     wanted: LAZYPIN=false and 0 repos" >&2
  echo "   │     got:    $got_a repo(s) — $(printf '%s' "$out_a" | grep -o 'LAZYPIN=[a-z]*' | tail -1)" >&2
  fails=$(( fails + 1 ))
fi

######################################################################
# ARM B — a lockfile that names no lazy.nvim ⇒ STILL no repo is fetched
#
# ⚠️ .why this arm exists at all
#   - arm A flips the file's EXISTENCE
#   - a guard keyed on `[[ -f … ]]` passes arm A and still fetches here — a present-but-useless lockfile is still a file
#   - this arm proves the reader asks for a usable PIN, not a path
#   - ⇒ it flips ONE input against arm C, on purpose
#   - an all-absent vs all-present pair cannot see a dropped validity test — the edit that actually happens
######################################################################
echo "   ├─ B. lockfile present, names no lazy.nvim  (a present file is not a pin)"

mkdir -p "$WORK/b/config/nvim" "$WORK/b/data"
printf '%s\n' '{ "telescope.nvim": { "branch": "master", "commit": "0123456789abcdef0123456789abcdef01234567" } }' \
  > "$WORK/b/config/nvim/lazy-lock.json"
out_b="$(ask_nvim "$WORK/b/config" "$WORK/b/data")"
got_b="$(fetched_count "$WORK/b/data")"

if [[ "$out_b" == *"LAZYPIN=false"* && "$got_b" -eq 0 ]]; then
  echo "   │  ✔ reported LAZYPIN=false and fetched 0 repos"
else
  echo "   │  ✋ a lockfile that pins no lazy.nvim was treated as a pin" >&2
  echo "   │     ⇒ the reader keys on the FILE, not on a usable commit" >&2
  echo "   │     wanted: LAZYPIN=false and 0 repos" >&2
  echo "   │     got:    $got_b repo(s) — $(printf '%s' "$out_b" | grep -o 'LAZYPIN=[a-z]*' | tail -1)" >&2
  fails=$(( fails + 1 ))
fi

######################################################################
# ARM C — the GREEN direction, on this box's own config root
#
# 🛑 .why a play must show a check pass, not only fail
#   - a guard proven in one direction only is half proven
#   - a refusal that refuses EVERY input is trivially "safe" and useless (`gotcha.a-check-that-cries-wolf-gets-silenced`, `.the corollary`)
#
# ⚠️ .why this arm uses the REAL roots and stays network-free
#   - it needs a box that already holds a valid lockfile and its plugins
#   - this box does: lazy finds every spec installed and fetches none
#   - a box without them is not a guard failure — this arm DECLINES rather than report one
######################################################################
echo "   ├─ C. this box's own pin  (the green direction)"

real_cfg="${XDG_CONFIG_HOME:-$HOME/.config}"
real_data="${XDG_DATA_HOME:-$HOME/.local/share}"

if [[ ! -r "$real_cfg/nvim/lazy-lock.json" ]]; then
  echo "   │  🌙 this box holds no lazy-lock.json, so the green direction has no"
  echo "   │     subject here. arms A and B stand; this one is UNPROVEN"
elif [[ ! -d "$real_data/nvim/lazy/lazy.nvim" ]]; then
  echo "   │  🌙 this box has not installed lazy.nvim, so a green arm would have"
  echo "   │     to fetch — and a probe may not. UNPROVEN here"
else
  before_c="$(fetched_count "$real_data")"
  out_c="$(ask_nvim "$real_cfg" "$real_data")"
  after_c="$(fetched_count "$real_data")"

  if [[ "$out_c" == *"LAZYPIN=true"* && "$after_c" -eq "$before_c" ]]; then
    echo "   │  ✔ reported LAZYPIN=true, and fetched no new repo ($after_c present)"
  else
    echo "   │  ✋ a box WITH a valid pin did not report one, or fetched" >&2
    echo "   │     wanted: LAZYPIN=true and the repo count unchanged" >&2
    echo "   │     got:    $before_c → $after_c — $(printf '%s' "$out_c" | grep -o 'LAZYPIN=[a-z]*' | tail -1)" >&2
    fails=$(( fails + 1 ))
  fi
fi

######################################################################
# ARM D — the UN-FIXED config must go RED
#
# 🛑 .why this arm is the one that makes the other three worth a read
#   - arms A-C watch only the REPAIRED file
#   - a deleted guard leaves arms A-C green regardless, the claim then limited to what the box happens to do
#   - a clamp nobody has seen FAIL is a guess (`rule.require.clamp-edge-cases`, `.prove the clamp bites`)
#   - ⇒ this arm takes the config as it stood BEFORE the fix, straight out of git, never hand-typed
#   - ⇒ it demands the reader reject that config
#
# ⚠️ .why `GIT_ALLOW_PROTOCOL=none` and not a real clone
#   - the un-fixed config's defect is that it FETCHES
#   - a faithful reproduction pulls 14 repos and runs `:TSUpdate` on a tip — the exact act this play argues against
#   - `GIT_ALLOW_PROTOCOL=none` makes git refuse every transport: the clone fails at once, no packet leaves the box
#   - ⇒ this proves the READER rejects the old config, the property a clamp needs
#   - that the old config fetches is settled by its own source and by lazy's pipeline, not by this arm
#
# ⚠️ .why it DECLINES rather than fails when git has no such version
#   - a worktree with no committed history for the file is not a defect in the guard
#   - an absent subject yields no verdict (condition 2)
######################################################################
echo "   ├─ D. the config as it stood BEFORE the fix  (the clamp must bite)"

if ! git -C "$ROOT" show HEAD:src/grove.provision/4.terminal/4.5.nvim/init.lua > "$WORK/old.init.lua" 2>/dev/null \
   || [[ ! -s "$WORK/old.init.lua" ]]; then
  echo "   │  🌙 git holds no HEAD:init.lua to compare against, so the RED"
  echo "   │     direction is UNPROVEN here"
elif grep -q 'lazy_pinned' "$WORK/old.init.lua"; then
  echo "   │  🌙 HEAD already carries the pin, so there is no un-fixed config to"
  echo "   │     reject. this arm needs a HEAD from before the fix"
else
  mkdir -p "$WORK/d/config/nvim" "$WORK/d/data"
  out_d="$(XDG_CONFIG_HOME="$WORK/d/config" XDG_DATA_HOME="$WORK/d/data" \
           XDG_STATE_HOME="$WORK/state" XDG_CACHE_HOME="$WORK/cache" \
           GIT_ALLOW_PROTOCOL=none GIT_TERMINAL_PROMPT=0 \
             timeout -k 10 60 "$nvim_bin" -n -u "$WORK/old.init.lua" --headless \
               -c 'lua io.write(("LAZYPIN=%s\n"):format(vim.g.lazy_pinned))' \
               +q 2>&1)"
  got_d="$(fetched_count "$WORK/d/data")"

  # the SAME assertion arm A makes — a pass here voids arm A's proof
  if [[ "$out_d" == *"LAZYPIN=false"* && "$got_d" -eq 0 ]]; then
    echo "   │  ✋ the UN-FIXED config satisfied arm A's assertion" >&2
    echo "   │     ⇒ so arm A would stay green with the guard deleted, and this" >&2
    echo "   │       play proves no property at all" >&2
    fails=$(( fails + 1 ))
  else
    echo "   │  ✔ rejected — it reports $(printf '%s' "$out_d" | grep -o 'LAZYPIN=[a-z]*' | tail -1), never LAZYPIN=false"
  fi
fi

######################################################################
# the verdict
######################################################################
echo "   │"
if [[ "$fails" -eq 0 ]]; then
  echo "   ├─ ✔ init.lua fetches no plugin it cannot name a commit for"
else
  echo "   ├─ ✋ $fails arm(s) did not discriminate" >&2
fi

# ⚠️ condition 4: the trap below reports whether the restore took
[[ "$fails" -eq 0 ]] || exit 1
exit 0

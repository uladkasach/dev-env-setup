#!/usr/bin/env bash
######################################################################
# .what = run nvim lua tests / syntax checks headlessly
#
# .why  = nvim config + plugin logic is lua; it must be testable without a
#         human at a terminal. this skill runs a lua test file via
#         `nvim --headless -l` (real nvim runtime, real vim.* api) or
#         syntax-checks a lua file via loadfile (parse, no exec).
#
#         proves nvim-side behavior in CI / agent loops without a live editor.
#
# usage:
#   nvim.test.headless.sh --check src/grove.provision/4.terminal/4.5.nvim/init.lua  # parse only (no exec)
#   nvim.test.headless.sh --run tests/foo.test.lua        # run a lua test file
#   nvim.test.headless.sh --run tests/foo.test.lua --clean # run with clean config (-u NONE)
#   nvim.test.headless.sh --lua "print(1+1)"              # run an inline lua snippet
#   nvim.test.headless.sh --probe p.lua --arm control --arm old  # drive a probe, arm by arm
#   nvim.test.headless.sh --help                          # show this usage header
#
# options:
#   --check FILE   parse a lua file via loadfile (no exec)
#   --run FILE     run a lua test file via `nvim --headless -l`
#   --lua CODE     run an inline lua snippet
#   --probe FILE   drive a probe against the REAL config, once per --arm
#   --arm NAME     an arm to drive (repeatable; default: control)
#   --config FILE  the config --probe boots (default: this repo's 4.5.nvim init.lua)
#   --out DIR      where each arm's rows land (default: a temp dir, path reported)
#   --within SECS  per-arm bound (default 90)
#   --clean        add `-u NONE` (skip user config) for --run
#   --skill NAME   absorbed + ignored — rhachet injects this pair when the
#                  skill is invoked via `rhx nvim.test.headless ...`
#   -h, --help     show this usage header
#
# a --run test file should print a clear pass marker on success and, ideally,
# `os.exit(fails > 0 and 1 or 0)` so the exit code is authoritative. this skill
# also scans output for FAIL / SYNTAX ERROR as a safety net.
#
# 🛑 .why --probe exists, and why it is NOT --run
#
#   `--run` uses `-l FILE`, which loads NO init.lua at all. so it can prove a
#   pure lua unit and can prove NO part of a plugin interaction — the plugin is
#   not there. a probe of the breaker, of neominimap's cached buffer, of any
#   contract the shipped config declares, needs the third invocation shape:
#
#       nvim --headless -u <config> -c "luafile <probe>"
#
#   that shape was typed by hand, repeatedly, against a SCRATCH copy of a probe
#   body the play already held — one probe, two copies, free to drift (m.9, the
#   exact defect the play exists to close). the hand-typed form also earned a
#   brittle exact-match permission entry that named a scratch path.
#
#   ⇒ `rule.forbid.adhoc-shell`: an absent skill is the defect to fix, never a
#     licence to go adhoc. this mode is that fix.
#
# .the skill DRIVES; the caller JUDGES
#
#   an arm's rows are handed back verbatim. this skill declares no verdict about
#   what a row SHOULD say — the play that owns the claim does that. what this
#   skill guarantees is that each arm actually RAN and actually SPOKE, so a
#   caller can never read silence as an answer (`rule.forbid.failhide`).
#
#   ⚠️ the probe is handed `PROBE_ARM` and `PROBE_OUT`. it must write its rows
#      to `PROBE_OUT` — a probe that writes a fixed `$HOME` path is a
#      `rule.forbid.fixed-paths-in-a-shared-tmp` defect and will report as mute.
#
# guarantee:
#   - exit 0 = pass
#   - exit 1 = malfunction (nvim itself crashed / non-zero exit with no fail
#              marker; an arm timed out; an arm wrote no rows at all)
#   - exit 2 = constraint (user must fix: bad args, file absent, nvim absent,
#              syntax error, test failure, lua error; an arm reported
#              `world=absent` — its own fixture did not take)
######################################################################

set -euo pipefail

# ── turtle vibes ────────────────────────────────────────────────────
say_head() { echo "🐢 $1"; echo ""; }
say_ok()   { echo "✨ $1"; }
say_bad()  { echo "⛈️  $1" >&2; }

# ⚠️ the two voices below are the CURRENT convention (✋ = constraint, the caller
#    fixes it; 💥 = malfunction, something broke). `say_bad` above predates them
#    and is left alone rather than swept, so the older modes keep their extant
#    output shape (`rule.prefer.wickup-touched-prose` — fix forward, in scope).
say_halt()  { echo "   ✋ $1" >&2; }
say_broke() { echo "   💥 $1" >&2; }

# ── parse args ──────────────────────────────────────────────────────
MODE=""
TARGET=""
CLEAN=0
INLINE=""
PROBE=""
CONFIG=""
OUTDIR=""
WITHIN=90
ARMS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skill)
      # absorb rhachet's injected `--skill <name>` pair; guard the value shift
      shift
      [[ $# -gt 0 ]] && shift
      ;;
    --check|--run|--lua|--probe|--arm|--config|--out|--within)
      # each of these needs a value arg; verify it exists before we shift 2,
      # else `shift 2` crashes with a cryptic "shift count" bash error
      if [[ $# -lt 2 ]]; then
        say_bad "$1 needs an argument"
        exit 2
      fi
      case "$1" in
        --check)  MODE="check"; TARGET="$2" ;;
        --run)    MODE="run";   TARGET="$2" ;;
        --lua)    MODE="lua";   INLINE="$2" ;;
        --probe)  MODE="probe"; PROBE="$2" ;;
        --arm)    ARMS+=("$2") ;;
        --config) CONFIG="$2" ;;
        --out)    OUTDIR="$2" ;;
        --within) WITHIN="$2" ;;
      esac
      shift 2
      ;;
    --clean) CLEAN=1; shift ;;
    -h|--help)
      grep '^#' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) say_bad "unknown arg: $1"; exit 2 ;;
  esac
done

# ── guard: nvim present ─────────────────────────────────────────────
if ! command -v nvim >/dev/null 2>&1; then
  say_bad "nvim not found on PATH"
  exit 2
fi

# ── guard: a mode was chosen ────────────────────────────────────────
if [[ -z "$MODE" ]]; then
  say_bad "no mode — use --check FILE, --run FILE, --lua 'CODE', or --probe FILE"
  exit 2
fi

# ── guard: file modes need an extant file ───────────────────────────
if [[ "$MODE" == "check" || "$MODE" == "run" ]]; then
  if [[ -z "$TARGET" ]]; then
    say_bad "$MODE needs a file path"
    exit 2
  fi
  if [[ ! -f "$TARGET" ]]; then
    say_bad "file not found: $TARGET"
    exit 2
  fi
fi

# base nvim flags: headless always; -u NONE only when --clean
nvim_base=(nvim --headless)
[[ $CLEAN -eq 1 ]] && nvim_base+=(-u NONE)

# ── mode: check (parse via loadfile, no exec) ───────────────────────
if [[ "$MODE" == "check" ]]; then
  say_head "syntax check — $TARGET"
  # pass the path via env (vim.env), NOT string interpolation — a path with a
  # single quote would otherwise break the Lua literal (injection hazard)
  LUA='local ok,err=loadfile(vim.env.NVIM_TEST_HEADLESS_TARGET); if ok then print("SYNTAX OK") else print("SYNTAX ERROR: "..vim.inspect(err)) end'
  set +e
  OUT="$(NVIM_TEST_HEADLESS_TARGET="$TARGET" "${nvim_base[@]}" -c "lua $LUA" -c "qa" 2>&1)"
  CODE=$?
  set -e
  echo "$OUT"
  echo ""
  # authoritative: nvim must exit clean (no crash) AND report SYNTAX OK.
  # a swallowed non-zero exit would hide a real nvim failure (failhide).
  if [[ $CODE -ne 0 ]]; then
    say_bad "nvim exited $CODE"
    exit 1  # malfunction: nvim itself crashed
  fi
  # ⚠️ every match in this file is `grep … >/dev/null`, never `grep -q`. `-q`
  #    exits at the first match, the `echo` subshell takes a SIGPIPE, and
  #    pipefail hands the pipeline that 141 (`gotcha.pipefail-grep-q`). the two
  #    fail-marker reads below are the dangerous polarity: a MATCH means the
  #    human's test FAILED, so a false 141 falls past the marker branch and
  #    reaches `say_ok "test passed"` — a failed test reported as a pass, which
  #    is `rule.forbid.failhide` exactly. and an nvim stack traceback is the
  #    large output that makes the SIGPIPE likely
  if echo "$OUT" | grep 'SYNTAX OK' >/dev/null; then
    say_ok "parse clean"
    exit 0
  fi
  say_bad "parse failed"
  exit 2  # constraint: the user's lua file has a syntax error to fix
fi

# ── mode: run (execute a lua test file) ─────────────────────────────
if [[ "$MODE" == "run" ]]; then
  say_head "run headless — $TARGET"
  set +e
  OUT="$("${nvim_base[@]}" -l "$TARGET" 2>&1)"
  CODE=$?
  set -e
  echo "$OUT"
  echo ""
  # a fail marker means the user's test/code failed → constraint (exit 2).
  # a bare non-zero exit with NO marker means nvim itself crashed → malfunction.
  if echo "$OUT" | grep -E 'FAIL|SYNTAX ERROR|E[0-9]+:|stack traceback' >/dev/null; then
    say_bad "fail marker in output"
    exit 2  # constraint: the user's test/lua failed
  fi
  if [[ $CODE -ne 0 ]]; then
    say_bad "test exited $CODE"
    exit 1  # malfunction: nvim exited non-zero with no fail marker
  fi
  say_ok "test passed"
  exit 0
fi

# ── mode: lua (inline snippet) ──────────────────────────────────────
if [[ "$MODE" == "lua" ]]; then
  say_head "run inline lua"
  # pass the snippet via env + load(), NOT `-c "lua $INLINE"` interpolation —
  # a snippet with a quote/semicolon would otherwise break shell quotes or
  # inject into the -c argument (injection hazard)
  LUA_RUN='assert(load(vim.env.NVIM_TEST_HEADLESS_INLINE, "=inline"))()'
  set +e
  OUT="$(NVIM_TEST_HEADLESS_INLINE="$INLINE" "${nvim_base[@]}" -c "lua $LUA_RUN" -c "qa" 2>&1)"
  CODE=$?
  set -e
  echo "$OUT"
  echo ""
  # a lua error marker means the user's snippet is broken → constraint (exit 2).
  # a bare non-zero exit with no marker means nvim itself crashed → malfunction.
  if echo "$OUT" | grep -E 'E[0-9]+:|stack traceback' >/dev/null; then
    say_bad "lua errored"
    exit 2  # constraint: the user's lua snippet has an error to fix
  fi
  if [[ $CODE -ne 0 ]]; then
    say_bad "nvim exited $CODE"
    exit 1  # malfunction: nvim exited non-zero with no lua-error marker
  fi
  say_ok "lua ran"
  exit 0
fi

# ── mode: probe (drive a probe against the REAL config, arm by arm) ──
if [[ "$MODE" == "probe" ]]; then
  # .the probe file — refuse an invented subject rather than boot nvim at one
  if [[ ! -f "$PROBE" ]]; then
    say_head "drive probe"
    say_halt "no probe at $PROBE"
    echo "      ⇒ --probe takes a lua file this skill hands PROBE_ARM + PROBE_OUT" >&2
    exit 2
  fi

  # .the config — the SHIPPED one by default, so a probe of a plugin contract
  #  measures what a human's editor actually loads. an explicit --config is for
  #  a probe aimed at some other config on purpose
  if [[ -z "$CONFIG" ]]; then
    repo_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
    if [[ -z "$repo_root" ]]; then
      say_head "drive probe"
      say_halt "no --config, and this is no git checkout so the default is unreachable"
      echo "      ⇒ pass --config <path to the init.lua the probe should boot>" >&2
      exit 2
    fi
    CONFIG="$repo_root/src/grove.provision/4.terminal/4.5.nvim/init.lua"
  fi
  if [[ ! -f "$CONFIG" ]]; then
    say_head "drive probe"
    say_halt "no config at $CONFIG"
    echo "      ⇒ the probe boots a REAL config; this skill will not invent one" >&2
    exit 2
  fi

  # .the bound must be a number — a typo here silently becomes `timeout ''`,
  #  which drops the bound entirely and lets one hung arm hold the terminal
  if [[ ! "$WITHIN" =~ ^[0-9]+$ ]]; then
    say_head "drive probe"
    say_halt "--within takes whole seconds, saw '$WITHIN'"
    exit 2
  fi

  # default arm. one arm proves the direction it drives and NO other, so a
  # single-arm run is legitimate only while a probe is under construction
  [[ ${#ARMS[@]} -eq 0 ]] && ARMS=(control)

  # ⚠️ a per-run dir, never a fixed path. two runs at once on one box would
  #    otherwise read each other's rows and report a measurement of the wrong
  #    arm (`rule.forbid.fixed-paths-in-a-shared-tmp`)
  if [[ -n "$OUTDIR" ]]; then
    mkdir -p "$OUTDIR"
  else
    OUTDIR="$(mktemp -d "${TMPDIR:-/tmp}/nvim.probe.XXXXXX")"
  fi

  say_head "drive probe — $(basename "$PROBE")"
  echo "   ├─ config: $CONFIG"
  echo "   ├─ arms:   ${ARMS[*]}"
  echo "   ├─ bound:  ${WITHIN}s per arm"
  echo "   └─ rows:   $OUTDIR"
  echo ""

  probe_failed=0
  probe_broke=0

  for arm in "${ARMS[@]}"; do
    arm_out="$OUTDIR/$arm.out"
    rm -f "$arm_out"

    # 🛑 `-u <config>` + `luafile`, never `-l`. `-l` loads NO init.lua, so every
    #    plugin the probe asks about would be absent and the probe would report
    #    a true verdict about a world nobody built
    set +e
    PROBE_ARM="$arm" PROBE_OUT="$arm_out" \
      timeout "$WITHIN" nvim --headless \
        -u "$CONFIG" \
        -c "luafile $PROBE" < /dev/null > /dev/null 2>&1
    CODE=$?
    set -e

    echo "   ├─ arm '$arm'"

    # a mute arm asked NO question. it is never a negative answer — that read is
    # the false ✔ this whole mode exists to make impossible
    if [[ ! -f "$arm_out" ]]; then
      if [[ $CODE -eq 124 ]]; then
        say_broke "arm '$arm' hit the ${WITHIN}s bound and wrote no rows"
        echo "      ⇒ raise --within, or the probe hangs on a signal that never comes" >&2
      else
        say_broke "arm '$arm' wrote no rows (nvim exited $CODE)"
        echo "      ⇒ read the probe: does it write to os.getenv('PROBE_OUT')?" >&2
        echo "        a probe that writes a fixed path reports as mute here" >&2
      fi
      probe_broke=1
      continue
    fi

    # ⚠️ `while read` alone drops a final line with no trailing newline, so the
    #    last row — often the verdict — would vanish from the report
    #    (`gotcha.while-read-drops-the-last-line`)
    while IFS= read -r row || [[ -n "$row" ]]; do
      echo "   │    $row"
    done < "$arm_out"

    # the probe's own read-back: it says its FIXTURE did not take, so its rows
    # describe a world nobody built. that is the caller's to fix, not a break
    if grep '^world=absent' "$arm_out" >/dev/null; then
      say_halt "arm '$arm' reports its fixture did not take"
      echo "      ⇒ this arm measured no world; its rows carry no verdict" >&2
      probe_failed=1
      continue
    fi

    echo "   │  ✔ arm '$arm' spoke"
  done

  echo ""

  # 🛑 the exit code says whether each arm RAN and SPOKE — never whether its
  #    rows say what the caller hoped. the caller owns that judgment
  if [[ $probe_broke -eq 1 ]]; then
    say_broke "an arm produced no rows — read the arms above"
    exit 1
  fi
  if [[ $probe_failed -eq 1 ]]; then
    say_halt "an arm measured no world — read the arms above"
    exit 2
  fi
  say_ok "every arm ran and spoke — rows under $OUTDIR"
  exit 0
fi

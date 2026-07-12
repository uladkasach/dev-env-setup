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
#   nvim.test.headless.sh --check src/init.lua            # parse only (no exec)
#   nvim.test.headless.sh --run tests/foo.test.lua        # run a lua test file
#   nvim.test.headless.sh --run tests/foo.test.lua --clean # run with clean config (-u NONE)
#   nvim.test.headless.sh --lua "print(1+1)"              # run an inline lua snippet
#   nvim.test.headless.sh --help                          # show this usage header
#
# options:
#   --check FILE   parse a lua file via loadfile (no exec)
#   --run FILE     run a lua test file via `nvim --headless -l`
#   --lua CODE     run an inline lua snippet
#   --clean        add `-u NONE` (skip user config) for --run
#   --skill NAME   absorbed + ignored — rhachet injects this pair when the
#                  skill is invoked via `rhx nvim.test.headless ...`
#   -h, --help     show this usage header
#
# a --run test file should print a clear pass marker on success and, ideally,
# `os.exit(fails > 0 and 1 or 0)` so the exit code is authoritative. this skill
# also scans output for FAIL / SYNTAX ERROR as a safety net.
#
# guarantee:
#   - exit 0 = pass
#   - exit 1 = malfunction (nvim itself crashed / non-zero exit with no fail marker)
#   - exit 2 = constraint (user must fix: bad args, file absent, nvim absent,
#              syntax error, test failure, lua error)
######################################################################

set -euo pipefail

# ── turtle vibes ────────────────────────────────────────────────────
say_head() { echo "🐢 $1"; echo ""; }
say_ok()   { echo "✨ $1"; }
say_bad()  { echo "⛈️  $1" >&2; }

# ── parse args ──────────────────────────────────────────────────────
MODE=""
TARGET=""
CLEAN=0
INLINE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skill)
      # absorb rhachet's injected `--skill <name>` pair; guard the value shift
      shift
      [[ $# -gt 0 ]] && shift
      ;;
    --check|--run|--lua)
      # each of these needs a value arg; verify it exists before we shift 2,
      # else `shift 2` crashes with a cryptic "shift count" bash error
      if [[ $# -lt 2 ]]; then
        say_bad "$1 needs an argument"
        exit 2
      fi
      case "$1" in
        --check) MODE="check"; TARGET="$2" ;;
        --run)   MODE="run";   TARGET="$2" ;;
        --lua)   MODE="lua";   INLINE="$2" ;;
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
  say_bad "no mode — use --check FILE, --run FILE, or --lua 'CODE'"
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
  if echo "$OUT" | grep -q 'SYNTAX OK'; then
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
  if echo "$OUT" | grep -Eq 'FAIL|SYNTAX ERROR|E[0-9]+:|stack traceback'; then
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
  if echo "$OUT" | grep -Eq 'E[0-9]+:|stack traceback'; then
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

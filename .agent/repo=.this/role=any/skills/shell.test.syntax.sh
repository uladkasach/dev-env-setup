#!/usr/bin/env bash
######################################################################
# .what = parse-check this repo's shell files under every shell that
#         actually consumes them
#
# .why  = these files are `sync`ed onto a live machine, and the highest-blast
#         -radius one — `bash_aliases.sh` — is read at shell startup. a parse
#         error there does not degrade a feature; it breaks the ability to open
#         a terminal at all. so the check must run BEFORE the sync, never after.
#
#         the non-obvious part is WHICH shell to parse under. `bash_aliases.sh`
#         is named for bash, but zsh sources it too:
#
#           src/zshrc.sh:119  source ~/.bash_aliases      # zsh reads it
#           src/zshrc.sh:124  export BASH_ENV=~/.bash_aliases  # bash reads it
#
#         so `bash -n` alone is a proxy: it answers "does bash parse it?" while
#         the human reads "is it safe to source?". those come apart the moment a
#         bash-only construct lands in a dual-consumed file — zsh would then
#         fail at login, with a clean bash check on record.
#         (rule.require.name-what-you-measured)
#
#         this skill names the consumer set per file and parses under each.
#
# usage:
#   shell.test.syntax.sh --all                    # every shell file in src/
#   shell.test.syntax.sh --check src/bash_aliases.sh
#   shell.test.syntax.sh --check a.sh --check b.sh # repeatable
#   shell.test.syntax.sh --check x.sh --as zsh     # force one shell
#   shell.test.syntax.sh --help
#
# options:
#   --all          check every src/*.sh and src/*.zsh
#   --check FILE   check one file (repeatable)
#   --as SHELL     force the shell (bash|zsh), rather than derive the consumers
#   --skill NAME   absorbed + ignored — rhachet injects this when invoked
#                  via `rhx shell.test.syntax ...`
#   -h, --help     show this usage header
#
# guarantee:
#   - a parse is a real `<shell> -n`, never a read of the source text
#   - a dual-consumed file is parsed under BOTH shells; one pass is not enough
#   - the report names the shells each file was parsed under, so the claim
#     "it parses" is never wider than what was measured
#   - exit 0 = every parse clean
#   - exit 1 = malfunction (a shell binary is on PATH but died oddly)
#   - exit 2 = constraint (user must fix: parse error, bad args, file absent,
#              a needed shell absent from PATH)
######################################################################

set -uo pipefail

# ── vibes ───────────────────────────────────────────────────────────
say_head() { echo "🐢 $1"; echo ""; }
say_con()  { echo "✋ $1" >&2; }   # constraint — the caller fixes it
say_mal()  { echo "💥 $1" >&2; }   # malfunction — it broke on its own

# ── the dual-consumed set ───────────────────────────────────────────
# .what = files that BOTH bash and zsh source, so both must parse them.
#
# .why  = `bash_aliases.sh` is the root: zsh sources it directly and bash
#         inherits it via BASH_ENV (both declared in src/zshrc.sh). the other
#         two are sourced BY bash_aliases, so they land in whichever shell read
#         it — which is both.
#
# .note = this list is a second copy of a truth that lives in the zsh bundle's
#         `zshrc.sh`, so it can drift from it. that is the hazard the `sync` term
#         records. verify against:
#           rhx grepsafe --pattern bash_aliases --glob zshrc.sh --path src/grove.provision
#
# 🛑 .keyed by BASENAME, never by path — and that is a repair, not a shortcut
#
# .why  = this list held full paths (`src/bash_aliases.sh`) until 2026-09-08,
#         when the bundle restructure moved all three under
#         `src/grove.provision/2.shell/2.7.aliases/`. every entry went stale in
#         one commit.
#
#         the skill did NOT fail. it reported `bash` for a file that BOTH shells
#         read — the wrong consumer set, printed with full confidence. the older
#         note here promised a drift would "surface as a consumer set that reads
#         wrong"; it did surface, and no reader was watching, because the report
#         names the shells and never the reason for them.
#
#         ⇒ that is the `proxy` shape: a PATH substituted for a CONSUMER SET,
#           with the condition (the file has not moved) unstated. a directory is
#           not a fact about who sources a file.
#
#         a basename cannot go stale in a move, which is the whole defect class
#         this repo's restructure just demonstrated (`rule.require.solve-at-cause`).
DUAL_CONSUMED=(
  "bash_aliases.sh"
  "ductwork.sh"
  "termwork.sh"
)

# .what = name the shells that consume a given file
# .why  = the consumer set, not the file extension, decides what must parse it
consumers_of() {
  local path="$1"
  local rel="${path#./}"
  local base="${rel##*/}"

  # a dual-consumed file must satisfy both parsers, wherever it lives
  local dual
  for dual in "${DUAL_CONSUMED[@]}"; do
    if [[ "$base" == "$dual" ]]; then
      echo "bash zsh"
      return
    fi
  done

  # zsh's own config, and any .zsh, is zsh-only
  case "$base" in
    *.zsh|zshrc.sh) echo "zsh"; return ;;
  esac

  # all else is a bash module, sourced or run explicitly
  echo "bash"
}

# ── parse args ──────────────────────────────────────────────────────
declare -a TARGETS=()
MODE=""
FORCE_SHELL=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skill)
      # absorb rhachet's injected `--skill <name>` pair; guard the value shift
      shift
      [[ $# -gt 0 ]] && shift
      ;;
    --all) MODE="all"; shift ;;
    --check)
      if [[ $# -lt 2 ]]; then
        say_con "--check needs a file path"
        exit 2
      fi
      TARGETS+=("$2")
      MODE="check"
      shift 2
      ;;
    --as)
      if [[ $# -lt 2 ]]; then
        say_con "--as needs a shell (bash|zsh)"
        exit 2
      fi
      case "$2" in
        bash|zsh) FORCE_SHELL="$2" ;;
        *) say_con "--as must be bash or zsh, got: $2"; exit 2 ;;
      esac
      shift 2
      ;;
    -h|--help)
      grep '^#' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) say_con "unknown arg: $1"; exit 2 ;;
  esac
done

if [[ -z "$MODE" ]]; then
  say_con "no mode — use --all, or --check FILE"
  exit 2
fi

# ── guard: run from the repo root, where src/ lives ─────────────────
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$REPO_ROOT" ]]; then
  say_con "not inside a git repo — run this from the dev-env-setup checkout"
  exit 2
fi
cd "$REPO_ROOT" || { say_mal "could not cd to repo root: $REPO_ROOT"; exit 1; }

# ── gather targets ──────────────────────────────────────────────────
if [[ "$MODE" == "all" ]]; then
  # nullglob so an absent pattern yields no literal glob string
  shopt -s nullglob
  TARGETS=(src/*.sh src/*.zsh)
  shopt -u nullglob
  if [[ ${#TARGETS[@]} -eq 0 ]]; then
    say_con "no shell files found under src/"
    exit 2
  fi
fi

say_head "lets make sure it parses"
echo "🐚 shell.test.syntax${MODE:+ --$MODE}${FORCE_SHELL:+ --as $FORCE_SHELL}"
echo "   ├─ files: ${#TARGETS[@]}"

# ── check each target under each of its consumers ───────────────────
declare -a REPORT=()
declare -a FAILS=()
CHECKS=0
MALFUNCTION=0

for target in "${TARGETS[@]}"; do
  if [[ ! -f "$target" ]]; then
    REPORT+=("✋ $target|file absent")
    FAILS+=("$target — file absent")
    continue
  fi

  if [[ -n "$FORCE_SHELL" ]]; then
    shells="$FORCE_SHELL"
  else
    shells="$(consumers_of "$target")"
  fi

  ok_shells=""
  bad=0

  for sh in $shells; do
    if ! command -v "$sh" >/dev/null 2>&1; then
      REPORT+=("✋ $target|$sh absent from PATH")
      FAILS+=("$target — $sh absent from PATH; install it or pass --as")
      bad=1
      continue
    fi

    CHECKS=$(( CHECKS + 1 ))
    ERR="$("$sh" -n "$target" 2>&1)"
    CODE=$?

    if [[ $CODE -eq 0 ]]; then
      ok_shells="${ok_shells:+$ok_shells, }$sh"
      continue
    fi

    bad=1
    # a parse error prints to stderr; a non-zero exit with EMPTY stderr means
    # the shell died for a reason that is not a parse error → malfunction.
    if [[ -z "$ERR" ]]; then
      MALFUNCTION=1
      REPORT+=("💥 $target|$sh exited $CODE, said no more")
      FAILS+=("$target — $sh exited $CODE with no message")
    else
      REPORT+=("✋ $target|$sh parse error")
      FAILS+=("$target [$sh]"$'\n'"$ERR")
    fi
  done

  [[ $bad -eq 0 ]] && REPORT+=("✔ $target|$ok_shells")
done

echo "   ├─ parses: $CHECKS"
echo "   └─ results"

# ── print the report, aligned ───────────────────────────────────────
WIDEST=0
for row in "${REPORT[@]}"; do
  name="${row%%|*}"
  [[ ${#name} -gt $WIDEST ]] && WIDEST=${#name}
done

LAST_I=$(( ${#REPORT[@]} - 1 ))
for i in "${!REPORT[@]}"; do
  row="${REPORT[$i]}"
  name="${row%%|*}"
  note="${row#*|}"
  branch="├─"
  [[ $i -eq $LAST_I ]] && branch="└─"
  printf '      %s %-*s  %s\n' "$branch" "$WIDEST" "$name" "$note"
done

echo ""

# ── verdict ─────────────────────────────────────────────────────────
if [[ ${#FAILS[@]} -eq 0 ]]; then
  echo "✨ every file parses under every shell that reads it"
  exit 0
fi

echo "🐚 what to fix"
for f in "${FAILS[@]}"; do
  echo "   │"
  printf '%s\n' "$f" | sed 's/^/   │  /'
done
echo ""

if [[ $MALFUNCTION -eq 1 ]]; then
  say_mal "a shell exited non-zero with no parse error to show"
  exit 1
fi

say_con "fix the parse errors above, THEN sync — a broken bash_aliases breaks shell startup"
exit 2

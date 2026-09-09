#!/usr/bin/env bash
######################################################################
# .what = prune abandoned test-fixture dirs from /tmp
#
# .why  = test harnesses mkdtemp a fixture dir per run and never remove
#         it. measured 2026-08-30: 12,901 of 15,385 /tmp dirs (84%) were
#         abandoned `rhachet-test-*` fixtures.
#
#         the harm is not disk — these are mostly small — it is COUNT:
#           - systemd-tmpfiles-setup walks /tmp at boot; a large /tmp
#             blocks boot for minutes on LUKS (pop-os/pop#1048)
#           - a /tmp glob now times out (ripgrep exceeded 20s)
#           - inodes are held and never returned
#
#         the extant `tmp-cleanup.timer` runs daily with `-mtime +3`, so
#         every dir younger than 3 days survives it, and the harnesses
#         recreate them faster than a daily pass removes them. this skill
#         prunes by a tighter predicate, on demand or on a timer.
#
# usage:
#   tmp.fixture.prune.sh                        # plan (default)
#   tmp.fixture.prune.sh --mode apply           # remove
#   tmp.fixture.prune.sh --min-age 60           # only older than 60m
#   tmp.fixture.prune.sh --pattern 'foo-*'      # add a fixture pattern
#
# guarantee:
#   - plan mode by default; never removes without --mode apply
#   - ONLY removes dirs whose name matches a known fixture pattern
#   - NEVER removes a dir that is the cwd of a live process
#   - NEVER removes a dir younger than --min-age (default 30m)
#   - reports each skip reason by name, so the predicate is auditable
######################################################################

set -uo pipefail

MODE="plan"
MIN_AGE_MIN=30
PATTERNS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode) MODE="${2:-}"; shift 2 ;;
    --min-age) MIN_AGE_MIN="${2:-}"; shift 2 ;;
    --pattern) PATTERNS+=("${2:-}"); shift 2 ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    # absorb harness-injected args; `rhx <skill>` prepends these
    --repo|--role|--skill) shift 2 ;;
    *) echo "✋ unknown arg: $1" >&2; exit 2 ;;
  esac
done

[[ "$MODE" == "plan" || "$MODE" == "apply" ]] \
  || { echo "✋ --mode must be plan or apply (got: $MODE)" >&2; exit 2; }
[[ "$MIN_AGE_MIN" =~ ^[0-9]+$ ]] \
  || { echo "✋ --min-age must be a whole number of minutes (got: $MIN_AGE_MIN)" >&2; exit 2; }

# the known fixture shapes. each is a harness that mkdtemps and never reaps.
# a dir must match one of these to be eligible — an unknown /tmp dir is
# never touched, so a stray user file cannot be caught by accident.
if [[ ${#PATTERNS[@]} -eq 0 ]]; then
  PATTERNS=(
    'rhachet-test-*'
    'rhachet-roles-test-*'
    'work-test-cwd-*'
    'pii-brain-live-*'
  )
fi

echo "🐢 lets clear the fixtures..."
echo ""
echo "🐚 tmp.fixture.prune --mode $MODE --min-age ${MIN_AGE_MIN}m"

# collect the cwd of every live process ONCE. a fixture dir that an active
# test still occupies must survive, or we yank the floor out from under it.
declare -A CWD_LIVE=()
for procdir in /proc/[0-9]*; do
  cwd=$(readlink "$procdir/cwd" 2>/dev/null) || continue
  [[ -n "$cwd" ]] && CWD_LIVE["$cwd"]=1
done

found_n=0
young_n=0
inuse_n=0
prunable=()

for pattern in "${PATTERNS[@]}"; do
  while IFS= read -r -d '' dir; do
    found_n=$((found_n + 1))

    # skip: a live process occupies it as cwd
    if [[ -n "${CWD_LIVE[$dir]:-}" ]]; then
      inuse_n=$((inuse_n + 1))
      continue
    fi

    # skip: younger than the age gate (a test may be mid-run)
    if [[ -n "$(find "$dir" -maxdepth 0 -mmin "-${MIN_AGE_MIN}" 2>/dev/null)" ]]; then
      young_n=$((young_n + 1))
      continue
    fi

    prunable+=("$dir")
  done < <(find /tmp -maxdepth 1 -type d -name "$pattern" -print0 2>/dev/null)
done

echo "   ├─ found (fixture dirs): $found_n"
echo "   ├─ skip (a live process cwd): $inuse_n"
echo "   ├─ skip (younger than ${MIN_AGE_MIN}m): $young_n"
echo "   ├─ prunable (fixture + idle + aged): ${#prunable[@]}"

if [[ ${#prunable[@]} -eq 0 ]]; then
  echo "   └─ action"
  echo "      ├─"
  echo "      │"
  echo "      │  no prunable fixtures — none to remove"
  echo "      │"
  echo "      └─"
  exit 0
fi

if [[ "$MODE" == "plan" ]]; then
  echo "   └─ action"
  echo "      ├─"
  echo "      │"
  echo "      │  plan only — no dir was removed"
  echo "      │"
  echo "      │  to apply:"
  echo "      │    rhx tmp.fixture.prune --mode apply"
  echo "      │"
  echo "      └─"
  exit 0
fi

removed_n=0
failed_n=0
for dir in "${prunable[@]}"; do
  # guard the path shape one final time. a prune is destructive, so the
  # predicate is re-asserted at the point of removal rather than trusted
  # from the collection loop.
  case "$dir" in
    /tmp/*) ;;
    *) continue ;;
  esac
  [[ "$dir" == "/tmp" || "$dir" == "/tmp/" ]] && continue

  if rm -rf -- "$dir" 2>/dev/null; then
    removed_n=$((removed_n + 1))
  else
    failed_n=$((failed_n + 1))
  fi
done

echo "   └─ action"
echo "      ├─"
echo "      │"
echo "      │  removed $removed_n fixture dir(s)"
[[ $failed_n -gt 0 ]] && echo "      │  could not remove $failed_n (permission or race)"
echo "      │"
echo "      └─"
echo ""
echo "🥥 re-run in plan mode to confirm they are gone"

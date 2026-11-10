#!/usr/bin/env bash
######################################################################
# .what = wait until a guard round's peer givens land for one stone,
#         or until a bound passes — then name what landed
#
# .why  = a guard round with expensive lanes (an l3 `rhx enroll`) runs for
#         many minutes, and its givens land only when each lane ends. a
#         driver that polls by hand spends turns; this waits once, bounded,
#         and reports which slugs landed at the asked iteration
#
# usage:
#   route.guard.round.await.sh --route .behavior/<route> --stone <stone> --iteration 12 --slugs 2
#   route.guard.round.await.sh ... --within 1500        # seconds, default 1200
#
# guarantee:
#   - read-only: lists files, writes naught
#   - exit 0 = the asked count of givens landed
#   - exit 2 = bad input, or the bound passed first (the landed ones are named)
######################################################################
set -euo pipefail

route=""
stone=""
iteration=""
slugs=""
within=1200
while [[ $# -gt 0 ]]; do
  case "$1" in
    --route) route="${2:-}"; shift 2 ;;
    --stone) stone="${2:-}"; shift 2 ;;
    --iteration) iteration="${2:-}"; shift 2 ;;
    --slugs) slugs="${2:-}"; shift 2 ;;
    --within) within="${2:-}"; shift 2 ;;
    # rhx passes its own dispatch flags through; they are not this skill's
    --skill|--repo|--role) shift 2 ;;
    -h|--help)
      sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) echo "✋ ConstraintError: unknown arg '$1'" >&2; exit 2 ;;
  esac
done

if [[ -z "$route" || -z "$stone" || ! "$iteration" =~ ^[0-9]+$ || ! "$slugs" =~ ^[0-9]+$ || ! "$within" =~ ^[0-9]+$ ]]; then
  echo "✋ ConstraintError: --route, --stone, --iteration <n>, --slugs <n> are required" >&2
  echo "   fix: route.guard.round.await.sh --route .behavior/<route> --stone <stone> --iteration 12 --slugs 2" >&2
  exit 2
fi
if [[ ! -d "$route/.reviews/peer" ]]; then
  echo "✋ ConstraintError: no peer review dir at '$route/.reviews/peer'" >&2
  exit 2
fi

iter="$(printf 'i%03d' "$iteration")"

# the givens at the asked iteration, by name
givens_landed() {
  local f
  for f in "$route/.reviews/peer/${stone}._.review.${iter}."*"._.given.by_peer."*.md; do
    [[ -e "$f" ]] && echo "$f"
  done
  return 0
}

begin=$SECONDS
while :; do
  mapfile -t landed < <(givens_landed)
  if (( ${#landed[@]} >= slugs )); then
    break
  fi
  if (( SECONDS - begin >= within )); then
    break
  fi
  sleep 15
done

waited=$(( SECONDS - begin ))
echo "🐢 heres the wave..."
echo ""
echo "🐚 route.guard.round.await --stone $stone --iteration $iteration"
echo "   ├─ waited: ${waited}s (bound ${within}s)"
echo "   ├─ landed: ${#landed[@]} of $slugs"
if (( ${#landed[@]} == 0 )); then
  echo "   └─ givens: (none)"
else
  echo "   └─ givens"
  for i in "${!landed[@]}"; do
    bar='├─'
    (( i == ${#landed[@]} - 1 )) && bar='└─'
    echo "      $bar ${landed[$i]}"
  done
fi

if (( ${#landed[@]} < slugs )); then
  echo "" >&2
  echo "✋ ConstraintError: the bound passed with ${#landed[@]} of $slugs givens landed" >&2
  exit 2
fi

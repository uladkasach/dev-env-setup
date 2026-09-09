#!/usr/bin/env bash
######################################################################
# .what = profile one process class: what each member costs, and
#         whether that cost grows with age
#
# .why  = a census names WHICH class holds the memory. it cannot say
#         WHY. the two candidate answers demand opposite responses:
#
#           baseline — every member costs the same from birth, so the
#                      total is a headcount problem. close some.
#           leak     — cost climbs with age, so the total is a defect.
#                      restarting is a workaround; the fix is upstream.
#
#         one number separates them: the correlation between a
#         member's age and its footprint. this reports it, alongside
#         the youngest member's cost as the floor a fresh member pays.
#
#         it also splits rss from swap per member, because a member
#         that swapped out is a member the box already gave up on.
#
# usage:
#   machine.diagnose.class.sh --of claude       # profile the claude class
#   machine.diagnose.class.sh --of node --top 20
#   machine.diagnose.class.sh --drill 4059672   # why is THIS member heavy
#
# options:
#   --of NAME    the process comm to profile (required, unless --drill)
#   --top N      how many members to list (default 12)
#   --drill PID  break one member's footprint into where it went
#   --help, -h   show usage and exit
#
# guarantee:
#   - read-only; no kill, no mutation
#   - exits 0 always (a report is not a verdict)
######################################################################
# .note = `pipefail` is deliberately absent; every listing pipeline
#         ends in a bounded cut, where an early exit is intent.
set -eu

OF=""
TOP=12
DRILL=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --of)    OF="$2"; shift 2 ;;
    --top)   TOP="$2"; shift 2 ;;
    --drill) DRILL="$2"; shift 2 ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    # absorb harness-injected args; `rhx <skill>` prepends --repo/--role/--skill
    --repo|--role|--skill) shift 2 ;;
    *) echo "✋ unknown arg: $1" >&2; exit 2 ;;
  esac
done

######################################################################
# ── mode: drill ── where ONE member's footprint went
#
# .why  = the class profile says a member is dear; it cannot say why.
#         for a session-shaped process the candidates are distinct and
#         call for different responses:
#
#           heap      — what the runtime holds live (context, buffers)
#           file map  — the binary and libs, shared with every sibling
#           transcript— what it wrote to disk, a PROXY for context size
#
#         the transcript is the useful one: it is the only durable
#         record of how much conversation a session accumulated, and
#         it is readable without attaching a debugger.
######################################################################

if [[ -n "$DRILL" ]]; then
  if [[ ! -d "/proc/$DRILL" ]]; then
    echo "✋ pid $DRILL is not alive" >&2
    echo "   list live members first:  rhx machine.diagnose.class --of claude" >&2
    exit 2
  fi

  D_COMM=$(cat "/proc/$DRILL/comm" 2>/dev/null || echo "?")
  D_CWD=$(readlink "/proc/$DRILL/cwd" 2>/dev/null || echo "?")
  D_AGE=$(ps -o etimes= -p "$DRILL" 2>/dev/null | tr -d ' ')

  # /proc/<pid>/status carries the split ps cannot report: VmSwap is the
  # part already evicted, and RssAnon vs RssFile separates private heap
  # (which only this member holds) from mapped files (shared with siblings).
  eval "$(awk '
    /^VmRSS:/    {printf "D_RSS_M=%.0f;",  $2/1024}
    /^RssAnon:/  {printf "D_ANON_M=%.0f;", $2/1024}
    /^RssFile:/  {printf "D_FILE_M=%.0f;", $2/1024}
    /^VmSwap:/   {printf "D_SWAP_M=%.0f;", $2/1024}
    /^Threads:/  {printf "D_THREADS=%d;",  $2}
  ' "/proc/$DRILL/status" 2>/dev/null)"

  # the transcript this session writes. claude stores one jsonl per
  # session under ~/.claude/projects/<slugged-cwd>/, so the dir total is
  # a proxy for how much conversation this cwd accumulated — labelled as
  # a proxy because the dir is keyed by cwd, never by pid.
  # .note = EVERY non-alphanumeric char becomes `-`, not just the slash.
  #         an earlier form replaced only `/` and so found zero files for
  #         any cwd holding a `.` or `_` — which is most worktrees. worse,
  #         it then reported "transcript is small", turning a failed
  #         lookup into a false finding. verify against a real dir name:
  #           /home/vlad/git/more/_worktrees/dev-env-setup.vlad.fix-speed
  #         → -home-vlad-git-more--worktrees-dev-env-setup-vlad-fix-speed
  D_SLUG=$(printf '%s' "$D_CWD" | sed 's|[^a-zA-Z0-9]|-|g')
  D_PROJ="$HOME/.claude/projects/$D_SLUG"
  D_TX_M=0
  D_TX_N=0
  D_TX_FOUND=0
  if [[ -d "$D_PROJ" ]]; then
    D_TX_FOUND=1
    D_TX_M=$(find "$D_PROJ" -maxdepth 1 -name '*.jsonl' -printf '%s\n' 2>/dev/null \
      | awk '{s+=$1} END {printf "%.0f", s/1048576}')
    D_TX_N=$(find "$D_PROJ" -maxdepth 1 -name '*.jsonl' 2>/dev/null | grep -c . || true)
    [[ -z "$D_TX_M" ]] && D_TX_M=0
  fi

  echo ""
  echo "🐈 heres where pid=${DRILL} put it...  (${D_COMM}, $(awk -v a="${D_AGE:-0}" 'BEGIN{printf "%.1f", a/3600}')h old)"
  echo "   │"
  echo "   ├─ 🌕 anon:   ${D_ANON_M:-?}M private heap — what THIS member holds alone"
  echo "   ├─ 🌕 file:   ${D_FILE_M:-?}M mapped files — shared with every sibling"
  echo "   ├─ 🌕 swap:   ${D_SWAP_M:-?}M evicted — held, but the box already gave up on it"
  echo "   ├─ 🌕 threads: ${D_THREADS:-?}"
  echo "   ├─ 🌕 cwd:    ${D_CWD}"
  if [[ "$D_TX_FOUND" -eq 1 ]]; then
    echo "   └─ 🌕 transcript: ${D_TX_M}M across ${D_TX_N} session file(s) on disk"
    echo "         └─ (a PROXY for context size — the dir is per-cwd, not per-pid)"
  else
    echo "   └─ 💥 transcript: dir absent — could not read it"
    echo "         └─ looked in: ${D_PROJ}"
  fi

  echo ""
  echo "🐈 heres what concerns me..."
  echo "   │"

  # anon is the only part a close reclaims outright; file pages are
  # shared, so their share of the total overstates what one exit frees.
  RECLAIM_M=$(( ${D_ANON_M:-0} + ${D_SWAP_M:-0} ))
  echo "   ├─ 🌊 a close of this pid frees ~${RECLAIM_M}M (anon + swap)"
  echo "   │  └─ 🪄 the ${D_FILE_M:-0}M of mapped files is shared; it survives the close"
  echo "   │"
  # .note = the absent-dir branch must NOT fall through to "small". a
  #         failed read is not a small reading (rule.forbid.failhide).
  if [[ "$D_TX_FOUND" -eq 0 ]]; then
    echo "   └─ 💥 could not size the transcript, so context is unproven here"
    echo "      └─ 🪄 the anon figure above still holds; treat context as unknown"
  elif [[ "${D_TX_M}" -ge 20 ]]; then
    echo "   └─ 📜 ${D_TX_M}M of transcript — a large context is the likely cost"
    echo "      └─ 🪄 /compact in that session, or close and start fresh"
  else
    echo "   └─ 🧱 transcript is small (${D_TX_M}M) — the cost is runtime baseline, not context"
    echo "      └─ 🪄 no context to compact; only a close reclaims it"
  fi
  echo ""
  exit 0
fi

if [[ -z "$OF" ]]; then
  echo "✋ --of is required" >&2
  echo "   which class to profile, e.g.:  --of claude" >&2
  echo "   see the names via:  rhx machine.usage.diagnose" >&2
  exit 2
fi

######################################################################
# gather — one row per member: pid, age, rss, swap
#
# swap comes from /proc/<pid>/status VmSwap, which ps cannot report.
# a member deep in swap is one the kernel already evicted, so it is
# the half of the cost that hurts most and shows least.
######################################################################

ROWS=$(ps -eo pid=,etimes=,rss=,comm= 2>/dev/null \
  | awk -v of="$OF" '$4 == of { print $1, $2, $3 }' \
  | while read -r pid age rss; do
      swap=$(awk '/^VmSwap:/{print $2}' "/proc/$pid/status" 2>/dev/null || echo 0)
      [[ -z "$swap" ]] && swap=0
      printf '%s\t%s\t%s\t%s\n' "$pid" "$age" "$rss" "$swap"
    done)

if [[ -z "$ROWS" ]]; then
  echo ""
  echo "🐈 no members of class '${OF}' are alive"
  echo ""
  exit 0
fi

MEMBERS=$(printf '%s\n' "$ROWS" | grep -c .)

# totals, the floor, and the age/footprint correlation, in one pass.
#
# .note = pearson r over (age, rss+swap). r near +1 means footprint
#         tracks age — the leak signature. r near 0 means age does not
#         predict cost — a flat baseline, so the total is a headcount.
# .note = the floor is the MINIMUM footprint across members, not the
#         youngest member's. an earlier form used the youngest as a
#         proxy for "what a fresh member pays" and mislabelled it
#         `floor` — on the first real run the youngest cost 1026M
#         while the true minimum was 240M, so the word promised a
#         bound it did not hold. a single member is a sample of one;
#         the minimum is the actual floor, and the median is the
#         better estimate of what a typical member costs.
eval "$(printf '%s\n' "$ROWS" | awk -F'\t' '
  {
    age[NR]=$2; foot[NR]=($3+$4)
    sum_rss+=$3; sum_swap+=$4
    if (min_foot=="" || foot[NR]<min_foot) min_foot=foot[NR]
    if (foot[NR]>max_foot) { max_foot=foot[NR]; max_foot_age=$2 }
    if (max_age=="" || $2>max_age) max_age=$2
    if (min_age=="" || $2<min_age) min_age=$2
    n++
  }
  END {
    for (i=1;i<=n;i++) { sx+=age[i]; sy+=foot[i] }
    mx=sx/n; my=sy/n
    for (i=1;i<=n;i++) { dx=age[i]-mx; dy=foot[i]-my; sxy+=dx*dy; sxx+=dx*dx; syy+=dy*dy }
    r = (sxx>0 && syy>0) ? sxy/sqrt(sxx*syy) : 0
    # median footprint, via an insertion sort over a small n
    for (i=1;i<=n;i++) s[i]=foot[i]
    for (i=2;i<=n;i++) { v=s[i]; j=i-1; while (j>0 && s[j]>v) { s[j+1]=s[j]; j-- } s[j+1]=v }
    med = (n%2) ? s[(n+1)/2] : (s[n/2]+s[n/2+1])/2
    printf "TOT_RSS_G=%.1f;",  sum_rss/1048576
    printf "TOT_SWAP_G=%.1f;", sum_swap/1048576
    printf "FLOOR_M=%.0f;",    min_foot/1024
    printf "MED_M=%.0f;",      med/1024
    printf "PEAK_M=%.0f;",     max_foot/1024
    printf "PEAK_AGE_H=%.1f;", max_foot_age/3600
    printf "MIN_AGE_H=%.1f;",  min_age/3600
    printf "MAX_AGE_H=%.1f;",  max_age/3600
    printf "CORR=%.2f;",       r
  }')"

# headcount x median is the cost that no restart removes — the
# irreducible part of the total, while every member stays alive.
MED_TOTAL_G=$(awk -v f="$MED_M" -v n="$MEMBERS" 'BEGIN{printf "%.1f", (f*n)/1024}')

######################################################################
# report
######################################################################

echo ""
echo "🐈 heres what '${OF}' costs...  (${MEMBERS} members)"
echo "   │"
echo "   ├─ 🌕 total:  ${TOT_RSS_G}G rss + ${TOT_SWAP_G}G swap"
echo "   ├─ 🌕 spread: ${FLOOR_M}M cheapest · ${MED_M}M median · ${PEAK_M}M dearest"
echo "   ├─ 🌕 ages:   ${MIN_AGE_H}h youngest · ${MAX_AGE_H}h oldest"
echo "   ├─ 🌕 fixed:  ${MED_TOTAL_G}G is median x headcount — no restart removes it"
echo "   └─ 🌕 members: age vs footprint"
# .note = sorted by FOOTPRINT, not age. the list exists to answer "which
#         one do i close first", and the answer is whichever holds most.
#         an age sort only leads when age predicts cost, which the
#         correlation below is what decides — so the list cannot assume it.
printf '%s\n' "$ROWS" \
  | awk -F'\t' '{printf "%d\t%s\t%s\t%s\t%s\n", $3+$4, $1, $2, $3, $4}' \
  | sort -t$'\t' -k1 -rn \
  | awk -F'\t' -v n="$TOP" 'NR<=n {
      printf "         %s pid=%-8s %6.1fh  %6.0fM rss  %6.0fM swap  = %.0fM\n",
             "├─", $2, $3/3600, $4/1024, $5/1024, $1/1024
    }'

echo ""
echo "🐈 heres what concerns me..."
echo "   │"

# r >= 0.5 is a real trend across a dozen members; below that, age is
# not what predicts the cost.
IS_LEAK=$(awk -v r="$CORR" 'BEGIN{print (r>=0.5) ? 1 : 0}')

if [[ "$IS_LEAK" -eq 1 ]]; then
  echo "   ├─ 🩸 footprint tracks age (r=${CORR}) — this class leaks"
  echo "   │  └─ 🪄 a restart reclaims it; the durable fix is upstream in ${OF}"
  echo "   │"
  echo "   └─ 🌊 the dearest member holds ${PEAK_M}M at ${PEAK_AGE_H}h, against a ${FLOOR_M}M floor"
  echo "      └─ 🪄 close the oldest members first — age predicts the cost here"
  echo ""
  exit 0
fi

echo "   ├─ 🧱 footprint does NOT track age (r=${CORR}) — a baseline, not a leak"
echo "   │  └─ 🪄 age does not predict cost; the total is a headcount, not a defect"
echo "   │"
echo "   ├─ 🌊 ${MEMBERS} members x ~${MED_M}M median = ${MED_TOTAL_G}G, held while they live"
echo "   │  └─ 🪄 close members to reclaim; one closure frees its own row above, no more"
echo "   │"
echo "   └─ 🕯️ the spread is ${FLOOR_M}M to ${PEAK_M}M — what a member HOLDS drives it"
echo "      └─ 🪄 close the dearest rows above, not the oldest — age is the wrong sort here"
echo ""

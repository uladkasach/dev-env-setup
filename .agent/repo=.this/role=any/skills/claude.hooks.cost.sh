#!/usr/bin/env bash
######################################################################
# .what = measure the cpu, memory, and wall time every PreToolUse hook
#         costs for one tool call, and the floor each process kind
#         pays just to start
#
# .why  = a tool call starts one process per hook whose matcher fits.
#         to know whether a single dispatcher is worth it, split each
#         hook's cpu into STARTUP (paid per process) vs WORK (its own
#         checks, paid either way). the startup column is what a
#         dispatcher deletes
#
# usage:
#   rhx claude.hooks.cost                       # Bash, 5 runs each
#   rhx claude.hooks.cost --tool Read --runs 10
#
# guarantee:
#   - reads the hooks from .claude/settings.of.repo.json (what claude runs)
#   - feeds each hook a benign sample call (Bash: `pwd`; else README.md),
#     so no hook blocks and none records a nudge
#   - per hook, medians of: cpu ms (user+sys of its whole tree), peak rss
#     MB, and wall ms — via /usr/bin/time
#   - exit 0 = measured · 1 = malfunction · 2 = bad input
######################################################################
set -uo pipefail

tool="Bash" runs=5
while [[ $# -gt 0 ]]; do
  case "$1" in
    --tool) tool="${2:-}"; shift 2 ;;
    --runs) runs="${2:-}"; shift 2 ;;
    # absorb harness-injected args; `rhx <skill>` prepends --repo/--role/--skill
    --repo|--role|--skill) shift 2 ;;
    -h|--help) sed -n '2,24p' "$0"; exit 0 ;;
    *) echo "✋ ConstraintError: unknown arg '$1'" >&2; exit 2 ;;
  esac
done
[[ "$runs" =~ ^[0-9]+$ && "$runs" -ge 1 ]] || { echo "✋ ConstraintError: --runs is a number ≥ 1" >&2; exit 2; }

settings=".claude/settings.of.repo.json"
[[ -f "$settings" ]] || { echo "💥 MalfunctionError: $settings absent; run from a repo root" >&2; exit 1; }
[[ -x /usr/bin/time ]] || { echo "💥 MalfunctionError: /usr/bin/time absent; apt install time" >&2; exit 1; }

# a benign sample input, shaped as claude sends it
case "$tool" in
  Bash) input="$(jq -nc --arg c "$PWD" '{session_id:"cost",cwd:$c,hook_event_name:"PreToolUse",tool_name:"Bash",tool_input:{command:"pwd",description:"print cwd"}}')" ;;
  *)    input="$(jq -nc --arg c "$PWD" --arg t "$tool" --arg f "$PWD/README.md" '{session_id:"cost",cwd:$c,hook_event_name:"PreToolUse",tool_name:$t,tool_input:{file_path:$f,pattern:"x",content:"x",old_string:"x",new_string:"y"}}')" ;;
esac

# every PreToolUse hook whose matcher regex fits the tool name
mapfile -t cmds < <(jq -r --arg t "$tool" '
  .hooks.PreToolUse[]? | select(.matcher as $m | $t | test("^(" + $m + ")$")) | .hooks[].command' "$settings")
[[ ${#cmds[@]} -gt 0 ]] || { echo "🌴 no PreToolUse hook fires for $tool"; exit 0; }

# .what = median of a list of integers
__median() { sort -n | awk '{ a[NR] = $1 } END { print a[int((NR + 1) / 2)] }'; }

# .what = "<cpu ms> <peak rss MB> <wall ms>" medians for one command, run as claude runs it
# .note = /usr/bin/time reports user+sys of every child it waited on, and the
#         largest rss of any one process in the tree
__measure() {
  local cmd="$1" cpus="" rsss="" walls="" i out tmp
  tmp="$(mktemp)"
  for ((i = 0; i < runs; i++)); do
    printf '%s' "$input" | /usr/bin/time -o "$tmp" -f '%U %S %M %e' sh -c "$cmd" >/dev/null 2>&1
    out="$(tail -n 1 "$tmp")"
    cpus+="$(awk '{ printf "%d", ($1 + $2) * 1000 }' <<<"$out")"$'\n'
    rsss+="$(awk '{ printf "%d", $3 / 1024 }' <<<"$out")"$'\n'
    walls+="$(awk '{ printf "%d", $4 * 1000 }' <<<"$out")"$'\n'
  done
  rm -f "$tmp"
  echo "$(printf '%s' "$cpus" | __median) $(printf '%s' "$rsss" | __median) $(printf '%s' "$walls" | __median)"
}

# .what = a short label for a hook command
__label() {
  local s="${1#bash .agent/repo=ehmpathy/role=mechanic/inits/claude.hooks/}"
  echo "${s#./node_modules/.bin/}"
}

echo "🐢 lets weigh the hooks..."
echo ""

# the floor: each process kind started with no work
read -r fb_cpu fb_mem fb_wall < <(__measure 'bash -c "cat >/dev/null"')
read -r fj_cpu fj_mem fj_wall < <(__measure 'jq -r .tool_name >/dev/null')
read -r fr_cpu fr_mem fr_wall < <(__measure './node_modules/.bin/rhx --version')

echo "🐚 the floor — one process started with no work (median of $runs)"
echo "   │           cpu     peak      wall"
printf '   ├─ %8s ms %5s MB %6s ms  sh + bash, read stdin, exit\n' "$fb_cpu" "$fb_mem" "$fb_wall"
printf '   ├─ %8s ms %5s MB %6s ms  sh + jq, parse stdin once\n' "$fj_cpu" "$fj_mem" "$fj_wall"
printf '   └─ %8s ms %5s MB %6s ms  sh + rhx boot (--version)\n' "$fr_cpu" "$fr_mem" "$fr_wall"
echo ""

echo "🐚 claude.hooks.cost --tool $tool --runs $runs"
echo "   ├─ hooks that fire per $tool call: ${#cmds[@]}"
echo "   └─ per hook"
echo "      ├─"
echo "      │       cpu     peak      wall   cpu split"
sum_cpu=0 sum_mem=0 sum_wall=0 sum_work=0
for cmd in "${cmds[@]}"; do
  read -r cpu mem wall < <(__measure "$cmd")
  floor="$fb_cpu"
  [[ "$cmd" == *rhx* || "$cmd" == *rhachet* ]] && floor="$fr_cpu"
  work=$(( cpu > floor ? cpu - floor : 0 ))
  sum_cpu=$((sum_cpu + cpu)); sum_mem=$((sum_mem + mem)); sum_wall=$((sum_wall + wall)); sum_work=$((sum_work + work))
  printf '      │  %5s ms %5s MB %6s ms   startup %4s · work %4s   %s\n' "$cpu" "$mem" "$wall" "$floor" "$work" "$(__label "$cmd")"
done
echo "      │"
printf '      │  %5s ms %5s MB %6s ms   = %s separate processes, per %s call\n' "$sum_cpu" "$sum_mem" "$sum_wall" "${#cmds[@]}" "$tool"
echo "      └─"
echo ""

# the dispatcher estimate: one rhx boot + one stdin parse + every hook's own work
disp_cpu=$((fr_cpu + fj_cpu + sum_work))
save_cpu=$((sum_cpu - disp_cpu))
pct=$(( sum_cpu > 0 ? save_cpu * 100 / sum_cpu : 0 ))
echo "🐚 one dispatcher process that fans out in-process (estimate)"
printf '   ├─ cpu   %5s ms  = one rhx boot %s + one parse %s + all rule work %s\n' "$disp_cpu" "$fr_cpu" "$fj_cpu" "$sum_work"
printf '   ├─ peak  %5s MB  = one process, vs %s MB across %s that run at once\n' "$fr_mem" "$sum_mem" "${#cmds[@]}"
printf '   └─ saves %5s ms cpu per %s call (%s%%), and ~%s MB of concurrent rss\n' "$save_cpu" "$tool" "$pct" "$((sum_mem - fr_mem))"
echo ""

# the two dispatcher shapes, measured: one boot that spawns N rhx children,
# vs one boot alone (an in-process fan-out pays one boot + the rules' work)
n="${#cmds[@]}"
fan_child="./node_modules/.bin/rhx --version >/dev/null; for i in \$(seq $n); do ./node_modules/.bin/rhx --version >/dev/null; done"
read -r fc_cpu fc_mem fc_wall < <(__measure "$fan_child")
echo "🐚 dispatcher shapes, measured (startup only, no rule work)"
echo "   │           cpu     peak      wall"
printf '   ├─ %8s ms %5s MB %6s ms  1 dispatcher that spawns %s rhx children\n' "$fc_cpu" "$fc_mem" "$fc_wall" "$n"
printf '   ├─ %8s ms %5s MB %6s ms  1 dispatcher that runs %s rules in-process\n' "$fr_cpu" "$fr_mem" "$fr_wall" "$n"
printf '   └─ %8s ms %8s %9s  today: %s separate hook processes (startup column sum)\n' "$((sum_cpu - sum_work))" "" "" "$n"
echo ""
echo "🥥 the startup column is what a dispatcher deletes; the work column it still pays"

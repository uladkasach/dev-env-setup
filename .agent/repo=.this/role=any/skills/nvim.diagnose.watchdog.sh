#!/usr/bin/env bash
######################################################################
# .what = read the nvim self-watchdog's trend log and name what grows
#
# .why  = `machine.usage.diagnose` reports THAT the watchdog tripped;
#         this reports WHY. the watchdog logs three dimensions beside
#         rss — buffer count, treesitter count, and cpu ticks — and the
#         one that moves with rss is the leak. no other instrument on
#         the box can make that split, because nvim's core is a single
#         process and `ps` sees only its total.
#
#         the split matters because the two known leak modes need
#         opposite fixes:
#           - bufs climbs with rss  -> a buffer leak; a plugin opens
#             buffers and never wipes them. the breaker's `Neominimap
#             off` + `treesitter.stop` does NOT touch it.
#           - bufs flat, rss climbs -> a leak the instruments cannot
#             see. the breaker cannot help either; the cause is upstream.
#
# usage:
#   nvim.diagnose.watchdog.sh              # trips + the live trend
#   nvim.diagnose.watchdog.sh --trips      # every trip on record
#   nvim.diagnose.watchdog.sh --marks      # marks per namespace, from a live core
#   nvim.diagnose.watchdog.sh --tail 60    # widen the trend window
#
# guarantee:
#   - read-only; no kill, no mutation, no config change
#   - reports absent-log as an absent log, never as a calm machine
######################################################################

# .note = `pipefail` is deliberately absent. the trend pipelines end in
#         `tail`/`awk`, and an early exit hands SIGPIPE to the writer;
#         under pipefail that reads as a failed pipeline and set -e
#         aborts the report.
set -eu

LOG="${HOME}/.local/state/nvim/selfwatch.log"
MODE="trend"
TAIL=40
SOCK_ARG=""

# .what = find a live nvim rpc socket
#
# .why  = the log records COUNTS; only a live core can say what the counted
#         things ARE. a buffer count of 34,354 names a leak and no culprit;
#         the buffers' own names and types name the plugin that made them.
#
# .note = an absent socket is reported as absent, never as an empty result.
#         "no socket" and "no buffers" are opposite findings.
find_sock() {
  [[ -n "$SOCK_ARG" ]] && { printf '%s' "$SOCK_ARG"; return; }
  ls -t /run/user/"$(id -u)"/nvim.*.0 2>/dev/null | awk 'NR<=1' || true
}

# .what = ask every live core, keep the first real answer
#
# .why  = the newest socket is not the most answerable. a core deep in a leak
#         is exactly the one that cannot service an rpc, so a single-socket
#         query reports "no answer" while a healthy sibling holds the same
#         evidence. one starved core must not end the hunt.
#
# .note = each attempt carries its own timeout, so a wedged core costs 10s and
#         the sweep moves on rather than blocks the whole diagnostic.
#
# .note = a socket whose pid is DEAD is skipped, and counted separately. the
#         socket name embeds the pid (`nvim.<pid>.0`) and nvim does not always
#         unlink it on exit, so the directory accumulates stale files. without
#         this check every stale socket costs a 10s timeout and then gets
#         reported as "starved or wedged" — a cause asserted from silence,
#         when the true cause is that no process is there at all.
ask_any_core() {
  local expr="$1"
  local sock pid reply
  # .note = the explicit-socket path must keep the same counters as the sweep.
  #         a first version returned early without them, so both stayed 0 and
  #         the caller took the "no socket at all" branch — reporting an absent
  #         socket for one the human had just named. a shared verdict needs
  #         shared bookkeeping on every path that reaches it.
  if [[ -n "$SOCK_ARG" ]]; then
    LIVE_SOCKS=1
    reply=$(timeout 10 nvim --server "$SOCK_ARG" --remote-expr "$expr" 2>/dev/null || true)
    if [[ -n "$reply" ]]; then
      ANSWERED_SOCK="$SOCK_ARG"
      printf '%s' "$reply"
      return
    fi
    MUTE_SOCKS=1
    return
  fi
  for sock in $(ls -t /run/user/"$(id -u)"/nvim.*.0 2>/dev/null || true); do
    pid=$(printf '%s' "$sock" | sed 's|.*/nvim\.\([0-9]*\)\.0$|\1|')
    if [[ -n "$pid" ]] && [[ ! -d "/proc/${pid}" ]]; then
      STALE_SOCKS=$(( STALE_SOCKS + 1 ))
      continue
    fi
    LIVE_SOCKS=$(( LIVE_SOCKS + 1 ))
    reply=$(timeout 10 nvim --server "$sock" --remote-expr "$expr" 2>/dev/null || true)
    if [[ -n "$reply" ]]; then
      ANSWERED_SOCK="$sock"
      printf '%s' "$reply"
      return
    fi
    MUTE_SOCKS=$(( MUTE_SOCKS + 1 ))
  done
}
ANSWERED_SOCK=""
STALE_SOCKS=0
LIVE_SOCKS=0
MUTE_SOCKS=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --trips) MODE="trips"; shift ;;
    --marks) MODE="marks"; shift ;;
    --history) MODE="history"; shift ;;
    --bufs) MODE="bufs"; shift ;;
    --sock) SOCK_ARG="${2:-}"; shift 2 ;;
    --tail)  TAIL="${2:-40}"; shift 2 ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    # absorb harness-injected args; `rhx <skill>` prepends these to every call
    --repo|--role|--skill) shift 2 ;;
    *) shift ;;
  esac
done

######################################################################
# the log must exist — an absent log is a report, not a clean bill
######################################################################

# .why = the watchdog writes a trend line only once a core crosses 800M.
#        so an absent log has two very different causes, and to report
#        either as "all clear" would be a failhide: it may mean no core
#        ever grew (good), or it may mean the watchdog is not installed
#        (bad, and invisible). the fix string names both.
if [[ ! -r "$LOG" ]]; then
  echo ""
  echo "🐈 heres the nvim watchdog..."
  echo "   │"
  echo "   └─ 💥 no log at ${LOG}"
  echo "      ├─ 🪄 either no core ever crossed 800M, or the watchdog is absent"
  echo "      └─ 🪄 confirm it is installed:  sync.devenv.nvim"
  echo ""
  exit 0
fi

LOG_M=$(( $(wc -c < "$LOG") / 1048576 ))
TRIPS_ALL=$(grep -c TRIP "$LOG" || true)
SINCE=$(date -d '24 hours ago' '+%Y-%m-%dT%H:%M:%S' 2>/dev/null || echo "0")
TRIPS_24H=$(awk -v s="$SINCE" '/TRIP/ && $1 >= s' "$LOG" | grep -c . || true)

######################################################################
# --trips: the full trip record
######################################################################

if [[ "$MODE" == "trips" ]]; then
  echo ""
  echo "🐈 every watchdog trip on record  (${TRIPS_ALL} total, ${TRIPS_24H} in 24h)"
  echo "   │"
  if [[ "$TRIPS_ALL" -eq 0 ]]; then
    echo "   └─ 🌴 no trip on record — no core has reached 1.2G"
  else
    # .note = fields are read BY NAME, never by position. the first version
    #         used $4/$5, which silently printed "rss=pid=618858" once the trip
    #         line gained fields — position is a proxy for identity, and it
    #         breaks the moment the format grows. a named read cannot.
    grep TRIP "$LOG" | tail -n 40 \
      | awk 'function field(line, key,   pat) {
               pat = key "=-?[0-9]+"
               if (match(line, pat)) return substr(line, RSTART+length(key)+1, RLENGTH-length(key)-1)
               return -1
             }
             {
               rec = field($0, "reclaimed_mb")
               printf "   ├─ %s  rss=%sM  pid=%-8s %s\n", $1, field($0, "rss_mb"), field($0, "pid"),
                 (rec >= 0 ? sprintf("reclaimed %sM", rec) : "(reclaim unmeasured)")
             }'
    echo "   └─ (each trip is a DIFFERENT pid — every core climbs, not one)"
  fi
  echo ""
  exit 0
fi

######################################################################
# --history: the shape of every climb on record, one row per session
#
# .why  = the default trend reads the last 40 lines, which is one core's last
#         moments. a leak's CAUSE is in its shape over a whole session: where
#         it started, what its buffer count did, how long the climb took. one
#         row per cwd makes the pattern legible across dozens of sessions.
#
# .note = grouped by cwd, because the question a human actually holds is
#         "which repo makes nvim explode?" — a pid answers no question after
#         the process is gone, but a cwd names a reproducible case.
######################################################################

if [[ "$MODE" == "history" ]]; then
  echo ""
  echo "🐈 heres every climb on record...  (grouped by cwd)"
  echo "   │"

  HIST=$(awk '
    function field(line, key,   pat) {
      pat = key "=-?[0-9]+"
      if (match(line, pat)) return substr(line, RSTART+length(key)+1, RLENGTH-length(key)-1)
      return -1
    }
    # .note = the +0 coercions are load-bearing. `field()` returns a STRING,
    #         and awk compares two strings lexicographically — so "999" sorts
    #         above "1004" and the report printed a peak BELOW its own floor.
    #         a comparison operator does not announce which ordering it used.
    /rss_mb=/ && /cwd=/ {
      cwd = $NF; sub(/^cwd=/, "", cwd)
      r = field($0, "rss_mb") + 0; b = field($0, "bufs") + 0
      if (!(cwd in lo) || r < lo[cwd]) lo[cwd] = r
      if (!(cwd in hi) || r > hi[cwd]) hi[cwd] = r
      if (!(cwd in bhi) || b > bhi[cwd]) bhi[cwd] = b
      n[cwd]++
    }
    END { for (k in n) printf "%d\t%d\t%d\t%d\t%s\n", hi[k], lo[k], bhi[k], n[k], k }
  ' "$LOG" | sort -rn -k1 | awk 'NR<=12')

  if [[ -z "$HIST" ]]; then
    echo "   └─ 🌴 no trend lines on record — no core has crossed the 800M warn mark"
    echo ""
    exit 0
  fi

  printf '%s\n' "$HIST" | awk -F'\t' \
    '{ n = split($5, p, "/"); short = p[n] ? p[n] : $5
       printf "   ├─ %5dM peak  %5dM floor  %6d bufs  %5d ticks  %s\n", $1, $2, $3, $4, short }'
  echo "   │"
  echo "   └─ (peak = worst rss seen · bufs = worst buffer count · ticks = samples above 800M)"

  echo ""
  echo "🐈 heres what concerns me..."
  echo "   │"
  WORST_B=$(printf '%s\n' "$HIST" | sort -rn -k3 | awk -F'\t' 'NR==1{print $3}')
  WORST_BC=$(printf '%s\n' "$HIST" | sort -rn -k3 | awk -F'\t' 'NR==1{n=split($5,p,"/"); print p[n]}')
  if [[ "${WORST_B:-0}" -gt 1000 ]]; then
    echo "   ├─ 🔥 ${WORST_B} buffers in one core (${WORST_BC}) — a buffer leak, not a workload"
    echo "   │  └─ 🪄 a human opens tens of buffers, never thousands"
    echo "   │"
    echo "   ├─ 🌊 the known cause is a minimap made for each minimap"
    echo "   │  ├─ 🪄 a minimap is a nofile scratch buffer, so it is eligible for one of its own"
    echo "   │  └─ 🪄 confirm on a live core:  rhx nvim.diagnose.watchdog --bufs"
    echo "   │"
    # .note = this clause MEASURES whether the live config carries the fix; it
    #         does not assert it. an earlier form hardcoded "the fix is in the
    #         repo, not on this box" — true when written, false the moment the
    #         sync ran, and it kept its verdict with the authority of a check it
    #         never performed. a stale fix string is the `proxy` shape: a claim
    #         substituted for a measurement (rule.require.name-what-you-measured).
    #
    # .note = a config on disk is NOT a config inside a live core. nvim reads its
    #         init.lua once, at startup, so a core older than the sync still runs
    #         the config it booted with. that is why the restart clause is part
    #         of the fix and not an afterthought — it is the same `sync` hazard
    #         one layer on: a delivered file is not yet a live behavior.
    LIVE_CFG="$HOME/.config/nvim/init.lua"
    if [[ -f "$LIVE_CFG" ]] && grep -q "'neominimap'" "$LIVE_CFG"; then
      echo "   └─ 🌊 the fix IS in the live config — so this core predates the sync"
      echo "      ├─ 🪄 nvim reads init.lua once, at startup; a core older than"
      echo "      │     the sync still carries the config it booted with"
      echo "      └─ 🪄 restart the core to pick it up; no config change is owed"
    else
      echo "   └─ 🌊 the fix is NOT in the live config at ${LIVE_CFG}"
      echo "      └─ 🪄 deliver it:  sync.devenv.nvim"
    fi
  else
    echo "   └─ 🌴 no core shows a buffer leak (worst: ${WORST_B} bufs)"
  fi
  echo ""
  exit 0
fi

######################################################################
# --bufs: what ARE the leaked buffers — the question --history cannot answer
#
# .why  = `--history` proves a buffer leak exists (34,354 buffers observed).
#         it cannot say whose, because the log holds a count and no identity.
#         this groups a LIVE core's buffers by filetype + buftype + name shape,
#         which is what actually names the plugin: a scratch buffer with no
#         name and a `nofile` buftype is a plugin artifact, and its filetype
#         is that plugin's signature.
#
# .note = grouped, never listed. a list of 34,354 rows is not a diagnosis.
######################################################################

if [[ "$MODE" == "bufs" ]]; then
  echo ""
  echo "🐈 heres what the buffers are..."
  echo "   │"

  if [[ -z "$(find_sock)" ]]; then
    echo "   └─ 💥 no nvim rpc socket found under /run/user/$(id -u)/"
    echo "      ├─ 🪄 a live core is needed; the log holds counts, never identities"
    echo "      └─ 🪄 start one with a socket:  nvim --listen /run/user/$(id -u)/nvim.diag.0"
    echo ""
    exit 0
  fi

  # group every buffer by (filetype, buftype, named-or-scratch). one pass in
  # the core, so the wire carries a summary rather than 34k rows.
  Q='luaeval("(function() local g={} for _,b in ipairs(vim.api.nvim_list_bufs()) do local ok,ft=pcall(function() return vim.bo[b].filetype end) local ok2,bt=pcall(function() return vim.bo[b].buftype end) local nm=vim.api.nvim_buf_get_name(b) local key=string.format(\"%s|%s|%s|%s\",(ok and ft~=\"\" and ft or \"-\"),(ok2 and bt~=\"\" and bt or \"file\"),(nm~=\"\" and \"named\" or \"scratch\"),(vim.api.nvim_buf_is_loaded(b) and \"loaded\" or \"listed\")) g[key]=(g[key] or 0)+1 end local out={} for k,v in pairs(g) do out[#out+1]=string.format(\"%d\\t%s\",v,k) end table.sort(out,function(a,b) return tonumber(a:match(\"^%d+\"))>tonumber(b:match(\"^%d+\")) end) return table.concat(out,\"\\n\") end)()")'

  # .note = the timeout is mandatory, not defensive. `--remote-expr` blocks
  #         until the core's event loop services it, and a core deep enough in
  #         a leak to be worth this query is exactly one that cannot answer.
  #         without the timeout the DIAGNOSTIC hangs — the tool inherits the
  #         defect it hunts, which is the watchdog's own failure mode.
  BUFS=$(ask_any_core "$Q")
  if [[ -z "$BUFS" ]]; then
    # the two causes of silence need OPPOSITE responses, so they are split
    # rather than merged into one guess
    if [[ "$LIVE_SOCKS" -eq 0 && "$STALE_SOCKS" -eq 0 ]]; then
      # zero sockets is a THIRD case, distinct from "all stale". merged into
      # the stale branch it printed "0 sockets, every pid dead" — a sentence
      # about a population that does not exist.
      echo "   └─ 💥 no nvim rpc socket present at all"
      echo "      ├─ 🪄 nvim only listens when given one; a plain \`nvim\` does not"
      echo "      └─ 🪄 open one:  nvim --listen /run/user/$(id -u)/nvim.diag.0"
    elif [[ "$LIVE_SOCKS" -eq 0 ]]; then
      echo "   └─ 💥 no LIVE core to ask — all ${STALE_SOCKS} socket(s) belong to dead pids"
      echo "      ├─ 🪄 nvim does not always unlink its socket on exit; these are leftovers"
      echo "      └─ 🪄 open an nvim, then re-run — or pass one:  --sock <path>"
    else
      echo "   └─ 💥 ${MUTE_SOCKS} live core(s) went mute for 10s each (${STALE_SOCKS} stale skipped)"
      echo "      ├─ 🪄 the silence is evidence: a core that cannot service an rpc"
      echo "      │     in 10s is starved or wedged — chase that first"
      echo "      └─ 🪄 confirm from outside:  rhx nvim.inspect.embed --all"
    fi
    echo ""
    exit 0
  fi

  TOTAL=$(printf '%s\n' "$BUFS" | awk -F'\t' '{s+=$1} END{print s+0}')
  echo "   ├─ 🌕 socket: ${ANSWERED_SOCK}"
  echo "   ├─ 🌕 total:  ${TOTAL} buffers"
  echo "   └─ 🌕 by filetype · buftype · named · loaded"
  printf '%s\n' "$BUFS" | awk -F'\t' 'NR<=14 {
      split($2, p, "|")
      printf "         ├─ %7d  %-18s %-10s %-8s %s\n", $1, p[1], p[2], p[3], p[4]
    }'

  echo ""
  echo "🐈 heres what concerns me..."
  echo "   │"
  TOP_N=$(printf '%s\n' "$BUFS" | awk -F'\t' 'NR==1{print $1}')
  TOP_K=$(printf '%s\n' "$BUFS" | awk -F'\t' 'NR==1{print $2}')
  TOP_FT=$(printf '%s\n' "$TOP_K" | cut -d'|' -f1)

  # .what = the count of plausible SOURCE buffers — the real workload
  #
  # .why  = the ratio of artifacts to sources decides which of two very
  #         different leak shapes this is, and they need opposite fixes:
  #           ~1:1 with sources -> one artifact PER source. bounded by the real
  #             workload; a plugin that maps each buffer, correctly.
  #           far above 1:1     -> the artifact is made for artifacts. an
  #             amplifier: its own output re-enters its own input.
  #
  # .note = the denominator is NOT "every other row". a first version summed
  #         all non-top rows and would have called this repo's own case 1:1
  #         (1367 vs 1347) — the wrong verdict, because 1,342 of those 1,347
  #         were untyped `nofile` scratch buffers, which are the SAME leak
  #         before its filetype was set. counting a leak's own output as
  #         workload hides the amplification perfectly.
  #
  #         a source is a buffer a human could have opened: it is `named`, or
  #         its buftype is `file`. a scratch `nofile` buffer is a plugin
  #         artifact by construction and can never be a source.
  SOURCE_N=$(printf '%s\n' "$BUFS" | awk -F'\t' '
    { split($2, p, "|")
      if (p[3] == "named" || p[2] == "file") s += $1 }
    END { print s+0 }')

  if [[ "${TOP_N:-0}" -gt 1000 ]]; then
    echo "   ├─ 🔥 ${TOP_N} buffers share one shape: ${TOP_K}"
    echo "   │  └─ 🪄 that filetype is the plugin's signature — it names the leaker"
    echo "   │"
    # .note = the ratio is MEASURED, never assumed. an earlier version asserted
    #         "a buffer per event" from the count alone — a cause inferred from
    #         a snapshot, which is exactly the proxy defect
    #         `rule.require.name-what-you-measured` forbids. the count says a
    #         leak exists; only the ratio says which kind.
    if [[ "$SOURCE_N" -le 0 ]] || [[ $(( TOP_N / SOURCE_N )) -ge 3 ]]; then
      echo "   └─ 🌊 AMPLIFIED — ${TOP_N} artifacts against ${SOURCE_N} source buffer(s)"
      echo "      ├─ 🪄 far past one artifact per source; the artifact is made FOR artifacts"
      echo "      └─ 🪄 break the loop: exclude ${TOP_FT} from itself, in its own config"
    else
      echo "   └─ 🌊 about one artifact per source (${TOP_N} against ${SOURCE_N} sources)"
      echo "      ├─ 🪄 bounded by the workload, so this tracks the source count"
      echo "      └─ 🪄 the leak is upstream: what opens ${SOURCE_N} source buffers?"
    fi
  else
    echo "   └─ 🌴 no single buffer shape dominates (top: ${TOP_N})"
  fi
  echo ""
  exit 0
fi

######################################################################
# --marks: attribute extmarks to the namespace (and so the plugin)
#
# .why  = an extmark count says a leak exists; a namespace says WHOSE. this
#         queries a LIVE core over its rpc socket, because the count per
#         namespace is far too costly to log every 30s — the walk itself is
#         the stampede hazard the cadence guard exists to avoid.
#
# .note = needs a listening socket. nvim exposes one at $NVIM inside a child
#         process, and `--listen` sets one otherwise. an absent socket is
#         reported as absent, never as zero marks.
######################################################################

if [[ "$MODE" == "marks" ]]; then
  echo ""
  echo "🐈 heres who holds the extmarks..."
  echo "   │"

  SOCK=$(ls -t /run/user/"$(id -u)"/nvim.*.0 2>/dev/null | awk 'NR<=1' || true)
  if [[ -z "$SOCK" ]]; then
    echo "   └─ 💥 no nvim rpc socket found under /run/user/$(id -u)/"
    echo "      ├─ 🪄 a live core is needed; the log alone cannot name a namespace"
    echo "      └─ 🪄 start one with a socket:  nvim --listen /run/user/$(id -u)/nvim.diag.0"
    echo ""
    exit 0
  fi

  # one expression, evaluated in the live core: marks per namespace, desc
  LUA_EXPR='luaeval("(function() local out={} for name,ns in pairs(vim.api.nvim_get_namespaces()) do local n=0 for _,b in ipairs(vim.api.nvim_list_bufs()) do if vim.api.nvim_buf_is_loaded(b) then n=n+#vim.api.nvim_buf_get_extmarks(b,ns,0,-1,{limit=20000}) end end if n>0 then out[#out+1]=string.format(\"%d\\t%s\",n,name) end end table.sort(out,function(a,b) return tonumber(a:match(\"^%d+\"))>tonumber(b:match(\"^%d+\")) end) return table.concat(out,\"\\n\") end)()")'

  # same mandatory timeout as --bufs; see the note there
  MARKS=$(timeout 10 nvim --server "$SOCK" --remote-expr "$LUA_EXPR" 2>/dev/null || true)
  if [[ -z "$MARKS" ]]; then
    echo "   └─ 💥 no answer from the core within 10s"
    echo "      ├─ 🪄 socket: ${SOCK}"
    echo "      └─ 🪄 a core that cannot service an rpc in 10s is starved or wedged"
    echo ""
    exit 0
  fi

  echo "   ├─ 🌕 socket: ${SOCK}"
  echo "   └─ 🌕 marks by namespace"
  printf '%s\n' "$MARKS" | awk -F'\t' 'NR<=12 {printf "         ├─ %-34s %7d marks\n", $2, $1}'
  echo ""
  echo "🐈 heres what concerns me..."
  echo "   │"
  TOP_N=$(printf '%s\n' "$MARKS" | awk -F'\t' 'NR==1{print $1}')
  TOP_NS=$(printf '%s\n' "$MARKS" | awk -F'\t' 'NR==1{print $2}')
  if [[ "${TOP_N:-0}" -gt 50000 ]]; then
    echo "   └─ 🔥 ${TOP_NS} holds ${TOP_N} marks — that is a leak, not a workload"
    echo "      └─ 🪄 a mark per line per refresh, with the prior batch never cleared"
  else
    echo "   └─ 🌴 no namespace holds an alarming count (top: ${TOP_NS} at ${TOP_N})"
  fi
  echo ""
  exit 0
fi

######################################################################
# the live trend — what grows, and how fast
######################################################################

# each trend line carries rss_mb, bufs, and ts. the dimension that moves
# WITH rss is the leak; the ones that stay flat are exonerated. this is
# the whole diagnostic, and it is why the watchdog logs all three.
#
# .note = lua_kb / marks / chans default to -1 when absent, NOT 0. an older log
#         predates those fields, and 0 is a legitimate value for each — so a
#         shared value space would let "field absent" pose as "measured zero"
#         and exonerate a suspect that was never examined. -1 cannot be a count.
TREND=$(tail -n "$TAIL" "$LOG" | awk '
  function field(line, key,   pat) {
    pat = key "=-?[0-9]+"
    if (match(line, pat)) return substr(line, RSTART+length(key)+1, RLENGTH-length(key)-1)
    return -1
  }
  /rss_mb=/ {
    r = field($0, "rss_mb"); b = field($0, "bufs"); t = field($0, "ts")
    l = field($0, "lua_kb"); m = field($0, "marks"); c = field($0, "chans")
    if (n == 0) { r0=r; b0=b; t0=t; l0=l; m0=m; c0=c; ts0=$1 }
    r1=r; b1=b; t1=t; l1=l; m1=m; c1=c; ts1=$1; n++
  }
  END {
    if (n < 2) { print "SHORT"; exit }
    printf "N=%d;R0=%d;R1=%d;B0=%d;B1=%d;T0=%d;T1=%d;L0=%d;L1=%d;M0=%d;M1=%d;C0=%d;C1=%d;T_FROM=%s;T_TO=%s",
      n, r0, r1, b0, b1, t0, t1, l0, l1, m0, m1, c0, c1, ts0, ts1
  }')

echo ""
echo "🐈 heres the nvim watchdog...  (log ${LOG_M}M, ${TRIPS_ALL} trips all-time, ${TRIPS_24H} in 24h)"
echo "   │"

if [[ "$TREND" == "SHORT" ]]; then
  echo "   └─ 🌴 no trend lines in the last ${TAIL} — no core is above the 800M warn mark"
  echo "      └─ 🪄 the watchdog logs only once a core crosses 800M, so quiet = calm"
  echo ""
  exit 0
fi

eval "$TREND"

D_RSS=$(( R1 - R0 ))
D_BUF=$(( B1 - B0 ))
D_TS=$(( T1 - T0 ))

# .what = the rate, derived from the WALL CLOCK, never from the tick count
#
# .why  = the first version of this multiplied the line count by 30s, on the
#         assumption that one line means one 30s tick. that assumption breaks
#         in exactly the case the report matters most: when the box is starved,
#         libuv fires the repeat timer once per MISSED interval, so dozens of
#         lines land in the SAME second. the tick-count math then divided a
#         real 17M of growth by a fictional 20 minutes and reported a calm
#         0.9M/min — a failhide, and a confident one.
#
#         the timestamps are the only truth about elapsed time. read them.
SECS=$(( $(date -d "$T_TO" +%s 2>/dev/null || echo 0) - $(date -d "$T_FROM" +%s 2>/dev/null || echo 0) ))

# .what = is this window a stampede?
#
# .why  = the test is LINES PER SECOND against the configured cadence, not
#         `SECS == 0`. the first version tested for a zero span exactly, and a
#         real 40-line burst that happened to straddle a second boundary
#         (span = 1s) slipped through it — then reported 1020M/min and an eta
#         of "-0 min". an equality test on a continuous quantity has one
#         passing value and cannot describe a range.
#
#         the timer fires every 30s, so a healthy window holds at most one line
#         per 30 seconds. anything past 1 line/sec is two orders of magnitude
#         off cadence and cannot be a genuine sample.
BURST=0
[[ "$N" -ge 10 && "$SECS" -le "$(( N / 2 ))" ]] && BURST=1

echo "   ├─ 🌕 window: ${T_FROM} → ${T_TO}  (${N} lines, ${SECS}s wall)"
if [[ "$BURST" -eq 0 && "$SECS" -gt 0 ]]; then
  RATE=$(awk -v d="$D_RSS" -v s="$SECS" 'BEGIN{printf "%.1f", d*60/s}')
  echo "   ├─ 🌕 rss:    ${R0}M → ${R1}M   (+${D_RSS}M, ${RATE}M/min)"
else
  # a window compressed far below cadence is not a fast leak — it is a stampede
  RATE=0
  echo "   ├─ 🌕 rss:    ${R0}M → ${R1}M   (+${D_RSS}M, rate unknowable)"
fi
echo "   ├─ 🌕 bufs:   ${B0} → ${B1}   (+${D_BUF})"
echo "   ├─ 🌕 ts:     ${T0} → ${T1}   (+${D_TS}  treesitter-attached buffers)"

# .note = an absent field prints as absent, never as a zero delta. a zero
#         delta reads as "measured, and it did not move" — which exonerates.
#         an unlogged dimension has not been examined at all, and the two must
#         never look alike in a report a human acts on.
if [[ "$L1" -lt 0 ]]; then
  D_LUA=0; D_MARK=0; D_CHAN=0
  echo "   └─ 💥 lua/marks/chans absent from this log — the instrument predates them"
  echo "         └─ 🪄 sync the wider instrument, then re-read:  sync.devenv.nvim"
else
  D_LUA=$(( L1 - L0 ))
  D_MARK=$(( M1 - M0 ))
  D_CHAN=$(( C1 - C0 ))
  echo "   ├─ 🌕 lua:    $(( L0 / 1024 ))M → $(( L1 / 1024 ))M   (${D_LUA}kb  lua gc heap)"
  echo "   ├─ 🌕 marks:  ${M0} → ${M1}   (+${D_MARK}  extmarks)"
  echo "   └─ 🌕 chans:  ${C0} → ${C1}   (+${D_CHAN}  jobs/rpc channels)"
fi

echo ""
echo "🐈 heres what concerns me..."
echo "   │"

# .what = many lines inside one second = the watchdog fired in a burst
#
# .why  = this is reported FIRST because it invalidates every other number
#         below it. a burst means the event loop was starved, libuv queued one
#         fire per missed interval, and the whole 40-line window is a single
#         instant — so no rate can be derived from it, and the rss delta is
#         growth the core accrued while it was NOT scheduled.
#
#         the burst is also a defect in its own right: each fire is a /proc
#         read, a buffer walk, and a log append, so the guard against a leak
#         becomes a load exactly when the box can least afford it.
if [[ "$BURST" -eq 1 ]]; then
  echo "   ├─ 🔥 STAMPEDE — ${N} watchdog fires inside ${SECS}s (cadence is 1 per 30s)"
  echo "   │  ├─ 🪄 the event loop was starved; libuv fired once per missed interval"
  echo "   │  └─ 🪄 each fire costs a /proc read + a buffer walk + a log append"
  echo "   │"
  echo "   ├─ 🌊 the repo has the guard for this; this machine does not"
  echo "   │  └─ 🪄 sync it:  sync.devenv.nvim"
  echo "   │"
  echo "   └─ 🌊 no rate is derivable from this window — ${N} lines in ${SECS}s"
  echo "      └─ 🪄 the +${D_RSS}M is growth accrued while the core was unscheduled"
  echo ""
  exit 0
fi

# no growth at all — the calm branch, stated explicitly rather than by omission
if [[ "$D_RSS" -le 0 ]]; then
  echo "   └─ 🌴 rss is flat or falls — no leak in this window"
  echo ""
  exit 0
fi

# .what = attribute the growth to the dimension that moved with it
#
# .why  = the breaker's remedy (Neominimap off + treesitter.stop) only
#         helps ONE of these modes. to report a leak without a name for
#         its mode invites the wrong fix, which is worse than no fix —
#         the human disables minimap, sees no change, distrusts the tool.
if [[ "$D_BUF" -gt 100 ]]; then
  echo "   ├─ 🔥 BUFFER leak — bufs grew by ${D_BUF} alongside ${D_RSS}M of rss"
  echo "   │  └─ 🪄 the breaker does NOT fix this; it stops minimap+treesitter, not buffers"
  echo "   │"
  echo "   └─ 🌊 find what opens them:  :ls in the affected core, look for repeats"
  echo "      └─ 🪄 a preview/diff plugin that opens a buffer per call and never wipes it"
  echo ""
  exit 0
fi

if [[ "$D_TS" -gt 5 ]]; then
  echo "   └─ 🔥 TREESITTER leak — ${D_TS} more attached buffers alongside ${D_RSS}M"
  echo "      └─ 🪄 the breaker DOES address this; it will stop them at 1.2G"
  echo ""
  exit 0
fi

# an extmark leak: marks climb while buffers stay flat. the classic invisible
# nvim leak — a plugin sets a mark per line per refresh and never clears the
# prior batch, so the count grows with no new buffer to show for it.
if [[ "$D_MARK" -gt 1000 ]]; then
  echo "   ├─ 🔥 EXTMARK leak — ${D_MARK} more marks alongside ${D_RSS}M of rss"
  echo "   │  └─ 🪄 the breaker does NOT clear marks; minimap+treesitter are the wrong lever"
  echo "   │"
  echo "   └─ 🌊 the setters here are gitsigns, neominimap, and diagnostics"
  echo "      └─ 🪄 name the namespace:  rhx nvim.diagnose.watchdog --marks"
  echo ""
  exit 0
fi

# a channel leak: a job spawned per refresh and never closed. invisible to
# bufs, invisible to lua, and it holds a pipe + its buffers per instance.
if [[ "$D_CHAN" -gt 5 ]]; then
  echo "   ├─ 🔥 CHANNEL leak — ${D_CHAN} more jobs/channels alongside ${D_RSS}M"
  echo "   │  └─ 🪄 a shell-out per refresh whose close is missed on an error path"
  echo "   │"
  echo "   └─ 🌊 gitsigns shells out to git per buffer per change — start there"
  echo ""
  exit 0
fi

# .what = the lua-vs-native split, the single most valuable discriminator
#
# .why  = rss is lua-managed memory PLUS native allocations, and the two have
#         opposite fixes. this branch is reached only when every countable
#         dimension stayed flat, so the split is the last thing that can narrow
#         the search — and it narrows it by half.
if [[ "$L1" -ge 0 ]]; then
  # lua heap grew by a meaningful share of the rss growth -> lua-side
  LUA_MB=$(( D_LUA / 1024 ))
  if [[ "$LUA_MB" -gt 0 ]] && [[ $(( LUA_MB * 2 )) -ge "$D_RSS" ]]; then
    echo "   ├─ 🔥 LUA-SIDE leak — lua heap +${LUA_MB}M of the ${D_RSS}M rss growth"
    echo "   │  └─ 🪄 a table, closure, or callback retained by a plugin — reachable, so findable"
    echo "   │"
    echo "   └─ 🌊 the breaker's collectgarbage CAN reclaim this; check reclaimed_mb on the next trip"
    echo "      └─ 🪄 if reclaimed_mb is ~0 on a lua-side leak, the memory is still referenced"
    echo ""
    exit 0
  fi

  echo "   ├─ 🔥 NATIVE leak — rss +${D_RSS}M while the lua heap moved ${D_LUA}kb"
  echo "   │  ├─ 🪄 every countable dimension is flat: bufs, ts, marks, chans"
  echo "   │  └─ 🪄 lua gc CANNOT reclaim this — the breaker's collectgarbage is ceremony here"
  echo "   │"
  echo "   ├─ 🌊 native suspects, in order of prior probability for this config:"
  echo "   │  ├─ image.nvim — kitty graphics holds decoded image data outside lua"
  echo "   │  ├─ treesitter parser state — freed on stop, but the TREES may persist"
  echo "   │  └─ a libuv handle never closed (timer, watcher, pipe)"
  echo "   │"
  echo "   └─ 🌊 confirm at the next trip: reclaimed_mb ≈ 0 proves gc has no lever"
  echo "      └─ 🪄 a restart resets it; the leak is upstream, so it will recur"
  echo ""
  exit 0
fi

# the residual case, and the most important one: rss climbs while every
# instrumented dimension stays flat. that is a leak the watchdog can
# measure but cannot attribute, and the breaker cannot stop.

# the residual case, and the most important one: rss climbs while every
# instrumented dimension stays flat. that is a leak the watchdog can
# measure but cannot attribute, and the breaker cannot stop.
# .note = an eta is printed only when the core is BELOW the trip line and the
#         rate is real. above the line the projection is negative, and "trips
#         in -0 min" is a countdown to a moment already past — it reads as
#         imminent when the truth is that the breaker has already fired.
MINS_LEFT=$(awk -v r="$R1" -v rate="$RATE" 'BEGIN{ printf "%.0f", (rate>0 && r<1200 ? (1200-r)/rate : -1) }')
echo "   ├─ 🔥 UNATTRIBUTED leak — rss +${D_RSS}M while bufs and ts stayed flat"
echo "   │  ├─ 🪄 bufs ${B0}→${B1}, ts ${T0}→${T1} — both exonerated by the log"
echo "   │  └─ 🪄 the breaker cannot stop this; it disables minimap+treesitter, neither of which grew"
echo "   │"
if [[ "$MINS_LEFT" -ge 0 ]]; then
  echo "   └─ 🌊 at ${RATE}M/min this core trips the 1.2G breaker in ~${MINS_LEFT} min"
  echo "      └─ 🪄 a restart resets it; the leak is upstream, so it will recur"
else
  echo "   └─ 🌊 this core is ALREADY past the 1.2G line (${R1}M) — the breaker has fired"
  echo "      └─ 🪄 growth continues after the trip, which is the proof the remedy missed"
fi
echo ""

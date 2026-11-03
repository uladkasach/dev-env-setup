#!/usr/bin/env bash
######################################################################
# .what = measure what each power profile buys: cpu throughput, against the fan,
#         the temperature, and the package power it costs
#
# .why  = "performance mode" is a promise of speed with a sure cost in noise and heat.
#         whether the speed is real on THIS laptop, under THIS cooler, is a measurement,
#         and a human who hears the fans deserves the number before they choose
#
# .how
#   - one fixed workload: each worker hashes 64 MB of zeros, again and again, until a
#     deadline; throughput is chunks per second. sha256 is pure cpu, with no disk and no net
#   - two shapes: ALL cores (sustained load — where heat and fans bite) and ONE core
#     (a single burst — where a boost clock shows, and what an editor or a test feels)
#   - the profiles alternate A B A B, with a cooldown between, so a box that warms or a
#     background load that drifts lands on both sides rather than on one
#   - every 2s it samples: the fastest fan, the hottest cpu sensor, and package energy
#
# ⚠️ a box under other load measures the SUM. the load at start is printed so the reader
#    can judge the noise; the A B A B order is what keeps that noise fair between profiles
#
# usage:
#   rhx machine.power.profile.bench --probe           # which sensors this box exposes
#   rhx machine.power.profile.bench                   # balanced vs performance, ~5 min
#   rhx machine.power.profile.bench --secs 30 --cool 20
#   rhx machine.power.profile.bench --profiles battery,balanced,performance
#
# guarantee:
#   - the profile in effect at the start is restored at the end, on any exit
#   - exit 0 = measured; 1 = a profile set failed; 2 = bad input or no system76-power
######################################################################
set -uo pipefail

SECS=20
COOL=15
PROFILES="balanced,performance"
PROBE=0
PASSIVE=0
CHUNK_MB=64

while [[ $# -gt 0 ]]; do
  case "$1" in
    --secs)     SECS="$2"; shift 2 ;;
    --cool)     COOL="$2"; shift 2 ;;
    --profiles) PROFILES="$2"; shift 2 ;;
    --probe)    PROBE=1; shift ;;
    --passive)  PASSIVE=1; shift ;;
    --repo|--role|--skill) shift 2 ;;
    -h|--help) awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print } !/^#/ && NR > 1 { exit }' "$0"; exit 0 ;;
    *) echo "✋ ConstraintError: unknown arg: $1" >&2; exit 2 ;;
  esac
done
[[ "$SECS" =~ ^[1-9][0-9]*$ && "$COOL" =~ ^[0-9]+$ ]] || {
  echo "✋ ConstraintError: --secs and --cool take whole seconds" >&2; exit 2; }
IFS=',' read -r -a PROFILE_LIST <<< "$PROFILES"
for p in "${PROFILE_LIST[@]}"; do
  [[ "$p" =~ ^(battery|balanced|performance)$ ]] || {
    echo "✋ ConstraintError: --profiles takes battery, balanced, performance — got '$p'" >&2; exit 2; }
done

# ---- the sensors
# .what = every fan rpm input, every cpu temperature input, and the package energy counter
FANS=(); TEMPS=(); RAPL=""
for h in /sys/class/hwmon/hwmon*; do
  name="$(cat "$h/name" 2>/dev/null)"
  for f in "$h"/fan*_input; do [[ -r "$f" ]] && FANS+=("$f"); done
  # cpu dies only: coretemp (intel), k10temp / zenpower (amd). a battery or nvme sensor
  #   runs cool and would hide the die the fans answer to
  case "$name" in
    coretemp|k10temp|zenpower) for t in "$h"/temp*_input; do [[ -r "$t" ]] && TEMPS+=("$t"); done ;;
  esac
done
[[ -r /sys/class/powercap/intel-rapl:0/energy_uj ]] && RAPL=/sys/class/powercap/intel-rapl:0/energy_uj

__fan_max()  { local m=0 v f; for f in "${FANS[@]}"; do v="$(<"$f")"; (( v > m )) && m=$v; done; echo "$m"; }
# .what = the mean clock across every core, in MHz — on a box pinned by other work, this IS
#   the box's throughput, since every core runs the whole window either way
__freq_avg() {
  local s=0 n=0 f
  for f in /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq; do
    [[ -r "$f" ]] || continue; s=$(( s + $(<"$f") )); n=$(( n + 1 ))
  done
  (( n )) && echo $(( s / n / 1000 )) || echo 0
}
__temp_max() { local m=0 v t; for t in "${TEMPS[@]}"; do v="$(<"$t")"; (( v > m )) && m=$v; done; echo $(( m / 1000 )); }

if (( PROBE )); then
  echo "🔋 machine.power.profile.bench --probe"
  echo "   ├─ fans:    ${#FANS[@]} rpm input(s)$( ((${#FANS[@]})) && echo ", fastest now $(__fan_max) rpm")"
  echo "   ├─ temps:   ${#TEMPS[@]} cpu input(s)$( ((${#TEMPS[@]})) && echo ", hottest now $(__temp_max)°C")"
  if [[ -n "$RAPL" ]]; then
    echo "   ├─ power:   package energy counter readable ✔"
  else
    echo "   ├─ power:   package energy counter absent or root-only — watts will read '?'"
  fi
  echo "   ├─ profile: $(system76-power profile 2>/dev/null | awk -F': *' 'tolower($1) ~ /power profile/ { print $2; exit }')"
  echo "   └─ load:    $(cut -d' ' -f1-3 /proc/loadavg) on $(nproc) cores"
  exit 0
fi

command -v system76-power >/dev/null 2>&1 || { echo "✋ ConstraintError: system76-power is absent" >&2; exit 2; }

PROFILE_START="$(system76-power profile 2>/dev/null | awk -F': *' 'tolower($1) ~ /power profile/ { print tolower($2); exit }')"
WORKERS_PIDS=()
__restore() {
  local pid; for pid in "${WORKERS_PIDS[@]}"; do kill "$pid" 2>/dev/null; done
  [[ -n "$PROFILE_START" ]] && system76-power profile "$PROFILE_START" >/dev/null 2>&1
}
trap __restore EXIT
trap 'exit 130' INT TERM

# .what = one worker: hash fixed chunks until the deadline, print the count
__worker() {
  local end=$(( $(date +%s) + SECS )) n=0
  while (( $(date +%s) < end )); do
    head -c $(( CHUNK_MB * 1024 * 1024 )) /dev/zero | sha256sum >/dev/null
    n=$(( n + 1 ))
  done
  echo "$n"
}

# .what = one measured run: N workers under one profile; prints "chunks/s fan_avg temp_max watts"
__run() {
  local profile="$1" workers="$2" out i f
  system76-power profile "$profile" >/dev/null 2>&1 || { echo "💥 MalfunctionError: could not set $profile" >&2; return 1; }
  sleep 3   # the governor and fan curve take a moment to land

  out="$(mktemp -d)"
  WORKERS_PIDS=()
  for (( i = 0; i < workers; i++ )); do __worker > "$out/w$i" & WORKERS_PIDS+=($!); done

  local e0 e1 t0 t1 fan_sum=0 n=0 tmax=0 v
  t0="$(date +%s.%N)"; e0="$([[ -n "$RAPL" ]] && cat "$RAPL" 2>/dev/null)"
  while kill -0 "${WORKERS_PIDS[0]}" 2>/dev/null; do
    sleep 2
    fan_sum=$(( fan_sum + $(__fan_max) )); n=$(( n + 1 ))
    v="$(__temp_max)"; (( v > tmax )) && tmax=$v
  done
  wait "${WORKERS_PIDS[@]}" 2>/dev/null
  t1="$(date +%s.%N)"; e1="$([[ -n "$RAPL" ]] && cat "$RAPL" 2>/dev/null)"
  WORKERS_PIDS=()

  local chunks=0; for f in "$out"/w*; do chunks=$(( chunks + $(<"$f") )); done
  rm -rf "$out"
  local watts="?"
  [[ -n "$e0" && -n "$e1" ]] && (( e1 > e0 )) && watts="$(awk -v a="$e0" -v b="$e1" -v s="$t0" -v t="$t1" 'BEGIN { printf "%.0f", (b - a) / 1e6 / (t - s) }')"
  awk -v c="$chunks" -v s="$t0" -v t="$t1" -v fan="$(( n ? fan_sum / n : 0 ))" -v temp="$tmax" -v w="$watts" \
    'BEGIN { printf "%.2f %d %d %s\n", c / (t - s), fan, temp, w }'
}

CORES="$(nproc)"

# ---- --passive: add NO load; switch the profile under whatever the box already runs, and
#   read the clock it holds. the right measure for a box already pinned by other work —
#   a benchmark there competes with that work and measures only its own share
if (( PASSIVE )); then
  echo "🔋 machine.power.profile.bench --passive  (${SECS}s per profile, A B A B)"
  echo "   ├─ load at start: $(cut -d' ' -f1-3 /proc/loadavg) on $CORES cores"
  echo "   ├─ profile at start: ${PROFILE_START:-?} (restored at the end)"
  declare -A P_FREQ P_FAN P_TEMP P_N
  for round in 1 2; do
    for p in "${PROFILE_LIST[@]}"; do
      system76-power profile "$p" >/dev/null 2>&1 || { echo "💥 MalfunctionError: could not set $p" >&2; exit 1; }
      sleep 8   # the fan curve lags the clock; let both land before the window opens
      fs=0; ns=0; fan_s=0; tmax=0; end=$(( $(date +%s) + SECS ))
      while (( $(date +%s) < end )); do
        fs=$(( fs + $(__freq_avg) )); fan_s=$(( fan_s + $(__fan_max) )); ns=$(( ns + 1 ))
        v="$(__temp_max)"; (( v > tmax )) && tmax=$v
        sleep 2
      done
      printf '   │  round %d  %-11s  clock %5d MHz  fan %5d rpm  cpu peak %3d°C  load %s\n' \
        "$round" "$p" $(( fs / ns )) $(( fan_s / ns )) "$tmax" "$(cut -d' ' -f1 /proc/loadavg)"
      P_FREQ[$p]=$(( ${P_FREQ[$p]:-0} + fs / ns )); P_FAN[$p]=$(( ${P_FAN[$p]:-0} + fan_s / ns ))
      (( tmax > ${P_TEMP[$p]:-0} )) && P_TEMP[$p]=$tmax
      P_N[$p]=$(( ${P_N[$p]:-0} + 1 ))
    done
  done
  echo "   └─ summary  (mean of 2 rounds; clock vs the first profile)"
  b=$(( P_FREQ[${PROFILE_LIST[0]}] / P_N[${PROFILE_LIST[0]}] ))
  for p in "${PROFILE_LIST[@]}"; do
    f=$(( P_FREQ[$p] / P_N[$p] ))
    awk -v p="$p" -v f="$f" -v b="$b" -v fan="$(( P_FAN[$p] / P_N[$p] ))" -v t="${P_TEMP[$p]}" \
      'BEGIN { printf "         %-11s  clock %5d MHz (%+5.1f%%)  fan %5d rpm  cpu peak %3d°C\n", p, f, (b ? 100 * (f - b) / b : 0), fan, t }'
  done
  exit 0
fi

echo "🔋 machine.power.profile.bench  (${SECS}s per run, ${COOL}s cooldown, ${CHUNK_MB} MB chunks)"
echo "   ├─ load at start: $(cut -d' ' -f1-3 /proc/loadavg) on $CORES cores — other load is measured too"
echo "   ├─ profile at start: ${PROFILE_START:-?} (restored at the end)"

declare -A SUM_TP SUM_FAN MAX_TEMP SUM_W CNT
for shape in all one; do
  workers=$CORES; [[ "$shape" == one ]] && workers=1
  echo "   ├─ $shape core(s):"
  for round in 1 2; do
    for p in "${PROFILE_LIST[@]}"; do
      read -r tp fan temp w <<< "$(__run "$p" "$workers")" || exit 1
      [[ -n "$tp" ]] || exit 1
      printf '   │     round %d  %-11s  %7.2f chunks/s  fan %5d rpm  cpu %3d°C  %s W\n' "$round" "$p" "$tp" "$fan" "$temp" "$w"
      k="$shape.$p"
      SUM_TP[$k]="$(awk -v a="${SUM_TP[$k]:-0}" -v b="$tp" 'BEGIN { print a + b }')"
      SUM_FAN[$k]=$(( ${SUM_FAN[$k]:-0} + fan ))
      (( temp > ${MAX_TEMP[$k]:-0} )) && MAX_TEMP[$k]=$temp
      [[ "$w" != "?" ]] && SUM_W[$k]=$(( ${SUM_W[$k]:-0} + w ))
      CNT[$k]=$(( ${CNT[$k]:-0} + 1 ))
      sleep "$COOL"
    done
  done
done

echo "   └─ summary  (mean of 2 rounds; throughput vs the first profile)"
for shape in all one; do
  base="${SUM_TP[$shape.${PROFILE_LIST[0]}]}"
  for p in "${PROFILE_LIST[@]}"; do
    k="$shape.$p"; c="${CNT[$k]}"
    awk -v sh="$shape" -v p="$p" -v tp="${SUM_TP[$k]}" -v b="$base" -v c="$c" \
        -v fan="$(( SUM_FAN[$k] / c ))" -v temp="${MAX_TEMP[$k]}" -v w="${SUM_W[$k]:-}" \
      'BEGIN { m = tp / c; d = (b > 0) ? 100 * (tp - b) / b : 0
               printf "         %-3s %-11s  %7.2f chunks/s (%+5.1f%%)  fan %5d rpm  cpu peak %3d°C  %s W\n",
                 sh, p, m, d, fan, temp, (w == "" ? "?" : sprintf("%.0f", w / c)) }'
  done
done

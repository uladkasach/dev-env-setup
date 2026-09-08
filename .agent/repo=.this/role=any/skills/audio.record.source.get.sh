#!/usr/bin/env bash
######################################################################
# .what = read the DECLARED state of the box's capture sources
#
# .why  = when `audio.record.probe` refuses and a human disagrees with it,
#   this is the skill that settles the argument. it prints every fact the
#   probe keys on — which source is default, whether it is a monitor, its
#   mute flag, its volume, its state — so a refusal can be checked rather
#   than merely believed
#
# 🛑 .the split from `audio.record.probe`, and why it is load-bear
#   this reads the DECLARED state: what the box SAYS about a source. the
#   probe measures the LIVE signal: what the mic actually returns. they are
#   different questions and they can disagree —
#     · declared healthy + live silent = a hardware mute, a dead jack, or an
#       app that holds the device
#     · declared muted + live sound    = the declared state moved under you
#   ⇒ so read BOTH before you conclude. one alone names half a fault
#
# ⚠️ .why a SKILL and not a handful of pactl calls
#   `rule.forbid.adhoc-shell`. the four reads below were typed raw once, to
#   answer "the probe says muted and my mic is not" — and a raw answer helps
#   exactly one human, once. the same question recurs every time the probe
#   refuses, which is precisely when a human is least inclined to trust it
#
# usage:
#   rhx audio.record.source.get              # the default source, in full
#   rhx audio.record.source.get --all        # every source, monitors too
#   rhx audio.record.source.get --source <name>
#
# guarantee:
#   - READ-ONLY. it changes no source, no volume, no mute state
#   - exit 0 = a real input is declared healthy · exit 2 = it is not
######################################################################

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/audio.record.operations.sh"

__audio_source_help() {
  cat <<'HELP'
🎙️ audio.record.source.get — read what the box DECLARES about its mics

  usage:
    rhx audio.record.source.get [--source <name>] [--all]

  options:
    --source   read one named source   (default: the box's default source)
    --all      read every source, monitors included

  .why  when the probe refuses and you disagree with it, this prints every
        fact the probe keys on — so you can check the refusal, not just
        believe it.

  ⚠️ this reads the DECLARED state. `audio.record.probe` measures the LIVE
     signal. they answer different questions and can disagree — read both.

  example:
    rhx audio.record.source.get --all

  exit 0 = a real input is declared healthy · exit 2 = it is not
HELP
}

# .note = `__audio_source_mute_word` and `__audio_source_volume_pct` live in
#         audio.record.operations.sh — the PROBE reads the same two, and two
#         copies is two places for a fix to miss one

######################################################################
# .what = the runtime state of a source — RUNNING, IDLE, SUSPENDED
# .why  = SUSPENDED is normal for an unused mic and alarms humans who read
#         it as broken, so it is reported with that note beside it
######################################################################
__audio_source_state() {
  pactl list short sources 2>/dev/null \
    | awk -v n="$1" '$2 == n { print $NF }'
}

######################################################################
# .what = the sample format a source declares
######################################################################
__audio_source_format() {
  pactl list short sources 2>/dev/null \
    | awk -v n="$1" '$2 == n { for (i = 3; i < NF; i++) printf "%s ", $i }' \
    | sed 's/^PipeWire *//; s/ *$//'
}

######################################################################
# .what = render one source, every fact the probe keys on
######################################################################
__audio_source_render() {
  local name="$1" default="$2" prefix="$3"
  local mute pct base state fmt kind

  if __audio_source_is_monitor "$name"; then
    kind="🌙 MONITOR — the loopback of an OUTPUT, never the room"
  else
    kind="✔ a real input"
  fi

  mute="$(__audio_source_mute_word "$name")"
  pct="$(__audio_source_volume_pct "$name")"
  state="$(__audio_source_state "$name")"
  fmt="$(__audio_source_format "$name")"

  echo "$prefix$name"
  echo "   │  ├─ kind:    $kind"
  echo "   │  ├─ default: $([[ "$name" == "$default" ]] && echo 'yes ⭐' || echo 'no')"

  case "$mute" in
    no)  echo "   │  ├─ mute:    no ✔" ;;
    yes) echo "   │  ├─ mute:    YES ✋ — a take would hold bit-exact silence" ;;
    *)   echo "   │  ├─ mute:    ? 🌙 — pactl gave no answer for this source" ;;
  esac

  if [[ "$pct" == "?" ]]; then
    echo "   │  ├─ volume:  ? 🌙"
  elif [[ "$pct" -eq 0 ]]; then
    echo "   │  ├─ volume:  0% ✋ — a take would hold bit-exact silence"
  else
    echo "   │  ├─ volume:  ${pct}%"
  fi

  ####################################################################
  # the base is the fact that says whether a gain raise BUYS a better take.
  # at or under it a raise moves the ADC's own gain; over it, pulse just
  # multiplies samples — louder, identical SNR, and it can clip
  ####################################################################
  base="$(__audio_source_base_pct "$name")"
  if [[ "$base" == "?" || "$pct" == "?" ]]; then
    echo "   │  ├─ base:    ${base} 🌙 — so gain headroom is unknown"
  elif [[ "$pct" -lt "$base" ]]; then
    echo "   │  ├─ base:    ${base}% — ✔ ${pct}% is UNDER it, so a raise adds real analog gain"
  elif [[ "$pct" -eq "$base" ]]; then
    echo "   │  ├─ base:    ${base}% — ⚠️ at unity. a raise past here is a DIGITAL multiply:"
    echo "   │  │           louder, same signal-to-noise, and it can clip a take that"
    echo "   │  │           cannot be re-made. move the mic closer instead"
  else
    echo "   │  ├─ base:    ${base}% — ⚠️ ${pct}% is ABOVE it, so $(( pct - base ))% of this is"
    echo "   │  │           a digital multiply. it raises noise with signal, and clips"
  fi

  if [[ "$state" == "SUSPENDED" ]]; then
    echo "   │  ├─ state:   SUSPENDED 🌙 — normal for a source nobody reads yet"
  else
    echo "   │  ├─ state:   ${state:-?}"
  fi
  echo "   │  └─ format:  ${fmt:-?}"
}

main() {
  __audio_skill_args "$@"
  set -- "${AUDIO_SKILL_ARGS[@]+"${AUDIO_SKILL_ARGS[@]}"}"

  local source="" all=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --source)  source="${2:-}"; shift 2 ;;
      --all)     all=1; shift ;;
      --help|-h) __audio_source_help; return 0 ;;
      *)
        echo "✋ unknown arg: $1" >&2
        echo "   fix: rhx audio.record.source.get --help" >&2
        return 2
        ;;
    esac
  done

  if ! command -v pactl >/dev/null 2>&1; then
    echo "✋ pactl is absent, so no source state can be read" >&2
    echo "   ⇒ it is owned by the audio bundle, so the fix is a provision" >&2
    echo "   fix: rhx grove.provision --what 1.9.audio --mode apply" >&2
    return 2
  fi

  local default
  default="$(__audio_source_default)"

  echo ""
  echo "🎙️ audio.record.source.get"
  echo "   ├─ default: ${default:-🌙 the box declares none}"

  ####################################################################
  # 1. name the sources to read
  ####################################################################
  local names=()
  if [[ -n "$source" ]]; then
    names+=("$source")
  elif [[ "$all" -eq 1 ]]; then
    local n
    while IFS= read -r n; do
      [[ -n "$n" ]] && names+=("$n")
    done < <(pactl list short sources 2>/dev/null | awk '{ print $2 }')
  else
    if [[ -z "$default" ]]; then
      echo "   └─ ✋ the box declares no default source" >&2
      echo "      fix: read them all —" >&2
      echo "        rhx audio.record.source.get --all" >&2
      return 2
    fi
    names+=("$default")
  fi

  if [[ "${#names[@]}" -eq 0 ]]; then
    echo "   └─ ✋ this box declares no capture source at all" >&2
    echo "      fix: plug a mic in, then re-read" >&2
    return 2
  fi

  ####################################################################
  # 2. render each, and judge whether ONE real input is healthy
  ####################################################################
  local healthy=0 name
  for name in "${names[@]}"; do
    echo "   │"
    __audio_source_render "$name" "$default" "   ├─ "

    if ! __audio_source_is_monitor "$name" \
      && [[ "$(__audio_source_mute_word "$name")" == "no" ]] \
      && [[ "$(__audio_source_volume_pct "$name")" != "0" ]]; then
      healthy=$(( healthy + 1 ))
    fi
  done

  echo "   │"
  if [[ "$healthy" -eq 0 ]]; then
    echo "   └─ ✋ no real input is declared healthy here"
    echo "      ⇒ the DECLARED state alone cannot prove a mic hears sound."
    echo "        measure the live signal too: rhx audio.record.probe --play"
    return 2
  fi

  echo "   └─ ✔ $healthy real input(s) declared healthy"
  echo ""
  echo "   ⚠️ declared healthy is NOT the same as heard. a hardware mute, a"
  echo "      dead jack, or an app that holds the device all read healthy here."
  echo "      measure it: rhx audio.record.probe --play"
  return 0
}

main "$@"

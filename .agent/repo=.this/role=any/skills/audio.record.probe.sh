#!/usr/bin/env bash
######################################################################
# .what = prove a mic will actually capture sound, BEFORE a take starts
#
# 🛑 .why this skill exists at all — the failure it catches is SILENT
#   a crash is the loud failure, and it is the cheap one: a wav is a header
#   plus appended samples, so a killed take keeps every flushed second and the
#   only damage is two size fields a repair recomputes.
#
#   the expensive failure makes no sound and raises no error. the recorder runs
#   90 minutes, exits clean, writes a large file — and the file holds bit-exact
#   silence, because the source was a monitor, or muted, or a mic that was
#   unplugged an hour ago. every layer reports success. you find out after the
#   conversation is over and cannot be repeated.
#
#   ⇒ that is `rule.forbid.failhide` at its purest, and it is why
#     `audio.record.start` runs this probe unconditionally rather than on a flag
#
# ⚠️ .the discriminator — bit-exact zero, never a threshold
#   a LIVE mic in a real room always returns a noise floor, so its peak is
#   never exactly 0. a dead, muted, or unplugged input is the only thing that
#   returns exact zeros. so `peak == 0` separates "a quiet room" from "no input
#   at all" with almost no false positive — where a level threshold would
#   redden on a genuinely quiet room and get itself silenced
#   (`gotcha.a-check-that-cries-wolf-gets-silenced`)
#
# usage:
#   rhx audio.record.probe
#   rhx audio.record.probe --within 5
#   rhx audio.record.probe --source alsa_input.usb-xxxx.mono-fallback
#   rhx audio.record.probe --play          # hear the probe back, the cheap ritual
#
# guarantee:
#   - READ-ONLY with respect to the box: it captures to a temp file and removes
#     it. it changes no source, no volume, no mute state
#   - exit 0 = a take will capture sound · exit 2 = it will not, and why
######################################################################

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/audio.record.operations.sh"

__audio_probe_help() {
  cat <<'HELP'
🎙️ audio.record.probe — prove a mic will capture sound before you rely on it

  usage:
    rhx audio.record.probe [--source <name>] [--within <seconds>] [--play]

  options:
    --source   the capture source to test    (default: the box's default source)
    --within   seconds of audio to sample    (default: 3)
    --play     play the probe back to you    (the ritual that catches a bad mic)

  example:
    rhx audio.record.probe --within 5 --play

  it is run for you by:
HELP
  __audio_demo_line
  echo ""
  echo "  exit 0 = a take will capture sound · exit 2 = it will not, and why"
}

main() {
  __audio_skill_args "$@"
  set -- "${AUDIO_SKILL_ARGS[@]+"${AUDIO_SKILL_ARGS[@]}"}"

  local source="" within=3 play=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --source) source="${2:-}"; shift 2 ;;
      --within) within="${2:-}"; shift 2 ;;
      --play)   play=1; shift ;;
      --help|-h) __audio_probe_help; return 0 ;;
      *)
        echo "✋ unknown arg: $1" >&2
        echo "   fix: rhx audio.record.probe --help" >&2
        return 2
        ;;
    esac
  done

  if ! [[ "$within" =~ ^[0-9]+$ ]] || [[ "$within" -lt 1 ]]; then
    echo "✋ --within wants a whole number of seconds, got '$within'" >&2
    return 2
  fi

  echo "🎙️ audio.record.probe --within $within"

  ####################################################################
  # 1. is there a real input on this box at all?
  ####################################################################
  local reals
  reals="$(__audio_sources_real)"
  if [[ -z "$reals" ]]; then
    echo '   ✋ no non-monitor input exists on this box' >&2
    echo '      ⇒ every source here is a .monitor, which is the loopback of an' >&2
    echo '        OUTPUT — it records what the box PLAYS, never what the room says' >&2
    echo '      fix: plug a mic in, then re-run this probe' >&2
    echo '      read what exists: pactl list short sources' >&2
    return 2
  fi

  ####################################################################
  # 2. name the source under test
  ####################################################################
  [[ -z "$source" ]] && source="$(__audio_source_default)"
  if [[ -z "$source" ]]; then
    echo "   ✋ the box declares no default source" >&2
    echo "      fix: name one explicitly —" >&2
    echo "        rhx audio.record.probe --source <name>" >&2
    echo "      the real inputs on this box:" >&2
    echo "$reals" | sed 's/^/        /' >&2
    return 2
  fi
  echo "   ├─ source: $source"

  ####################################################################
  # 3. it must not be a monitor
  #
  # ⚠️ this is the hazard that hides best. a monitor source records perfectly
  #    — a big file, a healthy peak, a clean exit — and what it holds is the
  #    box's own playback rather than the voice in the room
  ####################################################################
  if __audio_source_is_monitor "$source"; then
    echo "   ✋ '$source' is a MONITOR — the loopback of an output" >&2
    echo "      ⇒ it would record what this box PLAYS, not what the room says," >&2
    echo "        and it would do so with a healthy peak and a clean exit" >&2
    echo "      fix: name a real input —" >&2
    echo "        rhx audio.record.probe --source <name>" >&2
    echo "      the real inputs on this box:" >&2
    echo "$reals" | sed 's/^/        /' >&2
    return 2
  fi
  echo "   ├─ • not a monitor ✔"

  ####################################################################
  # 4. it must not be muted, and the box must be able to SAY so
  #
  # ⚠️ the `?` arm is not pedantry. a reader that folds "could not answer"
  #    into "not muted" passes a source it never read (`rule.forbid.failhide`)
  ####################################################################
  local mute
  mute="$(__audio_source_mute_word "$source")"
  case "$mute" in
    yes)
      echo "   ✋ '$source' is MUTED — a take would hold bit-exact silence" >&2
      echo "      ⇒ read the whole declared state, to see what else is off:" >&2
      echo "        rhx audio.record.source.get --all" >&2
      echo "      fix: pactl set-source-mute '$source' 0" >&2
      return 2
      ;;
    no)
      echo "   ├─ • unmuted ✔"
      ;;
    *)
      echo "   ✋ the box gave no mute state for '$source'" >&2
      echo "      ⇒ this is NOT 'unmuted'. the source may not exist, or the" >&2
      echo "        audio daemon may be down — either way it went unread" >&2
      echo "      read what the box declares: rhx audio.record.source.get --all" >&2
      return 2
      ;;
  esac

  ####################################################################
  # 4b. a source at 0% is silent with its mute flag CLEAR
  #
  # ⚠️ so the mute check alone does not cover the silent-source hazard —
  #    this is the second way to get a large file of bit-exact zeros
  ####################################################################
  local vol
  vol="$(__audio_source_volume_pct "$source")"
  if [[ "$vol" == "0" ]]; then
    echo "   ✋ '$source' is at 0% capture volume — silent, though unmuted" >&2
    echo "      fix: pactl set-source-volume '$source' 60%" >&2
    return 2
  fi
  [[ "$vol" != "?" ]] && echo "   ├─ • volume ${vol}% ✔"

  ####################################################################
  # 5. THE claim — it actually hears sound
  #
  # ⚠️ pw-record's exit code is NOT read. measured 2026-09-06: it exited 1 on a
  #    run that produced a byte-exact file. so the ARTIFACT is the verdict —
  #    the peak that came out of it, and whether it parsed at all
  ####################################################################
  local tmp
  tmp="$(mktemp -t audio.record.probe.XXXXXX.wav)" || {
    echo "   ✋ could not make a temp file to probe into" >&2
    return 2
  }
  # shellcheck disable=SC2064
  trap "rm -f '$tmp'" EXIT

  ####################################################################
  # ⚠️ .the `timeout` is load-bear — `-n <samples>` is NOT a bound
  #
  #   `-n` says how many samples to KEEP, never how long to wait for them.
  #   a wedged pipewire daemon yields none, so the count is never reached and
  #   pw-record waits forever. that makes an unwrapped probe "a stall with a
  #   question mark on it" (`term=probe`, .a probe must be BOUNDED).
  #
  # 🛑 and the blast radius is larger here than in a verify: `audio.record.start`
  #    runs this probe UNCONDITIONALLY, so an unbounded probe hangs the
  #    RECORDER — at the one moment a human is sat down to capture a
  #    conversation that cannot be repeated
  #
  #   the slack is generous on purpose: a cold pipewire graph takes a moment to
  #   route, and a probe that reports a false stall is a check that cries wolf
  ####################################################################
  echo "   ├─ • listens for ${within}s…"
  timeout $(( within + 10 )) pw-record \
    --target "$source" \
    --rate "$AUDIO_RECORD_RATE" \
    --channels "$AUDIO_RECORD_CHANNELS" \
    --format "$AUDIO_RECORD_FORMAT" \
    -n $(( AUDIO_RECORD_RATE * within )) \
    "$tmp" </dev/null >/dev/null 2>&1 || true

  local pcm
  pcm="$(__audio_pcm_bytes_of "$tmp")"
  if [[ "$pcm" -eq 0 ]]; then
    echo "   ✋ the probe captured no pcm at all from '$source'" >&2
    echo "      ⇒ the recorder produced a header and no samples, so the source" >&2
    echo "        exists and yields no stream" >&2
    echo "      read why: pw-record --target '$source' -n $AUDIO_RECORD_RATE /tmp/t.wav" >&2
    return 2
  fi

  local peak
  peak="$(__audio_peak_of "$tmp")" || return 2

  if [[ "$peak" -le "$AUDIO_RECORD_PEAK_DEAD" ]]; then
    echo "   ✋ '$source' returned BIT-EXACT SILENCE over ${within}s" >&2
    echo "      ⇒ a live mic in a real room always returns a noise floor, so an" >&2
    echo "        exact zero is a dead input — never a quiet one" >&2
    echo "      the usual causes, in the order they happen:" >&2
    echo "        · a hardware mute switch on the mic or the laptop" >&2
    echo "        · the mic is unplugged, or plugged into the output jack" >&2
    echo "        · the capture volume is zero —" >&2
    echo "            pactl get-source-volume '$source'" >&2
    echo "            pactl set-source-volume '$source' 60%" >&2
    echo "        · another app holds the device exclusively" >&2
    return 2
  fi

  ####################################################################
  # 6. the two ADVISORIES — reported, never refused
  #
  # a quiet room and a loud thump are both real. to refuse on either would be
  # a check that argues against a healthy box, and those get silenced
  ####################################################################
  # the same bar the recorder's live meter draws, on the same dB scale — so a
  # human calibrates their eye HERE, before a take, rather than mid-conversation
  echo "   ├─ • peak $(__audio_meter_bar "$peak" 22) $peak / 32767 ✔ (live)"

  ####################################################################
  # 🛑 .the gain a fix-text names is COMPUTED, never a literal
  #
  # ⚠️ measured 2026-09-06: this printed `set-source-volume … 80%` as the fix
  #    for a THIN take, on a box whose source was already at 100%. so the named
  #    fix was a REDUCTION — it would have made the take quieter, and it reads
  #    as specific and authoritative, which is exactly the false ✋ that gets
  #    applied rather than questioned
  #    (`gotcha.a-check-that-cries-wolf-gets-silenced`, q7)
  #
  # ⇒ a literal percentage is a claim about a box this skill never read. so
  #   both arms read the CURRENT volume and move relative to it
  ####################################################################
  local target base
  if [[ "$peak" -lt "$AUDIO_RECORD_PEAK_THIN" ]]; then
    echo "   ├─ ⚠️ that is THIN — audible, and quiet enough to be hard to hear later"
    echo "   │     · move the mic CLOSER first — it is free, and it raises the voice"
    echo "   │       without the room noise. gain raises both together"

    ##################################################################
    # 🛑 .the BASE decides whether a gain raise BUYS a better take
    #
    # at or under the base, a raise moves the ADC's own gain — the signal
    # itself gets louder and the noise floor does not. over it, pulse merely
    # multiplies samples: louder, IDENTICAL signal-to-noise, and it clips.
    #
    # ⚠️ measured 2026-09-06 on this laptop's internal mic — base 32%, volume
    #    100%. so the `raise it to 140%` this arm printed named a 4.4×
    #    digital multiply and called it a fix. every rung of that advice was
    #    already spent, and the arm could not say so because it never read the
    #    base (`gotcha.a-check-that-cries-wolf-gets-silenced`, q7)
    ##################################################################
    base="$(__audio_source_base_pct "$source")"

    if [[ "$vol" == "?" ]]; then
      echo "   │     · then, if it is still thin, raise the capture gain:"
      echo "   │         pactl set-source-volume '$source' 130%"
    elif [[ "$base" != "?" && "$vol" -ge "$base" ]]; then
      echo "   │     · ⚠️ the gain is SPENT. this source's base is ${base}% and it sits"
      echo "   │       at ${vol}%, so a raise past here is a digital multiply — louder,"
      echo "   │       same signal-to-noise, and it can clip a take nobody can re-make"
      echo "   │     · so distance, mic placement, and a quieter room are the levers"
      echo "   │       that remain. each raises the voice without the room"
    elif [[ "$vol" -ge 150 ]]; then
      echo "   │     · the gain is already at ${vol}%, so there is none left to add."
      echo "   │       distance and mic placement are the only levers that remain"
    else
      target=$(( vol + 40 ))
      [[ "$base" != "?" && "$target" -gt "$base" ]] && target="$base"
      [[ "$target" -gt 150 ]] && target=150
      echo "   │     · then, if it is still thin, raise the capture gain from ${vol}%:"
      echo "   │         pactl set-source-volume '$source' ${target}%"
      [[ "$base" != "?" ]] && echo "   │       (${base}% is this source's base — real analog gain up to there)"
    fi
    echo "   │     · a take cannot be re-made, so this is worth a minute now"
  elif [[ "$peak" -ge "$AUDIO_RECORD_PEAK_CLIP" ]]; then
    echo "   ├─ ⚠️ that is CLIPPED — the loud parts are destroyed, and no repair"
    echo "   │     recovers them. lower the gain:"
    if [[ "$vol" == "?" ]]; then
      echo "   │         pactl set-source-volume '$source' 60%"
    else
      target=$(( vol * 6 / 10 ))
      [[ "$target" -lt 10 ]] && target=10
      echo "   │         pactl set-source-volume '$source' ${target}%   (from ${vol}%)"
    fi
  fi

  ####################################################################
  # 7. the ritual — hear it back
  ####################################################################
  if [[ "$play" -eq 1 ]]; then
    if command -v paplay >/dev/null 2>&1; then
      echo "   ├─ • plays the probe back…"
      paplay "$tmp" >/dev/null 2>&1 || echo "   ├─ ⚠️ playback failed; the capture is still good"
    else
      echo "   ├─ 🌙 paplay is absent, so the probe cannot be played back"
    fi
  fi

  echo "   └─ ✔ ready — a take on '$source' will capture sound"
  return 0
}

main "$@"

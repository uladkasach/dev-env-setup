#!/usr/bin/env bash
######################################################################
# .what = prove every link of the capture chain is reachable
#
# 🛑 .the split this file draws — TOOLS here, SIGNAL at the probe
#   this bundle asserts that the six binaries EXIST. it says not one word about
#   whether a mic currently hears anything, and that omission is deliberate:
#
#     - a mic is unplugged, muted, and re-plugged many times a day. a verify
#       that reddened on each would argue against a healthy box most of the
#       time, and a check that cries wolf gets silenced — taking every check
#       beside it along (`gotcha.a-check-that-cries-wolf-gets-silenced`)
#     - the signal question has a RIGHT moment, and it is the moment a human is
#       about to record. `rhx audio.record.probe` owns it, and `audio.record.start`
#       runs it unconditionally before it captures a byte
#
#   ⇒ so: a tool absent is a PROVISION defect and reddens here. a mic silent is
#     a RUNTIME fact and reddens there. neither check can answer the other's
#     question, and to fuse them would cost this one its credibility
#
# ⚠️ .why `od` and `awk` are asserted at all, when both ship with coreutils
#   they are how the probe reads a peak amplitude out of a wav — there is no
#   ffmpeg and no sox on this box, so these two ARE the signal reader. an
#   absent one turns every silence check into a false ✔, which is the exact
#   failure the probe exists to prevent (`rule.forbid.failhide`)
#
# guarantee:
#   - READ-ONLY. it observes; it mutates no state
######################################################################

grove_provision_1_9_audio_provision_verify() {
  if [[ "$GROVE_ENV_SERVER" != "local@unix" ]]; then
    echo "   🌙 declined — no microphone on $GROVE_ENV_SERVER, so no capture"
    echo "      chain is expected here"
    return 0
  fi

  local failed=0

  ####################################################################
  # 1. the six binaries, each with the fix that names ITS package
  #
  # .why one loop and not six blocks: the claim is identical per row, and the
  #      only thing that varies is the package name — so the package rides in
  #      the row rather than in a copy of the block
  ####################################################################
  local pair tool pkg absent=()
  for pair in \
    "pw-record:pipewire-bin" \
    "pactl:pulseaudio-utils" \
    "notify-send:libnotify-bin" \
    "systemd-inhibit:systemd" \
    "od:coreutils" \
    "awk:mawk"
  do
    tool="${pair%%:*}"
    pkg="${pair#*:}"
    if command -v "$tool" >/dev/null 2>&1; then
      echo "   • $tool ✔"
    else
      echo "   ✋ $tool is absent from PATH (ships in $pkg)" >&2
      absent+=("$tool")
      failed=1
    fi
  done

  if [[ ${#absent[@]} -gt 0 ]]; then
    echo "      ⇒ absent: ${absent[*]}" >&2
    echo "      fix: rhx grove.provision --what 1.9.audio --mode apply" >&2
  fi

  ####################################################################
  # 2. `pw-record` writes WAV and no other container — a measured constraint
  #
  # 📜 measured 2026-09-06: `pw-record --rate 48000 --channels 1 -n 4800
  #    /tmp/probe.ogg` wrote a file that `file` reports as
  #    `RIFF (little-endian) data, WAVE audio, Microsoft PCM, 16 bit, mono
  #    48000 Hz` — the extension was ignored outright.
  #
  #    so the recorder has NO container choice: wav, or `--raw` headerless pcm.
  #    ogg and flac are unreachable without a second tool, and every downstream
  #    design here rests on that. the note lives with the verify because this is
  #    where a reader comes to learn what the chain can do
  #
  # ⚠️ .and it exited 1 on that same run, with a byte-exact 9644-byte file
  #    (44 header + 4800 samples × 2). so `pw-record`'s exit code is NOT a
  #    verdict on the take — a caller that trusts it reports a perfect capture
  #    as a failure. every audio.record.* skill judges the ARTIFACT instead
  ####################################################################

  ####################################################################
  # 3. an advisory count of real inputs — never a claim
  #
  # a `.monitor` source is the loopback of an OUTPUT: it records what the box
  # PLAYS, not what the room says. it is always present and it is never the
  # thing a mic take wants, so it is excluded from the count
  ####################################################################
  if command -v pactl >/dev/null 2>&1; then
    local inputs
    inputs="$(pactl list short sources 2>/dev/null | awk '$2 !~ /\.monitor$/' | wc -l)"
    if [[ "$inputs" -gt 0 ]]; then
      echo "   • $inputs non-monitor input(s) present ✔"
    else
      echo "   🌙 no non-monitor input is present right now — a mic may simply"
      echo "      be unplugged. this is a RUNTIME fact, so it is reported and"
      echo "      never failed on; rhx audio.record.probe is what refuses"
    fi
  fi

  return $failed
}

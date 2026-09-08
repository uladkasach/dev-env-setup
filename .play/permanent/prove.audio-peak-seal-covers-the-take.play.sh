#!/usr/bin/env bash
######################################################################
# .what = drive `__audio_peak_sealed` through every way its two inputs can
#         disagree, and demand the peak still covers the WHOLE take
#
# 🛑 .why this clamp exists, and why it is permanent
#
# 📜 2026-09-07: a 58-minute take's seal ran 76 SECONDS after the shell prompt
#    had already returned, and every second was a full-file peak scan. the fix
#    made `__audio_watch` keep a max as it goes, so the seal reads a file.
#
# ⇒ that fix bought speed with a NEW failure mode, and it is the dangerous kind:
#   the watchdog covers a PREFIX of the take, so a peak taken from its max alone
#   would under-report — silently, in range, with no signal. a take whose loud
#   half came after the watchdog died would read as quiet forever.
#
# ⚠️ that is `rule.forbid.failhide` exactly: a number that looks like an answer
#    and is a fact about a prefix. and no real take can make this check BITE,
#    because on a healthy box the watchdog covers nearly everything — so the
#    arms below plant the loud audio AFTER `seen` on purpose
#    (`term=bite._.choice._.md` — a check proven in one direction is half proven)
#
# .the five arms, and what each would let through if the fold were wrong
#   1. no progress file      → a full scan. a naive read of an absent file
#                              yields max=0, and the take reads as silent
#   2. a prefix-only max     → the watchdog died early. THE arm this exists for:
#                              trust `max` alone and the loud tail is invisible
#   3. a max above the tail  → the loud part happened while the watchdog ran.
#                              drop the max and the take under-reports again
#   4. a `seen` past the end → a corrupt or stale progress file. a `seen` taken
#                              at face value skips a tail that exists
#   5. a half-written line   → a kill mid-`printf`. it must degrade to a wider
#                              scan, never to a number in range
#
# guarantee:
#   - READ-ONLY on this box. it builds its own wav under `mktemp -d` and
#     removes it on EVERY exit path. it touches no take and no state dir
######################################################################

set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=/dev/null
source "$HERE/.agent/repo=.this/role=any/skills/audio.record.operations.sh"

failed=0

echo "🌲 prove.audio-peak-seal-covers-the-take"

####################################################################
# .the fixture — a wav whose LOUD part is at the very end
#
# ⚠️ the shape is the whole point. a fixture with its peak in the middle would
#    pass under a broken fold, because the watchdog's prefix would hold it. the
#    loud samples sit past every `seen` the arms below claim
####################################################################
QUIET_SAMPLES=200      # value  100
LOUD_SAMPLES=100       # value 8000  ← the number every arm must find
QUIET_VALUE=100
LOUD_VALUE=8000

tmp="$(mktemp -d)" || { echo "   ✋ could not make a temp dir" >&2; exit 1; }
trap 'rm -rf "$tmp"' EXIT

wav="$tmp/fixture.wav"
progress="$tmp/peak"

# a 44-byte canonical wav header: s16 mono 48000Hz, then the pcm
#   offset 34 = bits per sample (16) — `__audio_bytes_per_sample_of` reads it
#   offset 36 = the literal 'data'  — `__audio_peak_of` refuses without it
{
  printf '\122\111\106\106'          # 'RIFF'
  printf '\174\002\000\000'          # riff size = 36 + 600
  printf '\127\101\126\105'          # 'WAVE'
  printf '\146\155\164\040'          # 'fmt '
  printf '\020\000\000\000'          # subchunk1 size = 16
  printf '\001\000'                  # format = 1 (pcm)
  printf '\001\000'                  # channels = 1
  printf '\200\273\000\000'          # rate = 48000
  printf '\000\167\001\000'          # byte rate = 96000
  printf '\002\000'                  # block align = 2
  printf '\020\000'                  # bits per sample = 16
  printf '\144\141\164\141'          # 'data'
  printf '\130\002\000\000'          # data size = 600
  for ((i = 0; i < QUIET_SAMPLES; i++)); do printf '\144\000'; done   #  100
  for ((i = 0; i < LOUD_SAMPLES;  i++)); do printf '\100\037'; done   # 8000
} >"$wav"

pcm="$(__audio_pcm_bytes_of "$wav")"
quiet_bytes=$(( QUIET_SAMPLES * 2 ))

# ⚠️ the fixture is checked BEFORE it is used. a probe that measures a world its
#    own fixture failed to build reports on no subject at all
#    (`gotcha.a-check-that-cries-wolf-gets-silenced`, m.5)
want=$(( (QUIET_SAMPLES + LOUD_SAMPLES) * 2 ))
if [[ "$pcm" -ne "$want" ]]; then
  echo "   ✋ fixture: pcm reads $pcm bytes, expected $want — the wav did not build" >&2
  exit 1
fi
full="$(__audio_peak_of "$wav")" || full=-1
if [[ "$full" -ne "$LOUD_VALUE" ]]; then
  echo "   ✋ fixture: a full scan reads $full, expected $LOUD_VALUE" >&2
  exit 1
fi
echo "   • fixture: $pcm B, quiet $QUIET_VALUE then loud $LOUD_VALUE, full scan = $full ✔"

expect() {
  local arm="$1" want="$2" got="$3"
  if [[ "$got" -eq "$want" ]]; then
    echo "   • $arm → $got ✔"
  else
    echo "   ✋ $arm → $got, expected $want" >&2
    failed=1
  fi
}

# arm 1 — no progress file. the watchdog never wrote one, or it was removed
rm -f "$progress"
expect "no progress file" "$LOUD_VALUE" "$(__audio_peak_sealed "$wav" "$progress" "$pcm")"

####################################################################
# arm 2 — 🛑 THE arm this play exists for
#
# the progress file covers the quiet prefix ONLY, as it would if the watchdog
# died before the loud part. its max is honest about what it read and silent
# about what it never reached.
#
# ⇒ a fold that returns `max` when a progress file is present passes arms 1, 3
#   and 4 and fails only here. that is why the loud audio is planted past `seen`
####################################################################
printf '%s %s\n' "$QUIET_VALUE" "$quiet_bytes" >"$progress"
expect "watchdog died early (max=$QUIET_VALUE, seen=$quiet_bytes)" \
  "$LOUD_VALUE" "$(__audio_peak_sealed "$wav" "$progress" "$pcm")"

# arm 3 — the max exceeds anything left in the tail, so the max must survive
printf '%s %s\n' "20000" "$pcm" >"$progress"
expect "max above the tail (max=20000, seen=$pcm)" \
  "20000" "$(__audio_peak_sealed "$wav" "$progress" "$pcm")"

# arm 4 — a `seen` past the end of the take. taken at face value it skips a
#         tail that exists; clamped to `pcm` it re-reads the last sample
printf '%s %s\n' "1" "$(( pcm * 4 ))" >"$progress"
expect "seen past the end (seen=$(( pcm * 4 )) of $pcm)" \
  "$LOUD_VALUE" "$(__audio_peak_sealed "$wav" "$progress" "$pcm")"

# arm 5 — a half-written line, as a kill mid-`printf` leaves it
printf '4966' >"$progress"
expect "a truncated progress line" "$LOUD_VALUE" \
  "$(__audio_peak_sealed "$wav" "$progress" "$pcm")"

if [[ "$failed" -ne 0 ]]; then
  echo "🌲 prove.audio-peak-seal-covers-the-take: a seal peak under-reports its take ✋" >&2
  exit 1
fi
echo "🌲 prove.audio-peak-seal-covers-the-take: every arm covers the whole take ✔"

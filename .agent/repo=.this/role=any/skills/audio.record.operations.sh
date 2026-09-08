#!/usr/bin/env bash
######################################################################
# .what = shared operations for every `rhx audio.record.*` skill
#
# .why  = the probe, the recorder, and the header setter all need the SAME
#         three moves — strip rhachet's flags, name the source, read a peak
#         amplitude out of a wav. three copies is three places for a fix to
#         miss one (`rule.require.identical-bundle-composition`)
#
# .note = this file is loaded by the audio.record.* skills, never run on its own
######################################################################

# the capture format. mono because a take is one room and one voice, so stereo
# doubles the bytes and buys no information. uncompressed pcm because a take is
# an ARCHIVE that cannot be re-made — it is the one format with no codec to go
# obsolete
#
# 🛑 .why s32 and NOT s16 — we were DISCARDING half the bits
#   measured 2026-09-07. `audio.record.source.get` reported the source's own
#   format as `s32le 2ch 48000Hz` while this line asked for `s16`, so pipewire
#   downconverted and threw away 16 bits per sample, in the graph, silently.
#   s32 is what the converter hands us, so it is a ZERO-conversion path
#
# ⚠️ .and it changes NO audible part of a take. say so plainly, because the
#    opposite is the easy claim to believe: s16's quantization floor already
#    sits ~50 dB below this mic's own analog self-noise, so the mic dominates
#    completely. the argument is "stop a discard", never "improve the take"
#    (`term=audio.gain._.choice._.md` — louder is not better, and neither is
#    finer). the lever that WOULD improve it is distance
#
# 🛑 .why NOT f32, though it cannot clip
#   measured the same hour, and it is a header fact rather than a taste:
#     pw-record --format s32 → `Microsoft PCM, 32 bit` · 44-byte header ✔
#     pw-record --format f32 → `IEEE Float`            · 80-byte header ✋
#   an 80-byte header moves the two size fields this repo repairs, so f32 would
#   break the one guarantee that lets a take survive a crash. the take is
#   unrepeatable; the extra headroom is not worth the repair contract
#
# ⚠️ there is no `s24`. pw-record offers ulaw|alaw|u8|s8|s16|s32|f32|f64 and no
#    width between s16 and s32 — do not reach for it
AUDIO_RECORD_RATE="${AUDIO_RECORD_RATE:-48000}"
AUDIO_RECORD_CHANNELS="${AUDIO_RECORD_CHANNELS:-1}"
AUDIO_RECORD_FORMAT="${AUDIO_RECORD_FORMAT:-s32}"

# a wav header written by pw-record is exactly 44 bytes — measured 2026-09-06 at
# s16 (4800 samples → 9644 bytes) and re-measured 2026-09-07 at s32 (4800
# samples → 19244 bytes). both are `WAVE_FORMAT_PCM`, so both carry the
# canonical 44. `__audio_peak_of` ASSERTS this rather than assumes it
AUDIO_RECORD_HEADER_BYTES=44

# ⚠️ every threshold below is on a FIXED 0..32767 scale, whatever width a take
#    was captured at. `__audio_peak_of` scales its read to that range on the way
#    out — see the block above it for why that is not merely a convenience

# the silence floor. a LIVE mic in a real room always returns a noise floor, so
# its peak is never bit-exact zero — a dead, muted, or unplugged input is the
# only thing that gives exact zeros. that makes 0 a discriminator with almost no
# false positive, and it is why the probe keys on it rather than on a threshold
AUDIO_RECORD_PEAK_DEAD=0

# below this (of 32767) a take is audible but thin — mic too far, or gain low.
# it is ADVISORY only: a quiet room is a real thing, and to refuse on it would
# be a check that cries wolf
AUDIO_RECORD_PEAK_THIN="${AUDIO_RECORD_PEAK_THIN:-600}"

# at or above this the take is clipped — the loud parts are destroyed and no
# repair recovers them. also advisory: one thump should not stop a session
AUDIO_RECORD_PEAK_CLIP="${AUDIO_RECORD_PEAK_CLIP:-32700}"

# where the last-used --into/--purpose pair is remembered.
# ⚠️ deliberately OUTSIDE this repo. the pair names a real person and a real
#    family, and this repo is PUBLIC (`rule.forbid.dox-in-public-repo`)
AUDIO_RECORD_STATE_DIR="${AUDIO_RECORD_STATE_DIR:-$HOME/.local/state/audio.record}"

######################################################################
# .what = drop rhachet's own flags, keep the caller's
# .why  = rhachet forwards --skill/--repo/--role into the skill's argv
# .how  = sets the global array AUDIO_SKILL_ARGS
######################################################################
__audio_skill_args() {
  AUDIO_SKILL_ARGS=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --) shift; AUDIO_SKILL_ARGS+=("$@"); break ;;
      --skill|--repo|--role) shift 2 ;;
      *) AUDIO_SKILL_ARGS+=("$1"); shift ;;
    esac
  done
}

######################################################################
# .what = the default capture source's node name, or empty
# .why  = every hazard the probe raises is ABOUT a source, so the source must
#         be named before any of them can be asked
######################################################################
__audio_source_default() {
  pactl get-default-source 2>/dev/null
}

######################################################################
# .what = every non-monitor source on the box, one per line
#
# .why the monitor exclusion is load-bear
#   a `.monitor` source is the loopback of an OUTPUT — it records what the box
#   PLAYS, not what the room says. it is always present, so a caller that counts
#   "sources" finds one on a box with no mic at all and reports a capture chain
#   that captures silence
######################################################################
__audio_sources_real() {
  pactl list short sources 2>/dev/null | awk '$2 !~ /\.monitor$/ { print $2 }'
}

######################################################################
# .what = is this source a monitor (an output loopback) rather than an input?
######################################################################
__audio_source_is_monitor() {
  [[ "$1" == *.monitor ]]
}

######################################################################
# .what = the mute flag of a source — the WORD, three-valued
#
# .why  = a muted source records bit-exact silence while every other check
#         passes — the exact shape of a false ✔ (`rule.forbid.failhide`)
#
# 🛑 .why THREE values and not a boolean
#   `pactl get-source-mute` can fail — no daemon, a name that resolves to no
#   source, a socket that went away. a boolean reader must fold that failure
#   into one of its two answers, and the only fold that seems safe is
#   "not muted" — which passes a source nobody could read at all.
#
#   ⇒ measured 2026-09-06: the first cut of this reader was
#     `[[ "$(pactl ... 2>/dev/null)" == *yes* ]]`, and an ERROR took the same
#     branch as a healthy `Mute: no`. so "the box could not answer" and "the
#     box said fine" were one verdict. `?` splits them
#
# echoes: yes | no | ?
######################################################################
__audio_source_mute_word() {
  local out
  out="$(pactl get-source-mute "$1" 2>/dev/null)" || { echo "?"; return 0; }
  case "$out" in
    *yes*) echo "yes" ;;
    *no*)  echo "no" ;;
    *)     echo "?" ;;
  esac
}

######################################################################
# .what = the first volume percentage of a source, or ? if unreadable
# .why  = a source at 0% yields bit-exact silence with its mute flag clear,
#         so the mute check alone does not cover the silent-source hazard
######################################################################
__audio_source_volume_pct() {
  local out pct
  out="$(pactl get-source-volume "$1" 2>/dev/null)" || { echo "?"; return 0; }
  pct="$(printf '%s' "$out" | sed -n 's/.*[^0-9]\([0-9][0-9]*\)%.*/\1/p' | head -1)"
  [[ -n "$pct" ]] && echo "$pct" || echo "?"
}

######################################################################
# .what = a source's BASE volume percentage, or ? if unreadable
#
# 🛑 .why this is the fact that decides whether a gain raise pays
#   base volume is the point at which the driver stops and the arithmetic
#   starts. at or under it, a volume change moves the ADC's own gain — the
#   signal grows and the noise floor does not, so the take genuinely improves.
#   ABOVE it, pulse multiplies the samples it already has:
#
#   | where | what a raise does | to the archive |
#   |---|---|---|
#   | ≤ base | more analog gain before the converter | better signal-to-noise |
#   | > base | a digital multiply after the converter | louder, same SNR, and it can CLIP |
#
#   ⇒ so a raise past base buys exactly what the playback slider buys, and
#     charges for it in a currency a take cannot refund: a clipped peak is
#     destroyed, and the take cannot be re-made
#
# ⚠️ .why it must be READ and never assumed
#   base is a property of one source. this box's HDMI monitor reports base
#   100%, and to carry that number over to the mic would be a true measurement
#   of the wrong subject (`gotcha.a-check-that-cries-wolf-gets-silenced`, m.4)
######################################################################
__audio_source_base_pct() {
  local out pct
  out="$(pactl list sources 2>/dev/null)" || { echo "?"; return 0; }
  pct="$(printf '%s\n' "$out" | awk -v n="$1" '
    $1 == "Name:"                              { inblock = ($2 == n) }
    inblock && $1 == "Base" && $2 == "Volume:" {
      for (i = 3; i <= NF; i++) if ($i ~ /%$/) { gsub(/%/, "", $i); print $i; exit }
    }
  ')"
  [[ -n "$pct" ]] && echo "$pct" || echo "?"
}

######################################################################
# .what = the peak absolute sample amplitude (0..32767) of a wav's pcm
#
# .why  = this is the ONLY reader of whether a take holds sound. there is no
#         ffmpeg and no sox on this box, so `od` + `awk` ARE the signal reader
#
# usage:
#   __audio_peak_of <file> [byte-offset]
#     byte-offset defaults to the header; pass a later one to read a TAIL,
#     which is how the watchdog samples a growing file in constant time
#     instead of re-reading the whole take every minute
#
# ⚠️ .why `-v` on od, and why its absence would be a silent defect
#   od COLLAPSES runs of identical lines into a single `*`. silence is, by
#   definition, runs of identical lines. so without `-v` the reader's input
#   shrinks exactly where the signal matters most, and any count or mean drawn
#   from it is wrong while the command still exits 0. `-v` disables the collapse
#
# ⚠️ .why the `data` tag is ASSERTED and not assumed
#   the 44-byte offset is true of pw-record's own output and is NOT true of wav
#   in general — a file with a LIST or fact chunk puts pcm somewhere else. read
#   at the wrong offset and the peak is computed over header bytes, which yields
#   a plausible number that carries no signal at all. so the tag at offset 36 is
#   read first, and a mismatch REFUSES rather than guesses
######################################################################
######################################################################
# .what = bytes per sample of the format the NEXT take will be captured at
#
# ⚠️ .the ONE place the config is the right subject
#   every reader of a take on disk must ask the TAKE
#   (`__audio_bytes_per_sample_of`). this asks the config, and is correct in
#   exactly one situation: the recorder, before `pw-record` has created the
#   file. there is no artifact to interrogate yet, and we are the party about
#   to determine its width — so the config is not a proxy here, it is the fact
#
# ⇒ two readers for one quantity is deliberate, and it is the `declared` vs
#   `live` split (`term=declared`, `term=live`). a caller that reaches for this
#   one while holding a real take has read the wrong subject
######################################################################
__audio_bytes_per_sample_declared() {
  case "${1:-$AUDIO_RECORD_FORMAT}" in
    s16) echo 2 ;;
    s32) echo 4 ;;
    *)   echo 0; return 2 ;;
  esac
}

######################################################################
# .what = bytes per sample, READ FROM THE TAKE — never from the config
#
# 🛑 .why the file and not `AUDIO_RECORD_FORMAT`
#   the config says what the NEXT take will be captured at. it says nothing
#   about a take already on disk, and the two disagree the moment the default
#   changes — as it did on 2026-09-07, when five extant s16 takes sat beside a
#   config that had moved to s32
#
#   ⇒ to size a read by the config would compute a peak over misaligned bytes
#     and return a plausible number that carries no signal. that is
#     `rule.forbid.failhide` in its quietest form: a wrong answer, in range,
#     with no error. so every reader judges the ARTIFACT
#
# .note = wav carries bits-per-sample as a u16 at offset 34, in the fmt chunk
######################################################################
__audio_bytes_per_sample_of() {
  local file="$1" bits
  [[ -f "$file" ]] || { echo 0; return 2; }
  bits="$(od -An -tu2 -v -j 34 -N 2 "$file" 2>/dev/null | tr -d ' \n')"
  case "$bits" in
    16) echo 2 ;;
    32) echo 4 ;;
    *)  echo 0; return 2 ;;
  esac
}

######################################################################
# .what = the peak absolute amplitude of a wav's pcm, on a FIXED 0..32767 scale
#
# 🛑 .why it scales, rather than return the raw sample value
#   a raw peak is meaningless without the width beside it — 891 out of 32767 is
#   a quiet take, and 891 out of 2147483647 is silence. so a raw number would
#   make every threshold, every sidecar `peak`, and every row of
#   `audio.record.list` mean a different thing per take
#
#   ⇒ worse, it would break the ARCHIVE's own comparability. the five takes
#     captured before 2026-09-07 are s16; every take after is s32. a human who
#     asks "was that one quieter?" must be able to compare them, and a scale
#     that shifts under the format answers that question wrong, forever
#
#   ⇒ so 0..32767 is the declared scale of this whole family — the thresholds,
#     the meter bar, and the `peak` field in every sidecar ever written
######################################################################
__audio_peak_of() {
  local file="$1"
  local from="${2:-$AUDIO_RECORD_HEADER_BYTES}"

  if [[ ! -f "$file" ]]; then
    echo "✋ no such take: $file" >&2
    return 2
  fi

  local tag
  tag="$(od -An -c -v -j 36 -N 4 "$file" 2>/dev/null | tr -d ' \n')"
  if [[ "$tag" != "data" ]]; then
    echo "✋ $file is not a 44-byte-header wav — its chunk at offset 36 reads '$tag'" >&2
    echo "   ⇒ a peak read at the wrong offset returns a plausible number that" >&2
    echo "     carries no signal, so this refuses rather than guesses" >&2
    return 2
  fi

  local bps
  bps="$(__audio_bytes_per_sample_of "$file")" || {
    echo "✋ $file declares a sample width this repo cannot read" >&2
    echo "   ⇒ supported: 16-bit and 32-bit pcm" >&2
    return 2
  }

  # ⚠️ the read must start on a SAMPLE boundary. a tail offset computed by a
  #    caller can land mid-sample once the width is 4, and od would then pair
  #    the high half of one sample with the low half of the next — a number in
  #    range, with no signal in it
  from=$(( from - ( (from - AUDIO_RECORD_HEADER_BYTES) % bps ) ))

  local od_fmt div
  if [[ "$bps" -eq 4 ]]; then od_fmt="d4"; div=65536; else od_fmt="d2"; div=1; fi

  od -An "-t$od_fmt" -v -j "$from" "$file" 2>/dev/null \
    | awk -v div="$div" '
        { for (i = 1; i <= NF; i++) { v = ($i < 0) ? -$i : $i; if (v > m) m = v } }
        END { print int((m + 0) / div) }'
}

######################################################################
# .what = a take's peak, from the watchdog's max plus whatever it never read
# .why  = so the seal costs a file read rather than a full-file scan
#
# 📜 measured 2026-09-07: a 58-minute take's seal ran 76 SECONDS after the shell
#    prompt had returned, and every one of those seconds was `__audio_peak_of`
#    over the whole file — ~690 MB and ~168 million samples, to learn one
#    number. `__audio_watch` had already read every one of those bytes, a minute
#    at a time, and thrown each result away.
#
# ⇒ so the watchdog keeps a max and writes `<max> <seen>`; this folds it with a
#   scan of what came after. `rule.require.solve-at-cause`
#
# 🛑 .the tail is SCANNED, never assumed — and that is what keeps this honest
#
# the watchdog ticks once a minute, so between its last tick and the stop there
# is up to 60s of audio it never read. and it can die early — a kill, an OOM, a
# take shorter than one tick — which leaves a max that covers a prefix.
#
# ⇒ so this reads `seen` and scans ONLY `seen → EOF`. that tail is bounded by
#   the tick interval, never by the take, so an 8-hour take and a 2-minute one
#   cost the same here. no progress file at all → a full scan, which is correct
#   and slow rather than fast and wrong
#
# ⚠️ to trust `max` alone would be `rule.forbid.failhide`: a watchdog that died
#    at minute 3 of an hour-long take would hand back the peak of its first
#    three minutes, reported as the peak of the take, with no signal at all.
#    `prove.audio-peak-seal-covers-the-take` is the clamp — it plants the loud
#    part of a fixture take AFTER `seen` and demands this still find it
#
# .where it lives: beside `__audio_peak_of`, which it wraps, rather than in
#   `audio.record.start` which is its one caller — a play must reach it to
#   clamp it, and that file runs `main` at source time
######################################################################
__audio_peak_sealed() {
  local take="$1" progress="$2" pcm="$3"
  local max=0 seen=0 tail

  if [[ -s "$progress" ]]; then
    read -r max seen <"$progress" || { max=0; seen=0; }
  fi

  # ⚠️ a non-numeric or absent field means the file is unreadable, so it carries
  #    no fact — fall back rather than fold a garbage number into a max. the
  #    watchdog is killed mid-`printf` on a narrow window, and a half-written
  #    line must degrade to a wider scan, never to a wrong number
  [[ "$max"  =~ ^[0-9]+$ ]] || max=0
  [[ "$seen" =~ ^[0-9]+$ ]] || seen=0

  ####################################################################
  # 🛑 a `seen` PAST THE END discards BOTH fields — it does not clamp
  #
  # 📜 caught 2026-09-08 by `prove.audio-peak-seal-covers-the-take`, on the
  #    clamp's first run. this line read `[[ "$seen" -gt "$pcm" ]] && seen="$pcm"`
  #    and the arm returned **1** where the take's true peak was 8000.
  #
  # .why the clamp was wrong: it treated a corrupt record as a COMPLETE one.
  #   `seen` can only ever hold a byte count the watchdog measured off THIS take,
  #   and no such count can exceed the take's final size. so `seen > pcm` does
  #   not mean "read too far" — it PROVES the record is corrupt or belongs to
  #   another file. and a record whose second field is impossible says no true
  #   thing about its first: `max` is exactly as untrustworthy as `seen`.
  #
  # ⇒ to clamp `seen` down to `pcm` announced *"the watchdog covered it all"*,
  #   which is the one claim that makes the tail scan read zero bytes and hands
  #   back a garbage `max` unchallenged — `rule.forbid.failhide`, arrived at
  #   through a line whose comment said it was there to PREVENT a skipped tail
  #
  # ⇒ discard both, and the run falls back to a full scan: correct and slow,
  #   which is this operation's stated failure direction everywhere else
  ####################################################################
  if [[ "$seen" -gt "$pcm" ]]; then
    max=0
    seen=0
  fi

  tail="$(__audio_peak_of "$take" $(( AUDIO_RECORD_HEADER_BYTES + seen )) 2>/dev/null)" || tail=0
  [[ "$tail" =~ ^[0-9]+$ ]] || tail=0

  [[ "$tail" -gt "$max" ]] && max="$tail"
  printf '%s\n' "$max"
}

######################################################################
# .what = read a little-endian uint32 at a byte offset
#
# .why it lives HERE and not in the one skill that writes
#   `audio.record.header.set` SETS these two fields and `audio.record.list`
#   READS them, to name which takes were cut mid-flight. two copies is two
#   places for a fix to miss one (`rule.require.identical-bundle-composition`)
######################################################################
__audio_read_u32le() {
  local file="$1" offset="$2"
  od -An -tu4 -v -j "$offset" -N 4 "$file" 2>/dev/null | tr -d ' \n'
}

######################################################################
# .what = does this wav's header disagree with its size on disk?
#
# .why  = a take killed mid-sentence keeps every sample and leaves the two
#         size fields at their length as of open. so a disagreement names a
#         take a player would cut short — the one repairable defect there is
#
# ⚠️ .a LIVE take reads as drifted too, and that is correct
#   pw-record sets the fields at open and revises them at close, so a take
#   still in progress genuinely disagrees with its size. the caller must not
#   read drift as "crashed" — only as "the header is not current"
#
# exit 0 = the fields drifted · exit 1 = they match · exit 2 = unreadable
######################################################################
__audio_header_drifted() {
  local file="$1"
  local tag size
  tag="$(od -An -c -v -j 36 -N 4 "$file" 2>/dev/null | tr -d ' \n')"
  [[ "$tag" == "data" ]] || return 2

  size="$(wc -c <"$file")"
  [[ "$size" -gt "$AUDIO_RECORD_HEADER_BYTES" ]] || return 2

  [[ "$(__audio_read_u32le "$file" 4)"  == "$(( size - 8 ))" ]] || return 0
  [[ "$(__audio_read_u32le "$file" 40)" == "$(( size - AUDIO_RECORD_HEADER_BYTES ))" ]] || return 0
  return 1
}

######################################################################
# .what = seconds as a human reads them — 1h02m18s, 18m04s, 42s
# .why  = a take is an hour long, and a raw second count of 3738 is a number
#         a human must do arithmetic on before it means duration
######################################################################
__audio_duration_human() {
  local secs="$1"
  local h=$(( secs / 3600 ))
  local m=$(( (secs % 3600) / 60 ))
  local s=$(( secs % 60 ))
  if   [[ "$h" -gt 0 ]]; then printf '%dh%02dm%02ds' "$h" "$m" "$s"
  elif [[ "$m" -gt 0 ]]; then printf '%dm%02ds' "$m" "$s"
  else                        printf '%ds' "$s"
  fi
}

######################################################################
# .what = the pcm byte count of a wav, from its size on disk
# .why  = the growth check reads this; a take whose pcm stops its growth has
#         a dead recorder behind it, whatever `pw-record`'s exit code claims
######################################################################
__audio_pcm_bytes_of() {
  local file="$1"
  [[ -f "$file" ]] || { echo 0; return 0; }
  local size
  size="$(wc -c <"$file")"
  if [[ "$size" -le "$AUDIO_RECORD_HEADER_BYTES" ]]; then
    echo 0
  else
    echo $(( size - AUDIO_RECORD_HEADER_BYTES ))
  fi
}

######################################################################
# .what = seconds of audio a pcm byte count represents
######################################################################
__audio_seconds_of() {
  local pcm="$1"
  # ⚠️ the width is a PARAMETER, and its default is the config's. a caller that
  #    holds a take must pass that take's own width — an s16 take measured at
  #    s32 reports HALF its true duration, which is a wrong number in range
  local bps="${2:-0}"
  if [[ "$bps" -le 0 ]]; then
    case "$AUDIO_RECORD_FORMAT" in
      s16) bps=2 ;;
      s32) bps=4 ;;
      *)   bps=2 ;;
    esac
  fi
  local bytes_per_second=$(( AUDIO_RECORD_RATE * AUDIO_RECORD_CHANNELS * bps ))
  [[ "$bytes_per_second" -gt 0 ]] || { echo 0; return 0; }
  echo $(( pcm / bytes_per_second ))
}

######################################################################
# .what = a byte count as a human reads it — 5.9 MB, 1.24 GB, 812 KB
# .why  = a take is measured in hundreds of megabytes, and a raw byte count is
#         a number a human must do arithmetic on before it means size
######################################################################
__audio_size_human() {
  awk -v b="${1:-0}" 'BEGIN {
    if      (b >= 1073741824) printf "%.2f GB", b / 1073741824
    else if (b >= 1048576)    printf "%.1f MB", b / 1048576
    else if (b >= 1024)       printf "%d KB",   b / 1024
    else                      printf "%d B",    b
  }'
}

######################################################################
# .what = render a peak (0..32767) as a level bar
#
# 🛑 .why the scale is dB and not linear
#   an ear is logarithmic and so is a mic's useful range. normal speech peaks
#   around 1000-3000 of 32767, which is 3-9% — so a LINEAR bar sits nearly empty
#   through an entire healthy conversation, and a human reads "nearly empty" as
#   "it is not hearing me". a meter that raises alarm on a healthy take is a
#   check that cries wolf (`gotcha.a-check-that-cries-wolf-gets-silenced`), and
#   the cost here is worse than a red row: they stop the take and re-seat the mic
#
#   ⇒ so the bar spans -60 dBFS..0 dBFS, where speech lands mid-scale and the
#     eye reads motion rather than absence
#
# .note = this RENDERS a peak; it does not read one. `__audio_peak_of` stays the
#         single reader of what a take holds, so the meter and the watchdog can
#         never disagree about the signal (`rule.require.identical-bundle-composition`)
######################################################################
__audio_meter_bar() {
  awk -v p="${1:-0}" -v w="${2:-22}" 'BEGIN {
    if (p < 1) p = 1
    db = 20 * log(p / 32767) / log(10)
    n  = int((db + 60) / 60 * w + 0.5)
    if (n < 0) n = 0
    if (n > w) n = w
    s = ""
    for (i = 0; i < n; i++) s = s "█"
    for (i = n; i < w; i++) s = s "░"
    print s
  }'
}

######################################################################
# .what = is this destination a SCRATCH location, and why?
#
# 🛑 .why a take may not land in scratch
#   `--into` is REMEMBERED between runs, which is the right ergonomic for a
#   human who records the same person weekly — and it is a live hazard, because
#   a single test run silently re-points every later take at the test's dir.
#
#   ⇒ measured 2026-09-06: a smoke test with `--into .temp/audiocheck` made
#     `.temp/audiocheck/smoke` the default destination. the next bare
#     `audio.record.start` captured into a gitignored scratch dir inside a repo
#     checkout — no error, no warn, and the take would have been swept by the
#     next clean. that is exactly the silent failure this family exists to catch,
#     arrived at through the convenience rather than through the mic
#
# ⚠️ the check is deliberately NARROW — a system temp dir, a `.temp` component,
#    or a git work tree. each is provably not an archive: scratch dirs are swept
#    and a checkout holds code. it makes no judgment about any other path, so a
#    human's own dir layout is never second-guessed
#
# ⚠️ .the ONE carve-out — a skill's own cache dir
#   a demo take is scratch by intent, and it needs somewhere to land that a
#   human recognizes as disposable. this repo already has that place, and it is
#   NAMED rather than improvised:
#
#     .agent/.cache/repo=.this/role=any/skill=audio.record/
#
#   ⇒ the carve-out is deliberately narrow: it matches that ONE shape, so a
#     demo cannot be an excuse to accept `.temp` or a bare repo dir back in
#
# echoes the reason on stdout · exit 0 = scratch · exit 1 = fine
######################################################################
__audio_dest_scratch_why() {
  local dir="$1" probe root

  # a skill's own cache dir is the declared home for a demo take
  case "$dir" in
    */.agent/.cache/repo=*/role=*/skill=*) return 1 ;;
  esac

  case "$dir" in
    /tmp|/tmp/*|/var/tmp|/var/tmp/*)
      echo "it is under a system temp dir, which the box sweeps"
      return 0 ;;
    */.temp|*/.temp/*)
      echo "it is under a .temp scratch dir, which is swept and gitignored"
      return 0 ;;
    "$HOME"/.cache|"$HOME"/.cache/*|*/.cache/*)
      echo "it is under a .cache dir, which is disposable by definition"
      return 0 ;;
  esac

  # the dir may not exist yet, so ask git about its nearest extant ancestor
  probe="$dir"
  while [[ -n "$probe" && "$probe" != "/" && ! -d "$probe" ]]; do
    probe="$(dirname "$probe")"
  done

  if [[ -d "$probe" ]] && git -C "$probe" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    root="$(git -C "$probe" rev-parse --show-toplevel 2>/dev/null)"
    echo "it is inside a git checkout (${root:-unknown}), which holds code rather than archives"
    return 0
  fi

  return 1
}

######################################################################
# .what = the purpose reserved for a throwaway take
# .why  = a demo is the one take nobody keeps, so it is the one take that may
#         land in a cache dir — and naming it makes that a DECLARED case rather
#         than a hole a real take can fall through
######################################################################
AUDIO_RECORD_DEMO_PURPOSE="demo"

######################################################################
# .what = where a `--purpose demo` take lands, absent an explicit --into
#
# 🛑 .why a demo gets its own dir AND its own memory rule
#   `--into` is remembered between runs, so a demo that wrote the remembered
#   pair would re-point every later take at a cache dir — the exact defect
#   `__audio_dest_scratch_why` exists to catch, re-introduced through the
#   convenience that a demo is supposed to be.
#
#   ⇒ so `audio.record.start` treats a demo two ways at once: it DEFAULTS here,
#     and it writes NO memory. a demo can never become the default destination
#
# echoes the dir · empty if this is not a checkout
######################################################################
__audio_demo_dir() {
  local root
  root="$(git -C "${1:-.}" rev-parse --show-toplevel 2>/dev/null)" || return 0
  [[ -n "$root" ]] && echo "$root/.agent/.cache/repo=.this/role=any/skill=audio.record"
}

######################################################################
# .what = decide a run's --into, given what the caller named and what the
#         box remembers. sets AUDIO_INTO and AUDIO_INTO_DEMO
#
# 🛑 .why this is ONE function and not a block per skill
#   the demo default is a RULE about a set — "which dir does `--purpose demo`
#   land in" — and `rule.require.identical-bundle-composition` says a set gets
#   one reader. spelled per-skill it drifts, and the drift is invisible:
#
#   📜 measured 2026-09-06. `open` grew the demo default and `list` did not,
#      so a demo take captured fine and `rhx audio.record.list --purpose demo`
#      answered "no such dir: <a stale remembered dir>/demo" — reported against
#      a take that was on disk the whole time. the write side and the read side
#      of one archive disagreed, with no signal
#
# usage:
#   __audio_into_decide "$into" "$into_given" "$purpose" "$purpose_given" "$SCRIPT_DIR"
#   → AUDIO_INTO       the decided dir, ~ expanded. empty = none could be found
#   → AUDIO_INTO_DEMO  1 = this is a demo run, so it must write NO memory
#   → AUDIO_INTO_GIVEN 1 = named or derived · 0 = recalled, so a refusal says so
######################################################################
__audio_into_decide() {
  local into="$1" into_given="$2" purpose="$3" purpose_given="$4" script_dir="${5:-.}"

  AUDIO_INTO=""
  AUDIO_INTO_DEMO=0
  AUDIO_INTO_GIVEN="$into_given"

  ####################################################################
  # a DEMO take defaults into this skill's own cache dir, and is REMEMBERED
  # BY NOBODY — see `__audio_demo_dir` for why the second half is load-bear
  ####################################################################
  if [[ "$purpose_given" -eq 1 && "$purpose" == "$AUDIO_RECORD_DEMO_PURPOSE" ]]; then
    AUDIO_INTO_DEMO=1
    if [[ "$into_given" -eq 0 ]]; then
      into="$(__audio_demo_dir "$script_dir")"
      AUDIO_INTO_GIVEN=1   # DERIVED, never recalled — so it earns no 'remembered' note
    fi
  fi

  [[ -n "$into" ]] && AUDIO_INTO="${into/#\~/$HOME}"
  return 0
}

######################################################################
# .what = the one line every audio.record.* skill prints to demo its flags
#
# .why  it is ONE function and not a copy per skill
#   `rule.require.errors-name-the-fix` wants the fix in every error, so this
#   string appears in help text AND in each refusal. spelled per-skill it would
#   drift, and the drifted copy is the one a human reads mid-refusal
#
# ⚠️ .why the demo purpose is a PLACEHOLDER
#   `$name` is literal here, never expanded. this repo is PUBLIC, so a real
#   relative's name may not enter a tracked file
#   (`rule.forbid.dox-in-public-repo`). type the real one at the call site —
#   it is remembered in $AUDIO_RECORD_STATE_DIR, which is outside this repo
#
# .why the indent is an ARGUMENT
#   the same line is read in two places at two depths — a help block sits at
#   4, a refusal sits under `   fix:` at 5. one hardcoded indent misaligns in
#   whichever context it was not written for
#
# ⚠️ printf, not echo, so the format string stays single-quoted and `$name`
#    is never a candidate for expansion
######################################################################
__audio_demo_line() {
  printf '%srhx audio.record.start --into ~/Dropbox/<family-dir> --purpose stories.babushka.$name\n' \
    "${1:-    }"
}

######################################################################
# .what = which app this DESKTOP declares as the handler for an audio file
#
# 🛑 .why a READER and not a hardcoded app name
#   the obvious form is `cosmic-player "$take"`, and it is wrong on two counts
#   at once: this box may not hold that binary, and a human who set their own
#   default gets it overridden by a skill that never asked.
#
#   ⇒ the desktop already HOLDS this answer — a mime default, set by the
#     session and changeable by the human. a hardcode is a second declaration
#     of a fact the box owns (`rule.require.identical-bundle-composition`)
#
# ⚠️ .why the mime type is passed IN
#   a wav is `audio/x-wav` and an mp3 is `audio/mpeg`, and a desktop may hand
#   them to different apps. to ask about one and open the other is
#   `gotcha.a-check-that-cries-wolf-gets-silenced`, m.4 — a true answer about
#   the wrong subject
#
# echoes the .desktop entry name · empty if the box declares none
######################################################################
__audio_player_declared() {
  local mime="${1:-audio/x-wav}" entry
  command -v xdg-mime >/dev/null 2>&1 || return 0
  entry="$(xdg-mime query default "$mime" 2>/dev/null)"
  [[ -n "$entry" ]] && echo "$entry"
}

######################################################################
# .what = the command that hands a file to the desktop, if the box has one
#
# ⚠️ .the order is not a preference, it is a FALLBACK CHAIN
#   `gio open` is the freedesktop-native launcher and honors the portal;
#   `xdg-open` is the lowest common denominator and is present nearly always.
#   either one obeys the mime default above, so neither picks an app itself
#
# echoes the binary name · empty if the box holds neither
######################################################################
__audio_opener_get() {
  local c
  for c in gio xdg-open; do
    command -v "$c" >/dev/null 2>&1 && { echo "$c"; return 0; }
  done
  return 0
}

######################################################################
# .what = the mime type a path's extension implies
# .why  = so `__audio_player_declared` is asked about the file in hand rather
#         than about wav always. see its own ⚠️ for what that mistake costs
######################################################################
__audio_mime_of() {
  case "${1,,}" in
    *.wav)          echo "audio/x-wav" ;;
    *.mp3)          echo "audio/mpeg" ;;
    *.flac)         echo "audio/flac" ;;
    *.ogg|*.oga)    echo "audio/ogg" ;;
    *.m4a|*.aac)    echo "audio/mp4" ;;
    *.opus)         echo "audio/opus" ;;
    *)              echo "audio/x-wav" ;;
  esac
}

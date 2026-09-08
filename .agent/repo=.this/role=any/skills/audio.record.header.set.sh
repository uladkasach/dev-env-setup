#!/usr/bin/env bash
######################################################################
# .what = set a wav's two size fields from the take's ACTUAL byte count
#
# 🛑 .why a crash costs two integers and no audio
#   a wav is a 44-byte header followed by raw samples, appended forever. so a
#   take killed mid-sentence — a crash, a SIGKILL, a lid close, a dead battery
#   — keeps every sample that reached the disk. there are no frames to resync
#   and no partial frame to discard.
#
#   the ONLY damage is two `uint32` fields the writer finalizes at close:
#     offset  4  RIFF chunk size = filesize - 8
#     offset 40  data chunk size = filesize - 44
#   both still hold the length as of open, so a player trusts them and stops
#   early, or refuses the file outright. both are recomputable from the size on
#   disk, which is what this skill does.
#
#   ⇒ so this is the whole crash-recovery story. it is idempotent: run it on a
#     healthy take and it writes the same values that are already there
#
# ⚠️ .why the verb is `header.set` and not `repair`
#   `repair` names no verb in this repo — `rule.forbid.repair-plays` retires it
#   outright. and `set` is the honest word: this OVERWRITES two declared fields
#   with the value the artifact says they should hold
#   (`rule.require.get-set-gen-verbs`)
#
# usage:
#   rhx audio.record.header.set --take <file.wav>
#   rhx audio.record.header.set --take <file.wav> --mode apply
#
# guarantee:
#   - plan mode is the DEFAULT. it reports the drift and writes no byte
#   - it never touches pcm. only bytes 4..7 and 40..43 are written
#   - idempotent: a re-run on a converged file changes no byte
######################################################################

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/audio.record.operations.sh"

######################################################################
# .what = write a little-endian uint32 at a byte offset, in place
#
# .note = its twin, the READER `__audio_read_u32le`, sits in
#         audio.record.operations.sh — `audio.record.list` reads these same
#         two fields to name the takes that were cut mid-flight
#
# ⚠️ .why the format string is built first, and the BYTES are never held in a
#    shell variable
#   a wav size field routinely holds a zero byte, and bash command substitution
#   DROPS nul bytes silently. so `x="$(printf '\000...')"` loses them and the
#   write lands short — a corruption with no error. instead the octal ESCAPES
#   are built as text (always nul-free), and printf emits the real bytes
#   straight into the pipe
######################################################################
__audio_write_u32le() {
  local file="$1" offset="$2" value="$3"
  local b0 b1 b2 b3 fmt
  b0=$(( value & 255 ))
  b1=$(( (value >> 8) & 255 ))
  b2=$(( (value >> 16) & 255 ))
  b3=$(( (value >> 24) & 255 ))
  fmt="$(printf '\\%03o\\%03o\\%03o\\%03o' "$b0" "$b1" "$b2" "$b3")"
  # shellcheck disable=SC2059
  printf "$fmt" | dd of="$file" bs=1 seek="$offset" conv=notrunc status=none
}

__audio_header_help() {
  cat <<'HELP'
🎙️ audio.record.header.set — make a crash-truncated take a valid wav again

  usage:
    rhx audio.record.header.set --take <file.wav> [--mode plan|apply]

  options:
    --take   the wav to read (and, in apply mode, to fix)
    --mode   plan (default, reports only) | apply (writes the two fields)

  .why  a killed take keeps every sample it flushed. only the two size fields
        in its header still hold the length as of open, so a player stops early
        or refuses the file. this recomputes both from the bytes on disk.

  example:
    rhx audio.record.header.set --take ~/Dropbox/<dir>/2026-09-06T14-30-00.wav --mode apply
HELP
}

main() {
  __audio_skill_args "$@"
  set -- "${AUDIO_SKILL_ARGS[@]+"${AUDIO_SKILL_ARGS[@]}"}"

  local take="" mode="plan"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --take) take="${2:-}"; shift 2 ;;
      --mode) mode="${2:-}"; shift 2 ;;
      --help|-h) __audio_header_help; return 0 ;;
      *)
        echo "✋ unknown arg: $1" >&2
        echo "   fix: rhx audio.record.header.set --help" >&2
        return 2
        ;;
    esac
  done

  if [[ -z "$take" ]]; then
    echo "✋ --take is required" >&2
    echo "   fix: rhx audio.record.header.set --take <file.wav>" >&2
    return 2
  fi
  if [[ ! -f "$take" ]]; then
    echo "✋ no such take: $take" >&2
    return 2
  fi
  if [[ "$mode" != "plan" && "$mode" != "apply" ]]; then
    echo "✋ --mode wants plan or apply, got '$mode'" >&2
    return 2
  fi

  echo "🎙️ audio.record.header.set --mode $mode"
  echo "   ├─ take: $take"

  # the tag guard — the same one the peak reader uses, and for the same reason:
  # a write at the wrong offset would corrupt pcm rather than fix a header
  local tag
  tag="$(od -An -c -v -j 36 -N 4 "$take" 2>/dev/null | tr -d ' \n')"
  if [[ "$tag" != "data" ]]; then
    echo "   ✋ this is not a 44-byte-header wav — offset 36 reads '$tag'" >&2
    echo "      ⇒ a write at the assumed offset would corrupt pcm rather than" >&2
    echo "        fix a header, so this refuses" >&2
    return 2
  fi

  local size riff_want data_want riff_have data_have
  size="$(wc -c <"$take")"
  if [[ "$size" -le "$AUDIO_RECORD_HEADER_BYTES" ]]; then
    echo "   ✋ the take holds a header and no samples ($size bytes)" >&2
    echo "      ⇒ there is no audio here to recover" >&2
    return 2
  fi

  riff_want=$(( size - 8 ))
  data_want=$(( size - AUDIO_RECORD_HEADER_BYTES ))
  riff_have="$(__audio_read_u32le "$take" 4)"
  data_have="$(__audio_read_u32le "$take" 40)"

  # ⚠️ the take's OWN width. this repair runs on takes of every vintage, and an
  #    s16 take measured at the config's s32 reports half its true duration
  local secs bps
  bps="$(__audio_bytes_per_sample_of "$take")" || bps=0
  secs="$(__audio_seconds_of "$data_want" "$bps")"
  echo "   ├─ on disk: $size bytes → ${secs}s of audio"
  echo "   ├─ riff size: have $riff_have · wants $riff_want"
  echo "   ├─ data size: have $data_have · wants $data_want"

  if [[ "$riff_have" == "$riff_want" && "$data_have" == "$data_want" ]]; then
    echo "   └─ • both fields already match the bytes on disk ✔ (no write owed)"
    return 0
  fi

  if [[ "$mode" == "plan" ]]; then
    echo "   └─ would write both fields — re-run with --mode apply"
    return 0
  fi

  __audio_write_u32le "$take" 4 "$riff_want" || {
    echo "   ✋ the riff size write failed" >&2
    return 1
  }
  __audio_write_u32le "$take" 40 "$data_want" || {
    echo "   ✋ the data size write failed" >&2
    return 1
  }

  # judge the ARTIFACT, never the write's exit code
  riff_have="$(__audio_read_u32le "$take" 4)"
  data_have="$(__audio_read_u32le "$take" 40)"
  if [[ "$riff_have" == "$riff_want" && "$data_have" == "$data_want" ]]; then
    echo "   └─ ✔ set — ${secs}s of audio is now a valid wav"
    return 0
  fi

  echo "   ✋ the write reported success and the fields did not take" >&2
  echo "      riff: $riff_have (wanted $riff_want) · data: $data_have (wanted $data_want)" >&2
  return 1
}

main "$@"

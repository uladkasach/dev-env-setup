#!/usr/bin/env bash
######################################################################
# .what = read back every take in a dir, and name the ones that need a hand
#
# .why  = a take is an ARCHIVE. the question a human asks of it is not "what
#   files are here" — `ls` answers that — but the three `ls` cannot:
#     1. how long is each, and did the mic actually hear a sound?
#     2. which of them were CUT mid-flight and still owe a `header.set`?
#     3. which have no title yet, so future-you cannot tell them apart?
#
# .why it reads the SIDECAR and the WAV, never one alone
#   the sidecar carries what a human declared (purpose, title) and what the
#   recorder measured at close (seconds, peak). the wav carries the truth of
#   what is on disk RIGHT NOW. they disagree exactly when a take was cut, so
#   a read of either alone would report a take that ends early as healthy
#   (`rule.forbid.failhide`)
#
# ⚠️ .why an OPEN take is reported and never repaired here
#   `open` in the sidecar means the recorder never reached its close. that is
#   true of a take still LIVE and of one that crashed, and this skill cannot
#   tell them apart — so it says both and lets the human, who knows whether a
#   take is live, pick. to guess would be a check that cries wolf
#
# usage:
#   rhx audio.record.list                 # the last-used --into/--purpose
#   rhx audio.record.list --purpose <purpose>
#   rhx audio.record.list --into <dir> --purpose <purpose>
#   rhx audio.record.list --all           # every purpose under --into
#
# guarantee:
#   - READ-ONLY. it writes no byte, and never repairs what it reports
#   - exit 0 = every take is healthy · exit 2 = at least one owes a hand
######################################################################

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/audio.record.operations.sh"

__audio_list_help() {
  cat <<'HELP'
🎙️ audio.record.list — read back your takes, and see which need a hand

  usage:
    rhx audio.record.list [--into <dir>] [--purpose <purpose>] [--all]

  options:
    --into      the dir the takes were captured into (remembered between runs)
    --purpose   which set of takes to read          (remembered between runs)
    --all       read every purpose under --into, not one

  example:
HELP
  __audio_demo_line
  cat <<'HELP'
    rhx audio.record.list                 # re-uses the last --into/--purpose

  what each mark means:
    ✔   the take is closed, holds audio, and its header is current
    ⚠️   the header is stale — the take was cut, so a player stops it early
    ●   the sidecar says open — the take is live, or it was cut
    ✋   the take holds no audio at all

  exit 0 = every take is healthy · exit 2 = at least one owes a hand
HELP
}

######################################################################
# .what = read one key out of a take's sidecar json
#
# ⚠️ .why jq, and why this SKILL asserts it rather than the bundle
#   `2.1.toolkit` already owns jq, and it dispatches AFTER `1.9.audio` — so
#   for 1.9.audio to assert jq would be a verify that reads state a later
#   bundle writes, which can never hold on a first apply
#   (`define.provision-defect-shapes`, shape 7). a SKILL has no such problem:
#   a human runs it long after the whole tree converged
#
#   and jq rather than a sed: this skill TELLS the human to hand-edit the
#   sidecar to add a title, so its format is theirs to reshape. a hand-rolled
#   parse would break on the very edit the skill invites
######################################################################
__audio_side_get() {
  local side="$1" key="$2"
  jq -r --arg k "$key" '.[$k] // empty' "$side" 2>/dev/null
}

main() {
  __audio_skill_args "$@"
  set -- "${AUDIO_SKILL_ARGS[@]+"${AUDIO_SKILL_ARGS[@]}"}"

  local into="" purpose="" all=0 into_given=0 purpose_given=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --into)    into="${2:-}";    into_given=1;    shift 2 ;;
      --purpose) purpose="${2:-}"; purpose_given=1; shift 2 ;;
      --all)     all=1; shift ;;
      --help|-h) __audio_list_help; return 0 ;;
      *)
        echo "✋ unknown arg: $1" >&2
        echo "   fix: rhx audio.record.list --help" >&2
        return 2
        ;;
    esac
  done

  if ! command -v jq >/dev/null 2>&1; then
    echo "✋ jq is absent, and the sidecars are json" >&2
    echo "   ⇒ it is owned by the toolkit bundle, so the fix is a provision" >&2
    echo "   fix: rhx grove.provision --what 2.1.toolkit --mode apply" >&2
    return 2
  fi

  # recall the last-used pair, from outside the repo
  local state="$AUDIO_RECORD_STATE_DIR/last.env"
  if [[ -f "$state" ]]; then
    # shellcheck source=/dev/null
    source "$state"
    [[ -z "$into"    ]] && into="${AUDIO_LAST_INTO:-}"
    [[ -z "$purpose" ]] && purpose="${AUDIO_LAST_PURPOSE:-}"
  fi

  ####################################################################
  # ⚠️ the SAME decision the writer makes — `__audio_into_decide` is the one
  #    holder, because a reader that decides `--into` its own way answers about
  #    a different dir than the one the take landed in, and says so as though
  #    the take were absent
  ####################################################################
  __audio_into_decide "$into" "$into_given" "$purpose" "$purpose_given" "$SCRIPT_DIR"
  into="$AUDIO_INTO"; into_given="$AUDIO_INTO_GIVEN"

  if [[ -z "$into" ]]; then
    echo "✋ --into is required until one take has been captured" >&2
    echo "   ⇒ after one run it is remembered, so a later read needs no flags" >&2
    echo "   fix:" >&2
    __audio_demo_line '     ' >&2
    return 2
  fi

  ####################################################################
  # ⚠️ a REMEMBERED dir the writer would refuse is reported as such, rather
  #    than read. `open` refuses a scratch dir, so a recalled scratch dir names
  #    a place no take can be captured into — and "no such dir" would blame the
  #    archive for a stale memory
  ####################################################################
  local scratch_why
  if [[ "$into_given" -eq 0 ]] && scratch_why="$(__audio_dest_scratch_why "$into")"; then
    echo "✋ the remembered dir is not a place a take can be kept — $scratch_why" >&2
    echo "     $into" >&2
    echo "   ⇒ so audio.record.start refuses it too. the memory is stale, not the archive" >&2
    echo "   fix: name the archive dir once, and it is remembered from then on —" >&2
    __audio_demo_line '     ' >&2
    return 2
  fi

  ####################################################################
  # 1. name the dirs to read
  ####################################################################
  local dirs=()
  if [[ "$all" -eq 1 ]]; then
    local d
    for d in "$into"/*/; do
      [[ -d "$d" ]] || continue
      dirs+=("${d%/}")
    done
  else
    if [[ -z "$purpose" ]]; then
      echo "✋ --purpose is required unless you pass --all" >&2
      echo "   fix: rhx audio.record.list --all" >&2
      return 2
    fi
    dirs+=("$into/$purpose")
  fi

  if [[ "${#dirs[@]}" -eq 0 ]]; then
    echo "✋ no take dirs under $into" >&2
    echo "   ⇒ capture one first:" >&2
    __audio_demo_line '     ' >&2
    return 2
  fi

  echo ""
  echo "🎙️ audio.record.list"

  ####################################################################
  # 2. read each take — the sidecar AND the wav, never one alone
  ####################################################################
  local takes=0 owed=0 total=0 total_bytes=0
  local dir side stamp base take title status secs peak human mark note drift bytes bps

  for dir in "${dirs[@]}"; do
    if [[ ! -d "$dir" ]]; then
      echo "   ├─ ✋ no such dir: $dir"
      owed=$(( owed + 1 ))
      continue
    fi

    echo "   ├─ ${dir/#$HOME/\~}"

    local found=0
    for side in "$dir"/*.json; do
      [[ -f "$side" ]] || continue
      found=1
      takes=$(( takes + 1 ))

      base="${side%.json}"
      take="$base.wav"
      stamp="$(__audio_side_get "$side" opened)"
      title="$(__audio_side_get "$side" title)"
      status="$(__audio_side_get "$side" status)"
      [[ -z "$stamp" ]] && stamp="$(basename "$base")"

      # the WAV is the truth of what is on disk right now
      if [[ ! -f "$take" ]]; then
        echo "   │  ├─ ✋ $stamp · the sidecar has no wav beside it"
        owed=$(( owed + 1 ))
        continue
      fi

      bytes="$(wc -c <"$take")"
      # ⚠️ each take's OWN width, never the config's. this archive spans both:
      #    takes captured before 2026-09-07 are s16, every take after is s32
      bps="$(__audio_bytes_per_sample_of "$take")" || bps=0
      secs="$(__audio_seconds_of "$(__audio_pcm_bytes_of "$take")" "$bps")"
      human="$(__audio_duration_human "$secs")"
      total=$(( total + secs ))
      total_bytes=$(( total_bytes + bytes ))

      if [[ "$secs" -eq 0 ]]; then
        echo "   │  ├─ ✋ $stamp · holds no audio at all"
        echo "   │  │     ⇒ read why: rhx audio.record.probe --play"
        owed=$(( owed + 1 ))
        continue
      fi

      peak="$(__audio_peak_of "$take" 2>/dev/null)" || peak="?"

      ##################################################################
      # the sidecar and the wav disagree exactly when a take was cut, and
      # the PAIR says more than either alone
      #
      # 🛑 .the one inference that is sound here
      #   a LIVE take always has a stale header — pw-record sets the two size
      #   fields at open and revises them only at close. so:
      #     open + stale   = live NOW, or cut and unrepaired → a human must say
      #     open + CURRENT = cut, then repaired. a live take cannot reach this
      #   ⇒ that second row is why a repaired take goes quiet, even though
      #     `header.set` writes no sidecar (it touches four bytes, by contract)
      ##################################################################
      __audio_header_drifted "$take"; drift=$?   # 0 drifted · 1 current · 2 unreadable

      mark="✔"; note=""
      if [[ "$drift" -eq 2 ]]; then
        mark="✋"
        note="the wav's header could not be read at all — it is not a 44-byte-header wav"
        owed=$(( owed + 1 ))
      elif [[ "$status" == "open" && "$drift" -eq 0 ]]; then
        mark="●"
        note="open, header stale — live NOW, or cut and unrepaired. if no take is live: rhx audio.record.header.set --take '$take' --mode apply"
        owed=$(( owed + 1 ))
      elif [[ "$drift" -eq 0 ]]; then
        mark="⚠️"
        note="header is stale, so a player stops it early. fix: rhx audio.record.header.set --take '$take' --mode apply"
        owed=$(( owed + 1 ))
      fi

      if [[ -n "$title" ]]; then
        echo "   │  ├─ $mark $stamp · $human · $(__audio_size_human "$bytes") · peak $peak · \"$title\""
      else
        echo "   │  ├─ $mark $stamp · $human · $(__audio_size_human "$bytes") · peak $peak · 🌙 no title yet"
      fi
      [[ -n "$note" ]] && echo "   │  │     ⇒ $note"
    done

    [[ "$found" -eq 0 ]] && echo "   │  └─ 🌙 no takes here yet"
  done

  ####################################################################
  # 3. the tally — and the one ask that keeps an archive findable
  ####################################################################
  echo "   │"
  echo "   ├─ $takes take(s) · $(__audio_duration_human "$total") captured · $(__audio_size_human "$total_bytes") on disk"

  if [[ "$owed" -gt 0 ]]; then
    echo "   └─ ✋ $owed need a hand — see the ⇒ lines above"
    return 2
  fi

  echo "   └─ ✔ every take is closed, holds audio, and its header is current"
  echo ""
  echo "   🌙 a take with no title is one you will not find in ten years."
  echo "      set it in the sidecar's \"title\" field, beside the wav."
  return 0
}

main "$@"

#!/usr/bin/env bash
######################################################################
# .what = hand an audio file to this desktop's own player
#
# .why  = a take is captured to be HEARD. `audio.record.list` says a take holds
#   audio and `audio.record.probe` says the mic was live — neither is the same
#   claim as "a human listened to it and it was there". this is the skill that
#   closes that gap, and it is the last check no meter can stand in for
#
# 🛑 .why a SKILL and not `xdg-open <path>`
#   `rule.forbid.adhoc-shell`. the raw call was typed once, and it hides three
#   faults a human then diagnoses by hand every time:
#     · the path is a directory, or has no file behind it
#     · the wav's header is STALE, so a player stops it early and the take
#       reads as truncated when every byte is on disk
#     · this box declares no audio handler at all, so the open silently no-ops
#   ⇒ each is a real cause with a different fix, and each is checked here
#
# ⚠️ .why the app is READ and never named
#   the desktop holds the answer as a mime default the human can change. a
#   hardcoded player is a second declaration of a fact the box owns — see
#   `__audio_player_declared` for the full reason
#
# usage:
#   rhx audio.listen --take <path>       # hand it to the desktop player
#   rhx audio.listen                     # the newest take of the last archive
#   rhx audio.listen --purpose demo      # the newest take of one purpose
#   rhx audio.listen --with cli          # play in the terminal, no window
#   rhx audio.listen --what              # name the player, open no window
#
# guarantee:
#   - READ-ONLY on the take. it plays; it never repairs and never re-encodes
#   - exit 0 = handed to a player · exit 2 = it could not be
######################################################################

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/audio.record.operations.sh"

__audio_listen_help() {
  cat <<'HELP'
🎧 audio.listen — hear a take back, in this desktop's own player

  usage:
    rhx audio.listen [--take <path>] [--into <dir>] [--purpose <purpose>]
                     [--with desktop|cli] [--what]

  options:
    --take      the file to play. absent = the NEWEST take of the archive
    --into      the archive dir       (remembered between runs)
    --purpose   which set of takes    (remembered between runs)
    --with      desktop (default) opens a window · cli plays in the terminal
    --what      name the player this box declares, and open no window

  .why  a meter proves the mic heard sound. only an ear proves the take is
        the conversation you meant to keep.

  example:
    rhx audio.listen                     # the last take, in the desktop player
    rhx audio.listen --purpose demo      # the newest demo take
    rhx audio.listen --what              # which app would open it

  exit 0 = handed to a player · exit 2 = it could not be
HELP
}

######################################################################
# .what = the newest take under a dir, by name
#
# ⚠️ .why by NAME and not by mtime
#   a take's filename carries its opened stamp, so name order IS time order —
#   and it survives a copy, a sync, and a restore, each of which rewrites
#   mtime. a Dropbox sync alone would reorder an archive read by mtime
######################################################################
__audio_listen_newest() {
  local dir="$1" f newest=""
  for f in "$dir"/*.wav; do
    [[ -f "$f" ]] || continue
    [[ "$f" > "$newest" ]] && newest="$f"
  done
  [[ -n "$newest" ]] && echo "$newest"
}

main() {
  __audio_skill_args "$@"
  set -- "${AUDIO_SKILL_ARGS[@]+"${AUDIO_SKILL_ARGS[@]}"}"

  local take="" into="" purpose="" with="desktop" what=0
  local into_given=0 purpose_given=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --take)    take="${2:-}"; shift 2 ;;
      --into)    into="${2:-}";    into_given=1;    shift 2 ;;
      --purpose) purpose="${2:-}"; purpose_given=1; shift 2 ;;
      --with)    with="${2:-}"; shift 2 ;;
      --what)    what=1; shift ;;
      --help|-h) __audio_listen_help; return 0 ;;
      *)
        echo "✋ unknown arg: $1" >&2
        echo "   fix: rhx audio.listen --help" >&2
        return 2
        ;;
    esac
  done

  case "$with" in
    desktop|cli) ;;
    *)
      echo "✋ --with takes 'desktop' or 'cli', never '$with'" >&2
      echo "   fix: rhx audio.listen --with desktop" >&2
      return 2
      ;;
  esac

  ####################################################################
  # 1. name the take — given, or the newest of the remembered archive
  ####################################################################
  if [[ -z "$take" ]]; then
    local state="$AUDIO_RECORD_STATE_DIR/last.env"
    if [[ -f "$state" ]]; then
      # shellcheck source=/dev/null
      source "$state"
      [[ -z "$into"    ]] && into="${AUDIO_LAST_INTO:-}"
      [[ -z "$purpose" ]] && purpose="${AUDIO_LAST_PURPOSE:-}"
    fi

    # ⚠️ the SAME decision the writer makes, so a demo take is findable by the
    #    reader that plays it (`__audio_into_decide` carries the measurement)
    __audio_into_decide "$into" "$into_given" "$purpose" "$purpose_given" "$SCRIPT_DIR"
    into="$AUDIO_INTO"

    if [[ -z "$into" || -z "$purpose" ]]; then
      echo "✋ name a take, or capture one so an archive is remembered" >&2
      echo "   fix: rhx audio.listen --take <path>" >&2
      echo "     or:" >&2
      __audio_demo_line '       ' >&2
      return 2
    fi

    if [[ ! -d "$into/$purpose" ]]; then
      echo "✋ no such archive dir: $into/$purpose" >&2
      echo "   fix: read what is there — rhx audio.record.list --all" >&2
      return 2
    fi

    take="$(__audio_listen_newest "$into/$purpose")"
    if [[ -z "$take" ]]; then
      echo "✋ '$into/$purpose' holds no take to play" >&2
      echo "   fix: rhx audio.record.list --all" >&2
      return 2
    fi
  fi

  take="${take/#\~/$HOME}"

  if [[ -d "$take" ]]; then
    echo "✋ '$take' is a dir, and a dir cannot be played" >&2
    echo "   fix: name the file, or let this skill pick the newest —" >&2
    echo "     rhx audio.listen --into '$take' --purpose <purpose>" >&2
    return 2
  fi

  if [[ ! -f "$take" ]]; then
    echo "✋ no such take: $take" >&2
    echo "   fix: read what is there — rhx audio.record.list --all" >&2
    return 2
  fi

  echo ""
  echo "🎧 audio.listen"
  echo "   ├─ take:   ${take/#$HOME/\~}"

  ####################################################################
  # 2. the ONE fault a player cannot report itself
  #
  # 🛑 a stale header makes a whole take read as truncated
  #   pw-record writes the two size fields at OPEN and revises them at close,
  #   so a take that was cut carries a header that describes a shorter file
  #   than the one on disk. every player believes the header — so a 40-minute
  #   conversation plays for 4 seconds and a human concludes it was lost.
  #
  #   ⇒ that is the most expensive false alarm this family can produce, and it
  #     is knowable BEFORE the window opens. so it is checked here, and it is
  #     reported rather than repaired: `header.set` is a WRITE, and this
  #     skill's contract is read-only (`rule.require.get-set-gen-verbs`)
  ####################################################################
  local pcm secs bytes drift bps
  bytes="$(wc -c <"$take")"
  pcm="$(__audio_pcm_bytes_of "$take")"
  # ⚠️ the take's OWN width — an archive spans formats, and a take measured at
  #    the wrong one reports half or double its true duration
  bps="$(__audio_bytes_per_sample_of "$take")" || bps=0
  secs="$(__audio_seconds_of "$pcm" "$bps")"

  echo "   ├─ holds:  $(__audio_duration_human "$secs") · $(__audio_size_human "$bytes") on disk"

  if [[ "$secs" -eq 0 ]]; then
    echo "   └─ ✋ this take holds no audio at all" >&2
    echo "      ⇒ read why the mic gave none: rhx audio.record.probe --play" >&2
    return 2
  fi

  __audio_header_drifted "$take"; drift=$?   # 0 drifted · 1 current · 2 unreadable
  if [[ "$drift" -eq 0 ]]; then
    echo "   ├─ ⚠️ the header is STALE, so a player will stop it early"
    echo "   │     every byte is on disk — the header simply describes a"
    echo "   │     shorter file than the one it sits on"
    echo "   │     fix it first, then listen:"
    echo "   │       rhx audio.record.header.set --take '$take' --mode apply"
  fi

  ####################################################################
  # 3. name the player — and let `--what` stop here
  ####################################################################
  local mime player opener
  mime="$(__audio_mime_of "$take")"
  player="$(__audio_player_declared "$mime")"
  opener="$(__audio_opener_get)"

  echo "   ├─ mime:   $mime"
  echo "   ├─ player: ${player:-🌙 this box declares none for $mime}"

  if [[ "$what" -eq 1 ]]; then
    echo "   └─ ✔ named only — no window was opened (--what)"
    return 0
  fi

  ####################################################################
  # 4. play it
  ####################################################################
  if [[ "$with" == "cli" ]]; then
    if ! command -v paplay >/dev/null 2>&1; then
      echo "   └─ ✋ paplay is absent, so there is no terminal player" >&2
      echo "      ⇒ it is owned by the audio bundle, so the fix is a provision" >&2
      echo "      fix: rhx grove.provision --what 1.9.audio --mode apply" >&2
      return 2
    fi
    echo "   └─ ● plays in this terminal — ctrl-c to stop"
    paplay "$take" || {
      echo "   ✋ paplay could not play it" >&2
      return 2
    }
    return 0
  fi

  if [[ -z "$opener" ]]; then
    echo "   └─ ✋ this box holds neither gio nor xdg-open, so no window opens" >&2
    echo "      ⇒ play it in the terminal instead:" >&2
    echo "        rhx audio.listen --take '$take' --with cli" >&2
    return 2
  fi

  ####################################################################
  # ⚠️ .why the launch is DETACHED
  #   a player is a window a human keeps open while they listen, and this skill
  #   returns in a second. attached, the window would die with the skill — or
  #   worse, hold the shell for the length of the conversation
  #
  # ⚠️ and why its output is discarded: a gtk app writes theme and portal
  #    warnings to stderr on a HEALTHY launch, and those would read as this
  #    skill's own failure (`gotcha.a-check-that-cries-wolf-gets-silenced`)
  ####################################################################
  if [[ "$opener" == "gio" ]]; then
    setsid gio open "$take" >/dev/null 2>&1 &
  else
    setsid xdg-open "$take" >/dev/null 2>&1 &
  fi
  disown 2>/dev/null || true

  echo "   └─ ✔ handed to ${player:-the desktop} via $opener"
  echo ""
  echo "   ⚠️ handed off is NOT heard. if no window appeared, this box's mime"
  echo "      default names an app it does not hold — read it with --what,"
  echo "      or play it here instead: rhx audio.listen --with cli"
  return 0
}

main "$@"

#!/usr/bin/env bash
######################################################################
# .what = capture a take, straight into the dir that backs it up
#
# .the four guards it puts around a conversation that cannot be repeated
#   1. it PROBES first, always. a muted or monitor source is refused before a
#      byte is captured, because that failure is silent and only shows up after
#      the conversation is over (`audio.record.probe`)
#   2. it INHIBITS sleep for the duration. the top real cause of a lost take on
#      a laptop is a lid close or an idle suspend — not a crash
#   3. it writes DIRECTLY into the backup dir, under a name it never renames.
#      so every flushed second is already in the path that syncs offsite, and
#      no rename forces a re-upload of the whole take at the worst moment
#   4. it WATCHES the take as it runs and raises a desktop alert if the input
#      goes bit-exact flat or the file stops its growth. a human mid
#      conversation does not watch a terminal, so a toast is the only surface
#      that reaches them
#
# ⚠️ .the watchdog only ever WARNS
#   it never stops the take. a stop would destroy audio to report a suspicion,
#   and a false alarm is certain eventually — so the loud half is the alert and
#   the take carries on regardless
#
# ⚠️ .why the wav's name never changes
#   a `.part` → final rename reads to a sync client as a delete plus a create,
#   which forces a full re-upload of the whole take. so STATUS lives in a small
#   sidecar json that is cheap to rewrite, and the big file is append-only from
#   first byte to last
#
# ⚠️ .why the real --into and --purpose are NOT in this repo
#   they name a real person and a real family, and this repo is PUBLIC
#   (`rule.forbid.dox-in-public-repo`). the last-used pair is remembered under
#   $AUDIO_RECORD_STATE_DIR, which sits outside the checkout
#
# usage:
#   rhx audio.record.start --into ~/Dropbox/<family-dir> --purpose <purpose>
#   rhx audio.record.start                 # re-uses the last --into/--purpose
#
# guarantee:
#   - stop it with ctrl-c. the header is set on the way out, whatever killed it
#   - a take is never overwritten: the name carries a utc timestamp
######################################################################

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/audio.record.operations.sh"

__audio_start_help() {
  cat <<'HELP'
🎙️ audio.record.start — capture a take, straight into the dir that backs it up

  usage:
    rhx audio.record.start --into <dir> --purpose <purpose> [--source <name>]

  options:
    --into      the dir to capture into    (remembered between runs)
    --purpose   what this set of takes is  (remembered between runs)
    --source    the capture source         (default: the box's default source)
    --anyway    capture even if the probe refuses — see the warn it prints

  example:
HELP
  __audio_demo_line
  cat <<'HELP'

  it probes the mic first, every time. a muted or monitor source is refused
  before a byte is captured, because that failure is silent and shows up only
  after the conversation is over.

  stop with ctrl-c. the header is set on the way out, whatever killed it.
HELP
}

######################################################################
# .what = warn, out loud, when the take goes flat or stops its growth —
#         and, on the way past, keep the peak max the seal will want
# .why  = the human is mid conversation and reads no terminal
#
# 🛑 .why the PEAK is a byproduct here rather than a job of its own
#
# 📜 measured 2026-09-07: a 58-minute take's seal ran 76 SECONDS after the shell
#    prompt had returned. every one of those seconds was a full-file peak scan —
#    ~690 MB and ~168 million samples through `od` into `awk`, to learn one
#    number. the human's read was *"it just took forever to come through"*.
#
# ⇒ and this loop ALREADY read the take every 60s to test for silence, then
#   threw each result away. so the expensive scan re-computed, in one pass at
#   the end, a fact this loop had held piecewise the whole time.
#
# ⇒ the repair is at cause (`rule.require.solve-at-cause`): keep the max, write
#   it beside its byte count, and the seal's peak becomes a FILE READ. no new
#   scan, no new read of the take, one comparison per tick
#
# ⚠️ the range is `last → EOF`, never a fixed 60s window. a window can leave a
#    gap between ticks — and a gap in a MAX is a peak that under-reports, which
#    is the one direction this number must never be wrong in. `last` is where
#    the previous tick stopped, so every byte is read exactly once
#
# ⚠️ `seen` records `pcm`, which is what the tick MEASURED, not where the read
#    ran to — the file grows while the read runs, so `__audio_peak_of` covers a
#    little past `pcm`. an under-report of `seen` makes the seal re-scan a
#    slightly longer tail; to over-report it would make the seal skip audio
#    nobody ever read
######################################################################
__audio_watch() {
  local take="$1"
  # the width is passed in, read ONCE by the caller — a re-read per tick would
  # cost an od every 60s to learn a fact that cannot change mid-take
  local bps="${2:-2}"
  # where the max is left for the seal. absent → the seal falls back to a full
  # scan, which is correct and slow rather than fast and wrong
  local progress="${3:-}"
  local last=0 flat=0 max=0 pcm peak

  while sleep 60; do
    [[ -f "$take" ]] || return 0
    pcm="$(__audio_pcm_bytes_of "$take")"

    if [[ "$pcm" -le "$last" ]]; then
      notify-send -u critical "🎙️ the take stopped" \
        "no new audio in 60s — the recorder may be dead. the audio so far is safe." 2>/dev/null || true
      return 0
    fi

    peak="$(__audio_peak_of "$take" $(( AUDIO_RECORD_HEADER_BYTES + last )) 2>/dev/null)" || peak=1

    if [[ "$peak" -le "$AUDIO_RECORD_PEAK_DEAD" ]]; then
      flat=$(( flat + 1 ))
      if [[ "$flat" -ge 3 ]]; then
        notify-send -u critical "🎙️ the mic went dead" \
          "3 minutes of bit-exact silence — check the mic. the take is still open." 2>/dev/null || true
        flat=0
      fi
    else
      flat=0
    fi

    [[ "$peak" -gt "$max" ]] && max="$peak"
    last="$pcm"

    # written EVERY tick, never once at the end — this loop is killed by the
    # same trap that ends the take, so it never reaches an end of its own
    [[ -n "$progress" ]] && printf '%s %s\n' "$max" "$last" >"$progress"
  done
}

######################################################################
# .what = a live level meter, redrawn in place on ONE line
#
# .why  = the probe proves the mic hears sound BEFORE a take, and says no word
#         about the 90 minutes after. a human sat with their grandmother needs
#         to see, at a glance, that the take still picks her up — without a
#         scroll of output between them and the conversation
#
# 🛑 .why it reads the WAV and never opens a second capture stream
#   a second `pw-record` on the same source would measure the mic. this measures
#   the BYTES ON DISK, which is a strictly stronger claim: it proves the take
#   itself holds sound, so a recorder that is alive-but-writes-silence cannot
#   show a healthy meter. it also adds no rival reader to the audio graph at the
#   one moment a take cannot be re-made
#
# ⚠️ .why the tty test is NOT `rule.forbid.tty-as-a-proxy-for-a-human`
#   that rule forbids a tty test as a proxy for "a human is here" — to decide
#   whether to prompt. this asks a different and literal question: does this
#   stream understand a carriage return and an erase-line? a redraw into a log
#   file writes control bytes nobody can read. the tty IS the subject here,
#   never a stand-in for one
#
# ⚠️ it only ever DRAWS. the watchdog owns every alert, so a meter that dies
#    costs a display and no guarantee
######################################################################
__audio_meter() {
  local take="$1"
  local bps="${2:-2}"
  # a quarter second of pcm — long enough to catch a syllable, short enough
  # that the read stays constant-time as the take grows to gigabytes
  local window=$(( AUDIO_RECORD_RATE * AUDIO_RECORD_CHANNELS * bps / 4 ))
  local pcm from peak bar secs size note

  while sleep 0.5; do
    [[ -f "$take" ]] || return 0
    pcm="$(__audio_pcm_bytes_of "$take")"
    [[ "$pcm" -gt 0 ]] || continue

    from=$(( pcm - window ))
    [[ "$from" -lt 0 ]] && from=0
    peak="$(__audio_peak_of "$take" $(( AUDIO_RECORD_HEADER_BYTES + from )) 2>/dev/null)" || peak=0

    bar="$(__audio_meter_bar "$peak" 22)"
    secs="$(__audio_duration_human "$(__audio_seconds_of "$pcm" "$bps")")"
    size="$(__audio_size_human "$pcm")"

    note=""
    if   [[ "$peak" -le "$AUDIO_RECORD_PEAK_DEAD" ]]; then note="  ✋ SILENT"
    elif [[ "$peak" -ge "$AUDIO_RECORD_PEAK_CLIP" ]]; then note="  ⚠️ CLIP"
    elif [[ "$peak" -lt "$AUDIO_RECORD_PEAK_THIN" ]]; then note="  ⚠️ thin"
    fi

    # \r returns to column 0, \033[2K erases the whole line — so a shorter
    # render can never leave the tail of a longer one behind it
    printf '\r\033[2K   ● %-8s · %-9s · %s %5s%s' "$secs" "$size" "$bar" "$peak" "$note"
  done
}

main() {
  __audio_skill_args "$@"
  set -- "${AUDIO_SKILL_ARGS[@]+"${AUDIO_SKILL_ARGS[@]}"}"

  local into="" purpose="" source="" anyway=0
  local into_given=0 purpose_given=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --into)    into="${2:-}"; into_given=1; shift 2 ;;
      --purpose) purpose="${2:-}"; purpose_given=1; shift 2 ;;
      --source)  source="${2:-}"; shift 2 ;;
      --anyway)  anyway=1; shift ;;
      --help|-h) __audio_start_help; return 0 ;;
      *)
        echo "✋ unknown arg: $1" >&2
        echo "   fix: rhx audio.record.start --help" >&2
        return 2
        ;;
    esac
  done

  # recall the last-used pair, from outside the repo
  local state="$AUDIO_RECORD_STATE_DIR/last.env"
  if [[ -f "$state" ]]; then
    # shellcheck source=/dev/null
    source "$state"
    [[ -z "$into"    ]] && into="${AUDIO_LAST_INTO:-}"
    [[ -z "$purpose" ]] && purpose="${AUDIO_LAST_PURPOSE:-}"
  fi

  __audio_into_decide "$into" "$into_given" "$purpose" "$purpose_given" "$SCRIPT_DIR"
  into="$AUDIO_INTO"; into_given="$AUDIO_INTO_GIVEN"
  local demo="$AUDIO_INTO_DEMO"

  if [[ -z "$into" && "$demo" -eq 1 ]]; then
    echo "✋ --purpose demo defaults into this repo's cache dir, and this is no checkout" >&2
    echo "   fix: name a dir — rhx audio.record.start --into <dir> --purpose demo" >&2
    return 2
  fi

  if [[ -z "$into" || -z "$purpose" ]]; then
    echo "✋ --into and --purpose are both required on a first run" >&2
    echo "   ⇒ after one run they are remembered, so a later take needs no flags" >&2
    echo "   fix:" >&2
    __audio_demo_line '     ' >&2
    return 2
  fi

  ####################################################################
  # 0. the destination must be an ARCHIVE, never scratch
  #
  # ⚠️ this runs BEFORE the probe on purpose. the probe costs 3 seconds and a
  #    capture stream, and a wrong destination is knowable with neither
  ####################################################################
  local scratch_why
  if scratch_why="$(__audio_dest_scratch_why "$into")"; then
    echo "✋ '$into' is not a place to keep a take — $scratch_why" >&2
    if [[ "$into_given" -eq 0 ]]; then
      echo "   ⇒ and it was REMEMBERED from a previous run, never asked for here." >&2
      echo "     a single test run re-points every later take at the test's dir," >&2
      echo "     silently. that is why this refuses rather than warns" >&2
    fi
    echo "   fix: name the archive dir explicitly, once —" >&2
    __audio_demo_line '     ' >&2
    echo "   it is remembered after that, so later takes need no flags" >&2
    return 2
  fi

  ####################################################################
  # 1. the probe — unconditional, and the whole reason this skill exists
  ####################################################################
  local probe_args=(--within 3)
  [[ -n "$source" ]] && probe_args+=(--source "$source")

  if ! bash "$SCRIPT_DIR/audio.record.probe.sh" "${probe_args[@]}"; then
    if [[ "$anyway" -eq 0 ]]; then
      echo "" >&2
      echo "✋ the probe refused, so no take was started" >&2
      echo "   ⇒ fix what it named above, then re-run. a take against a dead" >&2
      echo "     input is a large file of silence you find out about too late" >&2
      echo "   override, if you truly mean to: --anyway" >&2
      return 2
    fi
    echo ""
    echo "⚠️ --anyway: the probe refused and the take starts regardless."
    echo "   this may capture silence. you accepted that."
  fi

  ####################################################################
  # 2. name the take, and never rename it
  ####################################################################
  local dir="$into/$purpose"
  mkdir -p "$dir" || {
    echo "✋ could not make $dir" >&2
    return 2
  }

  local stamp take side
  stamp="$(date -u +%Y-%m-%dT%H-%M-%SZ)"
  take="$dir/$purpose.$stamp.wav"
  side="$dir/$purpose.$stamp.json"

  [[ -z "$source" ]] && source="$(__audio_source_default)"

  # ⚠️ a demo writes NO memory. it is the throwaway take, so to remember it
  #    would re-point every later take at a cache dir — the defect the scratch
  #    guard exists to catch, re-introduced through the demo's own convenience
  if [[ "$demo" -eq 0 ]]; then
    mkdir -p "$AUDIO_RECORD_STATE_DIR"
    printf 'AUDIO_LAST_INTO=%q\nAUDIO_LAST_PURPOSE=%q\n' "$into" "$purpose" >"$state"
  fi

  # the sidecar carries the STATUS, so the wav never needs a rename
  #
  # 🛑 `"status": "open"` is NOT a leftover of the old skill name — do not
  #    "finish the rename" here. `start` is the ACT a human performs; `open` is
  #    the STATE the take is left in, and the two are different words for
  #    different concepts (`term=open._.choice._.md`). `audio.record.list` reads
  #    this exact string back to tell a live take from a cut one, so a rename
  #    here would make every extant take read as an unknown status
  printf '{\n  "purpose": "%s",\n  "source": "%s",\n  "rate": %s,\n  "channels": %s,\n  "format": "%s",\n  "opened": "%s",\n  "status": "open",\n  "title": ""\n}\n' \
    "$purpose" "$source" "$AUDIO_RECORD_RATE" "$AUDIO_RECORD_CHANNELS" \
    "$AUDIO_RECORD_FORMAT" "$stamp" >"$side"

  ####################################################################
  # 3. capture, under a sleep inhibit, with a watchdog beside it
  ####################################################################
  echo ""
  echo "🎙️ audio.record.start"
  echo "   ├─ into:    $take"
  # ⚠️ a remembered destination is stated OUT LOUD. it is the one input a human
  #    did not type, so it is the one they cannot check by reading their own
  #    command line
  [[ "$into_given"    -eq 0 ]] && echo "   │           ⤷ dir remembered from a previous run — --into to change"
  [[ "$purpose_given" -eq 0 ]] && echo "   │           ⤷ purpose '$purpose' remembered — --purpose to change"
  echo "   ├─ source:  $source"
  # ⚠️ the DECLARED width, not a read of the take — the take does not exist yet.
  #    this is the one caller for which the config is the subject rather than a
  #    proxy, because we are the party about to determine the file's width
  local bps
  bps="$(__audio_bytes_per_sample_declared)" || bps=2

  # 🛑 the rate is DERIVED, never a constant beside the three values that fix it.
  #    it read `~345 MB/hr` until 2026-09-07 — true of s16, and off by half the
  #    moment the format moved. a hardcoded number next to its own inputs is a
  #    second declaration that no check can redden
  local mb_hr=$(( AUDIO_RECORD_RATE * AUDIO_RECORD_CHANNELS * bps * 3600 / 1000000 ))
  echo "   ├─ format:  ${AUDIO_RECORD_RATE}Hz · ${AUDIO_RECORD_CHANNELS}ch · $AUDIO_RECORD_FORMAT (~${mb_hr} MB/hr)"
  echo "   ├─ sleep:   inhibited for the duration"
  echo "   └─ ● live — ctrl-c to stop"
  echo ""

  # ⚠️ this lives in the STATE dir, never beside the take. the take's dir is a
  #    Dropbox tree, so a per-minute rewrite there would push a sync on every
  #    tick for the whole take — and leave a stray file in an archive whose
  #    whole point is that a human can read it in ten years
  mkdir -p "$AUDIO_RECORD_STATE_DIR"
  local progress="$AUDIO_RECORD_STATE_DIR/peak.$stamp"

  __audio_watch "$take" "$bps" "$progress" &
  local watch_pid=$!

  # the meter is a DISPLAY, so it runs only where a redraw can be read
  #
  # 🛑 .the ABSENT meter is an EMPTY LIST, never the pid 0
  #
  # 📜 measured 2026-09-07, by a re-read of a path no test could reach. this held
  #    `meter_pid=0` and passed it to `kill` — and **`kill 0` signals the whole
  #    PROCESS GROUP**, this shell included. so on any run with no tty the skill
  #    killed itself at the exact moment the take ended, and the seal never ran.
  #
  # ⚠️ the tell was on the page the whole time: every backgrounded demo take died
  #    before the seal printed one line, and both left `"status": "open"` on a
  #    file whose audio was complete. that was read as *"the wrapper dies on
  #    ctrl-c"* — a true sentence about a DIFFERENT defect, which is exactly
  #    `gotcha.a-check-that-cries-wolf-gets-silenced` m.6: a correct explanation
  #    applied to the wrong symptom, so the real cause kept its cover
  #
  # ⇒ so an absent meter contributes NO ARGUMENT rather than a placeholder one.
  #   `${loops[@]}` of a one-element array is one pid; of a two-element array is
  #   two. there is no value of `meter_pid` that means "skip me", because every
  #   integer is a legal `kill` target and 0 is the most dangerous of them
  local loops=("$watch_pid")
  local meter_pid=0
  if [[ -t 1 ]]; then
    __audio_meter "$take" "$bps" &
    meter_pid=$!
    loops+=("$meter_pid")
  fi

  # both loops are killed on EVERY exit path — a clean stop, a ctrl-c, a crash
  # of this shell — so no background loop outlives the take
  #
  # ⚠️ the progress file goes with them. it is scratch state in $HOME, and the
  #    seal's own `rm` is reached only on the happy path — an empty take returns
  #    before it, and a crash never reaches it at all
  # shellcheck disable=SC2064
  trap "kill ${loops[*]} 2>/dev/null || true; rm -f '$progress'" EXIT

  ####################################################################
  # 🛑 .ctrl-c is the SANCTIONED stop, so it must not exit non-zero
  #
  # this skill prints `● live — ctrl-c to stop`. so ctrl-c is not an abort —
  # it is the ONE way a human ends a take, and the seal that follows it is the
  # most important work the skill does.
  #
  # ⚠️ measured 2026-09-06: a human stopped a healthy 16s take and the shell
  #    reported `💥130`. every byte was on disk, the header was already correct,
  #    and the run said `✔ done` one line above the failure code. that is
  #    `rule.forbid.failhide` inverted — a FAILURE reported on a success — and
  #    it is the more corrosive half: a code that cries wolf on the happy path
  #    teaches a human to discount every exit code from this family
  #
  # .the cause: with no INT trap, bash re-raises SIGINT to itself at exit so a
  #   parent shell sees 128+2. a no-op handler makes bash HANDLE the signal
  #   rather than die of it, and the terminal still delivers SIGINT to
  #   pw-record directly (same process group), so the stop is unaffected.
  #
  # ⇒ and it buys a second guarantee worth more than the code: the seal phase
  #   below can no longer be cut in half by a second ctrl-c. a header repair
  #   interrupted mid-write is the one way this skill could damage a take
  ####################################################################
  trap ':' INT

  systemd-inhibit \
    --what=sleep:idle \
    --who="audio.record" \
    --why="a take is open" \
    pw-record \
      --target "$source" \
      --rate "$AUDIO_RECORD_RATE" \
      --channels "$AUDIO_RECORD_CHANNELS" \
      --format "$AUDIO_RECORD_FORMAT" \
      "$take" || true

  # ⚠️ `${loops[@]}`, never a bare `$meter_pid` — see the array's own note above.
  #    a 0 here is a `kill 0`, which takes down this shell before the seal runs
  kill "${loops[@]}" 2>/dev/null || true

  # ⚠️ `kill` only SENDS, so it returns before the watchdog has died — and the
  #    seal is about to read the file that watchdog writes. the window is one
  #    printf out of every 60s, and the failure mode is benign (a short read
  #    fails the regex and the seal falls back to a wider scan), but a `wait`
  #    closes it outright and costs a scheduler tick
  #
  # ⚠️ it is `wait <pid>`, never a bare `wait` — a bare one joins EVERY
  #    background job of this shell, so one child that never exits is a hang
  #    that would wedge the seal on the one take that cannot be re-made
  local loop
  for loop in "${loops[@]}"; do
    wait "$loop" 2>/dev/null || true
  done

  # the meter left the cursor mid-line, so close it before the seal prints
  [[ "$meter_pid" -ne 0 ]] && printf '\r\033[2K'

  ####################################################################
  # 4. SEAL it — and judge the ARTIFACT, never pw-record's exit code
  #
  # measured 2026-09-06: pw-record exits 1 on a run that produced a byte-exact
  # file. so the verdict comes from the take itself
  #
  # 🛑 .the LISTEN line comes FIRST, and that ordering is the whole lesson
  #
  # 📜 measured 2026-09-07 on a 58-minute take: the seal ran 76 SECONDS after
  #    the shell prompt had already redrawn. the human waited the whole minute
  #    and their read was *"it just took forever to come through"*. what they
  #    were waiting FOR was the `hear it:` line — which needs one variable this
  #    skill has held since before the take began, and costs zero to print.
  #
  # ⇒ so the defect was never only that the peak was slow. it was that a
  #   ZERO-COST line a human needs was sequenced BEHIND the most expensive act
  #   in the skill. that ordering is wrong at any speed, so it is fixed first
  #   and independently — the cheap thing a human came for goes at the top
  #
  # ⚠️ every number BELOW that line is a claim about bytes: how many, how loud.
  #    not one says the take holds the conversation a human meant to keep — a
  #    mic aimed at the wrong side of a room clears every check on this page.
  #    the listen is the only act that settles it, so it must not queue behind
  #    the ones that cannot
  #
  # ⇒ `term=audio.record.seal._.choice._.md` carries why this phase is a term
  #   rather than the tail of the last one
  ####################################################################
  local pcm secs peak bps_have
  pcm="$(__audio_pcm_bytes_of "$take")"

  # the empty check runs BEFORE the listen line — a `hear it:` on a zero-byte
  # take is a command that can only disappoint, offered at the worst moment
  if [[ "$pcm" -eq 0 ]]; then
    printf '{\n  "purpose": "%s",\n  "opened": "%s",\n  "status": "empty",\n  "title": ""\n}\n' \
      "$purpose" "$stamp" >"$side"
    echo "✋ the take holds no audio at all" >&2
    echo "   ⇒ read why: rhx audio.record.probe --play" >&2
    return 1
  fi

  ####################################################################
  # 🛑 .EVERY act runs BEFORE the first byte is printed. the block is ATOMIC
  #
  # 📜 measured 2026-09-08 on a real ctrl-c'd take. the seal used to print its
  #    header and `hear it:` line, THEN do its work, THEN print the rest — and
  #    the human's page came back cut in half:
  #
  #      🔒 audio.record.seal
  #         ├─ hear it:  rhx audio.listen --take '…'
  #
  #      dev-env-setup … took 9s
  #      💥130 ➜    ├─ 6s captured · 1.2 MB on disk · peak 1288 / 32767
  #
  # .the cause is a race this skill cannot win by speed:
  #   ctrl-c goes to the whole foreground process group. `trap ':' INT` saves
  #   THIS bash, and the `rhx` node wrapper above it has no such trap — so it
  #   dies at once, the shell reaps it, and the prompt redraws. meanwhile this
  #   bash is still alive and still writes to that same tty.
  #
  # ⇒ so the prompt lands in whatever gap the seal leaves between two writes,
  #   and the work below WAS that gap: a `bash` subprocess for the header plus
  #   two `od` reads, ~100ms with a print on either side of it
  #
  # ⚠️ **the repair is not to make the gap smaller.** the round-11 fix already
  #    cut this phase from 76s to ~100ms and the tear survived it, because the
  #    race is against a process death, which is instant. a smaller gap is a
  #    rarer tear, never no tear — and a defect that shows one run in ten is
  #    worse than one that shows on every run
  #
  # ⇒ the repair is to leave NO gap: compute it all, then emit the whole block
  #   in one write. the prompt can then land before it or after it, and the
  #   page reads correctly either way
  #
  # ⚠️ the round-11 lesson is UNCHANGED — `hear it:` is still the first line
  #    inside the block. cheapest-first is about what a human reads first; this
  #    is about what the terminal can interleave. two different orderings, and
  #    the atomic block is what lets both hold at once
  ####################################################################

  ####################################################################
  # ⚠️ the header repair is KEPT, and it is deliberately not announced
  #
  # 📜 measured 2026-09-07 across every take this archive holds — 9 scratch and
  #    2 archive, two of them killed by a SIGNAL mid-capture — the header was
  #    already exact 11 times out of 11. so `pw-record` maintains the two size
  #    fields as it streams; it does not write them on exit.
  #
  # ⇒ it is kept because its cost is 8 bytes and one seek, and the case it
  #   covers (a kill so abrupt the last header write is lost) is the one nobody
  #   has produced yet — and an unrepeatable take is the wrong place to find out
  #
  # ⇒ it is NOT announced because an 8-byte instant act with its own headline
  #   made the seal read as heavy work. it is a line of code, not a phase
  ####################################################################
  bash "$SCRIPT_DIR/audio.record.header.set.sh" --take "$take" --mode apply >/dev/null || true

  # ⚠️ now the take EXISTS, so the take is the subject again — read its width
  #    rather than reuse the declared one. if pw-record honored a different
  #    format than we asked for, this is where that shows up
  bps_have="$(__audio_bytes_per_sample_of "$take")" || bps_have=0
  secs="$(__audio_seconds_of "$pcm" "$bps_have")"

  # a FILE READ plus a bounded tail — see `__audio_peak_sealed`. this replaced a
  # full-file scan that cost 76s on the take above and 0s on every short one,
  # which is why it went unnoticed until an archive take was made
  peak="$(__audio_peak_sealed "$take" "$progress" "$pcm")" || peak="?"
  rm -f "$progress"

  printf '{\n  "purpose": "%s",\n  "source": "%s",\n  "rate": %s,\n  "channels": %s,\n  "format": "%s",\n  "opened": "%s",\n  "closed": "%s",\n  "seconds": %s,\n  "peak": %s,\n  "status": "done",\n  "title": ""\n}\n' \
    "$purpose" "$source" "$AUDIO_RECORD_RATE" "$AUDIO_RECORD_CHANNELS" \
    "$AUDIO_RECORD_FORMAT" "$stamp" "$(date -u +%Y-%m-%dT%H-%M-%SZ)" \
    "$secs" "$peak" >"$side"

  ####################################################################
  # 🛑 ONE printf. every substitution is resolved into the argument list FIRST,
  #    so no subprocess runs between two writes and the prompt cannot land in
  #    the middle of the block. see the atomic-block note above
  #
  # ⚠️ it is a single `printf`, never a run of `echo`s. bash evaluates every
  #    `$(…)` before the call, so the `wc` and the two `__audio_*_human` reads
  #    happen ahead of the first byte — the very property a run of echoes
  #    cannot have, since each one re-opens the gap the last one closed
  #
  # ⚠️ `%s` for every value, never a value interpolated into the format string.
  #    a take's path is human-named and may hold a `%`, which printf would then
  #    read as a directive and eat the rest of the line
  ####################################################################
  printf '\n🔒 audio.record.seal\n   ├─ hear it:  rhx audio.listen --take '"'"'%s'"'"'\n   ├─ %s captured · %s on disk · peak %s / 32767\n   ├─ take:    %s\n   ├─ sidecar: %s\n   └─ ✔ done — add a title to the sidecar so you can find it in ten years\n\n   🌙 these numbers count BYTES. only an ear says the take holds what\n      you meant to keep — so paste the hear-it line now, while a\n      re-take is still possible.\n' \
    "$take" \
    "$(__audio_duration_human "$secs")" \
    "$(__audio_size_human "$(wc -c <"$take")")" \
    "$peak" \
    "$take" \
    "$side"
  return 0
}

####################################################################
# ⚠️ the exit code is stated EXPLICITLY
#
# `main "$@"` alone leaves the shell's own status to bash, and bash re-raises
# a handled SIGINT at exit. the INT trap above closes that, and this line is
# the clamp: whatever main decided is what the caller sees
####################################################################
main "$@"
exit $?

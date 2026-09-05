#!/usr/bin/env bash
######################################################################
# .what = prove no caller CAPTURES a `--reply` through `rhx`, and MEASURE
#         (never assume) whether the runner puts its own bytes on stdout
#
# 🛑 .the stream contract
#   - `git.grove.send --reply` promises its stdout carries the remote
#     command's own output and no other byte
#   - that promise lets a caller grep the answer, count a tally, or test for
#     an empty reply
#   - `rhx` is a RUNNER; it writes its own `🪨 run solid skill …` banner
#   - a caller that captures `$(rhx git.grove.send … --reply …)` receives
#     the runner's bytes glued to the box's answer
#   - the damage is SILENT, which makes it worth a clamp:
#       · a tally greps a stream that now holds a banner
#       · an EMPTY reply arrives as a NON-empty string, so every `-n "$out"`
#         arm is unreachable and the "the box said none" case never fires
#   - the split is by CALLER, never by taste:
#       a human at a keyboard  → `rhx git.grove.send …`   (the banner is the point)
#       a capture              → `bash "$_grove_ops_send" …`  (bytes are the point)
#
# 📜 2026-09-02 — one transport, three callers, a fix that reached two
#   - round 18 moved `_ask_at` and `_shell_at` off `rhx`
#     (`git.grove.operations.sh:550,679`) and left `_drive`
#     (`git.grove.provision.test.sh`) on it
#   - `_drive` sits inside a function whose own header says *"this helper has
#     the identical shape, so it had the identical defect, and it was fixed
#     alongside rather than left to be found the expensive way"*
#   - true of the 97 repair it was written about; false of this one, in the
#     same function (`gotcha.a-check-that-cries-wolf-gets-silenced`, m.9)
#
# 🛑 .why this play MEASURES the banner rather than assert it
#   - the claim *"rhx writes to stdout"* is a claim about a TOOL THIS REPO
#     DOES NOT OWN
#   - it was true when measured; a runner is free to change it
#   - a rule that forbids the capture would then forbid a safe act
#   - a rule that permits it would then permit an unsafe one
#   - arm 1 asks the runner, live, on this box
#   - the verdict below is that answer, not a remembered one
#     (`rule.require.trust-but-verify`, `gotcha.my-own-note-became-my-evidence`)
#
# .what it does to the box
#   - runs ONE harmless read-only skill, reads tracked files
#   - no write, no network, no remote reach — needs no grove, no credential
#
# guarantee:
#   - arm 1 is a live measurement; a runner that cannot be reached is a
#     DECLINE, never a pass
#   - arm 2 discovers its subjects, so a fourth capture is caught the day it
#     is written
#   - a comment that NAMES the forbidden shape is not the shape (m.7)
#
# usage:
#   rhx play.run --play prove.reply-captures-bypass-the-runner
#
# exit:
#   0 = no `--reply` capture rides the runner
#   1 = at least one does
#   2 = the subject could not be read, so no claim was proven
######################################################################

set -uo pipefail

echo "🔎 prove.reply-captures-bypass-the-runner"
echo "   └─ subject: every capture of git.grove.send --reply"
echo ""

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo "")"
if [[ -z "$ROOT" ]]; then
  echo "   └─ 🌙 not inside a git checkout, so the subject tree is unnamed" >&2
  exit 2
fi
cd "$ROOT" || exit 2

######################################################################
# .what = 1. MEASURE the runner — does it put its own bytes on stdout?
#
# .why
#   - `globsafe` is read-only, needs no credential
#   - its own stdout for a no-match pattern is short and predictable
#   - the pattern cannot match, so whatever arrives is the RUNNER's
#     contribution plus the skill's own "no matches" page
#   - stderr is DISCARDED on purpose: the contract is about stdout
#   - a caller's `$( )` captures stdout alone, so stderr cannot corrupt a
#     capture and is irrelevant to this claim
######################################################################
if ! command -v rhx >/dev/null 2>&1; then
  echo "   └─ 🌙 rhx is absent, so the runner's stream cannot be measured" >&2
  echo "      · this play's whole verdict rests on that measurement" >&2
  exit 2
fi

RUNNER_OUT="$(rhx globsafe --pattern 'zz-no-such-file-zz/**' 2>/dev/null || true)"
BANNER_ON_STDOUT=0
grep -q 'run solid skill' <<<"$RUNNER_OUT" && BANNER_ON_STDOUT=1

if [[ "$BANNER_ON_STDOUT" -eq 1 ]]; then
  echo "   ├─ runner: ✔ MEASURED — rhx writes its banner to STDOUT"
  echo "   │           so any \$( rhx … ) capture is corrupted"
else
  echo "   ├─ runner: 🌙 rhx did NOT put its banner on stdout on this box"
  echo "   │           the capture below may be harmless HERE and is still"
  echo "   │           forbidden: the runner's stream is not ours to depend on"
fi
echo "   │"

######################################################################
# .what = 2. find every CAPTURE of a --reply
#
# .why
#   - a capture is `$(` … `git.grove.send` … `--reply`
#   - the send may be spelled `rhx git.grove.send` or
#     `bash "$_grove_ops_send"`
#   - only the first is the defect, so the walk finds BOTH and classifies
######################################################################
CAPTURES=0
FAILED=0

while IFS= read -r hit; do
  file="${hit%%:*}"
  rest="${hit#*:}"
  lineno="${rest%%:*}"
  text="${rest#*:}"

  # prose is not code (m.7)
  trimmed="${text#"${text%%[![:space:]]*}"}"
  case "$trimmed" in ''|'#'*) continue ;; esac

  CAPTURES=$((CAPTURES + 1))
  case "$text" in
    *'rhx git.grove.send'*)
      FAILED=$((FAILED + 1))
      echo "   ├─ ✋ $file:$lineno"
      echo "   │     captures a --reply THROUGH the runner"
      echo "   │     · fix: bash \"\$_grove_ops_send\" <seat> --reply …"
      ;;
    *)
      echo "   ├─ ✔ $file:$lineno"
      echo "   │     captures a --reply, and bypasses the runner"
      ;;
  esac
done < <(grep -rn --include='*.sh' -E '\$\(.*git\.grove\.send.*--reply|\$\(.*_grove_ops_send.*--reply' . 2>/dev/null)

if [[ "$CAPTURES" -eq 0 ]]; then
  echo "   └─ 🌙 no --reply capture found anywhere in this tree" >&2
  echo "      · the family moved, or this walk went blind" >&2
  echo "      · a clean page over an empty set proves no claim" >&2
  exit 2
fi

echo "   │"
echo "   ├─ captures found: $CAPTURES"

######################################################################
# 3. the verdict
######################################################################
if [[ "$FAILED" -gt 0 ]]; then
  echo "   └─ ✋ $FAILED capture(s) ride the runner" >&2
  echo "      · the box's answer arrives with the runner's bytes glued to it" >&2
  echo "      · an EMPTY reply then reads as non-empty, so that arm goes dead" >&2
  exit 1
fi

echo "   └─ ✔ every --reply capture bypasses the runner"
exit 0

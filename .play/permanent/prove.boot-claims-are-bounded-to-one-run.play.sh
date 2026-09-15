#!/usr/bin/env bash
######################################################################
# .what = prove `git.grove.provision boot` reports only the claims of the run
#         it just drove, and never a prior run's
#
# 🛑 .the defect this clamps
#   - `git.grove.send --detach` writes `>> "$LOG"`, so ONE path on the box
#     accumulates every apply that box ever ran
#   - that is correct for the send: a detached job must not clobber a log
#     another reader holds
#   - ⇒ so every UNBOUNDED read in the boot is a claim about the wrong run
#
# 📜 2026-09-14 — the measurement that found it
#   - `git.grove.auth.keys.set` placed 8 keys and the grove read each one back
#   - the boot then reported all 8 as `the rack hands over an EMPTY value`
#   - one claim, two readers, and the boot read an OLDER apply
#     (`gotcha.a-check-that-cries-wolf-gets-silenced`, m.9)
#   - the tell was two lines that CANNOT come from a current run:
#       · `the rack names no profile for ehmpathy.demo.AWS_PROFILE`, which the
#         current `5.13.reach` verify cannot reach
#       · a tmux TERM claim proven green on that box hours earlier
#
# 🛑 .the FALSE ✔ is the worse half, and it had not fired yet
#   - the boot polls `tail -4` twenty seconds after the send
#   - before the new apply has written four lines, that tail carries the PRIOR
#     run's terminal line
#   - ⇒ a box whose last apply ended `🌲 grove.provision done` reports
#     `✔ converged in ~0m` for a run that had just begun
#   - arm 1's second fixture is the only place that face is exercised, since a
#     healthy box hides it behind a fast first write
#
# .the three arms, and why NO ONE of them alone settles it
#   - arm 1 is a FIXTURE: it builds a two-run log and watches the slice
#     discriminate. it proves the MECHANISM and says none of what the boot does
#   - arm 2 is a LIVE read of the boot's own source. it proves the boot REACHES
#     that mechanism and says none of whether the mechanism works
#   - arm 3 reads the slice as a HUMAN receives it — a bound that works over the
#     wire and collides in a fix-text is a repair a human cannot perform
#   - ⇒ read all three in the same run; accept no one of them alone
#     (`gotcha.a-check-that-cries-wolf-gets-silenced`, q10)
#
# .what it does to the box
#   - arm 1 writes ONLY inside its own `mktemp -d`, and removes it on exit
#   - arms 2 and 3 read one tracked file
#   - no network, no remote reach — needs no grove, no credential
#
# guarantee:
#   - arm 1 asserts the defect REPRODUCES unbounded, so a slice that silently
#     stopped to bound would not pass by accident (`term=bite`)
#   - arm 2 discovers its subjects, so a fourth unbounded read is caught the
#     day it is written
#   - arm 3 reads BOTH halves of a quote collision, so a repair to either one
#     clears it
#   - an UNBOUNDED read stays legal where the line names its trigger inline
#     (`rule.require.exemptions-name-their-trigger`)
#
# usage:
#   rhx play.run --play prove.boot-claims-are-bounded-to-one-run
#
# exit:
#   0 = every content read is bounded to one run, and the bound discriminates
#   1 = at least one is not
#   2 = the subject could not be read, so no claim was proven
######################################################################

set -uo pipefail

echo "🔎 prove.boot-claims-are-bounded-to-one-run"
echo "   └─ subject: every read of a grove's apply log by git.grove.provision boot"
echo ""

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo "")"
if [[ -z "$ROOT" ]]; then
  echo "   └─ 🌙 not inside a git checkout, so the subject tree is unnamed" >&2
  exit 2
fi

SUBJECT="$ROOT/.agent/repo=.this/role=any/skills/git.grove.provision.boot.sh"
if [[ ! -f "$SUBJECT" ]]; then
  echo "   └─ ✋ the subject is absent: $SUBJECT" >&2
  echo "      ⇒ a clamp that cannot find its subject proves none of it" >&2
  exit 2
fi

failed=0

######################################################################
# arm 1 — the FIXTURE: does a slice from a run marker discriminate?
#
# ⚠️ every path is under one `mktemp -d`. a fixed path in a shared tmp is a
#    collision another seat can win (`rule.forbid.fixed-paths-in-a-shared-tmp`)
######################################################################
echo "   arm 1 — the slice, against a two-run log"

FIXDIR="$(mktemp -d)" || {
  echo "   └─ ✋ could not build a fixture dir" >&2
  exit 2
}
trap 'rm -rf "$FIXDIR"' EXIT

MARK1='~~~ boot run 1000.11 ~~~'
MARK2='~~~ boot run 2000.22 ~~~'
MARK_ABSENT='~~~ boot run 3000.33 ~~~'

# ── fixture A: two runs, each of which left ONE claim
LOG_A="$FIXDIR/claims.log"
{
  printf '%s\n' "$MARK1"
  printf '%s\n' '   ✋ a claim the FIRST run left'
  printf '%s\n' '✋ grove.provision finished with failures'
  printf '%s\n' "$MARK2"
  printf '%s\n' '   ✋ a claim the SECOND run left'
  printf '%s\n' '✋ grove.provision finished with failures'
} > "$LOG_A"

bounded="$(sed -n "/$MARK2/,\$p" "$LOG_A" | grep ✋ | grep -v 'grove.provision finished')"
unbounded="$(grep ✋ "$LOG_A" | grep -v 'grove.provision finished')"

# 1a. the slice shows the SECOND run's claim, and only it
if [[ "$bounded" == *'SECOND run'* && "$bounded" != *'FIRST run'* ]]; then
  echo "      ✔ a slice from run 2's marker carries run 2's claim alone"
else
  echo "      ✋ a slice from run 2's marker did NOT isolate run 2's claim" >&2
  echo "         it read: $bounded" >&2
  failed=1
fi

# 1b. ⚠️ the defect must REPRODUCE unbounded, or this arm proves no bite
#     a slice that silently stopped to bound would still pass 1a
if [[ "$unbounded" == *'FIRST run'* && "$unbounded" == *'SECOND run'* ]]; then
  echo "      ✔ the same read UNBOUNDED carries both runs — the defect reproduces"
else
  echo "      ✋ the unbounded read did NOT carry both runs" >&2
  echo "         ⇒ this fixture no longer exercises the defect, so 1a proves none" >&2
  failed=1
fi

# ── fixture B: run 1 CONVERGED, run 2 has written one line
#    this is the false-✔ face, and a healthy box hides it
LOG_B="$FIXDIR/converged.log"
{
  printf '%s\n' "$MARK1"
  printf '%s\n' '   ├─ 2.8.tmux.configure.verify'
  printf '%s\n' '   └─ ✔ held'
  printf '%s\n' '🌲 grove.provision done'
  printf '%s\n' "$MARK2"
  printf '%s\n' '   ├─ 1.system'
} > "$LOG_B"

tail_bounded="$(sed -n "/$MARK2/,\$p" "$LOG_B" | tail -4)"
tail_unbounded="$(tail -4 "$LOG_B")"

# 1c. the slice must NOT carry run 1's terminal line
if [[ "$tail_bounded" != *'grove.provision done'* ]]; then
  echo "      ✔ a slice hides the PRIOR run's terminal line while run 2 is at work"
else
  echo "      ✋ the slice carried the prior run's 'done' — a FALSE ✔ is live" >&2
  failed=1
fi

# 1d. and unbounded it must, or 1c proves no bite
if [[ "$tail_unbounded" == *'grove.provision done'* ]]; then
  echo "      ✔ the same tail UNBOUNDED reports converged — the false ✔ reproduces"
else
  echo "      ✋ the unbounded tail did NOT report converged" >&2
  echo "         ⇒ this fixture no longer exercises the false ✔, so 1c proves none" >&2
  failed=1
fi

# 1e. an ABSENT marker renders EMPTY, which is the loud-halt degradation
absent="$(sed -n "/$MARK_ABSENT/,\$p" "$LOG_A")"
if [[ -z "${absent//[[:space:]]/}" ]]; then
  echo "      ✔ a marker that never landed renders EMPTY — the halt arm catches it"
else
  echo "      ✋ a slice from an absent marker rendered non-empty" >&2
  echo "         ⇒ a boot that could not mark its run would report a verdict" >&2
  failed=1
fi

echo ""

######################################################################
# arm 2 — the LIVE read: does the boot REACH that mechanism?
#
# 🛑 the forbidden shape is a CONTENT read aimed straight at `$log`:
#      `tail -N $log`   `grep … $log`   `sed … $log`   `cat $log`
#
# ⚠️ three shapes are NOT content reads and stay legal with no exemption:
#      `test -f $log`    — asks whether an apply EVER ran on this disk
#      `stat -c %y $log` — asks whether the file still GROWS
#      `--log "$log"`    — names the path for the send to write
#
# ⚠️ and a content read may stay UNBOUNDED where its line names the trigger.
#    one does today: the empty-payload halt, whose own cause is a marker that
#    never landed — a slice from it would render empty too
#    (`rule.require.exemptions-name-their-trigger`)
######################################################################
echo "   arm 2 — the boot's own reads"

subject_rel="${SUBJECT#"$ROOT"/}"
bare=0

while IFS= read -r hit; do
  lineno="${hit%%:*}"
  body="${hit#*:}"

  # the exemption must sit within three lines of the read it excuses
  window="$(sed -n "${lineno},$(( lineno + 3 ))p" "$SUBJECT")"
  if [[ "$window" == *UNBOUNDED* ]]; then
    echo "      · line $lineno — unbounded, and it names its trigger ✔"
    continue
  fi

  echo "      ✋ line $lineno reads the log with no bound and no stated trigger" >&2
  echo "         $(printf '%s' "$body" | sed 's/^[[:space:]]*//')" >&2
  bare=$(( bare + 1 ))
done < <(grep -nE '(tail -[0-9]+|grep |sed |cat) [^|]*\$log' "$SUBJECT" \
           | grep -v 'local slice=' \
           | grep -v '^[0-9]*:[[:space:]]*#')

if [[ "$bare" -eq 0 ]]; then
  echo "      ✔ every content read of the log is sliced to one run"
else
  echo "      ⇒ fix: route it through \$slice, or name its trigger inline" >&2
  failed=1
fi

# and the mechanism must still BE there — a slice nobody defines is no slice
if ! grep -q 'local slice=' "$SUBJECT"; then
  echo "      ✋ the boot declares no run slice at all" >&2
  echo "         ⇒ $subject_rel lost its marker; every read is a prior run's" >&2
  failed=1
fi

echo ""

######################################################################
# arm 3 — is the slice PASTEABLE, where a halt hands it to a human?
#
# 📜 2026-09-14, on the slice's own first run. the sed expression was single
#    quoted, which reads fine programmatically — the transport escapes the
#    whole `--what` verbatim — and it collides the moment a fix-text wraps it:
#
#      --what 'sed -n '/~~~ boot run N ~~~/,$p' $HOME/…'
#             └ opens ┘                        └ closes ┘
#
#    ⇒ the pasted command loses its quotes, so `$p` expands to empty and `~~~`
#      reaches zsh bare. the one command whose job is to SHOW this run's log
#      shows none of it (`rule.require.errors-name-the-fix`)
#
# ⚠️ the defect is a PAIR, never one line: a single-quoted slice is harmless
#    until a fix-text wraps it in single quotes. so this arm reads BOTH halves,
#    and a repair to either one clears it
######################################################################
echo "   arm 3 — the slice, as a human receives it"

slice_def="$(grep 'local slice=' "$SUBJECT" || true)"
wraps_single=0
grep -q -- "--what '\$slice'" "$SUBJECT" && wraps_single=1

if [[ "$wraps_single" -eq 1 && "$slice_def" == *"-n '"* ]]; then
  echo "      ✋ a fix-text wraps \$slice in single quotes, and the slice holds them too" >&2
  echo "         slice: $(printf '%s' "$slice_def" | sed 's/^[[:space:]]*//')" >&2
  echo "         ⇒ the quotes collide, so the pasted command reads the wrong thing" >&2
  echo "         fix: double-quote the sed expression, or the fix-text" >&2
  failed=1
else
  echo "      ✔ a halt's fix-text survives a paste — its quotes do not collide"
fi

echo ""

if [[ "$failed" -ne 0 ]]; then
  echo "✋ prove.boot-claims-are-bounded-to-one-run" >&2
  echo "   a boot that reports a PRIOR run's claims is a false ✋ machine, and a" >&2
  echo "   false ✋ is the half that gets a check silenced" >&2
  exit 1
fi

echo "🌲 prove.boot-claims-are-bounded-to-one-run ✔"
exit 0

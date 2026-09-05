#!/usr/bin/env bash
######################################################################
# .what = push the env's UNTRACKABLE secrets into 1password — the files that
#         cannot live in this repo because they are credentials
#
# .why  = `grove.provision` converges a machine TOWARD a declared state, and
#         everything it needs is declared in this repo. but a few files can
#         never be: aws credentials, vpn profiles. those are the ones a fresh
#         box cannot rebuild from a checkout, so they are the ones worth a
#         backup — and 1password is where they go.
#
# ⚠️ .why this is NOT a bundle, and must not become one
#         a bundle converges the machine. this does the opposite — it reads the
#         machine and writes OUT to 1password. same nouns, opposite direction.
#         to file it under `grove.provision` would put a data-exfiltration step
#         inside the verb that means "make this box match the repo", where a
#         `--mode apply` run would silently start uploading credentials.
#         it is a human-run utility, like `util.yubikey.ssh.sh`.
#
# ⚠️ .what was repaired here — 2026-07-31, and why it had to be
#         this file used the 1password CLI **v1** dialect:
#
#           op create document <file> --title <title>     # v1 — removed in v2
#           op document create <file> --title <title>     # v2 — what op takes now
#
#         so it died on its FIRST real command. the repo's own other 1password
#         caller — `util.yubikey.ssh.sh:170` — already used v2, so the two files
#         disagreed about which CLI they were talking to. that is the "two
#         answers to one question" defect this repo kills everywhere else.
#
#         it was also NON-IDEMPOTENT by construction: `create` on a document
#         that is already there is an error, so every re-run failed on whichever
#         document it had made first. `rule.require.idempotent-install-procedures`
#         wants a re-run to converge, so each push is now findsert-shaped.
#
#         and it was UNGUARDED: an absent `~/.vpn/…` aborted the run partway,
#         after some documents had gone up and before others had — the exact
#         partial-success shape a caller objected to in `bundle.upgrade`.
#
# .what was DROPPED, and where it went instead
#         · codium settings — this file used to end with `codium && echo 'run
#           the Sync Settings: Upload command'`, which LAUNCHED the editor and
#           then told a human to do the work by hand. `6.2.codium` now installs
#           the sync-settings extension AND its config, and its configure.verify
#           proves both. so the reminder is superseded by a real, proven step
#
# .what is KEPT but only ATTEMPTED, never demanded
#         · the gnome-shell radio channel list, and the DataGrip project repo.
#           no bundle installs either one, and this desktop is COSMIC now — so
#           they may well be gone. they are NOT deleted here, because "this repo
#           stopped installing it" is not proof "the human stopped using it".
#           each is guarded on its path being present, and reported if absent
#
# guarantee:
#   - READ-ONLY on this machine. it uploads; it changes no local file
#   - idempotent: a re-run updates each document rather than fail on it
#   - an absent source file SKIPS that one item; it does not abort the rest
#
# usage:
#   bash src/backup_env.sh              # plan  — show what WOULD be pushed
#   bash src/backup_env.sh --mode apply # apply — push it
#
# exit:
#   0 = every present file is backed up (absences are reported, not failures)
#   1 = 1password refused, and which document is named
#   2 = the `op` CLI is absent or not signed in
######################################################################
set -uo pipefail

MODE="plan"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode) MODE="${2:-plan}"; shift 2 ;;
    -h|--help) sed -n '2,68p' "$0"; exit 0 ;;
    *) echo "✋ unknown arg: $1" >&2; exit 2 ;;
  esac
done

DATESTAMP="$(date "+%Y.%m.%d")"
FAILED=0

echo "🌱 backup_env --mode $MODE"
echo "   └─ stamp: $DATESTAMP"
echo ""

######################################################################
# the 1password CLI must be present AND signed in
#
# ⚠️ presence is not enough, and this is the same lesson `5.4.gh` learned:
#    a SET credential that the far end rejects passes a presence test and then
#    fails at the first real call — inside whichever step made it, never here.
#    so this ASKS 1password who we are, rather than test that `op` is on PATH
######################################################################
if ! command -v op >/dev/null 2>&1; then
  echo "✋ the 1password CLI is absent" >&2
  echo "   ⇒ every backup below needs it; none can run" >&2
  echo "   fix: install it, then: op signin" >&2
  exit 2
fi

if ! op whoami >/dev/null 2>&1; then
  echo "✋ the 1password CLI is present but not signed in" >&2
  echo "   ⇒ 'op' would prompt, and a prompt on a duct (which is tmux) sits on" >&2
  echo "     the pane and then eats the next command sent down it as its answer" >&2
  echo "   fix: op signin" >&2
  exit 2
fi

echo "   • signed in to 1password ✔"
echo ""

######################################################################
# .what = push ONE file up, findsert-shaped
#
# ⚠️ .why `edit` is tried before `create`, and not the other way round
#      `op document create` on a title that is already taken is an ERROR, so a
#      create-first form fails on every run after the first. `edit` on an
#      absent title is also an error — but it is the CHEAP one to recover
#      from, because the fallback (create it) is exactly right. so: edit,
#      and on failure create. that is a findsert, and it converges either way
######################################################################
backup_one() {
  local path="$1" title="$2" why="$3"

  if [[ ! -f "$path" ]]; then
    echo "   🌙 $title — no file at $path, so there is none to back up"
    echo "      ⇒ $why"
    return 0
  fi

  if [[ "$MODE" != "apply" ]]; then
    echo "   • $title — WOULD push from $path"
    return 0
  fi

  if op document edit "$title" "$path" >/dev/null 2>&1; then
    echo "   • $title — updated ✔"
    return 0
  fi

  if op document create "$path" --title "$title" >/dev/null 2>&1; then
    echo "   • $title — created ✔"
    return 0
  fi

  echo "   ✋ $title — 1password refused both the edit and the create" >&2
  echo "      ⇒ the file is on disk at $path, so this is 1password's no," >&2
  echo "        not an absent source" >&2
  echo "      read why: op document edit '$title' '$path'" >&2
  FAILED=1
  return 1
}

######################################################################
# 1. aws credentials — the one backup that is also a VERSION HISTORY
#
# .why two documents and not one
#      the dated copy is kept FOREVER, so a bad rotation can be walked back to
#      a known-good day. the undated one is the live copy other things read.
#      one document alone would give you one or the other, never both
######################################################################
echo "  1. aws"
backup_one "$HOME/.aws/credentials" ".aws/credentials.$DATESTAMP" \
  "no aws credentials on this box — 5.6.aws installs the CLI, not the keys"
backup_one "$HOME/.aws/credentials" ".aws/credentials" \
  "no aws credentials on this box — 5.6.aws installs the CLI, not the keys"
echo ""

######################################################################
# 2. vpn profiles — a fresh box cannot rebuild these from a checkout
######################################################################
echo "  2. vpn"
for env in dev prod; do
  backup_one \
    "$HOME/.vpn/ahbode.$env.vpn.main.connection.ovpn" \
    ".vpn/ahbode.$env.vpn.main.connection.ovpn" \
    "no $env profile — 6.4.protonvpn installs the client, not the profiles"
done
echo ""

######################################################################
# 3. the leftovers — attempted, never demanded
#
# ⚠️ these two are the reason this file reports 🌙 rather than ✋ on an absent
#    source. no bundle installs either, and this desktop is COSMIC, so a gnome
#    shell extension's data is likely gone. that is a REASON to skip them, not
#    a reason to delete the lines: whether the human still uses DataGrip is the
#    human's fact, not this repo's
######################################################################
echo "  3. leftovers"
backup_one "$HOME/.gse-radio/channelList.json" ".gse-radio/channelList.json" \
  "gnome-shell radio data — this desktop is COSMIC now; likely retired"
echo ""

# the DataGrip project is a git repo, not a document — so it is REPORTED,
# never uploaded. a git repo's backup is its remote
if [[ -d "$HOME/DataGripProjects/ahbode/.git" ]]; then
  echo "   ⚠️ ~/DataGripProjects/ahbode is a git repo — its state:"
  git -C "$HOME/DataGripProjects/ahbode" status --short --branch | sed 's/^/      /'
  echo "      ⇒ a git repo's backup is its remote — push it, do not upload it"
else
  echo "   🌙 no ~/DataGripProjects/ahbode — no bundle installs DataGrip"
fi
echo ""

######################################################################
# codium is NOT here on purpose — see the header. 6.2.codium owns it
######################################################################
echo "   🌙 codium settings are NOT backed up here — 6.2.codium owns that,"
echo "      and its configure.verify proves the sync-settings config is in place"
echo ""

echo "🌲 verdict"
if [[ "$FAILED" -ne 0 ]]; then
  echo "   ✋ a document 1password would not take — named above" >&2
  exit 1
fi

if [[ "$MODE" != "apply" ]]; then
  echo "   • plan only — no document was pushed. re-run with --mode apply"
  exit 0
fi

echo "   ✔ every file present on this box is in 1password"
exit 0

#!/usr/bin/env bash
######################################################################
# .what = read a LIVE grove's backup back, then restore one unit of it aside
#         with --into, and compare what landed against the live seat
#
# .why  = `prove.grove-backup-round-trip` proves the logic over a dir that
#         stands in for the bucket. only a live run proves the real bucket,
#         the real credential, and the real timer: that the scheduled run put
#         each unit, and that what it put comes back whole
#
# .the claims
#   the run · the status line reads ✓ (a scheduled run succeeded)
#   the bucket · this grove is listed, and its .claude unit is there
#   the restore · `--home .claude --into <dir>` exits 0, with no plaintext
#     credential · a tree that holds a clone conversation restores `--into` a
#     dir, and the conversation lands byte for byte
#
# guarantee:
#   - waits, at most 3h, for a pass at work to settle before it reads the status
#   - runs on the camper seat (the agent backs up camper alone); declines,
#     exit 2, on any other
#   - writes only its own mktemp dir under the seat's home, removed on exit;
#     the live seat is never written
######################################################################

set -u

if [[ "$(id -un)" != "camper" ]]; then
  echo "🌙 prove.grove-backup-live declines: $(id -un) is not the camper seat"
  echo "   run it there: rhx git.grove.send <grove> --reply --play prove.grove-backup-live"
  exit 2
fi

failed=0
held() { echo "   • $1 ✔"; }
miss() { echo "   ✋ $1"; failed=1; }

echo "🔬 prove.grove-backup-live"

# ── the disk gate, first: this play lays a whole .claude and a whole tree aside, so
#   it refuses a box at the crews' own 90 pct gate (📜 2026-11-20, 0901 at 90 pct).
#   a df that cannot answer reads as full: the gate fails closed
disk_pct="$(df --output=pcent "$HOME" 2>/dev/null | tail -n 1 | tr -dc '0-9')"
if [[ "${disk_pct:-100}" -ge 90 ]]; then
  echo "   └─ ✋ ConstraintError: the disk reads ${disk_pct:-an unknown} pct, at or past the 90 pct crew gate"
  echo "      fix: run this proof on a grove with room, e.g. one under 80 pct"
  exit 2
fi
echo "   ├─ disk: ${disk_pct} pct"

# rhx resolves skills from a linked checkout, so the play runs from the one boot pushed
checkout="$HOME/git/more/dev-env-setup"
cd "$checkout" || { echo "   💥 MalfunctionError: no checkout at $checkout — boot pushes it there"; exit 1; }

grove="$(cat /etc/grove/name 2>/dev/null)"
[[ -n "$grove" ]] || { echo "   💥 MalfunctionError: /etc/grove/name is empty — 5.26.backup declares it"; exit 1; }
echo "   ├─ grove: $grove"

# ── a pass at work: wait for it, bounded, so the claims read a settled pass
# .why a box's first pass packs every tree, and on a full box it runs past an hour
# shellcheck source=/dev/null
source "$checkout/src/grove.provision/5.devtools/5.26.backup/grove.backup.operations.sh"
wait_secs="${GROVE_BACKUP_LIVE_WAIT_SECS:-10800}"
waited=0
# .why wait for ONE pass to end, never for an idle unit: on a busy box the timer
#      starts the next pass as the last ends, so the unit is never idle at a poll
#      (📜 2026-11-20, ec2: 180m of passes back to back, each one ✓)
status_file="$(grove_backup_status_file)"
began="$(date +%s)"
pass_ended() { [[ -f "$status_file" ]] && [[ "$(stat -c %Y "$status_file")" -ge "$began" ]]; }
while grove_backup_run_active && ! pass_ended; do
  [[ "$waited" -eq 0 ]] && echo "   ├─ ⏳ a backup pass is at work; this play waits for it (at most ${wait_secs}s)"
  [[ "$waited" -ge "$wait_secs" ]] && { miss "the pass still runs after ${wait_secs}s"; break; }
  sleep 30
  waited=$((waited + 30))
  # a wait with no word reads as a hang; say so every ten minutes
  (( waited % 600 == 0 )) && echo "   │  ⏳ still at work after ~$((waited / 60))m"
done
[[ "$waited" -gt 0 ]] && echo "   ├─ the pass settled after ~$((waited / 60))m"

# ── the run: did a scheduled backup succeed?
line="$(timeout -k 10 600 rhx grove.backup.get 2>&1 | grep -E '✓|✗' | tail -1)"
echo "   ├─ status: ${line:-<none>}"
[[ "$line" == *✓* ]] && held "a scheduled backup succeeded" || miss "no successful backup: ${line:-the status line is absent}"

# ── the bucket: this grove's units
units="$(timeout -k 10 600 rhx grove.backup.get --from "$grove" --list 2>&1)"
grep -E 'home=|units$' <<<"$units" | sed 's/^/   │ /'
[[ "$units" == *home=.claude* ]] && held "the bucket holds this grove's .claude unit" \
  || miss "the bucket lists no .claude unit for $grove"

# ── the restore: one unit, aside
work="$(mktemp -d "$HOME/.local/state/grove-backup-live.XXXXXX")"
trap 'rm -rf "$work"' EXIT
aside="$work/claude"

out="$(timeout -k 10 600 rhx grove.backup.restore --from "$grove" --home .claude --into "$aside" 2>&1)"; rc=$?
sed 's/^/   │ /' <<<"$out"
[[ "$rc" -eq 0 ]] && held "restore --home .claude --into exits 0" || miss "restore exited $rc"

[[ ! -e "$aside/.credentials.json" ]] && held "no plaintext credential landed" \
  || miss ".credentials.json landed — the cut failed"

# ── a clone's conversation: on a grove it lives INSIDE its tree, at
#   .agent/.actors/<actor>/brain/.claude/projects — so it rides in the tree's unit,
#   and ~/.claude/projects may hold none (📜 2026-11-20, hetzner camper: empty)
# ⚠️ a conversation only APPENDS, so it may have grown since the run that put it:
#   the laid copy must equal the live file's first bytes, byte for byte
convos="$(find "$HOME/git" -name node_modules -prune -o \
          -path '*/.agent/.actors/*/.claude/projects/*.jsonl' -size +0 -type f -print 2>/dev/null)"
units_walk="$(grove_backup_units_walk)"

# ── coverage: every clone conversation under ~/git sits inside a unit's path
#   .why a conversation outside every unit rides in no backup, so no restore can
#        return it; the walk names what it covers, so ask the walk
uncovered=0
while IFS= read -r c; do
  [[ -n "$c" ]] || continue
  if ! awk -F'\t' -v c="$c" '$1 != "home" && index(c, $3 "/") == 1 { hit = 1 } END { exit !hit }' <<<"$units_walk"; then
    uncovered=$((uncovered + 1))
    [[ "$uncovered" -le 5 ]] && echo "   │  · outside every unit: ${c#"$HOME/"}"
  fi
done <<<"$convos"
[[ "$uncovered" -eq 0 ]] && held "every clone conversation under ~/git sits inside a backed-up tree" \
  || miss "$uncovered clone conversation(s) sit inside no unit, so no backup carries them"

# ── the restore of one: a conversation inside a worktree unit, picked from the walk
live="" unit_path="" tree_unit=""
while IFS= read -r c; do
  [[ -n "$c" ]] || continue
  hit="$(awk -F'\t' -v c="$c" '$1 == "worktree" && index(c, $3 "/") == 1 { print $3 "\t" $4; exit }' <<<"$units_walk")"
  [[ -n "$hit" ]] && { live="$c"; unit_path="${hit%%$'\t'*}"; tree_unit="${hit#*$'\t'}"; break; }
done <<<"$convos"
if [[ -z "$live" ]]; then
  miss "no clone conversation inside a worktree unit to compare"
else
  # the unit names org, repo and tree; the walk is the one source of each
  root="$unit_path"
  rel="${live#"$root/"}"
  org="${tree_unit#*/org=}"; org="${org%%/*}"
  repo="${tree_unit#*/repo=}"; repo="${repo%%/*}"
  tree="${tree_unit##*/tree=}"
  echo "   ├─ conversation: $org/$repo tree=$tree · $rel"
  out="$(timeout -k 10 600 rhx grove.backup.restore --from "$grove" --of "$org/$repo" --tree "$tree" --into "$work/tree" 2>&1)"; rc=$?
  sed 's/^/   │ /' <<<"$out" | tail -12
  [[ "$rc" -eq 0 ]] && held "restore --of $org/$repo --tree $tree --into exits 0" || miss "tree restore exited $rc"
  laid="$work/tree/$rel"
  if [[ -s "$laid" ]] && cmp -s -n "$(stat -c %s "$laid")" "$laid" "$live"; then
    held "the clone conversation landed byte for byte ($(stat -c %s "$laid") of the $(stat -c %s "$live") live bytes)"
  else
    miss "the clone conversation $rel did not land whole"
  fi
fi

[[ "$failed" -ne 0 ]] && { echo "✋ prove.grove-backup-live — a claim failed, named above"; exit 1; }
echo "🌲 prove.grove-backup-live — all claims held ✔"
exit 0

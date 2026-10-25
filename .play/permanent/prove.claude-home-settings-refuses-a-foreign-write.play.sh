#!/usr/bin/env bash
# .what = prove `5.3.brains` strips role hooks from the home claude settings, locks the file
#         read-only, and that a write from outside the bundle — through a tree's arrow, the
#         way a sprout's init writes — then fails loud
# .how  = a SANDBOX home in a `mktemp -d` fixture, never the real one. seed a settings file
#         with role hooks + the commander's keys, symlink a tree's arrow to it, and drive the
#         checkout's own settings half against it
# .why  = every tree's `.claude/settings.json` is an arrow to home, so a tree's init that
#         writes "its" settings writes home, and its hooks then fire in every repo
#
# arms:
#   0  the fixture took: seed holds 3 role hooks + 1 unauthored, writable
#   1  RED: with no lock, a write through the arrow LANDS — the probe bites
#   2  apply: backup byte-equal to before; 0 role hooks; unauthored hook + env + model +
#      statusLine as before; the declared lock mode (0400) · 2k the transcript, pinned whole
#   3  GREEN: the same write through the arrow fails with "permission denied", file byte-equal
#   4  re-apply converges: [KEEP], no new backup, byte-equal
#   5  recovery: a hand-unlocked file that took a role hook is stripped and re-locked
#   6  lock-only: a clean but writable file is locked
#   7  interrupt: a SIGINT before the swap removes the candidate, names it, exits 130; home
#      byte-equal and still locked
#   8  the boot gate, against a FIXTURE checkout whose `prepare:rhachet` plays the sprout writer:
#      8a it exits clean                  → "the lock holds", locked
#      8b it opens the arrow              → EACCES; ✋, the lock and the strip kept (the gate writes naught)
#      8c it renames past the lock        → ✋ "CHANGED", the backup holds the before
#      8d the checkout has no arrow       → 🌙 the gate has no subject, locked
#      8e it fails for another reason     → ✋ "other than the lock", locked
#      8f an EACCES on some OTHER path    → ✋ "other than the lock", locked (no u+w)
#      8g it hits the 300s bound          → ✋ "300s bound", locked
#      8i it renames a byte-equal copy    → ✋ "CHANGED" (the inode moved, no byte did)
#      8j the before fingerprint fails    → ✋, no init run · 8k the after one fails → ✋ unproven
#      8l a [KEEP] apply still runs the gate · 8m a checkout arrow that loops → ✋ ·
#      8n the init runs with CLAUDE_CONFIG_DIR unset · 8o a CHANGED on a [KEEP] names no false "new"
#      8p the pass and halt verdicts, pinned whole · (8h retired: the gate restores no write bit)
#   9  the verify never reads "could not see" as "fine":
#      9a a home jq cannot read           → ✋ hooks uncounted
#      9b a mode stat cannot read         → ✋ the lock is unproven
#      9c a hooked, writable home         → ✋ role hooks AND ✋ writable
#      9d a stripped, locked home         → ✔ no role hook AND ✔ read-only
#      9e an unjudged hook                → ✋ outside `repo=…`
#      9f an author that is no string     → ✋ outside `repo=…` (a stamp-shape change)
#      9g an unjudged hook, through an apply → [KEEP] and ✋ named, so apply and verify agree
#   10 the public entry, with CLAUDE_CONFIG_DIR unset, converges all three files;
#      10b the verify after it is exit 0, every claim ✔ · 10c a second run keeps keybindings ·
#      10d keybindings through an arrow · 10e a non-list `.bindings` is refused
#   11 a failed step leaves home untouched and no tmp beside it:
#      11a the backup copy fails  · 11b the candidate lock fails  · 11c the rename fails
#   12 the tmp guard restores the caller's own INT trap
#   13 the other refusals, each a ✋ with its cause:
#      13a a new file's candidate write fails · 13b the extant file is not json ·
#      13c home's arrow loops (upsert and verify) · 13d mktemp fails · 13e the census fails ·
#      13f the verify has no `_.sh` beside it · 13g the verify has no jq ·
#      13h a fresh home is written whole · 13i home through an arrow ·
#      13j the verify alone in its own dir finds its `_.sh`
#   14 the global config half: fresh by rename · not json · SHRANK · rename fails · no jq ·
#      fresh write fails · 14g through an arrow, the target merged · 14h an arrow that loops
#   15 the keybindings half: no ~/.claude · arrow loops · no jq · rename fails · compare fails ·
#      fresh by rename
#   16 the settings half: no ~/.claude · no jq · a backup name already taken
#   17 the verify: each other refusal (17a–17g), and 17h it writes naught
#   18 the strip keeps the commander's empty containers; outside the hooks only the patch moves
#   19 the backups are reaped to the newest ten · 19b a human's own backup is never reaped ·
#      19c a failed reap is its own verdict, after the gate
#   20 a tmp the unguard cannot remove is named
#   21 the catalog cells driven through the real flow: 21a stripped but writable (c4.a) ·
#      21b locked but hooked (c4.b) · 21c locked, no hook, a stale key → never [KEEP] (c6.c) ·
#      21d a SIGINT mid-flow (c5) · 21e a racer just before the rename meets the lock (c7)
#   22 the lock DECLARATION (arms 0–21 run with it `on`): 22a declared `off` → a hooked, locked
#      home is stripped and left 0600 · 22b the verify ✔s the strip and 🌙s the owed lock · 22c a
#      converged 0600 home [KEEP]s · 22g a write lands, the plan ✋s it, the next apply strips it ·
#      22h a 644 home is never [KEEP] · 22i the gate runs no init · 22d the verify ✋s a locked home
#      under `off`, both fixes pinned · 22j a fresh home is written at 0600 · 22e a declaration
#      that reads neither on nor off → the apply refuses and the verify ✋s · 22f the shipped `_.sh`
#      reads `on` or `off`. every text a human reads under `off` is pinned whole
#   23 the SEAM: `bundle.upgrade` drives both configure phases under the shipped declaration,
#      and the whole report is pinned to `<this play>.seam.snap` (`GROVE_RESNAP=1` rewrites it)
#
# guarantee:
#   - HERMETIC: HOME and every checkout point into the fixture; arms 2–6 run with no checkout,
#     so the gate declines there; the fixture is removed on EXIT
#   - exit 0 = every arm holds · 1 = an arm failed · 2 = the play cannot run here
set -uo pipefail

# the play's own path names its checkout, so it runs in a pushed copy that is no git tree
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
upsert="$repo/src/grove.provision/5.devtools/5.3.brains/configure.upsert.sh"
verify="$repo/src/grove.provision/5.devtools/5.3.brains/configure.verify.sh"
# the readers both phases share live in the bundle's `_.sh`; the entrypoint sources it with every
# phase, so each subshell below sources it first, the same way
export GROVE_5_3_SHARED="$repo/src/grove.provision/5.devtools/5.3.brains/_.sh"

echo "🔭 the home claude settings refuse a foreign write"

# 🛑 root ignores a mode lock, so as root no arm could fail — the play would prove naught
if (( EUID == 0 )); then
  echo "   └─ 🌙 run as root, which a mode lock does not stop — run as the box's human" >&2
  exit 2
fi
command -v jq >/dev/null 2>&1 || { echo "   └─ 🌙 jq is absent, so the bundle cannot run" >&2; exit 2; }
command -v npm >/dev/null 2>&1 || { echo "   └─ 🌙 npm is absent, so the boot gate arms cannot run" >&2; exit 2; }

fix="$(mktemp -d)" || { echo "   └─ ✋ could not mint a fixture dir" >&2; exit 2; }
trap 'chmod -R u+w "$fix" 2>/dev/null; rm -rf "$fix"' EXIT

# arms 0–21 prove the LOCK, so they run with it declared `on` — one wrapper that sources the
# real `_.sh` and flips that one value. arm 22 proves the shipped declaration, whatever it reads
GROVE_5_3_SHARED_REAL="$GROVE_5_3_SHARED"
printf 'source %q\n_GROVE_PROVISION_5_3_BRAINS_SETTINGS_LOCK=on\n' "$GROVE_5_3_SHARED_REAL" > "$fix/shared.lock-on.sh"
export GROVE_5_3_SHARED="$fix/shared.lock-on.sh"
# every arm asserts the mode the bundle DECLARES for a lock, never a literal of its own
lockmode="$(bash -c 'source "$1"; echo "$_GROVE_PROVISION_5_3_BRAINS_SETTINGS_MODE_LOCKED"' _ "$GROVE_5_3_SHARED_REAL")"
[[ "$lockmode" =~ ^[0-7]{3}$ ]] || { echo "   └─ ✋ the declared lock mode reads '$lockmode', no octal mode" >&2; exit 2; }

home="$fix/home"
settings="$home/.claude/settings.json"
arrow="$fix/tree/.claude/settings.json"
mkdir -p "$home/.claude" "$fix/tree/.claude"
ln -s "$settings" "$arrow"

# the seed: 3 role hooks from two roles, 1 hook the commander wrote, and his own keys
seed='{
  "env": {"MY_OWN": "keep"},
  "model": "claude-opus-5-5[1m]",
  "permissions": {"defaultMode": "auto", "allow": ["Bash(ls)"]},
  "statusLine": {"type": "command", "command": "echo mine"},
  "hooks": {
    "SessionStart": [
      {"matcher": "*", "hooks": [
        {"type": "command", "command": "rhx route.drive", "author": "repo=bhrain/role=driver"},
        {"type": "command", "command": "echo hello", "timeout": 5}
      ]}
    ],
    "PreToolUse": [
      {"matcher": "Bash", "hooks": [
        {"type": "command", "command": "rhx check-permissions", "author": "repo=ehmpathy/role=mechanic"},
        {"type": "command", "command": "rhx forbid", "author": "repo=ehmpathy/role=mechanic"}
      ]}
    ]
  }
}'

# .what = write the seed into home at mode <mode>, writable or not before
reseed() { chmod u+w "$settings" 2>/dev/null; printf '%s\n' "$seed" > "$settings"; chmod "$1" "$settings"; }
reseed 0644

fails=0
pass() { printf '   ├─ ✔ %s\n' "$1"; }
fail() { printf '   ├─ ✋ %s\n' "$1" >&2; fails=$((fails + 1)); }
# .what = pass where <actual> equals the whole <expected> verdict, so a dropped cause or fix line fails
pinned() { [[ "$2" == "$3" ]] && pass "$1" || fail "$1: got <<$2>> want <<$3>>"; }

# .what = drive the checkout's settings half against the sandbox — the real one, no copy
# .note = <prelude> runs first inside the subshell, so an arm can replace one command there
apply() {
  ( HOME="$home" GROVE_SRC="$fix/src" \
      bash -c 'source "$GROVE_5_3_SHARED"; source "$1"; '"${1:-:}"'; _grove_provision_5_3_brains_settings_step' _ "$upsert" )
}
roles_in()   { ( bash -c 'source "$GROVE_5_3_SHARED"; source "$1"; _grove_provision_5_3_brains_role_hook_count "$2"' _ "$upsert" "$1" ); }
mode_of()    { stat -c '%a' "$1"; }
backups()    { find "$home/.claude" -maxdepth 1 -name 'settings.*.bak.json' | sort; }
tmps()       { find "$home/.claude" -maxdepth 1 -name 'settings.json.*'; }

# .what = write a role hook through the tree's arrow, the way a sprout's init does
# .note = its stderr lands in `foreign_err`, so a refusal is read for its CAUSE, not just its code
foreign_err=""
foreign() {
  foreign_err="$( { printf '{"hooks": {"Stop": [{"hooks": [{"type": "command", "command": "x", "author": "repo=a/role=b"}]}]}}\n' > "$arrow"; } 2>&1 )"
}

# ── arm 0: the fixture took
[[ "$(roles_in "$settings")" == 3 && "$(mode_of "$settings")" == 644 ]] \
  && pass "0  fixture: 3 role hooks, mode 644, reached through the arrow" \
  || { fail "0  fixture did not take — no arm below has a subject"; exit 2; }

# ── arm 1: RED — with no lock, the write through the arrow lands
foreign && [[ "$(roles_in "$settings")" == 1 ]] \
  && pass "1  red: unlocked, a write through the arrow lands in home (the defect)" \
  || fail "1  red: the unlocked write did not land, so the green arm would prove naught"
reseed 0644
before="$(cat "$settings")"

# ── arm 2: apply
out="$(apply 2>&1)"; code=$?
bak="$(backups | head -1)"
(( code == 0 ))                                                   && pass "2a apply exits 0"                         || fail "2a apply exited $code: $out"
[[ -n "$bak" ]] && [[ "$(cat "$bak")" == "$before" ]]              && pass "2b backup beside it is byte-equal"       || fail "2b no byte-equal backup"
# 2l: the backup of a 0644 file is 0600 — a copy of `env` no other user may read
[[ -n "$bak" ]] && [[ "$(mode_of "$bak")" == 600 ]]                && pass "2l backup of a 644 file is mode 600"       || fail "2l backup mode $(mode_of "$bak")"
[[ "$(roles_in "$settings")" == 0 ]]                              && pass "2c zero role hooks remain"                || fail "2c role hooks remain: $(roles_in "$settings")"
[[ "$(jq -c '.hooks.SessionStart[0].hooks' "$settings")" == '[{"type":"command","command":"echo hello","timeout":5}]' ]] \
                                                                  && pass "2d the unauthored hook is kept, as it was" || fail "2d unauthored hook changed"
[[ "$(jq -c '.hooks | has("PreToolUse")' "$settings")" == false ]] && pass "2e an event it emptied is dropped"         || fail "2e emptied event remains"
[[ "$(jq -c '[.env.MY_OWN, .permissions.allow, .statusLine.command]' "$settings")" == '["keep",["Bash(ls)"],"echo mine"]' ]] \
                                                                  && pass "2f the commander's keys hold their values" || fail "2f a commander key changed"
[[ "$(jq -r '.env.DISABLE_AUTOUPDATER' "$settings")" == 1 ]]      && pass "2g the patch merged"                      || fail "2g the patch did not merge"
[[ "$(mode_of "$settings")" == "$lockmode" ]]                             && pass "2h mode $lockmode"                             || fail "2h mode $(mode_of "$settings")"
[[ -z "$(tmps)" ]]                                                && pass "2i no tmp left beside it"                 || fail "2i a tmp was left behind"
[[ "$out" == *"boot gate"*"no rhachet checkout"* ]]               && pass "2j the boot gate declines: no checkout in the sandbox" || fail "2j boot gate said: $out"
pinned "2k the apply transcript on a hooked home, pinned whole" "$out" \
"   • backup → $bak
   • role hooks stripped → 3 removed; every unauthored hook kept
   • claude settings merged → $settings (mode 644 → $lockmode, swapped in by rename)
   🌙 boot gate: no rhachet checkout beside this run, so no init to prove the lock against"

# ── arm 3: GREEN — the same foreign write now fails on the lock, home byte-equal
locked="$(cat "$settings")"
foreign; code=$?
[[ "$code" != 0 && "$foreign_err" == *"ermission denied"* && "$(cat "$settings")" == "$locked" ]] \
  && pass "3  green: the write through the arrow fails on permission, home byte-equal" \
  || fail "3  green: exit $code, err '${foreign_err}', home $([[ "$(cat "$settings")" == "$locked" ]] && echo equal || echo CHANGED)"

# ── arm 4: re-apply converges
n="$(backups)"; out="$(apply 2>&1)"; code=$?
[[ "$code" == 0 && "$out" == *"[KEEP]"* && "$(backups)" == "$n" && "$(cat "$settings")" == "$locked" ]] \
  && pass "4  re-apply: [KEEP], no new backup, byte-equal" || fail "4  re-apply did not converge: exit $code: $out"
pinned "4  re-apply: the [KEEP] line pinned whole" "$(sed -n '/claude settings already/p' <<< "$out")" \
"   • claude settings already hold the patch, no role hook, and the declared mode ($lockmode) → $settings [KEEP]"

# ── arm 5: recovery — a hand unlock let a role hook land, then the file was re-locked
chmod u+w "$settings"
foreign || fail "5  setup: the hand-unlocked write did not land: $foreign_err"
chmod $lockmode "$settings"
out="$(apply 2>&1)"; code=$?
[[ "$code" == 0 && "$(roles_in "$settings")" == 0 && "$(mode_of "$settings")" == "$lockmode" ]] \
  && pass "5  recovery: the landed role hook is stripped, the file re-locked" \
  || fail "5  recovery: exit $code, roles $(roles_in "$settings"), mode $(mode_of "$settings"): $out"

# ── arm 6: lock-only — clean content, but writable
chmod 0644 "$settings"; clean="$(jq -S . "$settings")"
out="$(apply 2>&1)"; code=$?
[[ "$code" == 0 && "$(mode_of "$settings")" == "$lockmode" && "$(jq -S . "$settings")" == "$clean" ]] \
  && pass "6  lock-only: a clean writable file is locked, content as it was" \
  || fail "6  lock-only: exit $code, mode $(mode_of "$settings"): $out"

# ── arm 7: interrupt — a SIGINT lands after the candidate is minted, before the swap
locked="$(cat "$settings")"
out="$( HOME="$home" bash -c 'source "$GROVE_5_3_SHARED"; source "$1"; _grove_provision_5_3_brains_tmp_mint "$2"; printf "%s\n" "$_GROVE_PROVISION_5_3_BRAINS_TMP"; kill -INT $$; sleep 5' \
          _ "$upsert" "$settings" 2>&1 )"; code=$?
cand="$(head -n 1 <<< "$out")"
[[ "$code" == 130 && -n "$cand" && ! -e "$cand" && "$out" == *"interrupted before the swap"* \
   && "$(cat "$settings")" == "$locked" && "$(mode_of "$settings")" == "$lockmode" ]] \
  && pass "7  interrupt: candidate removed, named, exit 130; home byte-equal and locked" \
  || fail "7  interrupt: exit $code, candidate ${cand:-?} $([[ -e "$cand" ]] && echo left || echo gone): $out"

# ── arm 8: the boot gate — a fixture checkout, its settings an arrow to home, whose
#    `prepare:rhachet` plays the sprout writer. each arm re-seeds a writable home so the
#    apply swaps, and the gate runs after the swap
co="$fix/co"
mkdir -p "$co/src" "$co/node_modules/.bin" "$co/.claude"
printf '#!/bin/sh\n' > "$co/node_modules/.bin/rhachet"; chmod +x "$co/node_modules/.bin/rhachet"
ln -s "$settings" "$co/.claude/settings.json"

# .what = re-seed home, give the fixture checkout <command> as its init, and apply
# .note = <prelude> runs first inside the subshell, so an arm can replace one command there
gate_apply() {
  printf '{"name": "fx", "version": "0.0.0", "scripts": {"prepare:rhachet": %s}}\n' \
    "$(jq -Rn --arg s "$1" '$s')" > "$co/package.json"
  reseed 0644
  ( HOME="$home" GROVE_SRC="$co/src" \
      bash -c 'source "$GROVE_5_3_SHARED"; source "$1"; '"${2:-:}"'; _grove_provision_5_3_brains_settings_step' _ "$upsert" 2>&1 )
}

out="$(gate_apply 'true')"; code=$?
[[ "$code" == 0 && "$out" == *"left home untouched"* && "$out" == *"not proven here: a repo pinned below"* && "$(mode_of "$settings")" == "$lockmode" ]] \
  && pass "8a gate: a clean init → home untouched, its bound named, mode $lockmode" || fail "8a gate pass: exit $code: $out"

out="$(gate_apply "node -e \"require('fs').writeFileSync('.claude/settings.json', '{}')\"")"; code=$?
[[ "$code" == 1 && "$out" == *"HALTS rhachet init"*"the declared lock are kept"* && "$out" == *"SETTINGS_LOCK=off"* \
   && "$(mode_of "$settings")" == "$lockmode" && "$(roles_in "$settings")" == 0 ]] \
  && pass "8b gate: an init that hits EACCES on the settings → ✋, the lock and the strip kept, the gate writes naught" \
  || fail "8b gate halt: exit $code, mode $(mode_of "$settings"), roles $(roles_in "$settings"): $out"

n="$(backups)"
out="$(gate_apply "node -e \"const fs = require('fs'); const r = fs.realpathSync('.claude/settings.json'); fs.writeFileSync(r + '.x', '{}'); fs.renameSync(r + '.x', r)\"")"; code=$?
bak="$(comm -13 <(printf '%s\n' "$n") <(backups) | head -1)"
[[ "$code" == 1 && "$out" == *"CHANGED"* && -n "$bak" && "$(roles_in "$bak")" == 3 ]] \
  && pass "8c gate: an init that renames past the lock → ✋ CHANGED, the backup holds the before" \
  || fail "8c gate rename: exit $code, backup ${bak:-absent}: $out"

# 8i: an init that renames an IDENTICAL copy over home — bytes equal, inode new → ✋ CHANGED
out="$(gate_apply "node -e \"const fs = require('fs'); const r = fs.realpathSync('.claude/settings.json'); fs.copyFileSync(r, r + '.x'); fs.renameSync(r + '.x', r)\"")"; code=$?
[[ "$code" == 1 && "$out" == *"CHANGED"* ]] \
  && pass "8i gate: an init that renames a byte-equal copy past the lock → ✋ CHANGED (the inode moved)" \
  || fail "8i gate identical rename: exit $code: $out"

# 8d: the checkout's settings is a plain file, no arrow → the gate has no subject
rm -f "$co/.claude/settings.json"; printf '{}\n' > "$co/.claude/settings.json"
out="$(gate_apply 'true')"; code=$?
[[ "$code" == 0 && "$out" == *"is no arrow to"* && "$(mode_of "$settings")" == "$lockmode" ]] \
  && pass "8d gate: a checkout with no arrow → 🌙 no subject, mode $lockmode" || fail "8d gate no arrow: exit $code: $out"
rm -f "$co/.claude/settings.json"; ln -s "$settings" "$co/.claude/settings.json"

out="$(gate_apply 'echo broken >&2; exit 1')"; code=$?
[[ "$code" == 1 && "$out" == *"other than the lock"* && "$(mode_of "$settings")" == "$lockmode" ]] \
  && pass "8e gate: an init that fails for another reason → ✋, the lock kept" || fail "8e gate other: exit $code: $out"

# 8l: the file 8e left converged and $lockmode → the next apply [KEEP]s it AND still runs the gate,
#     so the init repaired since then is proven, never skipped
printf '{"name": "fx", "version": "0.0.0", "scripts": {"prepare:rhachet": "true"}}\n' > "$co/package.json"
out="$( HOME="$home" GROVE_SRC="$co/src" bash -c 'source "$GROVE_5_3_SHARED"; source "$1"; _grove_provision_5_3_brains_settings_step' _ "$upsert" 2>&1 )"; code=$?
[[ "$code" == 0 && "$out" == *"[KEEP]"* && "$out" == *"left home untouched"* ]] \
  && pass "8l gate: a [KEEP] apply still runs the gate, so a repaired init is proven" || fail "8l gate on keep: exit $code: $out"

# 8m: the checkout's arrow loops → ✋ a broken tree, never 🌙 "no subject"
rm -f "$co/.claude/settings.json"; ln -s settings.json "$co/.claude/settings.json"
out="$(gate_apply 'true')"; code=$?
[[ "$code" == 1 && "$out" == *"boot gate:"*"could not be followed, so the lock is unproven"* && "$out" != *"is no arrow to"* ]] \
  && pass "8m gate: a checkout arrow that loops → ✋ unresolved, never 🌙" || fail "8m gate loop: exit $code: $out"
rm -f "$co/.claude/settings.json"; ln -s "$settings" "$co/.claude/settings.json"

# 8n: an enrolled apply's CLAUDE_CONFIG_DIR never reaches the init, so the init writes home
out="$( export CLAUDE_CONFIG_DIR="$fix/actor"; gate_apply "echo \${CLAUDE_CONFIG_DIR:-unset} > $fix/init.env" )"; code=$?
[[ "$code" == 0 && "$(cat "$fix/init.env" 2>&1)" == unset ]] \
  && pass "8n gate: the init runs with CLAUDE_CONFIG_DIR unset" || fail "8n gate env: exit $code, init saw '$(cat "$fix/init.env" 2>&1)': $out"

out="$(gate_apply "echo 'EACCES: permission denied, open /etc/shadow' >&2; exit 1")"; code=$?
[[ "$code" == 1 && "$out" == *"other than the lock"* && "$out" != *"HALTS rhachet init"* && "$(mode_of "$settings")" == "$lockmode" ]] \
  && pass "8f gate: an EACCES on some other path → ✋ other, no write bit restored" || fail "8f gate foreign EACCES: exit $code, mode $(mode_of "$settings"): $out"

out="$(gate_apply 'true' 'timeout() { return 124; }')"; code=$?
[[ "$code" == 1 && "$out" == *"300s bound"* && "$(mode_of "$settings")" == "$lockmode" ]] \
  && pass "8g gate: an init that hits its 300s bound → ✋, the lock kept" || fail "8g gate timeout: exit $code: $out"

out="$(gate_apply 'true' '_grove_provision_5_3_brains_fingerprint() { return 1; }')"; code=$?
[[ "$code" == 1 && "$out" == *"could not read the fingerprint of"*"the lock is unproven"* && "$out" != *"npm run prepare:rhachet in"* && "$(mode_of "$settings")" == "$lockmode" ]] \
  && pass "8j gate: the BEFORE fingerprint fails → ✋, no init run, the lock kept" || fail "8j gate before-fingerprint: exit $code: $out"

# 8k: the first fingerprint reads, the second fails — a marker file counts across the `$(…)` calls
out="$(gate_apply 'true' '_grove_provision_5_3_brains_fingerprint() { [[ -e "$HOME/.fp" ]] && return 1; : > "$HOME/.fp"; echo x; }')"; code=$?
rm -f "$home/.fp"
[[ "$code" == 1 && "$out" == *"after the init"* && "$out" == *"whether home moved is unproven"* ]] \
  && pass "8k gate: the AFTER fingerprint fails → ✋ home moved is unproven" || fail "8k gate after-fingerprint: exit $code: $out"

# .what = drive the settings step against the home as it stands — no reseed, so a converged file [KEEP]s
step_as_is() { ( HOME="$home" GROVE_SRC="$co/src" bash -c 'source "$GROVE_5_3_SHARED"; source "$1"; _grove_provision_5_3_brains_settings_step' _ "$upsert" 2>&1 ); }
# .what = the gate's own lines in <out>, from its first verdict to the end of the step
gate_block() { sed -n '/boot gate:/,$p' <<< "$1"; }

# 8o: the file 8k left converged → a [KEEP] apply whose init renames past the lock says CHANGED,
#     and never claims the file was new to this apply
printf '{"name": "fx", "version": "0.0.0", "scripts": {"prepare:rhachet": %s}}\n' \
  "$(jq -Rn --arg s "node -e \"const fs = require('fs'); const r = fs.realpathSync('.claude/settings.json'); fs.copyFileSync(r, r + '.x'); fs.renameSync(r + '.x', r)\"" '$s')" > "$co/package.json"
out="$(step_as_is)"; code=$?
[[ "$code" == 1 && "$out" == *"[KEEP]"* && "$out" == *"CHANGED"* && "$out" == *"already converged ([KEEP]) or new"* && "$out" != *"was new to this apply"* ]] \
  && pass "8o gate: a CHANGED on a [KEEP] apply names no false 'new file'" || fail "8o gate keep changed: exit $code: $out"

# 8p: the gate's pass and halt verdicts, pinned whole — the commander reads these words
out="$(gate_apply 'true')"
pinned "8p gate pass → the whole verdict, the pinned-repo exposure named" "$(gate_block "$out")" \
"   • boot gate: npm run prepare:rhachet in $co (bounded at 300s)…
   • boot gate: this checkout's init completed and left home untouched (bytes, inode, mode)
      ⇒ not proven here: a repo pinned below the shielded rhachet 1.49.2 still writes home on install
        and, with the lock on, that install FAILS until its pin moves"
out="$(gate_apply "echo \"Error: EACCES: permission denied, open '/x/.claude/settings.json'\" >&2; exit 1")"
pinned "8p gate halt → the whole verdict, the lock kept, both fixes named" "$(gate_block "$out")" \
"   • boot gate: npm run prepare:rhachet in $co (bounded at 300s)…
   ✋ boot gate: the lock HALTS rhachet init — the strip and the declared lock are kept
      ⇒ an install whose init writes home fails against this file while the lock is declared on
      ⇒ the init's last words:
         Error: EACCES: permission denied, open '/x/.claude/settings.json'
      fix: upgrade that checkout's rhachet to a release whose init never writes home scope,
           or set _GROVE_PROVISION_5_3_BRAINS_SETTINGS_LOCK=off in 5.3.brains/_.sh; then
           rhx grove.provision --what 5.3.brains --mode apply"

# ── arm 9: the verify never reads "could not see" as "fine"
# .note = <prelude> runs first inside the subshell, so an arm can replace one command there
verify_run() {
  ( HOME="$home" bash -c 'source "$GROVE_5_3_SHARED"; source "$1"; source "$2"; '"$1"'; grove_provision_5_3_brains_configure_verify' \
      _ "$upsert" "$verify" 2>&1 )
}

# 9a: a home file jq cannot read → the census is ✋ uncounted, never "no role-authored hook ✔"
chmod u+w "$settings"; printf 'not json\n' > "$settings"; chmod $lockmode "$settings"
out="$(verify_run ':')"; code=$?
[[ "$code" == 1 && "$out" == *"role hooks are uncounted"* && "$out" != *"no role-authored hook"* ]] \
  && pass "9a verify: an unreadable home → ✋ hooks uncounted, never ✔" \
  || fail "9a verify on an unreadable home: exit $code: $out"

# 9b: a mode that cannot be read → ✋ the lock is unproven, never "read-only ✔"
#     (`stat` is replaced by a failure inside this subshell alone — the reader's seam)
reseed $lockmode
out="$(verify_run 'stat() { return 1; }')"; code=$?
[[ "$code" == 1 && "$out" == *"the lock is unproven"* && "$out" != *"is read-only"* ]] \
  && pass "9b verify: an unread mode → ✋ the lock is unproven, never ✔" \
  || fail "9b verify on an unread mode: exit $code: $out"

# 9c: the seed itself — hooked and writable → both claims ✋
reseed 0644
out="$(verify_run ':')"; code=$?
[[ "$code" == 1 && "$out" == *"holds 3 role-authored hooks"* && "$out" == *"is writable (mode 644)"* \
   && "$out" == *"├─ repo=bhrain/role=driver"*"1"* && "$out" == *"└─ repo=ehmpathy/role=mechanic"*"2"* ]] \
  && pass "9c verify: a hooked, writable home → ✋ role hooks (one tree row per author) and ✋ writable" \
  || fail "9c verify on the seed: exit $code: $out"

# 9d: after an apply → both claims ✔ (the keybindings and config halves are arm 10b's)
out="$(apply 2>&1)"; code=$?
(( code == 0 )) || fail "9d setup: the apply exited $code: $out"
out="$(verify_run ':')"
[[ "$out" == *"no role-authored hook"*"✔"* && "$out" == *"is read-only (mode $lockmode) ✔"* && "$out" != *"role-authored hooks, which fire"* ]] \
  && pass "9d verify: a stripped, locked home → ✔ no role hook and ✔ read-only" \
  || fail "9d verify after apply: $out"

# 9e: a hook stamped by an author outside `repo=…` → ✋, never stripped in silence
chmod u+w "$settings"
jq '.hooks.Stop = [{"hooks": [{"type": "command", "command": "y", "author": "acme-tool"}]}]' "$settings" > "$settings.x" \
  && mv -f "$settings.x" "$settings"; chmod $lockmode "$settings"
out="$(verify_run ':')"; code=$?
[[ "$code" == 1 && "$out" == *"by an author outside"* && "$out" == *"acme-tool"* ]] \
  && pass "9e verify: a unjudged hook → ✋ named for a human" \
  || fail "9e verify on an unjudged hook: exit $code: $out"

# 9g: the same unjudged hook, through an apply → [KEEP] AND ✋ named, so the apply never goes green
#     over a file its verify reddens
locked="$(cat "$settings")"
out="$(apply 2>&1)"; code=$?
[[ "$code" == 1 && "$out" == *"[KEEP]"* && "$out" == *"outside \`repo=…\`, which no apply strips"* && "$out" == *"acme-tool"* \
   && "$(cat "$settings")" == "$locked" ]] \
  && pass "9g apply: a unjudged hook → [KEEP] and ✋ named, byte-equal — the apply and verify agree" \
  || fail "9g apply on an unjudged hook: exit $code: $out"

# 9f: an author that is no string (a stamp shape this repo does not know) → ✋, never "no role hook ✔" alone
chmod u+w "$settings"
jq '.hooks.Stop = [{"hooks": [{"type": "command", "command": "z", "author": {"repo": "a", "role": "b"}}]}]' "$settings" > "$settings.x" \
  && mv -f "$settings.x" "$settings"; chmod $lockmode "$settings"
out="$(verify_run ':')"; code=$?
[[ "$code" == 1 && "$out" == *"by an author outside"* && "$out" == *'{"repo":"a","role":"b"}'* ]] \
  && pass "9f verify: a structured author → ✋ named, so a stamp-shape change never reads as clean" \
  || fail "9f verify on a structured author: exit $code: $out"

# ── arm 10: the public entry, as a bundle run calls it, with an enrolled clone's env unset
reseed 0644
out="$( env -u CLAUDE_CONFIG_DIR HOME="$home" GROVE_SRC="$fix/src" \
          bash -c 'source "$GROVE_5_3_SHARED"; source "$1"; grove_provision_5_3_brains_configure_upsert' _ "$upsert" 2>&1 )"; code=$?
[[ "$code" == 0 && "$(mode_of "$settings")" == "$lockmode" && "$(roles_in "$settings")" == 0 \
   && "$(jq -r '.diffSidebarOpen' "$home/.claude.json")" == false \
   && "$(jq -c '[.bindings[] | select(.context == "Chat") | .bindings["ctrl+x ctrl+s"]]' "$home/.claude/keybindings.json")" == '[null]' ]] \
  && pass "10 public entry: all three halves converge, settings stripped and $lockmode" \
  || fail "10 public entry: exit $code: $out"

# 10b: the verify after the public entry → every claim ✔, the keybindings and config halves too
out="$(verify_run ':')"; code=$?
[[ "$code" == 0 && "$out" == *"ctrl+enter is the one send-now key"*"✔"* && "$out" == *"diff panel shut-at-start holds the declared value ✔"* \
   && "$out" == *"is read-only (mode $lockmode) ✔"* && "$out" != *"✋"* ]] \
  && pass "10b verify after the public entry: exit 0, all three files ✔" \
  || fail "10b verify after the public entry: exit $code: $out"

# .what = drive the public entry, as a bundle run calls it
entry() {
  ( env -u CLAUDE_CONFIG_DIR HOME="$home" GROVE_SRC="$fix/src" \
      bash -c 'source "$GROVE_5_3_SHARED"; source "$1"; grove_provision_5_3_brains_configure_upsert' _ "$upsert" 2>&1 )
}
keys="$home/.claude/keybindings.json"

# 10c: a second run → the keybindings half keeps the file, byte-equal
was="$(cat "$keys")"; out="$(entry)"; code=$?
[[ "$code" == 0 && "$out" == *"keybindings already unbind"*"[KEEP]"* && "$(cat "$keys")" == "$was" ]] \
  && pass "10c second run: keybindings [KEEP], byte-equal" || fail "10c keybindings keep: exit $code: $out"

# 10d: keybindings is an arrow → the half writes the target, and the arrow stays an arrow
rm -f "$keys"; printf '{"bindings": []}\n' > "$fix/keys.real.json"; ln -s "$fix/keys.real.json" "$keys"
out="$(entry)"; code=$?
[[ "$code" == 0 && -L "$keys" \
   && "$(jq -c '[.bindings[] | select(.context == "Chat") | .bindings["ctrl+x ctrl+s"]]' "$fix/keys.real.json")" == '[null]' ]] \
  && pass "10d keybindings through an arrow: the target merged, the arrow kept" || fail "10d keybindings arrow: exit $code: $out"

# 10e: a `.bindings` that is no list → refused, byte-equal, no tmp
rm -f "$keys"; printf '{"bindings": {"x": 1}}\n' > "$keys"; was="$(cat "$keys")"
out="$(entry)"; code=$?
[[ "$code" == 1 && "$out" == *".bindings is not a list"* && "$(cat "$keys")" == "$was" \
   && -z "$(find "$home/.claude" -maxdepth 1 -name 'keybindings.json.*')" ]] \
  && pass "10e a non-list .bindings → ✋ refused, byte-equal, no tmp" || fail "10e keybindings non-list: exit $code: $out"
printf '{"bindings": []}\n' > "$keys"; entry >/dev/null

# ── arm 11: a failed step leaves home untouched, and no tmp beside it
# .what = re-seed writable, apply with <prelude>, then judge the refusal by <words>
fail_arm() {
  local label="$1" prelude="$2" words="$3" out code was
  reseed 0644; was="$(cat "$settings")"
  out="$(apply "$prelude" 2>&1)"; code=$?
  [[ "$code" == 1 && "$out" == *"$words"* && "$(cat "$settings")" == "$was" && "$(mode_of "$settings")" == 644 && -z "$(tmps)" ]] \
    && pass "$label → ✋ '$words', home untouched, no tmp" \
    || fail "$label: exit $code, mode $(mode_of "$settings"), tmps '$(tmps)': $out"
}
fail_arm "11a the backup copy fails"    'touch() { return 1; }'                                           "could not back up"
# 11a also leaves no partial backup: the name it minted is removed with the refusal
[[ -z "$(find "$home/.claude" -maxdepth 1 -name 'settings.*.bak.json' -newer "$settings")" ]] \
  && pass "11a the partial backup is removed with the refusal" || fail "11a a partial backup was left: $(backups)"

# 11d: a 0444 file — the laptop's own state — is backed up at 0600, never at its own mode
reseed 0444; apply >/dev/null 2>&1
[[ -n "$(backups)" && -z "$(find "$home/.claude" -maxdepth 1 -name 'settings.*.bak.json' ! -perm 600)" ]] \
  && pass "11d a 444 file → every backup is mode 600" \
  || fail "11d a backup is not 600: $(for b in $(backups); do printf '%s=%s ' "${b##*/}" "$(mode_of "$b")"; done)"
fail_arm "11b the candidate lock fails" 'chmod() { [[ "$1" == '"$lockmode"' ]] && return 1; command chmod "$@"; }' "could not give the candidate"
fail_arm "11c the rename fails"         'mv() { return 1; }'                                             "could not rename the candidate"

# ── arm 12: the tmp guard restores the caller's own INT trap
out="$( bash -c 'source "$GROVE_5_3_SHARED"; source "$1"; trap "echo mine" INT; _grove_provision_5_3_brains_tmp_guard "$2/never"; _grove_provision_5_3_brains_tmp_unguard; trap -p INT' \
          _ "$upsert" "$fix" 2>&1 )"
[[ "$out" == *"echo mine"* ]] \
  && pass "12 the tmp guard restores the caller's INT trap" || fail "12 the caller's trap was lost: '${out}'"

# ── arm 13: the other refusals — each a ✋ with its cause, home untouched, no tmp
fail_arm "13d the tmp cannot be made"   '_grove_provision_5_3_brains_tmp_create() { return 1; }'          "could not make a tmp"
fail_arm "13e the role census fails"    '_grove_provision_5_3_brains_role_hooks_by_author() { return 1; }' "could not count the role hooks"

# 13a: no extant file, and the candidate write fails → ✋, no settings file, no tmp
chmod u+w "$settings"; rm -f "$settings"
out="$(apply 'printf() { return 1; }' 2>&1)"; code=$?
[[ "$code" == 1 && "$out" == *"could not write the candidate"* && "$out" == *"fix:"* && ! -e "$settings" && -z "$(tmps)" ]] \
  && pass "13a a new file's candidate write fails → ✋ with a fix, no file, no tmp" \
  || fail "13a new-file write failure: exit $code, tmps '$(tmps)': $out"

# 13b: an extant file jq cannot read → ✋, byte-equal, no backup, no tmp
printf 'not json\n' > "$settings"; chmod 0644 "$settings"; was="$(cat "$settings")"; n="$(backups)"
out="$(apply 2>&1)"; code=$?
[[ "$code" == 1 && "$out" == *"jq could not read"* && "$out" == *"fix: repair it by hand"*"or move it aside"* && "$(cat "$settings")" == "$was" && "$(backups)" == "$n" && -z "$(tmps)" ]] \
  && pass "13b an extant file that is not json → ✋ with both remedies, byte-equal, no backup, no tmp" \
  || fail "13b invalid json: exit $code: $out"
# the census still speaks after a failed converge, and names the same unread file as its own verdict
[[ "$out" == *"   ✋ jq could not read $settings, so its unjudged hooks are uncounted"* ]] \
  && pass "13b invalid json: the census still speaks, and names the file uncounted" \
  || fail "13b invalid json, census absent: $out"
pinned "13b invalid json: the refusal and both remedies pinned whole" "$(sed -n '/jq could not read/,/or move it aside/{p;/or move it aside/q}' <<< "$out")" \
"   ✋ jq could not read $settings
      ⇒ the file is likely not valid json, so it was left untouched
      read why: jq . $settings
      fix: repair it by hand, then re-apply, which restores its declared mode:
             chmod u+w $settings, edit, rhx grove.provision --what 5.3.brains --mode apply
        or move it aside, re-apply to write the declared keys fresh, then carry your own keys"

# 13k: an extant file with zero bytes → jq reads no document and writes naught, so the merge must
#      refuse rather than swap in an empty file as "merged"
: > "$settings"; chmod 0644 "$settings"
out="$(apply 2>&1)"; code=$?
[[ "$code" == 1 && "$out" == *"holds no json document"* && "$out" == *"write {} into it"* && "$out" != *"claude settings merged"* \
   && ! -s "$settings" && "$(mode_of "$settings")" == 644 && -z "$(tmps)" ]] \
  && pass "13k an empty file → ✋ with a fix, never 'merged', home untouched, no tmp" \
  || fail "13k empty file: exit $code, tmps '$(tmps)': $out"

# 13c: home's settings is an arrow that loops → the upsert writes naught; the verify ✋s the lock
#      and still reads the keybindings claim beside it
rm -f "$settings"; ln -s settings.json "$settings"
out="$(apply 2>&1)"; code=$?
[[ "$code" == 1 && "$out" == *"could not be followed, so naught was written"* && -L "$settings" ]] \
  && pass "13c an arrow that loops → the upsert ✋, naught written" || fail "13c upsert on a loop: exit $code: $out"
out="$(verify_run ':')"; code=$?
[[ "$code" == 1 && "$out" == *"the strip and the lock are unproven"* && "$out" == *"send-now"* ]] \
  && pass "13c an arrow that loops → the verify ✋s the lock and still reads the keybindings" \
  || fail "13c verify on a loop: exit $code: $out"
rm -f "$settings"

# 13h: no settings file at all → the patch is written whole, $lockmode, by rename
out="$(apply 2>&1)"; code=$?
[[ "$code" == 0 && "$out" == *"claude settings declared"* && "$(mode_of "$settings")" == "$lockmode" \
   && "$(jq -r '.env.DISABLE_AUTOUPDATER' "$settings")" == 1 && -z "$(tmps)" ]] \
  && pass "13h a fresh home → the patch written whole, $lockmode, no tmp" || fail "13h fresh home: exit $code: $out"
pinned "13h a fresh home: the new-file line pinned whole" "$(sed -n '/claude settings declared/p' <<< "$out")" \
"   • claude settings declared → $settings (mode $lockmode, swapped in by rename)"

# 13i: home's settings is an arrow to a file elsewhere → the target is stripped and locked, the arrow kept
chmod u+w "$settings"; rm -f "$settings"; mkdir -p "$fix/elsewhere"
printf '%s\n' "$seed" > "$fix/elsewhere/settings.json"; chmod 0644 "$fix/elsewhere/settings.json"
ln -s "$fix/elsewhere/settings.json" "$settings"
out="$(apply 2>&1)"; code=$?
[[ "$code" == 0 && -L "$settings" && "$(mode_of "$fix/elsewhere/settings.json")" == "$lockmode" \
   && "$(roles_in "$fix/elsewhere/settings.json")" == 0 ]] \
  && pass "13i home through an arrow → the target stripped and $lockmode, the arrow kept" || fail "13i home arrow: exit $code: $out"
rm -f "$settings"; reseed 0644

# 13f: the verify sourced alone, with no `_.sh` beside it → ✋ the readers are absent
mkdir -p "$fix/lone"; cp "$verify" "$fix/lone/configure.verify.sh"
out="$( HOME="$home" bash -c 'source "$1"; grove_provision_5_3_brains_configure_verify' _ "$fix/lone/configure.verify.sh" 2>&1 )"; code=$?
[[ "$code" == 1 && "$out" == *"readers are absent"* && "$out" != *"✔"* ]] \
  && pass "13f the verify with no _.sh beside it → ✋ readers absent, never ✔" \
  || fail "13f verify alone: exit $code: $out"

# 13j: the verify sourced alone from its own dir → it sources the `_.sh` beside it, and the claims run
out="$( HOME="$home" bash -c 'source "$1"; grove_provision_5_3_brains_configure_verify' _ "$verify" 2>&1 )"
[[ "$out" != *"readers are absent"* && "$out" == *"role"* ]] \
  && pass "13j the verify alone in its own dir → finds the _.sh beside it, the claims run" \
  || fail "13j verify alone in its dir: $out"

# 13g: the verify with jq absent → ✋, never ✔
out="$(verify_run 'command() { [[ "$1 ${2:-}" == "-v jq" ]] && return 1; builtin command "$@"; }')"; code=$?
[[ "$code" == 1 && "$out" == *"jq is absent"* && "$out" != *"✔"* ]] \
  && pass "13g the verify with jq absent → ✋, never ✔" \
  || fail "13g verify without jq: exit $code: $out"

# .what = drive one named half of the upsert against the sandbox, with <prelude> run first
half()   { ( HOME="$home" bash -c 'source "$GROVE_5_3_SHARED"; source "$1"; '"$1"'; '"$2" _ "$upsert" 2>&1 ); }
# .what = the verdict lines a half wrote, without jq's own parse error interleaved
# .why  = every bundle verdict line is indented, and jq writes from column 0 — in words that
#         differ by version (1.6 `parse error: …`, 1.7 `jq: error …`), so match the indent, never jq
verdict() { grep '^ ' <<< "$1"; }
nojq='command() { [[ "$1 ${2:-}" == "-v jq" ]] && return 1; builtin command "$@"; }'
config="$home/.claude.json"
ctmps() { find "$home" -maxdepth 1 -name '.claude.json.*'; }
ktmps() { find "$home/.claude" -maxdepth 1 -name 'keybindings.json.*'; }

# ── arm 14: the global config half — the file that holds the oauth session
rm -f "$config"
out="$(half ':' _grove_provision_5_3_brains_config_upsert)"; code=$?
[[ "$code" == 0 && "$(jq -r '.diffSidebarOpen' "$config")" == false && "$(mode_of "$config")" == 600 && -z "$(ctmps)" ]] \
  && pass "14a a fresh global config → written by rename, mode 600, no tmp" || fail "14a fresh config: exit $code, mode $(mode_of "$config"): $out"

printf 'not json\n' > "$config"; was="$(cat "$config")"
out="$(half ':' _grove_provision_5_3_brains_config_upsert)"; code=$?
(( code == 1 )) && [[ "$(cat "$config")" == "$was" && -z "$(ctmps)" ]] || fail "14b config not json: exit $code, tmps '$(ctmps)': $out"
pinned "14b a global config that is not json → the whole ✋ verdict, byte-equal, no tmp" "$(verdict "$out")" \
"   ✋ jq could not read $config, so it was left untouched
      ⇒ the file is likely not valid json; it holds the oauth session, so it is never overwritten
      read why: jq . $config
      fix: repair the json by hand (never delete it — it holds the session), then
           rhx grove.provision --what 5.3.brains --mode apply"

printf '{"diffSidebarOpen": true, "oauthAccount": "a long session value that must survive"}\n' > "$config"; was="$(cat "$config")"
out="$(half '_grove_provision_5_3_brains_config_merge_filter() { echo "{diffSidebarOpen: false}"; }' _grove_provision_5_3_brains_config_upsert)"; code=$?
cand="$(ctmps | head -1)"
[[ "$code" == 1 && "$out" == *"SHRANK"* && "$out" == *"jq . $cand"* && "$out" == *"fix: once read, rm $cand, then"* && -n "$cand" && "$(cat "$config")" == "$was" ]] \
  && pass "14c a merge that SHRANK the config → ✋ refused, byte-equal, the candidate kept for a human" || fail "14c shrink: exit $code, candidate ${cand:-absent}: $out"
rm -f "$cand"

out="$(half 'mv() { return 1; }' _grove_provision_5_3_brains_config_upsert)"; code=$?
[[ "$code" == 1 && "$out" == *"could not rename the candidate over $config"* && "$out" == *"fix:"* && "$(cat "$config")" == "$was" && -z "$(ctmps)" ]] \
  && pass "14d a failed config rename → ✋ with a fix, byte-equal, no tmp" || fail "14d config rename: exit $code: $out"

out="$(half "$nojq" _grove_provision_5_3_brains_config_upsert)"; code=$?
[[ "$code" == 1 && "$out" == *"jq is absent, so the extant global config"* && "$out" == *"fix:"* && "$(cat "$config")" == "$was" ]] \
  && pass "14e jq absent → ✋ the config is never overwritten, byte-equal" || fail "14e config no jq: exit $code: $out"

rm -f "$config"
out="$(half 'printf() { return 1; }' _grove_provision_5_3_brains_config_upsert)"; code=$?
[[ "$code" == 1 && "$out" == *"could not write the candidate"* && "$out" == *"fix:"* && ! -e "$config" && -z "$(ctmps)" ]] \
  && pass "14f a fresh config's candidate write fails → ✋ with a fix, no file, no tmp" || fail "14f config fresh write: exit $code: $out"

# 14g: the global config through an arrow → the TARGET merged, the arrow kept, the session intact
ctarget="$fix/dotfiles/claude.json"; mkdir -p "$fix/dotfiles"
printf '{"diffSidebarOpen": true, "oauthAccount": "keep"}\n' > "$ctarget"; ln -s "$ctarget" "$config"
out="$(half ':' _grove_provision_5_3_brains_config_upsert)"; code=$?
[[ "$code" == 0 && -L "$config" && "$(jq -c '[.diffSidebarOpen, .oauthAccount]' "$ctarget")" == '[false,"keep"]' ]] \
  && pass "14g a config through an arrow → its target merged, the arrow kept, the session intact" \
  || fail "14g config arrow: exit $code, $( [[ -L "$config" ]] && echo arrow kept || echo arrow CUT): $out"

# 14h: a config arrow that loops → ✋, naught written
rm -f "$config"; ln -s .claude.json "$config"
out="$(half ':' _grove_provision_5_3_brains_config_upsert)"; code=$?
[[ "$code" == 1 && -L "$config" && "$out" == *"global config is an arrow that could not be followed"* ]] \
  && pass "14h a config arrow that loops → ✋, naught written" || fail "14h config loop: exit $code: $out"
rm -f "$config"

# 14i: an empty global config → ✋ refused, never swapped in as "merged" (the shrink guard sees 0 vs 0)
: > "$config"
out="$(half ':' _grove_provision_5_3_brains_config_upsert)"; code=$?
[[ "$code" == 1 && "$out" == *"holds no json document"* && "$out" != *"global config merged"* && ! -s "$config" && -z "$(ctmps)" ]] \
  && pass "14i an empty global config → ✋ with a fix, never 'merged', no tmp" || fail "14i empty config: exit $code, tmps '$(ctmps)': $out"
rm -f "$config"
printf '{"diffSidebarOpen": false}\n' > "$config"

# ── arm 15: the keybindings half's refusals
out="$(half 'mkdir() { return 1; }' _grove_provision_5_3_brains_keybindings_upsert)"; code=$?
(( code == 1 )) || fail "15a mkdir: exit $code"
pinned "15a ~/.claude cannot be made → the whole ✋ verdict, its cause and its fix" "$out" \
"   ✋ could not create $home/.claude, so no claude file could be written
      ⇒ $home is likely read-only, full, or owned by another user
      fix: make $home writable by its owner, then
           rhx grove.provision --what 5.3.brains --mode apply"

rm -f "$keys"; ln -s keybindings.json "$keys"
out="$(half ':' _grove_provision_5_3_brains_keybindings_upsert)"; code=$?
(( code == 1 )) && [[ -L "$keys" ]] || fail "15b keybindings loop: exit $code: $out"
pinned "15b a keybindings arrow that loops → the whole ✋ verdict, naught written" "$out" \
"   ✋ $keys is an arrow that could not be followed, so naught was written
      read why: readlink -f $keys
      fix: repair or remove that arrow, then rhx grove.provision --what 5.3.brains --mode apply"
rm -f "$keys"

printf '{"bindings": []}\n' > "$keys"; was="$(cat "$keys")"
out="$(half "$nojq" _grove_provision_5_3_brains_keybindings_upsert)"; code=$?
[[ "$code" == 1 && "$out" == *"jq is absent"*"keymaps"* && "$out" == *"fix:"* && "$(cat "$keys")" == "$was" ]] \
  && pass "15c jq absent → ✋ the keymaps are never overwritten, byte-equal" || fail "15c keybindings no jq: exit $code: $out"

out="$(half 'mv() { return 1; }' _grove_provision_5_3_brains_keybindings_upsert)"; code=$?
[[ "$code" == 1 && "$out" == *"could not rename the candidate over $keys"* && "$out" == *"fix:"* && "$(cat "$keys")" == "$was" && -z "$(ktmps)" ]] \
  && pass "15d a failed keybindings rename → ✋ with a fix, byte-equal, no tmp" || fail "15d keybindings rename: exit $code: $out"

out="$(half '_grove_provision_5_3_brains_json_equivalence() { return 1; }' _grove_provision_5_3_brains_keybindings_upsert)"; code=$?
[[ "$code" == 1 && "$out" == *"could not compare"* && "$out" == *"      fix: repair the json by hand, then rhx grove.provision --what 5.3.brains --mode apply"* \
   && "$(cat "$keys")" == "$was" && -z "$(ktmps)" ]] \
  && pass "15e a compare that cannot read → ✋ with a fix, never taken for 'differs', byte-equal, no tmp" || fail "15e keybindings compare: exit $code: $out"

out="$(half '_grove_provision_5_3_brains_keybindings_merge() { return 1; }' _grove_provision_5_3_brains_keybindings_upsert)"; code=$?
[[ "$code" == 1 && "$out" == *"jq could not merge into $keys"* && "$out" == *"      fix: repair it by hand so it parses and .bindings is a list, then"* \
   && "$(cat "$keys")" == "$was" && -z "$(ktmps)" ]] \
  && pass "15h a merge that fails → ✋ with a fix, byte-equal, no tmp" || fail "15h keybindings merge: exit $code: $out"

# 15i: an empty keybindings file → ✋ refused, never a false [KEEP] from two empty documents
: > "$keys"
out="$(half ':' _grove_provision_5_3_brains_keybindings_upsert)"; code=$?
[[ "$code" == 1 && "$out" == *"holds no json document"* && "$out" != *"[KEEP]"* && ! -s "$keys" && -z "$(ktmps)" ]] \
  && pass "15i an empty keybindings file → ✋ with a fix, never a false [KEEP], no tmp" || fail "15i empty keybindings: exit $code: $out"

rm -f "$keys"
out="$(half ':' _grove_provision_5_3_brains_keybindings_upsert)"; code=$?
[[ "$code" == 0 && "$(jq -c '[.bindings[] | select(.context == "Chat") | .bindings["ctrl+x ctrl+s"]]' "$keys")" == '[null]' && "$(mode_of "$keys")" == 600 && -z "$(ktmps)" ]] \
  && pass "15f a fresh keybindings file → written by rename, mode 600, the chord unbound, no tmp" || fail "15f keybindings fresh: exit $code, mode $(mode_of "$keys"): $out"

# ── arm 16: the settings half's other refusals
reseed 0644; was="$(cat "$settings")"; n="$(backups)"
out="$(apply 'mkdir() { return 1; }' 2>&1)"; code=$?
(( code == 1 )) && [[ "$(cat "$settings")" == "$was" ]] || fail "16a settings mkdir: exit $code: $out"
pinned "16a ~/.claude cannot be made → the whole ✋ verdict, home byte-equal" "$out" \
"   ✋ could not create $home/.claude, so no claude file could be written
      ⇒ $home is likely read-only, full, or owned by another user
      fix: make $home writable by its owner, then
           rhx grove.provision --what 5.3.brains --mode apply"

out="$(apply "$nojq" 2>&1)"; code=$?
[[ "$code" == 1 && "$out" == *"jq is absent, so the extant settings"* && "$(cat "$settings")" == "$was" && "$(backups)" == "$n" && -z "$(tmps)" ]] \
  && pass "16b jq absent → ✋ never an overwrite: byte-equal, no backup, no tmp" || fail "16b settings no jq: exit $code: $out"

collide="$home/.claude/settings.collide.bak.json"; printf 'old\n' > "$collide"
out="$(apply "_grove_provision_5_3_brains_backup_path() { echo $collide; }" 2>&1)"; code=$?
[[ "$code" == 1 && "$out" == *"already holds a backup"* && "$(cat "$collide")" == old && "$(cat "$settings")" == "$was" && "$(mode_of "$settings")" == 644 ]] \
  && pass "16c a backup name already taken → ✋, the old backup and home both untouched" || fail "16c backup collision: exit $code: $out"
rm -f "$collide"

# ── arm 17: the verify's other refusals, each against one broken file in a converged home
entry >/dev/null
# .what = break home with <command>, run the verify, judge it by <words>, then converge home again
verify_arm() {
  local label="$1" breaker="$2" words="$3" out code
  eval "$breaker"
  out="$(verify_run ':')"; code=$?
  # a state an apply can mend names the apply; a read that failed names how to read why
  [[ "$code" == 1 && "$out" == *"$words"* && ( "$out" == *"fix: rhx grove.provision"* || "$out" == *"read why: jq ."* ) ]] \
    && pass "$label → ✋ '$words'" || fail "$label: exit $code: $out"
  chmod u+w "$settings" 2>/dev/null; entry >/dev/null
}
verify_arm "17a no keybindings file"    'rm -f "$keys"'                                       "keybindings at $keys are absent"
verify_arm "17b keybindings not json"   'printf "not json\n" > "$keys"'                       "jq could not read $keys"
verify_arm "17c the chord still bound"  'printf "%s\n" "{\"bindings\": [{\"context\": \"Chat\", \"bindings\": {\"ctrl+x ctrl+s\": \"chat:sendNow\"}}]}" > "$keys"' "still bound to send-now"
verify_arm "17d no global config"       'rm -f "$config"'                                     "global config at $config is absent"
verify_arm "17e global config not json" 'printf "not json\n" > "$config"'                     "jq could not read $config"
verify_arm "17f the diff panel open"    'printf "{\"diffSidebarOpen\": true}\n" > "$config"' "NOT held shut"
verify_arm "17g no settings file"       'chmod u+w "$settings"; rm -f "$settings"'            "$settings is absent, so the strip and the lock are unproven"
# 17i: claude merges every Chat block, so one null beside a second bind is still a bound chord
verify_arm "17i one Chat block unbinds, a second still binds" 'printf "%s\n" "{\"bindings\": [{\"context\": \"Chat\", \"bindings\": {\"ctrl+x ctrl+s\": null}}, {\"context\": \"Chat\", \"bindings\": {\"ctrl+x ctrl+s\": \"chat:sendNow\"}}]}" > "$keys"' "still bound to send-now"
verify_arm "17j keybindings with no .bindings list" 'printf "{\"bindings\": {}}\n" > "$keys"' "holds no .bindings list, so the ctrl+x ctrl+s unbind cannot be judged"
# 17l: an ABSENT .bindings is `[]` to the merge filter, so the verify reads it bound — the apply mends it
verify_arm "17l keybindings with .bindings absent" 'printf "{}\n" > "$keys"' "still bound to send-now"

# 17m: an author with a space is counted whole — the census parts its fields on a tab
reseed 0644
printf '%s\n' '{"hooks": {"PreToolUse": [{"matcher": "Bash", "hooks": [{"type": "command", "command": "true", "author": "Jane Doe"}]}]}}' > "$settings"
out="$(verify_run ':')"; code=$?
[[ "$code" == 1 && "$out" == *"holds 1 hooks by an author outside"* && "$out" == *"Jane Doe"* ]] \
  && pass "17m verify, an author with a space → counted 1, named whole in the tree" || fail "17m spaced author: exit $code: $out"
entry >/dev/null

# 17h: the verify is READ-ONLY — a hooked, writable home with every claim off is left byte-equal
reseed 0644
printf '{"bindings": [{"context": "Chat", "bindings": {"ctrl+x ctrl+s": "chat:sendNow"}}]}\n' > "$keys"
printf '{"diffSidebarOpen": true}\n' > "$config"
snap() { for f in "$settings" "$keys" "$config"; do printf '%s %s\n' "$(mode_of "$f")" "$(sha256sum < "$f")"; done; }
was="$(snap)"; out="$(verify_run ':')"; code=$?
[[ "$code" == 1 && "$(snap)" == "$was" && -z "$(tmps)" ]] \
  && pass "17h the verify writes naught: all three files byte-equal, modes as they were" || fail "17h verify read-only: exit $code, files moved: $out"
entry >/dev/null

# 17k: a census that cannot total is a ✋ named for the census, never a count of zero
reseed 0644
out="$(verify_run '_grove_provision_5_3_brains_census_total() { return 1; }')"; code=$?
[[ "$code" == 1 && "$out" == *"role-authored hooks, and the census could not total them"* && "$out" == *"read why: command -v awk"* && "$out" != *"no role-authored hook in"* ]] \
  && pass "17k verify, a census that cannot total → ✋ named, with its read-why" || fail "17k census failure: exit $code: $out"
entry >/dev/null

# ── arm 18: the strip keeps what the commander left empty, and changes no key it was not asked to
mkdir -p "$fix/home2"
( HOME="$fix/home2" GROVE_SRC="$fix/src" bash -c 'source "$GROVE_5_3_SHARED"; source "$1"; _grove_provision_5_3_brains_settings_step' _ "$upsert" >/dev/null 2>&1 )
patch="$fix/home2/.claude/settings.json"
seed2="$(jq -c '.hooks.Notification = [] | .hooks.SessionStart += [{"matcher": "x", "hooks": []}]' <<< "$seed")"
chmod u+w "$settings"; printf '%s\n' "$seed2" > "$settings"; chmod 0644 "$settings"
out="$(apply 2>&1)"; code=$?
[[ "$code" == 0 && "$(jq -S -c '.hooks' "$settings")" == "$(jq -S -c . <<< '{"SessionStart": [{"matcher": "*", "hooks": [{"type": "command", "command": "echo hello", "timeout": 5}]}, {"matcher": "x", "hooks": []}], "Notification": []}')" ]] \
  && pass "18a the commander's empty event and empty block are kept; only the strip's own empties go" || fail "18a strip empties: exit $code, hooks $(jq -c '.hooks' "$settings"): $out"
[[ "$(jq -S -c --slurpfile p "$patch" '(del(.hooks) * ($p[0] | del(.hooks)))' <<< "$seed2")" == "$(jq -S -c 'del(.hooks)' "$settings")" ]] \
  && pass "18b outside the hooks, the file is exactly the seed with the patch merged — no other key moved" || fail "18b a key outside the patch moved: $(jq -S -c 'del(.hooks)' "$settings")"

# 18c: the reap drops only a container IT emptied — the commander's own empties stay as found
chmod u+w "$settings"; jq -c '.permissions.deny = [] | .modelSettings = {"x": {}}' <<< "$seed" > "$settings"; chmod 0644 "$settings"
out="$(apply 2>&1)"; code=$?
[[ "$code" == 0 && "$(jq -c '.permissions.deny' "$settings")" == '[]' && "$(jq -c '.modelSettings' "$settings")" == '{"x":{}}' ]] \
  && pass "18c the commander's empty deny list and empty per-model block are kept" || fail "18c reap empties: exit $code, deny $(jq -c '.permissions.deny' "$settings"), modelSettings $(jq -c '.modelSettings' "$settings"): $out"
# 18d: the reap removes `Agent` alone; a list it empties goes, a list with other names keeps them
chmod u+w "$settings"; jq -c '.permissions.deny = ["Agent"]' <<< "$seed" > "$settings"; chmod 0644 "$settings"
out="$(apply 2>&1)"; code=$?
[[ "$code" == 0 && "$(jq -c '.permissions | has("deny")' "$settings")" == false ]] \
  && pass "18d a deny list of Agent alone is reaped whole" || fail "18d deny [Agent]: exit $code, permissions $(jq -c '.permissions' "$settings"): $out"
chmod u+w "$settings"; jq -c '.permissions.deny = ["Agent", "Bash"]' <<< "$seed" > "$settings"; chmod 0644 "$settings"
out="$(apply 2>&1)"; code=$?
[[ "$code" == 0 && "$(jq -c '.permissions.deny' "$settings")" == '["Bash"]' ]] \
  && pass "18d a deny list of Agent and Bash keeps Bash" || fail "18d deny [Agent, Bash]: exit $code, deny $(jq -c '.permissions.deny' "$settings"): $out"

# ── arm 19: the backups beside the file are reaped to the newest ten
reseed 0644
while IFS= read -r b; do rm -f "$b"; done < <(backups)
for i in 01 02 03 04 05 06 07 08 09 10 11 12; do printf 'old\n' > "$home/.claude/settings.2000-01-01T00-00-$i.000000000Z.1.bak.json"; done
out="$(apply 2>&1)"; code=$?
[[ "$code" == 0 && "$(backups | wc -l)" == 10 && ! -e "$home/.claude/settings.2000-01-01T00-00-03.000000000Z.1.bak.json" \
   && -e "$home/.claude/settings.2000-01-01T00-00-04.000000000Z.1.bak.json" && "$(backups | tail -1)" != *2000-01-01* ]] \
  && pass "19 the backups are reaped to the newest ten, this apply's among them" || fail "19 reap: exit $code, $(backups | wc -l) backups: $out"

# 19b: a backup the bundle did not mint — a human's own — is never reaped, however old
# its name sorts BEFORE every minted stamp, so a reap that matched it would take it first
mine="$home/.claude/settings.1999-mine.bak.json"; printf 'mine\n' > "$mine"
for i in 13 14 15 16 17 18 19 20 21 22 23; do printf 'old\n' > "$home/.claude/settings.2000-01-01T00-00-$i.000000000Z.1.bak.json"; done
reseed 0644; out="$(apply 2>&1)"; code=$?
[[ "$code" == 0 && "$(cat "$mine" 2>/dev/null)" == mine ]] \
  && pass "19b a human's own backup, older than every minted one, outlives the reap" || fail "19b reap took a human's backup: exit $code: $out"
rm -f "$mine"

# 19c: a reap that cannot remove a backup → ✋ named, AFTER the gate and the census ran
for i in 24 25 26 27 28 29 30 31 32 33 34; do printf 'old\n' > "$home/.claude/settings.2000-01-01T00-00-$i.000000000Z.1.bak.json"; done
reseed 0644; out="$(apply 'rm() { return 1; }' 2>&1)"; code=$?
[[ "$code" == 1 && "$out" == *"could not reap the old backup"* && "$out" == *"boot gate"* && "$(roles_in "$settings")" == 0 ]] \
  && pass "19c a failed reap → ✋ its own verdict; the converge and the gate still ran" || fail "19c reap failure: exit $code: $out"

# ── arm 20: a tmp the unguard cannot remove is named, never reported as clean
mkdir -p "$fix/ro"; : > "$fix/ro/cand"; chmod 0555 "$fix/ro"
out="$( bash -c 'source "$GROVE_5_3_SHARED"; source "$1"; _grove_provision_5_3_brains_tmp_guard "$2"; _grove_provision_5_3_brains_tmp_unguard; echo "exit $?"' _ "$upsert" "$fix/ro/cand" 2>&1 )"
chmod 0755 "$fix/ro"
[[ "$out" == *"could not be removed"* && "$out" == *"exit 1"* ]] \
  && pass "20 a candidate the unguard cannot remove → ✋ named, exit nonzero" || fail "20 unguard leftover: '${out}'"

# ── arm 21: the vision's catalog cells that no arm above drives through the real flow
# 21a (c4.a): stripped but writable → the verify ✔s the strip and ✋s the lock
reseed 0644; apply >/dev/null 2>&1; chmod 0644 "$settings"
out="$(verify_run ':')"; code=$?
[[ "$code" == 1 && "$out" == *"no role-authored hook"*"✔"* && "$out" == *"is writable (mode 644)"* ]] \
  && pass "21a verify (c4.a): stripped, writable → ✔ no role hook, ✋ writable" || fail "21a verify c4.a: exit $code: $out"

# 21b (c4.b): locked but hooked → the verify ✋s the strip and ✔s the lock
reseed $lockmode
out="$(verify_run ':')"; code=$?
[[ "$code" == 1 && "$out" == *"holds 3 role-authored hooks"* && "$out" == *"is read-only (mode $lockmode) ✔"* ]] \
  && pass "21b verify (c4.b): locked, hooked → ✋ role hooks, ✔ read-only" || fail "21b verify c4.b: exit $code: $out"

# 21c (c6.c): locked, no role hook, a declared key gone stale → the skip must NOT [KEEP] it
reseed 0644; apply >/dev/null 2>&1
chmod u+w "$settings"
jq '.env.DISABLE_AUTOUPDATER = "0"' "$settings" > "$settings.x" && mv -f "$settings.x" "$settings"
chmod $lockmode "$settings"
out="$(apply 2>&1)"; code=$?
[[ "$code" == 0 && "$out" != *"[KEEP]"* && "$(jq -r '.env.DISABLE_AUTOUPDATER' "$settings")" == 1 && "$(mode_of "$settings")" == "$lockmode" ]] \
  && pass "21c apply (c6.c): locked, no hook, a stale key → merged, never [KEEP], $lockmode" \
  || fail "21c apply c6.c: exit $code, key $(jq -r '.env.DISABLE_AUTOUPDATER' "$settings"), mode $(mode_of "$settings"): $out"

# 21d (c5): a SIGINT inside the real settings flow — injected as the converge reads the backup
reseed 0644; was="$(cat "$settings")"
out="$(apply 'jq() { [[ "$1" == --argjson && "${@: -1}" == *.bak.json ]] && { kill -INT $$; sleep 1; }; command jq "$@"; }' 2>&1)"; code=$?
[[ "$code" == 130 && "$out" == *"interrupted before the swap"* && -z "$(tmps)" \
   && "$(cat "$settings")" == "$was" && "$(mode_of "$settings")" == 644 ]] \
  && pass "21d apply (c5): an interrupt mid-flow → exit 130, candidate gone, home byte-equal and as it was" \
  || fail "21d apply c5: exit $code, tmps '$(tmps)', mode $(mode_of "$settings"): $out"

# 21e (c7): a foreign write through the arrow races the apply, just before its rename — the live
#     file is still the locked one, so the racer meets the lock, and the swap lands whole
reseed $lockmode; rm -f "$fix/race.err"
race="{ printf '{}\n' > \"$arrow\"; } 2>\"$fix/race.err\" && echo landed > \"$fix/race.err\""
out="$(apply "mv() { [[ \"\${@: -1}\" == \"$settings\" ]] && $race; command mv \"\$@\"; }" 2>&1)"; code=$?
[[ "$code" == 0 && "$(cat "$fix/race.err" 2>/dev/null)" == *"ermission denied"* && "$(roles_in "$settings")" == 0 && "$(mode_of "$settings")" == "$lockmode" ]] \
  && pass "21e apply (c7): a racer just before the rename meets the lock; the swap lands, stripped, $lockmode" \
  || fail "21e apply c7: exit $code, racer '$(cat "$fix/race.err" 2>/dev/null)', roles $(roles_in "$settings"): $out"

# ── arm 22: the lock declaration — the same flow, with the one value set to `off` or a typo
printf 'source %q\n_GROVE_PROVISION_5_3_BRAINS_SETTINGS_LOCK=off\n' "$GROVE_5_3_SHARED_REAL" > "$fix/shared.lock-off.sh"
printf 'source %q\n_GROVE_PROVISION_5_3_BRAINS_SETTINGS_LOCK=On\n' "$GROVE_5_3_SHARED_REAL" > "$fix/shared.lock-typo.sh"

# .what = the backup this apply took — the one name in <after> absent from <before>
newbak() { comm -13 <(printf '%s\n' "$1") <(backups) | head -1; }
# .what = the shipped lifecycle runs under the off declaration
off() { GROVE_5_3_SHARED="$fix/shared.lock-off.sh" "$@"; }
# .what = the gate's verdict under off: no lock, so no init run, and the window named
gate_off="   🌙 boot gate: the lock is declared off, so no lock to prove — no init is run
      ⇒ a repo pinned below the shielded rhachet 1.49.2 still writes its hooks into home on install,
        and no writer re-strips them between applies; the plan's ✋ role hooks is the one detector"
# .what = the lock claim the verify makes, its ✔ or its ✋ with every line beneath it
#         (under off the met declaration is a 🌙 line that ends "pins", never a ✔)
lock_lines() { sed -n '/read-only (mode\|write bit (mode\|is writable (mode\|but the declaration is mode/,/fix:\|✔$\|pins$/p' <<< "$1" | sed '/✔$\|pins$/q'; }
# .what = the lines of <text> from the first that matches <start> through the next that matches <end>
block() { sed -n "/$1/,/$2/p" <<< "$3"; }

# 22a: declared off → a hooked, LOCKED home is stripped and given back its write bit, 0600
reseed $lockmode; n="$(backups)"
out="$(off apply 2>&1)"; code=$?
[[ "$code" == 0 && "$(roles_in "$settings")" == 0 && "$(mode_of "$settings")" == 600 ]] \
  && pass "22a apply, lock off: a hooked, locked home → stripped, mode 600" \
  || fail "22a apply lock off: exit $code, mode $(mode_of "$settings"): $out"
pinned "22a apply, lock off, from a $lockmode start → the transcript pinned whole, the lift named" "$out" \
"   • backup → $(newbak "$n")
   • role hooks stripped → 3 removed; every unauthored hook kept
   • claude settings merged → $settings (mode $lockmode → 600, swapped in by rename)
$gate_off"

# 22b: the verify under off → ✔ no role hook and 🌙 the owed lock, the claim pinned; the 🌙 never
#      fails the verify, so a converged home under off exits 0
out="$(off verify_run ':')"; code=$?
[[ "$code" == 0 && "$out" == *"no role-authored hook"*"✔"* && "$out" != *"is writable (mode"* ]] \
  && pass "22b verify, lock off: stripped, 0600 → ✔ no role hook, exit 0" \
  || fail "22b verify lock off: exit $code: $out"
pinned "22b verify, lock off: the write-bit claim pinned whole" "$(lock_lines "$out")" \
"   🌙 $settings keeps its write bit (mode 600), as declared off — the lock is owed, and waits for the pre-shield pins"

# 22c: a second apply under off → [KEEP], byte-equal, no new backup, the transcript pinned
was="$(cat "$settings")"; nb="$(backups | wc -l)"
out="$(off apply 2>&1)"; code=$?
[[ "$code" == 0 && "$(cat "$settings")" == "$was" && "$(backups | wc -l)" == "$nb" ]] \
  && pass "22c apply, lock off: a converged 0600 home → byte-equal, no backup" \
  || fail "22c apply lock off keep: exit $code: $out"
pinned "22c apply, lock off: the [KEEP] transcript pinned whole" "$out" \
"   • claude settings already hold the patch, no role hook, and the declared mode (600) → $settings [KEEP]
$gate_off"

# 22g: the shipped lifecycle — an unshielded write lands between applies, the plan ✋s it,
#      the next apply strips it. under off no writer re-strips in between
foreign; code=$?
[[ "$code" == 0 && "$(roles_in "$settings")" == 1 ]] \
  && pass "22g lock off: an unshielded write through the arrow LANDS between applies (no lock, by declaration)" \
  || fail "22g lock off write: exit $code, roles $(roles_in "$settings"): $foreign_err"
out="$(off verify_run ':')"; code=$?
[[ "$code" == 1 && "$out" == *"role-authored hook"* && "$out" == *"✋"* ]] \
  && pass "22g lock off: the plan ✋s the landed role hook — the one detector" \
  || fail "22g lock off plan: exit $code: $out"
pinned "22g lock off: the one detector's ✋ pinned whole, its fix included" "$(block 'role-authored hooks, which fire' 'fix:' "$out")" \
"   ✋ $settings holds 1 role-authored hooks, which fire in every repo
      └─ repo=a/role=b                  1
      fix: rhx grove.provision --what 5.3.brains --mode apply"
pinned "22g lock off: the hooked plan's lock line pinned whole" "$(lock_lines "$out")" \
"   🌙 $settings keeps its write bit (mode 600), as declared off — the lock is owed, and waits for the pre-shield pins"
out="$(off apply 2>&1)"; code=$?
[[ "$code" == 0 && "$(roles_in "$settings")" == 0 && "$(mode_of "$settings")" == 600 && "$out" == *"1 removed"* ]] \
  && pass "22g lock off: the next apply strips it, 0600" \
  || fail "22g lock off re-strip: exit $code, roles $(roles_in "$settings"), mode $(mode_of "$settings"): $out"
out="$(off verify_run ':')"; code=$?
[[ "$code" == 0 && "$out" == *"no role-authored hook"*"✔"* && "$(lock_lines "$out")" == *"as declared off"*"pins" ]] \
  && pass "22g lock off: the plan reads ✔ again" || fail "22g lock off plan after: exit $code: $out"

# 22h: under off, a mode wider than declared → the verify ✋s it; the apply never [KEEP]s it
chmod 0644 "$settings"; was="$(jq -S . "$settings")"
out="$(off verify_run ':')"; code=$?
pinned "22h verify, lock off, a 644 home → ✋ wider than declared, pinned whole" "$(lock_lines "$out")" \
"   ✋ $settings is mode 644, but the declaration is mode 600 — other users may read its env
      fix: rhx grove.provision --what 5.3.brains --mode apply"
n="$(backups)"
out="$(off apply 2>&1)"; code=$?
[[ "$code" == 0 && "$out" != *"[KEEP]"* && "$(mode_of "$settings")" == 600 && "$(jq -S . "$settings")" == "$was" ]] \
  && pass "22h apply, lock off, a 644 home → no [KEEP]; mode 600, content as it was" \
  || fail "22h apply lock off 644: exit $code, mode $(mode_of "$settings"): $out"
pinned "22h apply, lock off, from a 644 start → the transcript pinned whole" "$out" \
"   • backup → $(newbak "$n")
   • role hooks stripped → 0 removed; every unauthored hook kept
   • claude settings merged → $settings (mode 644 → 600, swapped in by rename)
$gate_off"

# 22k: under off, a 700 home grants no other user a read — the ✋ names a drift, never a leak
chmod 0700 "$settings"
out="$(off verify_run ':')"; code=$?
pinned "22k verify, lock off, a 700 home → ✋ a drift with no reader exposed, pinned whole" "$(lock_lines "$out")" \
"   ✋ $settings is mode 700, but the declaration is mode 600 — no other user may read it, yet its bits drift from the declaration
      fix: rhx grove.provision --what 5.3.brains --mode apply"
chmod 0600 "$settings"

# 22i: the gate under off, with a checkout — no lock to prove, so the init is never run: an
#      unshielded init would write its hooks through the arrow right after the strip
rm -f "$fix/init.ran"
out="$(off gate_apply ": > $fix/init.ran; node -e \"require('fs').writeFileSync('.claude/settings.json', JSON.stringify({hooks: {Stop: [{hooks: [{type: 'command', command: 'x', author: 'repo=a/role=b'}]}]}}))\"")"; code=$?
[[ "$code" == 0 && ! -e "$fix/init.ran" && "$(roles_in "$settings")" == 0 && "$(mode_of "$settings")" == 600 ]] \
  && pass "22i gate, lock off, an unshielded checkout → the init never runs; home stays stripped, 600" \
  || fail "22i gate lock off: exit $code, init $([[ -e "$fix/init.ran" ]] && echo RAN || echo skipped), roles $(roles_in "$settings"): $out"
pinned "22i gate, lock off → the whole verdict, the re-strip window named" "$(gate_block "$out")" "$gate_off"
reseed 0600; off apply >/dev/null 2>&1

# 22d: under off, a home some hand locked → the verify ✋s it, names the install it breaks
chmod $lockmode "$settings"
out="$(GROVE_5_3_SHARED="$fix/shared.lock-off.sh" verify_run ':')"; code=$?
[[ "$code" == 1 && "$out" == *"is read-only (mode $lockmode), but the lock is declared off"* && "$out" == *"fails its install"* ]] \
  && pass "22d verify, lock off: a $lockmode home → ✋ read-only against the declaration" \
  || fail "22d verify lock off on $lockmode: exit $code: $out"
pinned "22d verify, lock off, a $lockmode home → the ✋ and both fixes pinned whole" "$(block 'is read-only (mode' 'or set _GROVE' "$out")" \
"   ✋ $settings is read-only (mode $lockmode), but the lock is declared off
      ⇒ a repo pinned below the shielded rhachet fails its install against it
      fix: either rhx grove.provision --what 5.3.brains --mode apply   (sets mode 600; the lock lifts)
           or set _GROVE_PROVISION_5_3_BRAINS_SETTINGS_LOCK=on in 5.3.brains/_.sh, then apply (keeps the lock)"

# 22j: under off, no settings file at all → the patch written whole at 600, the new-file line pinned
rm -f "$settings"
out="$(off apply 2>&1)"; code=$?
[[ "$code" == 0 && "$(mode_of "$settings")" == 600 && "$(jq -r '.env.DISABLE_AUTOUPDATER' "$settings")" == 1 && -z "$(tmps)" ]] \
  && pass "22j apply, lock off: a fresh home → the patch written whole, 600, no tmp" \
  || fail "22j apply lock off fresh: exit $code, mode $(mode_of "$settings"): $out"
pinned "22j apply, lock off: the new-file line pinned whole" "$(sed -n '/claude settings declared/p' <<< "$out")" \
"   • claude settings declared → $settings (mode 600, swapped in by rename)"

# 22e: a declaration that reads neither on nor off → the apply refuses byte-equal; the verify ✋s
reseed 0644; was="$(cat "$settings")"; n="$(backups)"
out="$(GROVE_5_3_SHARED="$fix/shared.lock-typo.sh" apply 2>&1)"; code=$?
[[ "$code" == 1 && "$out" == *"reads 'On', neither on nor off"* && "$(block 'to on or off' 'mode apply' "$out")" == "      fix: set _GROVE_PROVISION_5_3_BRAINS_SETTINGS_LOCK to on or off in 5.3.brains/_.sh, then
           rhx grove.provision --what 5.3.brains --mode apply" && "$(cat "$settings")" == "$was" && -z "$(tmps)" && "$(backups)" == "$n" ]] \
  && pass "22e apply, a typo in the declaration → ✋ refused before any read: byte-equal, no tmp, no backup" \
  || fail "22e apply lock typo: exit $code, tmps '$(tmps)', new backup '$(newbak "$n")': $out"
out="$(GROVE_5_3_SHARED="$fix/shared.lock-typo.sh" verify_run ':')"; code=$?
typo_fix="      fix: set _GROVE_PROVISION_5_3_BRAINS_SETTINGS_LOCK to on or off in 5.3.brains/_.sh, then
           rhx grove.provision --what 5.3.brains --mode apply"
[[ "$code" == 1 && "$out" != *"read-only (mode"*"✔"* \
   && "$(block 'neither on nor off' 'mode apply' "$out")" == "   ✋ the lock declaration reads 'On', neither on nor off, so the lock is unjudged
$typo_fix" ]] \
  && pass "22e verify, a typo in the declaration → ✋ the lock unjudged, never ✔; the same fix as the apply's" \
  || fail "22e verify lock typo: exit $code: $out"

# 22f: the shipped `_.sh` declares on or off — never a value the readers refuse
out="$( bash -c 'source "$1"; _grove_provision_5_3_brains_lock_declared' _ "$GROVE_5_3_SHARED_REAL" )"; code=$?
[[ "$code" == 0 && ( "$out" == locked || "$out" == writable ) ]] \
  && pass "22f the shipped declaration reads on or off ($out)" \
  || fail "22f the shipped declaration: exit $code, '$out'"

# 15g: a keybindings file that already unbinds the chord → [KEEP], and no tmp is ever minted in ~/.claude
( HOME="$home" bash -c 'source "$GROVE_5_3_SHARED"; source "$1"; _grove_provision_5_3_brains_keybindings_upsert' _ "$upsert" >/dev/null 2>&1 )
rm -f "$fix/mint.log"
out="$( HOME="$home" bash -c 'source "$GROVE_5_3_SHARED"; source "$1"; _grove_provision_5_3_brains_tmp_mint() { echo minted >> "$2"; return 1; }; _grove_provision_5_3_brains_keybindings_upsert' _ "$upsert" "$fix/mint.log" 2>&1 )"; code=$?
[[ "$code" == 0 && "$out" == *"[KEEP]"* && ! -e "$fix/mint.log" ]] \
  && pass "15g a converged keybindings file → [KEEP], compared before any tmp is minted" \
  || fail "15g keybindings keep: exit $code, mint $([[ -e "$fix/mint.log" ]] && echo CALLED || echo absent): $out"

# 9h: an apply whose mode read fails → the failure is NAMED, never defaulted, and the swap still
#     lands the declared mode (the reader is replaced by a failure inside this subshell alone)
reseed 0644
out="$(half '_grove_provision_5_3_brains_file_mode() { return 1; }' _grove_provision_5_3_brains_settings_step)"; code=$?
[[ "$code" == 0 && "$out" == *"   • the mode of $settings could not be read, so it is rewritten at the declared mode ($lockmode)"* \
   && "$out" == *"(mode unread → $lockmode, swapped in by rename)"* && "$(mode_of "$settings")" == "$lockmode" ]] \
  && pass "9h apply, an unread mode → named, rewritten at mode $lockmode" \
  || fail "9h apply unread mode: exit $code, mode $(mode_of "$settings"): $out"

# a failed converge skips the gate alone: the unjudged-hook census and the backup reap still speak
reseed 0644
out="$(half '_grove_provision_5_3_brains_settings_upsert() { return 1; }
             _grove_provision_5_3_brains_settings_boot_gate() { echo "GATE RAN"; }
             _grove_provision_5_3_brains_settings_unjudged_name() { echo "CENSUS RAN"; }
             _grove_provision_5_3_brains_settings_backup_reap() { echo "REAP RAN"; }' \
  _grove_provision_5_3_brains_settings_step)"; code=$?
[[ "$code" == 1 && "$out" == *"CENSUS RAN"* && "$out" == *"REAP RAN"* && "$out" != *"GATE RAN"* ]] \
  && pass "9i apply, a failed converge → exit 1, no gate, the census and the reap still run" \
  || fail "9i apply failed converge: exit $code: $out"

# ── arm 23: the SEAM — the real runtime drives both configure phases, end to end, under the
#    SHIPPED declaration. every arm above calls a half by its own name; this one goes through
#    `bundle.upgrade <slug>`, the way `grove.provision --what 5.3.brains` does, so a dispatch,
#    a mode gate, or a phase name that drifts goes red here. the whole report is pinned to a
#    `.snap` beside this play: a changed line is a diff a reviewer reads, never a silent drift
#    .note = `rhx play.run --play <this> --resnap` rewrites the baseline; review its diff before a commit
snap="${BASH_SOURCE[0]%.play.sh}.seam.snap"
seam="$fix/seam"
mkdir -p "$seam/home/.claude"
printf '%s\n' "$seed" > "$seam/home/.claude/settings.json"
chmod 0644 "$seam/home/.claude/settings.json"
out="$( cd "$seam" && env -u CLAUDE_CONFIG_DIR HOME="$seam/home" GROVE_SRC="$repo/src" GROVE_MODE=apply \
  bash -c 'WHAT=(); source "$1/src/bundle.upgrade.sh"; source "$2"; source "$3"; source "$4"
           bundle.upgrade 5.3.brains.configure.upsert; bundle.upgrade 5.3.brains.configure.verify
           echo "exit=$BUNDLE_FAILED"' _ "$repo" "$GROVE_5_3_SHARED_REAL" "$upsert" "$verify" 2>&1 )"
# the fixture path and the backup stamp differ per run, so each is replaced by a fixed token
out="${out//$seam/<seam>}"
out="$(printf '%s\n' "$out" | sed -E 's/settings\.[0-9TZ.:-]+\.bak\.json/settings.<stamp>.bak.json/g')"
if [[ "${GROVE_RESNAP:-}" == 1 ]]; then
  printf '%s\n' "$out" > "$snap" && pass "23 seam: baseline rewritten at $snap — review its diff"
elif [[ ! -f "$snap" ]]; then
  fail "23 seam: no baseline at $snap — run with GROVE_RESNAP=1, then review it"
else
  pinned "23 seam: bundle.upgrade drives both configure phases, the report byte-equal to its .snap" \
    "$out" "$(cat "$snap")"
fi
[[ "$out" == *"exit=0"* && "$(roles_in "$seam/home/.claude/settings.json")" == 0 ]] \
  && pass "23 seam: the run exits clean and the sandbox home holds zero role hooks" \
  || fail "23 seam: exit or strip: roles $(roles_in "$seam/home/.claude/settings.json"): $out"

(( fails == 0 )) || { echo "   └─ ✋ ${fails} arm(s) failed"; exit 1; }
shipped="$( bash -c 'source "$1"; echo "$_GROVE_PROVISION_5_3_BRAINS_SETTINGS_LOCK"' _ "$GROVE_5_3_SHARED_REAL" )"
echo "   └─ ✔ every arm holds — under on: stripped, locked, a foreign write fails;"
echo "      under off: stripped, mode 600, a foreign write lands until the next apply. shipped: $shipped"

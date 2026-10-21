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
#      statusLine as before; mode 0444
#   3  GREEN: the same write through the arrow fails, file byte-equal
#   4  re-apply converges: [KEEP], no new backup, byte-equal
#   5  recovery: a hand-unlocked file that took a role hook is stripped and re-locked
#   6  lock-only: a clean but writable file is locked
#   7  interrupt: a SIGINT before the swap removes the candidate, names it, exits 130; home
#      byte-equal and still locked
#   8  the boot gate, against a FIXTURE checkout whose `prepare:rhachet` plays the sprout writer:
#      8a it exits clean           → "the lock holds", locked
#      8b it opens the arrow       → EACCES; the write bit restored, the strip kept, ✋
#      8c it renames past the lock → ✋ "CHANGED", the backup holds the before
#   9  the verify never reads "could not see" as "fine":
#      9a a home jq cannot read  → ✋ hooks uncounted
#      9b a mode stat cannot read → ✋ the lock is unproven
#
# guarantee:
#   - HERMETIC: HOME and every checkout point into the fixture; arms 2–6 run with no checkout,
#     so the gate declines there; the fixture is removed on EXIT
#   - exit 0 = every arm holds · 1 = an arm failed · 2 = the play cannot run here
set -uo pipefail

# the play's own path names its checkout, so it runs in a pushed copy that is no git tree
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
upsert="$repo/src/grove.provision/5.devtools/5.3.brains/configure.upsert.sh"

echo "🔭 the home claude settings refuse a foreign write"

# 🛑 root ignores 0444, so as root no arm could fail — the play would prove naught
if (( EUID == 0 )); then
  echo "   └─ 🌙 run as root, which 0444 does not stop — run as the box's human" >&2
  exit 2
fi
command -v jq >/dev/null 2>&1 || { echo "   └─ 🌙 jq is absent, so the bundle cannot run" >&2; exit 2; }
command -v npm >/dev/null 2>&1 || { echo "   └─ 🌙 npm is absent, so the boot gate arms cannot run" >&2; exit 2; }

fix="$(mktemp -d)" || { echo "   └─ ✋ could not mint a fixture dir" >&2; exit 2; }
trap 'chmod -R u+w "$fix" 2>/dev/null; rm -rf "$fix"' EXIT

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
printf '%s\n' "$seed" > "$settings"
chmod 0644 "$settings"

fails=0
pass() { printf '   ├─ ✔ %s\n' "$1"; }
fail() { printf '   ├─ ✋ %s\n' "$1" >&2; fails=$((fails + 1)); }

# drive the checkout's settings half against the sandbox — the real one, no copy
apply() {
  ( HOME="$home" GROVE_SRC="$fix/src" \
      bash -c 'source "$1"; _grove_provision_5_3_brains_settings_upsert' _ "$upsert" )
}
roles_in()   { ( bash -c 'source "$1"; _grove_provision_5_3_brains_role_hooks_by_author "$2"' _ "$upsert" "$1" ) | awk '{n += $2} END {print n + 0}'; }
mode_of()    { stat -c '%a' "$1"; }
backups()    { find "$home/.claude" -maxdepth 1 -name 'settings.*.bak.json' | wc -l; }
foreign()    { ( printf '{"hooks": {"Stop": [{"hooks": [{"type": "command", "command": "x", "author": "repo=a/role=b"}]}]}}\n' > "$arrow" ) 2>/dev/null; }

# ── arm 0: the fixture took
[[ "$(roles_in "$settings")" == 3 && "$(mode_of "$settings")" == 644 ]] \
  && pass "0  fixture: 3 role hooks, mode 644, reached through the arrow" \
  || { fail "0  fixture did not take — no arm below has a subject"; exit 2; }

# ── arm 1: RED — with no lock, the write through the arrow lands
if foreign && [[ "$(roles_in "$settings")" == 1 ]]; then
  pass "1  red: unlocked, a write through the arrow lands in home (the defect)"
else
  fail "1  red: the unlocked write did not land, so the green arm would prove naught"
fi
printf '%s\n' "$seed" > "$settings"; chmod 0644 "$settings"
before="$(cat "$settings")"

# ── arm 2: apply
out="$(apply 2>&1)"; code=$?
bak="$(find "$home/.claude" -maxdepth 1 -name 'settings.*.bak.json' | head -1)"
(( code == 0 ))                                                   && pass "2a apply exits 0"                         || fail "2a apply exited $code: $out"
[[ -n "$bak" ]] && [[ "$(cat "$bak")" == "$before" ]]              && pass "2b backup beside it is byte-equal"       || fail "2b no byte-equal backup"
[[ "$(roles_in "$settings")" == 0 ]]                              && pass "2c zero role hooks remain"                || fail "2c role hooks remain: $(roles_in "$settings")"
[[ "$(jq -c '.hooks.SessionStart[0].hooks' "$settings")" == '[{"type":"command","command":"echo hello","timeout":5}]' ]] \
                                                                  && pass "2d the unauthored hook is kept, as it was" || fail "2d unauthored hook changed"
[[ "$(jq -c '.hooks | has("PreToolUse")' "$settings")" == false ]] && pass "2e an event it emptied is dropped"         || fail "2e emptied event remains"
[[ "$(jq -c '[.env.MY_OWN, .permissions.allow, .statusLine.command]' "$settings")" == '["keep",["Bash(ls)"],"echo mine"]' ]] \
                                                                  && pass "2f the commander's keys hold their values" || fail "2f a commander key changed"
[[ "$(jq -r '.env.DISABLE_AUTOUPDATER' "$settings")" == 1 ]]      && pass "2g the patch merged"                      || fail "2g the patch did not merge"
[[ "$(mode_of "$settings")" == 444 ]]                             && pass "2h mode 0444"                             || fail "2h mode $(mode_of "$settings")"
[[ -z "$(find "$home/.claude" -maxdepth 1 -name 'settings.json.*')" ]] && pass "2i no tmp left beside it"            || fail "2i a tmp was left behind"
[[ "$out" == *"boot gate"*"no rhachet checkout"* ]]               && pass "2j the boot gate declines: no checkout in the sandbox" || fail "2j boot gate said: $out"

# ── arm 3: GREEN — the same foreign write now fails, home byte-equal
locked="$(cat "$settings")"
if foreign; then
  fail "3  green: the write through the arrow LANDED past the lock"
else
  [[ "$(cat "$settings")" == "$locked" ]] && pass "3  green: the write through the arrow fails, home byte-equal" \
                                          || fail "3  green: the write failed but home changed"
fi

# ── arm 4: re-apply converges
n="$(backups)"; out="$(apply 2>&1)"
[[ "$out" == *"[KEEP]"* && "$(backups)" == "$n" && "$(cat "$settings")" == "$locked" ]] \
  && pass "4  re-apply: [KEEP], no new backup, byte-equal" || fail "4  re-apply did not converge: $out"

# ── arm 5: recovery — a hand unlock let a role hook land, then the file was re-locked
chmod u+w "$settings"; foreign; chmod 0444 "$settings"
apply >/dev/null 2>&1
[[ "$(roles_in "$settings")" == 0 && "$(mode_of "$settings")" == 444 ]] \
  && pass "5  recovery: the landed role hook is stripped, the file re-locked" || fail "5  recovery: roles $(roles_in "$settings"), mode $(mode_of "$settings")"

# ── arm 6: lock-only — clean content, but writable
chmod 0644 "$settings"; clean="$(jq -S . "$settings")"
apply >/dev/null 2>&1
[[ "$(mode_of "$settings")" == 444 && "$(jq -S . "$settings")" == "$clean" ]] \
  && pass "6  lock-only: a clean writable file is locked, content as it was" || fail "6  lock-only: mode $(mode_of "$settings")"

# ── arm 7: interrupt — a SIGINT lands after the candidate is minted, before the swap
locked="$(cat "$settings")"
out="$( HOME="$home" bash -c 'source "$1"; t="$(mktemp "$2.XXXXXX")"; _grove_provision_5_3_brains_tmp_guard "$t"; printf "%s\n" "$t"; kill -INT $$; sleep 5' \
          _ "$upsert" "$settings" 2>&1 )"; code=$?
cand="$(head -n 1 <<< "$out")"
[[ "$code" == 130 && -n "$cand" && ! -e "$cand" && "$out" == *"interrupted before the swap"* \
   && "$(cat "$settings")" == "$locked" && "$(mode_of "$settings")" == 444 ]] \
  && pass "7  interrupt: candidate removed, named, exit 130; home byte-equal and locked" \
  || fail "7  interrupt: exit $code, candidate ${cand:-?} $([[ -e "$cand" ]] && echo left || echo gone): $out"

# ── arm 8: the boot gate — a fixture checkout, its settings an arrow to home, whose
#    `prepare:rhachet` plays the sprout writer. each arm re-seeds a writable home so the
#    apply swaps, and the gate runs after the swap
co="$fix/co"
mkdir -p "$co/src" "$co/node_modules/.bin" "$co/.claude"
printf '#!/bin/sh\n' > "$co/node_modules/.bin/rhachet"; chmod +x "$co/node_modules/.bin/rhachet"
ln -s "$settings" "$co/.claude/settings.json"
gate_apply() {
  printf '{"name": "fx", "version": "0.0.0", "scripts": {"prepare:rhachet": %s}}\n' \
    "$(jq -Rn --arg s "$1" '$s')" > "$co/package.json"
  chmod u+w "$settings"; printf '%s\n' "$seed" > "$settings"; chmod 0644 "$settings"
  ( HOME="$home" GROVE_SRC="$co/src" bash -c 'source "$1"; _grove_provision_5_3_brains_settings_upsert' _ "$upsert" 2>&1 )
}

out="$(gate_apply 'true')"; code=$?
[[ "$code" == 0 && "$out" == *"the lock holds"* && "$(mode_of "$settings")" == 444 ]] \
  && pass "8a gate: a clean init → the lock holds, mode 0444" || fail "8a gate pass: exit $code: $out"

out="$(gate_apply "node -e \"require('fs').writeFileSync('.claude/settings.json', '{}')\"")"; code=$?
[[ "$code" != 0 && "$out" == *"HALTS rhachet init"* && "$(mode_of "$settings")" == 644 && "$(roles_in "$settings")" == 0 ]] \
  && pass "8b gate: an init that hits EACCES → write bit restored, strip kept, ✋" \
  || fail "8b gate halt: exit $code, mode $(mode_of "$settings"), roles $(roles_in "$settings"): $out"

out="$(gate_apply "node -e \"const fs = require('fs'); const r = fs.realpathSync('.claude/settings.json'); fs.writeFileSync(r + '.x', '{}'); fs.renameSync(r + '.x', r)\"")"; code=$?
bak="$(find "$home/.claude" -maxdepth 1 -name 'settings.*.bak.json' -newer "$co/package.json" | head -1)"
[[ "$code" != 0 && "$out" == *"CHANGED"* && -n "$bak" && "$(roles_in "$bak")" == 3 ]] \
  && pass "8c gate: an init that renames past the lock → ✋ CHANGED, the backup holds the before" \
  || fail "8c gate rename: exit $code, backup ${bak:-absent}: $out"

# ── arm 9: the verify never reads "could not see" as "fine"
verify="$repo/src/grove.provision/5.devtools/5.3.brains/configure.verify.sh"
verify_run() {
  ( HOME="$home" bash -c 'source "$1"; source "$2"; '"$1"'; grove_provision_5_3_brains_configure_verify' \
      _ "$upsert" "$verify" 2>&1 )
}

# 9a: a home file jq cannot read → the census is ✋ uncounted, never "no role-authored hook ✔"
chmod u+w "$settings"; printf 'not json\n' > "$settings"; chmod 0444 "$settings"
out="$(verify_run ':')"; code=$?
[[ "$code" != 0 && "$out" == *"role hooks are uncounted"* && "$out" != *"no role-authored hook"* ]] \
  && pass "9a verify: an unreadable home → ✋ hooks uncounted, never ✔" \
  || fail "9a verify on an unreadable home: exit $code: $out"

# 9b: a mode that cannot be read → ✋ the lock is unproven, never "read-only ✔"
#     (`stat` is replaced by a failure inside this subshell alone — the reader's seam)
chmod u+w "$settings"; printf '%s\n' "$seed" > "$settings"; chmod 0444 "$settings"
out="$(verify_run 'stat() { return 1; }')"; code=$?
[[ "$code" != 0 && "$out" == *"the lock is unproven"* && "$out" != *"is read-only"* ]] \
  && pass "9b verify: an unread mode → ✋ the lock is unproven, never ✔" \
  || fail "9b verify on an unread mode: exit $code: $out"

(( fails == 0 )) || { echo "   └─ ✋ ${fails} arm(s) failed"; exit 1; }
echo "   └─ ✔ every arm holds — stripped, locked, and a foreign write fails"

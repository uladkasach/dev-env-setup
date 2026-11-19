#!/usr/bin/env bash
######################################################################
# .what = prove a TAILNET grove (a hetzner box) is woken, trusted, and
#         declared by the same skills an ec2 grove uses, with no aws
#
# .why  = `git.grove.wake` and `git.grove.trust.gen` were written for one
#         reach: an ssm tunnel on a localhost port. a hetzner grove is dialed
#         at its own tailnet name, so each skill asked aws or /proc a question
#         that has no answer there, and `git.grove.provision boot` halted at
#         step 1 on a healthy box
#
# .the arms
#   1. wake    — a tailnet entry with no alias block gets one, from the
#                registry; a block on disk is KEPT as found (infra lays it);
#                a re-run writes no second block
#   2. trust   — the scan reaches the host direct (no /proc port read), and
#                a key set the box itself reports, over ssh pinned to the
#                already-trusted key, is attested; a scanned key the box does
#                NOT report is refused (the subset check still bites)
#   3. set     — `--platform` lands in the entry, survives a partial set,
#                and a value outside the closed set is refused
#
# .what it does to the box
#   - every write lands under one `mktemp -d` HOME, removed on exit
#   - `ssh` and `ssh-keyscan` are stubs on PATH; no network, no credential
#
# usage:
#   rhx play.run --play prove.tailnet-grove-is-reached-and-trusted
#
# exit:
#   0 = every claim held · 1 = a claim failed · 2 = the subject is unreadable
######################################################################

set -uo pipefail

# the snap pins coreutils' own words (mktemp quotes its template in curly quotes
#   only under a UTF-8 locale), so the locale is declared, never inherited
export LC_ALL=C.UTF-8

echo "🔎 prove.tailnet-grove-is-reached-and-trusted"
echo "   └─ subject: git.grove.wake · git.grove.trust.gen · git grove set --platform"
echo ""

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo "")"
[[ -n "$ROOT" ]] || { echo "   └─ ✋ ConstraintError: not inside a git checkout" >&2; exit 2; }
SKILLS="$ROOT/.agent/repo=.this/role=any/skills"
ALIASES="$ROOT/src/grove.provision/2.shell/2.7.aliases/bash_aliases.sh"
for f in "$SKILLS/git.grove.wake.sh" "$SKILLS/git.grove.trust.gen.sh" "$SKILLS/git.grove.ssh.operations.sh" "$ALIASES"; do
  [[ -f "$f" ]] || { echo "   └─ ✋ ConstraintError: the subject is absent: $f" >&2; exit 2; }
done

failed=0; passed=0
claim() {
  local label="$1"; shift
  if "$@"; then echo "   ✔ $label"; passed=$((passed + 1)); return 0; fi
  echo "   💥 MalfunctionError: $label" >&2; failed=$((failed + 1))
}
has()    { [[ "$1" == *"$2"* ]]; }
hasnot() { [[ "$1" != *"$2"* ]]; }

FIX="$(mktemp -d)" || { echo "   └─ 💥 MalfunctionError: could not build a fixture dir" >&2; exit 1; }
LPID=""   # the loopback listener arm 2s binds; the trap stops it
trap '[[ -n "$LPID" ]] && kill "$LPID" 2>/dev/null; rm -rf "$FIX"' EXIT

# .what = every human-read line this play drives, masked of per-run values
# .why  = a claim proves one phrase; the snapshot makes the whole text a
#         reviewed artifact (`rule.require.contract-snapshot-exhaustiveness`)
transcript=""
record() {
  local label="$1" text="$2"
  text="${text//$FIX/<fix>}"
  # keys are minted per run, so their fingerprints AND the order they sort in
  #   vary: mask each, then sort each run of fingerprint rows
  #   a del's saved copy is stamped per run, so the stamp is masked too
  text="$(printf '%s\n' "$text" | sed -E 's/SHA256:[A-Za-z0-9+\/=]+/SHA256:<fp>/g; s/\.[0-9]{8}T[0-9]{6}Z\.json/.<stamp>.json/g' | awk '
    /SHA256:<fp> (✔|✋)/ { print | "sort"; inrun = 1; next }
    inrun { close("sort"); inrun = 0 }
    { fflush(); print }
    END { if (inrun) close("sort") }
  ')"
  transcript+="## $label"$'\n'"$text"$'\n\n'
}

export HOME="$FIX/home"
export GIT_FOREST_DIR="$HOME/.git.forest"
mkdir -p "$HOME/.ssh" "$GIT_FOREST_DIR/groves" "$FIX/bin" "$FIX/keys"
cp "$ALIASES" "$HOME/.bash_aliases"
GROVE="grove-fixture-hetzner"
TAILHOST="grove-fixture-hetzner-1"

# three real host keys, so ssh-keygen fingerprints them as the skill expects
for t in ed25519 ecdsa rsa; do
  ssh-keygen -q -t "$t" -N '' -f "$FIX/keys/host_$t" -C '' || { echo "   └─ 💥 MalfunctionError: ssh-keygen absent" >&2; exit 1; }
done
# an INTRUDER key, which the box does not hold
#   its type is one the laptop does NOT yet trust, so it is ABSENT, not CHANGED,
#   and only the box's own report can refuse it
ssh-keygen -q -t ecdsa -N '' -f "$FIX/keys/intruder" -C ''

# ── stubs: ssh-keyscan offers the keys in $FIX/offer; ssh answers -G from the
#    fixture config, `true` with rc 0, and the key report from $FIX/report
cat > "$FIX/bin/ssh-keyscan" <<STUB
#!/usr/bin/env bash
host="\${@: -1}"
while read -r t k; do echo "\$host \$t \$k"; done < "$FIX/offer"
STUB
# ⚠️ `-G` goes to the REAL ssh, against the fixture config: it parses and dials
#    naught, so the precedence ssh applies (first value wins, Include read in
#    place) is the real one, never a stub's guess
REAL_SSH="$(command -v ssh)" || { echo "   └─ 💥 MalfunctionError: ssh absent" >&2; exit 1; }
cat > "$FIX/bin/ssh" <<STUB
#!/usr/bin/env bash
echo "\$*" >> "$FIX/ssh.calls"
if [[ " \$* " == *" -G "* ]]; then
  exec "$REAL_SSH" -F "\$HOME/.ssh/config" "\$@"
fi
case "\${@: -1}" in
  true)
    [[ -e "$FIX/hostkey.fail" ]] && { echo "Host key verification failed." >&2; exit 255; }
    [[ -e "$FIX/pubkey.fail" ]] && { echo "camper@$TAILHOST: Permission denied (publickey)." >&2; exit 255; }
    [[ -e "$FIX/ssh.fail" ]] || exit 0
    echo "ssh: connect to host $TAILHOST port 22: Connection timed out" >&2
    exit 255 ;;
  'sudo -n bash -s')
    cat > "$FIX/auth.proc"
    echo "\$(grep -o "getent passwd '[^']*'" "$FIX/auth.proc" | cut -d"'" -f2)" >> "$FIX/auth.seats"
    [[ -e "$FIX/auth.fail" ]] && { echo "sudo: a password is required" >&2; exit 1; }
    seat="\$(grep -o "getent passwd '[^']*'" "$FIX/auth.proc" | cut -d"'" -f2)"
    # auth.set: the key is absent on the box — a plan answers PLAN, an apply SET
    if [[ -e "$FIX/auth.set" ]]; then
      grep -q 'echo "SET ' "$FIX/auth.proc" && { echo "SET \$seat"; echo "COUNT 1"; exit 0; }
      echo "PLAN \$seat"; exit 0
    fi
    echo "KEEP \$seat"; echo "COUNT 1"; exit 0 ;;
  *ssh_host_*)
    [[ -e "$FIX/pin.fail" ]] && { echo "Host key verification failed." >&2; exit 255; }
    for k in \$(cat "$FIX/report"); do ssh-keygen -lf "\$k"; done; exit 0 ;;
esac
exit 0
STUB
chmod +x "$FIX/bin/ssh-keyscan" "$FIX/bin/ssh"
export PATH="$FIX/bin:$PATH"

offer_keys() { : > "$FIX/offer"; for k in "$@"; do awk '{print $1, $2}' "$k.pub" >> "$FIX/offer"; done; }
report_keys() { : > "$FIX/report"; for k in "$@"; do echo "$k.pub" >> "$FIX/report"; done; }

######################################################################
# arm 0 — the alias writer on a FRESH box: no ~/.ssh/config at all
#   📜 a peer review caught it: `grep -v` exits 1 on an empty file, and the
#      writer read that as a fault, so the first wake on a new seat failed
#      with a "reason above" that nobody printed
######################################################################
echo "   arm 0 — the alias writer, on a seat with no ~/.ssh/config"
FRESH="$FIX/fresh"
mkdir -p "$FRESH"
out="$(HOME="$FRESH" bash -c 'source "$1"; grove_ssh_alias_set alias=fresh-seat host="$2" port=22 user=camper identity="$3/.ssh/id"' \
  _ "$SKILLS/git.grove.ssh.operations.sh" "$TAILHOST" "$FRESH" 2>&1)"; rc=$?
record "arm 0 · alias set on a fresh seat" "$out"
claim "0a. the first alias on a fresh seat is set (exit 0)" [ "$rc" -eq 0 ]
claim "0b. it reports [SET]" has "$out" "[SET] camper@$TAILHOST:22"
claim "0c. the Include is the first line of the new ~/.ssh/config" \
  [ "$(head -n 1 "$FRESH/.ssh/config")" = "Include $FRESH/.ssh/config.d/grove.conf" ]
out="$(HOME="$FRESH" bash -c 'source "$1"; grove_ssh_alias_set alias=fresh-seat host="$2" port=22' \
  _ "$SKILLS/git.grove.ssh.operations.sh" "$TAILHOST" 2>&1)"; rc=$?
record "arm 0 · alias set with no user= or identity=" "$out"
claim "0d. a call short of its args is refused by name (exit 2)" \
  bash -c '[[ "$1" -eq 2 && "$2" == *"needs alias=, host=, port=, user=, identity="* ]]' _ "$rc" "$out"
echo ""

######################################################################
# arm 3 next — the registry entry the other two arms read
######################################################################
echo "   arm 3 — git grove set --platform"
# shellcheck disable=SC1090
source "$HOME/.bash_aliases" 2>/dev/null || true
out="$(_git_grove_set "$GROVE" --at "camper@$TAILHOST:22" --alias "$GROVE" --env camp --platform hetzner.hetzbot 2>&1)"; rc=$?
record "arm 3 · git grove set --platform hetzner.hetzbot" "$out"
claim "3a. a set with --platform succeeds" [ "$rc" -eq 0 ]
claim "3b. the entry holds platform = hetzner.hetzbot" \
  [ "$(jq -r '.platform' "$GIT_FOREST_DIR/groves/$GROVE.json")" = "hetzner.hetzbot" ]
_git_grove_set "$GROVE" --env camp >/dev/null 2>&1
claim "3c. a partial set KEEPS the platform" \
  [ "$(jq -r '.platform' "$GIT_FOREST_DIR/groves/$GROVE.json")" = "hetzner.hetzbot" ]
out="$(_git_grove_set "$GROVE" --platform aws.ec2 2>&1)"; rc=$?
record "arm 3 · git grove set --platform aws.ec2 (refused)" "$out"
claim "3d. a platform outside the closed set is refused (exit 2)" [ "$rc" -eq 2 ]
claim "3e. the refusal leaves the entry as it was" \
  [ "$(jq -r '.platform' "$GIT_FOREST_DIR/groves/$GROVE.json")" = "hetzner.hetzbot" ]
claim "3e2. a hetzner entry carries no ec2 type stamp (the orphan sweep reads it)" \
  [ "$(jq -r '.type' "$GIT_FOREST_DIR/groves/$GROVE.json")" = "null" ]
# the help a human reads before a set: --at names the wake as the alias writer, and set names --platform
out="$(git_alias_grove --help 2>&1)"; rc=$?
record "arm 3 · git grove --help" "$out"
claim "3h1. git grove --help says the wake writes the ssh alias, rc 0" \
  bash -c '[[ "$1" == *"its wake writes the ssh alias"* && "$2" -eq 0 ]]' _ "$out" "$rc"
out="$(_git_grove_set --help 2>&1)"; rc=$?
record "arm 3 · git grove set --help" "$out"
claim "3h2. git grove set --help names --platform hetzner.hetzbot" has "$out" "[--platform hetzner.hetzbot]"

# a hetzner entry with a loopback or absent host routes as an ec2 tunnel — refused at the one writer
out="$(_git_grove_set "${GROVE}-loop" --at "camper@localhost:22" --platform hetzner.hetzbot 2>&1)"; rc=$?
record "arm 3 · git grove set --platform hetzner.hetzbot --at localhost (refused)" "$out"
claim "3e3. a hetzner entry on loopback is refused (exit 2), and no entry lands" \
  bash -c '[[ "$1" -eq 2 && ! -f "$2" ]]' _ "$rc" "$GIT_FOREST_DIR/groves/${GROVE}-loop.json"
out="$(_git_grove_set "${GROVE}-loop" --exid "${GROVE}-loop" --platform hetzner.hetzbot 2>&1)"; rc=$?
claim "3e4. a hetzner entry with no host is refused (exit 2)" [ "$rc" -eq 2 ]
claim "3e5. the refusal names the tailnet fix" bash -c '[[ "$1" == *"--at <user>@<tailnet host>:22 --platform hetzner.hetzbot"* ]]' _ "$out"
# the clamp judges the MERGED entry, never this call's flags
out="$(_git_grove_set "${GROVE}-loop" --alias infra-loop --at "camper@localhost:22" --platform hetzner.hetzbot 2>&1)"; rc=$?
claim "3e6. --alias does not excuse a loopback host on a hetzner entry (exit 2)" \
  bash -c '[[ "$1" -eq 2 && ! -f "$2" ]]' _ "$rc" "$GIT_FOREST_DIR/groves/${GROVE}-loop.json"
_git_grove_set "${GROVE}-seat" --alias infra-seat --platform hetzner.hetzbot >/dev/null 2>&1; rc=$?
claim "3e7. an --alias with no host on hetzner is refused (exit 2): no reader serves it" \
  bash -c '[[ "$1" -eq 2 && ! -f "$2" ]]' _ "$rc" "$GIT_FOREST_DIR/groves/${GROVE}-seat.json"
_git_grove_set "${GROVE}-seat" --alias infra-seat --at "camper@$TAILHOST:22" --platform hetzner.hetzbot >/dev/null 2>&1
out="$(_git_grove_set "${GROVE}-seat" --env camp 2>&1)"; rc=$?
record "arm 3 · git grove set --env on an --alias hetzner entry with a tailnet host" "$out"
claim "3e8. a later field update is judged on the merged entry: served (rc 0), the alias kept" \
  bash -c '[[ "$1" -eq 0 && "$(jq -r .sshAlias "$2")" == infra-seat ]]' _ "$rc" "$GIT_FOREST_DIR/groves/${GROVE}-seat.json"
# the alias is wake's to write, through its one writer — never a second block from set
out="$(_git_grove_set "${GROVE}-solo" --at "camper@$TAILHOST:22" --env camp 2>&1)"; rc=$?
record "arm 3 · git grove set --at, no --alias" "$out"
claim "3f. a set with --at writes no ssh Host block (wake owns the alias)" \
  bash -c '! grep -rqs "^Host $1\$" "$2/.ssh"' _ "${GROVE}-solo" "$HOME"
claim "3g. the --at line names the entry and hands over the wake" \
  bash -c '[[ "$1" == *"grove '"'"'$2'"'"' registered → camper@$3:22"* && "$1" == *"git grove wake $2"* ]]' \
  _ "$out" "${GROVE}-solo" "$TAILHOST"

# del strips the seat's block from wake's config.d, and keeps every neighbour block.
#   a tailnet entry's name in ~/.ssh/config is INFRA's block — del must leave it.
#   the ssh dir is restored after, so the arms below start from the state they always did
cp -a "$HOME/.ssh" "$FIX/ssh.before"
mkdir -p "$HOME/.ssh/config.d"
for sshcfg in "$HOME/.ssh/config.d/grove.conf" "$HOME/.ssh/config"; do
  printf 'Host %s\n  HostName %s\n\nHost keep-me\n  HostName 192.0.2.7\n' "${GROVE}-solo" "$TAILHOST" >> "$sshcfg"
done
out="$(_git_grove_del "${GROVE}-solo" 2>&1)"; rc=$?
record "arm 3 · git grove del, a tailnet entry, a block in each ssh file" "$out"
claim "3h. del unregisters the entry (exit 0)" \
  bash -c '[[ "$1" -eq 0 && "$2" == *"grove '"'"'$3'"'"' unregistered"* ]]' _ "$rc" "$out" "${GROVE}-solo"
claim "3i. del strips the block from config.d/grove.conf" \
  bash -c '! grep -qxF "Host $1" "$2"' _ "${GROVE}-solo" "$HOME/.ssh/config.d/grove.conf"
claim "3j. del LEAVES infra's block for a tailnet name in ~/.ssh/config" \
  bash -c 'grep -qxF "Host $1" "$2"' _ "${GROVE}-solo" "$HOME/.ssh/config"
claim "3k. del keeps every neighbour block, in both files" \
  bash -c 'grep -qxF "Host keep-me" "$1" && grep -qxF "Host keep-me" "$2"' _ "$HOME/.ssh/config.d/grove.conf" "$HOME/.ssh/config"
# a TUNNEL entry (loopback host) is the one an older writer laid in ~/.ssh/config
_git_grove_set "${GROVE}-tunnel" --at "ec2-user@localhost:2222" --env camp >/dev/null 2>&1
printf 'Host %s\n  HostName localhost\n  Port 2222\n' "${GROVE}-tunnel" >> "$HOME/.ssh/config"
out="$(_git_grove_del "${GROVE}-tunnel" 2>&1)"; rc=$?
record "arm 3 · git grove del, a tunnel entry an older writer laid" "$out"
claim "3j2. del strips an older writer's tunnel block from ~/.ssh/config" \
  bash -c '[[ "$1" -eq 0 ]] && ! grep -qxF "Host $2" "$3"' _ "$rc" "${GROVE}-tunnel" "$HOME/.ssh/config"
claim "3j3. and still keeps infra's tailnet block beside it" \
  bash -c 'grep -qxF "Host $1" "$2"' _ "${GROVE}-solo" "$HOME/.ssh/config"
out="$(_git_grove_del "${GROVE}-solo" 2>&1)"; rc=$?
record "arm 3 · git grove del, a name no longer registered" "$out"
claim "3l. a second del refuses by name (exit 2)" \
  bash -c '[[ "$1" -eq 2 && "$2" == *"ConstraintError: grove"*"not found"* ]]' _ "$rc" "$out"
rm -rf "$HOME/.ssh" && mv "$FIX/ssh.before" "$HOME/.ssh"
echo ""

######################################################################
# arm 1 — wake
######################################################################
echo "   arm 1 — git.grove.wake, tailnet reach"
# ANOTHER writer (infra) already laid a block for the camper's name, which
#   points at GROUND — 📜 2026-11-15, grove-ahbode-hetzner-v20261022
OWNED="$HOME/.ssh/config.d/grove.conf"
printf 'Host %s\n  HostName 192.0.2.9\n  User ground\n' "$GROVE" > "$HOME/.ssh/config"
seat_of() { ssh -G "$1" 2>/dev/null | awk '$1 == "user" { u = $2 } $1 == "hostname" { h = $2 } END { print u "@" h }'; }
claim "1z. fixture · before wake, the camper name reaches ground" [ "$(seat_of "$GROVE")" = "ground@192.0.2.9" ]

out="$(bash "$SKILLS/git.grove.wake.sh" "$GROVE" --mode apply 2>&1)"; rc=$?
record "arm 1 · wake, first run" "$out"
claim "1a. wake answers ✔ over ssh with no aws (exit 0)" [ "$rc" -eq 0 ]
claim "1b. wake names the tailnet reach" has "$out" "reach: the tailnet"
claim "1c. the registry's block is written [SET]" has "$out" "[SET]"
claim "1d. the block dials the registry's host, not localhost" \
  grep -qx "  HostName $TAILHOST" "$OWNED"
claim "1h. the owned file is the FIRST line of ~/.ssh/config" \
  [ "$(head -n 1 "$HOME/.ssh/config")" = "Include $OWNED" ]
claim "1i. ssh now reaches the REGISTRY's seat for the camper name" [ "$(seat_of "$GROVE")" = "camper@$TAILHOST" ]
claim "1j. the other writer's block is left as it stands" \
  grep -qx "  User ground" "$HOME/.ssh/config"
cp "$HOME/.ssh/config" "$FIX/config.after1"; cp "$OWNED" "$FIX/owned.after1"
out="$(bash "$SKILLS/git.grove.wake.sh" "$GROVE" --mode apply 2>&1)"
record "arm 1 · wake, re-run" "$out"
claim "1e. a re-run KEEPS the block" has "$out" "[KEEP]"
claim "1f. a re-run writes no byte to either file" \
  bash -c 'cmp -s "$1" "$2" && cmp -s "$3" "$4"' _ "$HOME/.ssh/config" "$FIX/config.after1" "$OWNED" "$FIX/owned.after1"
claim "1g. the round trip rides the alias, BatchMode on" \
  grep -q "BatchMode=yes .*$GROVE true" "$FIX/ssh.calls"

# the box does not answer: wake names what ssh said, and the fix
touch "$FIX/ssh.fail"
out="$(bash "$SKILLS/git.grove.wake.sh" "$GROVE" --mode apply 2>&1)"; rc=$?
rm -f "$FIX/ssh.fail"
record "arm 1 · wake, the box does not answer" "$out"
claim "1k. an unanswered round trip fails the wake (exit ≠ 0)" [ "$rc" -ne 0 ]
claim "1l. the failure quotes what ssh said" has "$out" "Connection timed out"

# the box ANSWERS and ssh refuses its host key (a first contact, a rebuilt box):
#   reach holds, so the wake passes, and names trust as the next step — else a
#   first boot could never reach its own trust step
touch "$FIX/hostkey.fail"
out="$(bash "$SKILLS/git.grove.wake.sh" "$GROVE" --mode apply 2>&1)"; rc=$?
rm -f "$FIX/hostkey.fail"
record "arm 1 · wake, the box answers with a host key not yet trusted" "$out"
claim "1m. an untrusted host key still proves reach (exit 0)" [ "$rc" -eq 0 ]
claim "1n. it says the key is not yet trusted, and names trust.gen" \
  bash -c '[[ "$1" == *"host key is not yet trusted here"* && "$1" == *"git.grove.trust.gen --grove"* ]]' _ "$out"

# the box ANSWERS and refuses this laptop's key: an authorization fault, never silence
touch "$FIX/pubkey.fail"
out="$(bash "$SKILLS/git.grove.wake.sh" "$GROVE" --mode apply 2>&1)"; rc=$?
rm -f "$FIX/pubkey.fail"
record "arm 1 · wake, the box refuses this laptop's key" "$out"
claim "1o. a refused key is a constraint (exit 2), never a malfunction" [ "$rc" -eq 2 ]
claim "1p. it names this laptop's key as the cause, never tailnet silence" \
  bash -c '[[ "$1" == *"refused this laptop'"'"'s key"* && "$1" != *"a silence is reach"* ]]' _ "$out"
claim "1q. it names the skill that places a key, run where ground is reached" \
  has "$out" "rhx git.grove.auth.ssh.set $GROVE --identity <this laptop's key>.pub --mode plan"

# the box answers and the alias cannot be written: the writer names why, and wake
#   says the duct itself is not at fault. the ec2 path prints the same sentence,
#   through the same writer (`grove_ssh_alias_set`)
cp "$OWNED" "$FIX/owned.before.ro"
printf 'Host %s\n  HostName 192.0.2.8\n' "$GROVE" > "$OWNED"   # a block that differs, so the writer must write
chmod 555 "$(dirname "$OWNED")"; chmod 444 "$OWNED"
out="$(bash "$SKILLS/git.grove.wake.sh" "$GROVE" --mode apply 2>&1)"; rc=$?
chmod 755 "$(dirname "$OWNED")"; chmod 644 "$OWNED"; cp "$FIX/owned.before.ro" "$OWNED"
record "arm 1 · wake, the alias file cannot be written" "$out"
claim "1r. an unwritable alias is a 💥 (exit 1)" [ "$rc" -eq 1 ]
claim "1s. it names the alias it could not set" \
  has "$out" "└─ alias '$GROVE' could not be set to the registry's seat"
# the writer's fault and the tool's own words nest UNDER that line — none lands raw at column 0
claim "1s2. the writer's 💥 sits one level under the alias line" \
  has "$out" "      💥 MalfunctionError: could not make a tmp file in"
claim "1s3. mktemp's own words ride under the 💥, never at column 0" \
  has "$out" "⇒ it said: mktemp:"

# a registry value outside its grammar, and one that ssh would read as an option:
#   each refused before any reach, its fix the set that rewrites the entry
REG="$GIT_FOREST_DIR/groves"
jq '.exid = "bad exid"' "$REG/$GROVE.json" > "$REG/${GROVE}-grammar.json"
out="$(bash "$SKILLS/git.grove.wake.sh" "${GROVE}-grammar" --mode apply 2>&1)"; rc=$?
record "arm 1 · wake, a registry exid outside its grammar" "$out"
claim "1t. a byte outside the grammar is a ✋ (exit 2), with the fix" \
  bash -c '[[ "$1" -eq 2 && "$2" == *"✋ ConstraintError: the registry'"'"'s exid holds a byte outside its grammar"* && "$2" == *"fix: rhx git.grove.set"* ]]' _ "$rc" "$out"
jq '.sshAlias = "-oProxyCommand"' "$REG/$GROVE.json" > "$REG/${GROVE}-dash.json"
out="$(bash "$SKILLS/git.grove.wake.sh" "${GROVE}-dash" --mode apply 2>&1)"; rc=$?
record "arm 1 · wake, a registry sshAlias whose first byte is '-'" "$out"
claim "1u. a '-' at the head is a ✋ (exit 2), and never reaches ssh" \
  bash -c '[[ "$1" -eq 2 && "$2" == *"✋ ConstraintError: the registry'"'"'s sshAlias starts with '"'"'-'"'"'"* ]] && ! grep -qF -- "-oProxyCommand" "$3"' _ "$rc" "$out" "$FIX/ssh.calls"
jq '.host = "-oProxyCommand"' "$REG/$GROVE.json" > "$REG/${GROVE}-hostdash.json"
out="$(bash "$SKILLS/git.grove.wake.sh" "${GROVE}-hostdash" --mode apply 2>&1)"; rc=$?
record "arm 1 · wake, a registry host whose first byte is '-'" "$out"
claim "1v. a host with '-' at the head is a ✋ (exit 2), before either reach" \
  bash -c '[[ "$1" -eq 2 && "$2" == *"✋ ConstraintError: the registry'"'"'s host starts with '"'"'-'"'"' — ssh would read it as an option"* ]] && ! grep -qF -- "-oProxyCommand" "$3"' _ "$rc" "$out" "$FIX/ssh.calls"
rm -f "$REG/${GROVE}-grammar.json" "$REG/${GROVE}-dash.json" "$REG/${GROVE}-hostdash.json"
echo ""

######################################################################
# arm 2 — trust.gen
######################################################################
echo "   arm 2 — git.grove.trust.gen, tailnet attestation"
# the builder laid ONE key (ed25519), under the bare host name (port 22)
echo "$TAILHOST $(awk '{print $1, $2}' "$FIX/keys/host_ed25519.pub")" > "$HOME/.ssh/known_hosts"

offer_keys "$FIX/keys/host_ed25519" "$FIX/keys/host_ecdsa" "$FIX/keys/host_rsa"
report_keys "$FIX/keys/host_ed25519" "$FIX/keys/host_ecdsa" "$FIX/keys/host_rsa"
out="$(bash "$SKILLS/git.grove.trust.gen.sh" --grove "$GROVE" 2>&1)"; rc=$?
record "arm 2 · trust.gen, plan" "$out"
claim "2a. no /proc port read — the host is scanned direct" has "$out" "no local tunnel"
claim "2b. the box itself attests, over ssh pinned to the trusted key" has "$out" "pinned to its trusted key (ssh-ed25519)"
claim "2c. every offered key matches (plan exit 0)" [ "$rc" -eq 0 ]
claim "2d. no key is refused" hasnot "$out" "NO boot record match"
claim "2e. the pin narrows HostKeyAlgorithms to the trusted type" \
  grep -q "HostKeyAlgorithms=ssh-ed25519 " "$FIX/ssh.calls"

out="$(bash "$SKILLS/git.grove.trust.gen.sh" --grove "$GROVE" --mode apply 2>&1)"; rc=$?
record "arm 2 · trust.gen, apply" "$out"
claim "2f. apply trusts the two absent keys (exit 0)" [ "$rc" -eq 0 ]
claim "2g. known_hosts files the keys under the bare host (port 22)" \
  [ "$(grep -c "^$TAILHOST " "$HOME/.ssh/known_hosts")" -eq 3 ]
claim "2h0. the trusted key is not appended a second time" \
  [ "$(grep -c "^$TAILHOST ssh-ed25519 " "$HOME/.ssh/known_hosts")" -eq 1 ]

# the subset check still bites: an offered key the box does not report
offer_keys "$FIX/keys/host_ed25519" "$FIX/keys/intruder"
report_keys "$FIX/keys/host_ed25519" "$FIX/keys/host_ecdsa" "$FIX/keys/host_rsa"
sed -i "/^$TAILHOST ssh-ed25519 /!d" "$HOME/.ssh/known_hosts"
out="$(bash "$SKILLS/git.grove.trust.gen.sh" --grove "$GROVE" --mode apply 2>&1)"; rc=$?
record "arm 2 · trust.gen, an unreported key (refused)" "$out"
claim "2h. an unreported key is refused (exit ≠ 0)" [ "$rc" -ne 0 ]
claim "2i. the refusal names the unmatched key" has "$out" "NO boot record match"
claim "2j. the intruder key was not written" \
  [ "$(grep -c "^$TAILHOST " "$HOME/.ssh/known_hosts")" -eq 1 ]

# the pinned channel itself fails — never read as a box that reported no key
offer_keys "$FIX/keys/host_ed25519" "$FIX/keys/host_ecdsa"
touch "$FIX/pin.fail"
out="$(bash "$SKILLS/git.grove.trust.gen.sh" --grove "$GROVE" --mode apply 2>&1)"; rc=$?
record "arm 2 · trust.gen, the pinned ssh fails" "$out"
claim "2k. a failed pinned ssh halts as a malfunction (exit 1)" [ "$rc" -eq 1 ]
claim "2l. it relays what ssh said" has "$out" "Host key verification failed."
claim "2m. it never falls to the ec2 boot-record text" hasnot "$out" "ec2 console output"
claim "2n. no key was written" \
  [ "$(grep -c "^$TAILHOST " "$HOME/.ssh/known_hosts")" -eq 1 ]
rm -f "$FIX/pin.fail"

# the box offers NO key (offline, or replaced under a new tailnet name): the text names
#   the tailnet and its peers, never a tunnel or an ssm session the box does not have
#   (📜 2026-11-18: a rebuilt box's old name timed out, and the text blamed ssm)
: > "$FIX/offer"
out="$(bash "$SKILLS/git.grove.trust.gen.sh" --grove "$GROVE" --timeout 1 2>&1)"; rc=$?
record "arm 2 · trust.gen, the tailnet name offers no key" "$out"
claim "2n2. a silent tailnet name fails (exit 1), named by its host" \
  bash -c '[[ "$1" -eq 1 && "$2" == *"$3:22 offered no host keys"* ]]' _ "$rc" "$out" "$TAILHOST"
claim "2n3. it names a replacement box and the tailnet peers read" \
  bash -c '[[ "$1" == *"joins under a NEW tailnet name"* && "$1" == *"rhx network.tailnet.peers.get --match"* ]]' _ "$out"
claim "2n4. it never names a tunnel or an ssm session" \
  bash -c '[[ "$1" != *"ssm"* && "$1" != *"tunnel is bound"* ]]' _ "$out"

# FIRST contact: no key on record, so no channel attests. a plan surveys (exit 0) and
#   names tofu; an apply refuses in tailnet words; tofu writes. never the ec2 text
cp "$HOME/.ssh/known_hosts" "$FIX/known_hosts.before"
: > "$HOME/.ssh/known_hosts"
offer_keys "$FIX/keys/host_ed25519" "$FIX/keys/host_ecdsa"
out="$(bash "$SKILLS/git.grove.trust.gen.sh" --grove "$GROVE" 2>&1)"; rc=$?
record "arm 2 · trust.gen, first contact, plan" "$out"
claim "2o. a first-contact plan is a survey (exit 0)" [ "$rc" -eq 0 ]
claim "2p. it names the tofu it would need" has "$out" "would need --trust tofu"
claim "2q. it never prints the ec2 console words" hasnot "$out" "ec2 console output"
out="$(bash "$SKILLS/git.grove.trust.gen.sh" --grove "$GROVE" --mode apply 2>&1)"; rc=$?
record "arm 2 · trust.gen, first contact, apply" "$out"
claim "2r. a first-contact apply refuses (exit 2), in tailnet words" \
  bash -c '[[ "$1" -eq 2 && "$2" == *"a tailnet box has no boot record"* && "$2" != *"hibernate"* ]]' _ "$rc" "$out"
claim "2s. it names the tofu apply, and writes no key" \
  bash -c '[[ "$1" == *"--mode apply --trust tofu"* && ! -s "$2" ]]' _ "$out" "$HOME/.ssh/known_hosts"
out="$(bash "$SKILLS/git.grove.trust.gen.sh" --grove "$GROVE" --mode apply --trust tofu 2>&1)"; rc=$?
record "arm 2 · trust.gen, first contact, apply --trust tofu" "$out"
claim "2t. tofu trusts the offered keys (exit 0)" \
  bash -c '[[ "$1" -eq 0 && "$(grep -c "^$2 " "$3")" -eq 2 ]]' _ "$rc" "$TAILHOST" "$HOME/.ssh/known_hosts"

# a REBUILT box: the key on record CHANGED. the refusal names infra's fingerprints, never
#   a local port; a replace attests the new key over ssh pinned to a key still on record
ssh-keygen -q -t ed25519 -N '' -f "$FIX/keys/rebuilt" -C ''
offer_keys "$FIX/keys/rebuilt" "$FIX/keys/host_ecdsa"
report_keys "$FIX/keys/rebuilt" "$FIX/keys/host_ecdsa"
out="$(bash "$SKILLS/git.grove.trust.gen.sh" --grove "$GROVE" --mode apply 2>&1)"; rc=$?
record "arm 2 · trust.gen, a changed key" "$out"
claim "2u. a changed key is refused (exit 2)" [ "$rc" -eq 2 ]
claim "2v. it names infra's fingerprints, never a local port" \
  bash -c '[[ "$1" == *"infra"* && "$1" != *"local port"* && "$1" != *"ss -tlnp"* ]]' _ "$out"
claim "2w. it names the attested replace" has "$out" "--mode apply --on-changed replace"
out="$(bash "$SKILLS/git.grove.trust.gen.sh" --grove "$GROVE" --mode apply --on-changed replace 2>&1)"; rc=$?
record "arm 2 · trust.gen, a changed key, replace" "$out"
claim "2x. a replace attested by a key still on record lays the rebuilt key, drops the old" \
  bash -c '[[ "$1" -eq 0 ]] && grep -qF "$(cut -d" " -f2 "$2")" "$4" && ! grep -qF "$(cut -d" " -f2 "$3")" "$4"' \
  _ "$rc" "$FIX/keys/rebuilt.pub" "$FIX/keys/host_ed25519.pub" "$HOME/.ssh/known_hosts"

# a FULL rebuild: every key on record changed, so no key still pins a channel. a replace
#   then has no attestation at all, and must refuse — never write an unattested key
ssh-keygen -q -t ed25519 -N '' -f "$FIX/keys/rebuilt2" -C ''
ssh-keygen -q -t ecdsa -b 256 -N '' -f "$FIX/keys/rebuilt2_ecdsa" -C ''
offer_keys "$FIX/keys/rebuilt2" "$FIX/keys/rebuilt2_ecdsa"
report_keys "$FIX/keys/rebuilt2" "$FIX/keys/rebuilt2_ecdsa"
cp "$HOME/.ssh/known_hosts" "$FIX/known_hosts.full"
out="$(bash "$SKILLS/git.grove.trust.gen.sh" --grove "$GROVE" --mode apply --on-changed replace 2>&1)"; rc=$?
record "arm 2 · trust.gen, a full rebuild (no key still on record), replace" "$out"
claim "2y. a replace with no key still on record refuses (exit 2)" [ "$rc" -eq 2 ]
claim "2y2. it writes no key — the file is byte-equal" cmp -s "$FIX/known_hosts.full" "$HOME/.ssh/known_hosts"
claim "2y3. it names a rebuilt tailnet box, never the ec2 text" \
  bash -c '[[ "$1" == *"ConstraintError: a rebuilt tailnet box"* && "$1" != *"ec2 console output"* ]]' _ "$out"
claim "2y4. a rebuild never advises tofu — it sends you to infra's fingerprints" \
  bash -c '[[ "$1" != *"--trust tofu"* && "$1" == *"compare the fingerprints above to infra"* ]]' _ "$out"
cp "$FIX/known_hosts.before" "$HOME/.ssh/known_hosts"
echo ""

######################################################################
# arm 2s — trust.gen, an ssm grove: a loopback host, its key attested over ssm
#   this branch shares every write with the tailnet arm above — the known_hosts
#   append, the `ssh-keygen -R … -f` of a replace — and reads a different road:
#   /proc for the bound family, a relabel to `[localhost]:<port>`, and the box's
#   own key report over `aws ssm`. a real listener binds the port, so /proc is real;
#   `aws` is a stub that answers as ssm would
######################################################################
echo "   arm 2s — git.grove.trust.gen, an ssm grove (loopback)"
SSMGROVE="grove-fixture-ec2"
python3 -c 'import socket,sys,time
s=socket.socket(); s.bind(("127.0.0.1",0)); s.listen(1)
print(s.getsockname()[1], flush=True); time.sleep(600)' > "$FIX/lport" &
LPID=$!
for _ in $(seq 50); do [[ -s "$FIX/lport" ]] && break; sleep 0.1; done
LPORT="$(cat "$FIX/lport")"
claim "2s0. a loopback listener is bound (the fixture took)" [ -n "$LPORT" ]

_git_grove_set "$SSMGROVE" --at "camper@localhost:$LPORT" --alias "$SSMGROVE" --env camp >/dev/null 2>&1
bash -c 'source "$1"; grove_ssh_alias_set alias="$2" host=localhost port="$3" user=camper identity="$4/.ssh/id"' \
  _ "$SKILLS/git.grove.ssh.operations.sh" "$SSMGROVE" "$LPORT" "$HOME" >/dev/null 2>&1

cat > "$FIX/bin/aws" <<STUB
#!/usr/bin/env bash
echo "\$*" >> "$FIX/aws.calls"
case "\$*" in
  *"ec2 describe-instances"*) echo i-fixture-ssm ;;
  *"ec2 get-console-output"*) echo "" ;;
  *"ssm send-command"*) echo cmd-fixture ;;
  *get-command-invocation*"--query Status"*) echo Success ;;
  *get-command-invocation*StandardOutputContent*) for k in \$(cat "$FIX/report"); do ssh-keygen -lf "\$k"; done ;;
esac
exit 0
STUB
chmod +x "$FIX/bin/aws"

# .what = trust.gen on the ssm grove, its per-run port masked for the transcript
ssm_trust() { AWS_ACCESS_KEY_ID=fixture bash "$SKILLS/git.grove.trust.gen.sh" --grove "$SSMGROVE" "$@" 2>&1; }
KH_SSM="[localhost]:$LPORT"

offer_keys "$FIX/keys/host_ed25519" "$FIX/keys/host_ecdsa"
report_keys "$FIX/keys/host_ed25519" "$FIX/keys/host_ecdsa"
out="$(ssm_trust --mode apply)"; rc=$?
record "arm 2s · trust.gen, an ssm grove, apply" "${out//$LPORT/<port>}"
claim "2s1. the bound family is read off /proc, and the scan aims at it" has "$out" "bound on ipv4 only (scan via 127.0.0.1)"
claim "2s2. the scan is relabeled to the name ssh looks up" has "$out" "labeled:  $KH_SSM"
claim "2s3. the box's own keys attest, over ssm" has "$out" "ssm (the box's own /etc/ssh keys)"
claim "2s4. apply trusts both offered keys under [localhost]:<port> (exit 0)" \
  bash -c '[[ "$1" -eq 0 && "$(grep -cF "$2 " "$3")" -eq 2 ]]' _ "$rc" "$KH_SSM" "$HOME/.ssh/known_hosts"
claim "2s5. the attestation asked ssm, never the pinned ssh" grep -q "ssm send-command" "$FIX/aws.calls"

out="$(ssm_trust --mode apply)"; rc=$?
record "arm 2s · trust.gen, an ssm grove, apply again" "${out//$LPORT/<port>}"
claim "2s6. a second apply writes no byte (exit 0, still 2 rows)" \
  bash -c '[[ "$1" -eq 0 && "$(grep -cF "$2 " "$3")" -eq 2 ]]' _ "$rc" "$KH_SSM" "$HOME/.ssh/known_hosts"

# a rebuilt ec2 box: the key on record CHANGED. refused, then replaced through `ssh-keygen -R … -f`
offer_keys "$FIX/keys/rebuilt" "$FIX/keys/host_ecdsa"
report_keys "$FIX/keys/rebuilt" "$FIX/keys/host_ecdsa"
out="$(ssm_trust --mode apply)"; rc=$?
record "arm 2s · trust.gen, an ssm grove, a changed key" "${out//$LPORT/<port>}"
claim "2s7. a changed key is refused (exit 2), and names the attested replace" \
  bash -c '[[ "$1" -eq 2 && "$2" == *"--on-changed replace"* ]]' _ "$rc" "$out"
out="$(ssm_trust --mode apply --on-changed replace)"; rc=$?
record "arm 2s · trust.gen, an ssm grove, a changed key, replace" "${out//$LPORT/<port>}"
# only the [localhost]:<port> rows are read: the tailnet grove's rows hold the old key too
grep -F "$KH_SSM " "$HOME/.ssh/known_hosts" > "$FIX/kh.ssm"
claim "2s8. the replace lays the rebuilt key and drops the old, under [localhost]:<port>" \
  bash -c '[[ "$1" -eq 0 ]] && grep -qF "$(cut -d" " -f2 "$2")" "$4" && ! grep -qF "$(cut -d" " -f2 "$3")" "$4"' \
  _ "$rc" "$FIX/keys/rebuilt.pub" "$FIX/keys/host_ed25519.pub" "$FIX/kh.ssm"
claim "2s9. the tailnet grove's rows are untouched by the ssm replace" \
  bash -c '[[ "$(grep -c "^$1 " "$2")" -eq "$(grep -c "^$1 " "$3")" ]]' _ "$TAILHOST" "$HOME/.ssh/known_hosts" "$FIX/known_hosts.before"

kill "$LPID" 2>/dev/null; LPID=""
rm -f "$FIX/bin/aws" "$FIX/aws.calls"
echo ""

######################################################################
# arm 4 — ready.verify, rungs 1-2, on the tailnet grove
#   rung 2's wake is stubbed here: arm 1 above proves the wake itself, so this
#   arm pins only the lines the ladder prints around it
######################################################################
echo "   arm 4 — git.grove.ready.verify, tailnet rungs"
printf '#!/usr/bin/env bash\n[[ -e %q ]] && { echo "ssh: connect to host %s port 22: Connection timed out"; exit 1; }\nexit 0\n' \
  "$FIX/wake.fail" "$TAILHOST" > "$FIX/bin/rhx"
chmod +x "$FIX/bin/rhx"
out="$(bash "$SKILLS/git.grove.ready.verify.sh" "$GROVE" --upto 2 2>&1)"; rc=$?
record "arm 4 · ready.verify --upto 2, the box answers" "$out"
claim "4a. a tailnet grove climbs rungs 1-2 (exit 0)" [ "$rc" -eq 0 ]
claim "4b. rung 1 owes no aws account on the tailnet" has "$out" "a tailnet grove ($TAILHOST): no aws account is owed"
claim "4c. rung 2's proof names the tailnet reach" has "$out" "✔ awake — answers over ssh on the tailnet"
claim "4d. no rack is asked on the tailnet" hasnot "$out" "aws profile"
touch "$FIX/wake.fail"
out="$(bash "$SKILLS/git.grove.ready.verify.sh" "$GROVE" --upto 2 2>&1)"; rc=$?
record "arm 4 · ready.verify --upto 2, the box does not answer" "$out"
claim "4e. an unanswered wake halts rung 2 (exit 3)" [ "$rc" -eq 3 ]
claim "4f. the halt names the tailnet, never a rack or a hibernate" \
  bash -c '[[ "$1" == *"did not answer over ssh on the tailnet"* && "$1" != *"rack DID"* && "$1" != *"hibernate often"* ]]' _ "$out"
rm -f "$FIX/wake.fail"
# the box ANSWERS and the wake refuses this laptop's key (rc 2): no silence to name
printf '#!/usr/bin/env bash\necho "✋ ConstraintError: answered, and refused this laptop'"'"'s key" >&2\nexit 2\n' > "$FIX/bin/rhx"
out="$(bash "$SKILLS/git.grove.ready.verify.sh" "$GROVE" --upto 2 2>&1)"; rc=$?
record "arm 4 · ready.verify --upto 2, the wake refuses this laptop's key" "$out"
claim "4k. a refused wake halts rung 2 (exit 3) and names the key placement" \
  bash -c '[[ "$1" -eq 3 && "$2" == *"the wake refused"* && "$2" == *"git.grove.auth.ssh.set"* ]]' _ "$rc" "$out"
claim "4l. it never blames the tailnet or the box's sshd" hasnot "$out" "laptop is off the tailnet"
# rung 3: the wake passed (a first contact passes it), and no session rides — the
#   halt speaks the tailnet's words: no tunnel to bind, no replace to attest
printf '#!/usr/bin/env bash\n[[ "$1" == git.grove.send ]] && { echo "Host key verification failed." >&2; exit 1; }\nexit 0\n' > "$FIX/bin/rhx"
chmod +x "$FIX/bin/rhx"
out="$(bash "$SKILLS/git.grove.ready.verify.sh" "$GROVE" --upto 3 2>&1)"; rc=$?
record "arm 4 · ready.verify --upto 3, no session rides" "$out"
claim "4g. no session halts rung 3 (exit 3)" [ "$rc" -eq 3 ]
claim "4h. the halt names tofu for a first contact" has "$out" "boot $GROVE --mode apply --trust tofu"
claim "4i. the halt names no tunnel and no replace road" \
  bash -c '[[ "$1" != *"tunnel bound"* && "$1" != *"--on-changed replace"* && "$1" != *"--prune orphans"* ]]' _ "$out"
claim "4j. no fix line ran as a command" hasnot "$out" "command not found"
rm -f "$FIX/bin/rhx"
echo ""

######################################################################
# arm 5 — stop, on the tailnet grove: naught to hibernate, no tunnel to close
#   its ec2 half would `pkill` a plugin pattern on port 22, and describe an
#   instance that does not exist. so it refuses before any of it runs
######################################################################
echo "   arm 5 — git.grove.stop, tailnet"
for b in pkill aws; do
  printf '#!/usr/bin/env bash\necho "%s $*" >> %q\nexit 0\n' "$b" "$FIX/stop.calls" > "$FIX/bin/$b"
  chmod +x "$FIX/bin/$b"
done
: > "$FIX/stop.calls"
for what in all duct; do
  out="$(bash "$SKILLS/git.grove.stop.sh" "$GROVE" --what "$what" --mode apply 2>&1)"; rc=$?
  record "arm 5 · stop --what $what --mode apply" "$out"
  claim "5a. stop --what $what refuses a tailnet grove (exit 2)" [ "$rc" -eq 2 ]
  claim "5b. stop --what $what names the tailnet reach" has "$out" "is reached over the tailnet ($TAILHOST)"
done
claim "5c. no pkill and no aws call ran" [ ! -s "$FIX/stop.calls" ]
echo ""

######################################################################
# arm 6 — auth.ssh.set, on the tailnet grove: no ssm, no ec2 lookup. the same
#   procedure runs as root over the ground seat, and reads back the same verdicts
#   (📜 2026-11-17: its ec2 half told a hetzner human "no box tagged exid… wake it",
#   and the wake answers ✔ — a loop with no exit)
######################################################################
echo "   arm 6 — git.grove.auth.ssh.set, tailnet"
: > "$FIX/stop.calls"
out="$(bash "$SKILLS/git.grove.auth.ssh.set.sh" "$GROVE" --seat camper --identity "$FIX/keys/host_ed25519.pub" --mode plan 2>&1)"; rc=$?
record "arm 6 · auth.ssh.set --mode plan, tailnet" "$out"
claim "6a. auth.ssh.set reaches a tailnet grove (exit 0)" [ "$rc" -eq 0 ]
claim "6b. it names the tailnet reach and the ground seat" has "$out" "reach: the tailnet ($TAILHOST) — via the ground seat '$GROVE.ground', no aws"
claim "6c. the seat's verdict reads back" has "$out" "camper [KEEP] already authorized"
claim "6d. no aws call ran" [ ! -s "$FIX/stop.calls" ]
claim "6e. the procedure ran as root over the ground seat" grep -q "$GROVE.ground sudo -n bash -s" "$FIX/ssh.calls"
touch "$FIX/auth.fail"
out="$(bash "$SKILLS/git.grove.auth.ssh.set.sh" "$GROVE" --seat camper --identity "$FIX/keys/host_ed25519.pub" --mode apply 2>&1)"; rc=$?
record "arm 6 · auth.ssh.set --mode apply, the ground seat holds no passwordless sudo" "$out"
claim "6f. a refused ground seat fails loud (exit 1), named" \
  bash -c '[[ "$1" -eq 1 && "$2" == *"could not run the procedure as root"* && "$2" == *"a password is required"* ]]' _ "$rc" "$out"
rm -f "$FIX/auth.fail"

# a SECOND laptop: the ground entry is registered as the howto does, with no --exid, so
#   it shares no exid with the camper — the tailnet host still names it a seat of the box
source "$HOME/.bash_aliases" 2>/dev/null || true
_git_grove_set "$GROVE.ground" --at "ground@$TAILHOST:22" --env camp --platform hetzner.hetzbot >/dev/null 2>&1
touch "$FIX/auth.set"
: > "$FIX/auth.seats"
out="$(bash "$SKILLS/git.grove.auth.ssh.set.sh" "$GROVE" --identity "$FIX/keys/rebuilt.pub" --mode plan 2>&1)"; rc=$?
record "arm 6 · auth.ssh.set --mode plan, a second laptop, both seats" "$out"
claim "6g. with no --seat, both seats of the box are planned (camper and ground)" \
  bash -c '[[ "$1" -eq 0 && "$2" == *"seats: camper ground"* && "$2" == *"ground [PLAN] would authorize"* ]]' _ "$rc" "$out"
claim "6h. the plan's footer carries the SAME key it read" \
  has "$out" "auth.ssh.set $GROVE --identity $FIX/keys/rebuilt.pub --mode apply"
out="$(bash "$SKILLS/git.grove.auth.ssh.set.sh" "$GROVE" --identity "$FIX/keys/rebuilt.pub" --mode apply 2>&1)"; rc=$?
record "arm 6 · auth.ssh.set --mode apply, a second laptop, both seats" "$out"
claim "6i. the apply sets the key on both seats, each confirmed once (exit 0)" \
  bash -c '[[ "$1" -eq 0 && "$2" == *"camper [SET] authorized ✔ confirmed present once"* && "$2" == *"ground [SET] authorized ✔ confirmed present once"* ]]' _ "$rc" "$out"
claim "6j. the apply names its read-back" has "$out" "🌲 authorized — every named seat holds this box's key ✔"
out="$(bash "$SKILLS/git.grove.auth.ssh.set.sh" "$GROVE.ground" --identity "$FIX/keys/rebuilt.pub" --mode plan 2>&1)"; rc=$?
record "arm 6 · auth.ssh.set on the ground entry itself" "$out"
claim "6k. a call on the ground entry rides the ground seat, never '.ground.ground'" \
  bash -c '[[ "$1" -eq 0 && "$2" == *"via the ground seat '"'"'$3.ground'"'"'"* && "$2" != *".ground.ground"* ]]' _ "$rc" "$out" "$GROVE"
rm -f "$FIX/auth.set" "$FIX/bin/pkill" "$FIX/bin/aws"
rm -f "$GIT_FOREST_DIR/groves/$GROVE.ground.json"
echo ""

# shellcheck source=/dev/null
source "$ROOT/.play/permanent/play.snap.operations.sh"
claim "snapshot · the transcript every arm printed" \
  play_snap_verify dir="$ROOT/.play/permanent/prove.tailnet-grove-is-reached-and-trusted.snap" name=transcript actual="$transcript"

echo "🌊 $passed held · $failed failed"
[[ "$failed" -eq 0 ]] || exit 1
exit 0

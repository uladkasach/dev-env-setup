#!/usr/bin/env bash
######################################################################
# .what = drive the grove alias resolver, and `git grove send` through it, against
#         an ssh that dials another seat than the registry declares
#
# .why  = 📜 2026-11-18, grove-ahbode-hetzner-v20261022: the registry named
#         `camper`, infra's Host block for the same name named `ground`, and no
#         camper alias was ever laid where ssh reads first. every "camper" send ran
#         as ground for days and no command errored. the resolver now reads
#         `ssh -G` back, so a misrouted send halts before the duct is touched
#
# guarantee:
#   - HERMETIC. a scratch HOME holds the registry; `ssh` is a stub on PATH that
#     answers `-G` from env, since a real ssh reads the passwd home, never $HOME
#   - the duct is a stub that records each call, so a refusal is proven to land
#     BEFORE any keystroke could reach a seat
######################################################################

set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ALIASES="$HERE/src/grove.provision/2.shell/2.7.aliases/bash_aliases.sh"
[[ -r "$ALIASES" ]] || { echo "✋ ConstraintError: bash_aliases.sh is absent from $HERE" >&2; exit 2; }

fixture="$(mktemp -d)" || { echo "💥 MalfunctionError: could not make a temp dir" >&2; exit 1; }
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/bin" "$fixture/.git.forest/groves"

# a stub ssh: `-G` answers the effective config from env; any other call is a fault
printf '%s\n' '#!/usr/bin/env bash' \
  '[[ "${1:-}" == "-G" ]] || { echo "stub ssh: only -G is expected here" >&2; exit 99; }' \
  'printf "user %s\nhostname %s\nport %s\n" "$SSH_G_USER" "$SSH_G_HOST" "$SSH_G_PORT"' > "$fixture/bin/ssh"
chmod +x "$fixture/bin/ssh"

# one registry entry — $1 = name · $2 = user · $3 = host ('' for an --alias seat) · $4 = port
reg() {
  jq -n --arg n "$1" --arg u "$2" --arg h "$3" --arg p "$4" \
    '{name: $n, sshAlias: $n, user: $u, host: (if $h == "" then null else $h end), port: ($p | tonumber)}' \
    > "$fixture/.git.forest/groves/$1.json"
}
reg grove-fix camper grove-fix 22
reg grove-fix-infra camper "" 22

failed=0
transcript=""
cry() { echo "$1" >&2; transcript+="$1"$'\n'; }

echo "🌲 prove.send-refuses-a-misrouted-seat"

# one row — $1 = label · $2 = grove · $3 = ssh -G user · $4 = host · $5 = port
#           $6 = exit wanted · $7 = text the output must hold · $8 = duct calls wanted
row() {
  local label="$1" grove="$2" out rc calls
  rm -f "$fixture/duct.calls"
  out="$(HOME="$fixture" PATH="$fixture/bin:$PATH" SSH_G_USER="$3" SSH_G_HOST="$4" SSH_G_PORT="$5" bash -c '
    source "$1" >/dev/null 2>&1
    duct.open() { echo open >> "$HOME/duct.calls"; }
    duct.send() { echo send >> "$HOME/duct.calls"; }
    _git_grove_send "$2" --what "id -un"' _ "$ALIASES" "$grove" 2>&1)" && rc=0 || rc=$?
  calls="$( [[ -f "$fixture/duct.calls" ]] && wc -l < "$fixture/duct.calls" || echo 0)"
  calls="${calls// /}"
  transcript+=$'\n'"## $label"$'\n'"rc=$rc duct-calls=$calls"$'\n'"$out"$'\n'
  if [[ "$rc" -eq "$6" && "$out" == *"$7"* && "$calls" -eq "$8" ]]; then
    echo "   • $label → rc=$rc, duct calls=$calls ✔"
    return 0
  fi
  cry "   💥 MalfunctionError: $label → rc=$rc (want $6), duct calls=$calls (want $8), holds '$7': $([[ "$out" == *"$7"* ]] && echo yes || echo no)"
  failed=1
}

row "another Host block names ground → refused, no duct touched" \
  grove-fix ground grove-fix 22 2 "dials another seat than the registry declares" 0
row "the refusal names the fix" \
  grove-fix ground grove-fix 22 2 "rhx git.grove.wake grove-fix" 0
row "the alias dials another host → refused" \
  grove-fix camper grove-elsewhere 22 2 "ssh -G:   camper@grove-elsewhere:22" 0
row "the alias dials another port → refused" \
  grove-fix camper grove-fix 2222 2 "ssh -G:   camper@grove-fix:2222" 0
row "the alias dials the registry's seat → the send reaches the duct" \
  grove-fix camper grove-fix 22 0 "" 2
row "an --alias seat (no host) whose block names another user → refused" \
  grove-fix-infra ground infra-host 22 2 "registry: camper@<its own Host block>" 0
row "an --alias seat whose block names its user → the send reaches the duct" \
  grove-fix-infra camper infra-host 22 0 "" 2

# shellcheck source=/dev/null
source "$HERE/.play/permanent/play.snap.operations.sh"
play_snap_verify dir="$HERE/.play/permanent/prove.send-refuses-a-misrouted-seat.snap" name=transcript actual="$transcript" \
  || failed=1

[[ "$failed" -eq 0 ]] && echo "🌲 all claims held ✔"
exit "$failed"

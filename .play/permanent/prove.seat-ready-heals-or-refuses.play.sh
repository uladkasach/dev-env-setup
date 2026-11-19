#!/usr/bin/env bash
######################################################################
# .what = drive `grove_ssh_seat_ready`, the gate every grove-dial skill passes
#         first, against each seat shape it must heal or refuse
#
# .why  = 📜 2026-11-18, the first hetzner grove: no camper alias was laid
#         where ssh reads first, so infra's Host block (User ground) answered every
#         "camper" dial. a refusal alone would leave the grove unusable until a
#         human ran the wake; so a tailnet seat is LAID to the registry on the spot,
#         and only a seat this repo may not write (an --alias seat) is refused
#
# guarantee:
#   - HERMETIC. a scratch HOME holds the registry and ~/.ssh; `ssh` is a stub on
#     PATH that answers `-G` the way a real ssh would: the owned file's block
#     first (it is Included first), else the "other" block named by env
#   - each row asserts the exit, the stderr text, and the seat ssh dials after
######################################################################

set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OPS="$HERE/.agent/repo=.this/role=any/skills/git.grove.ssh.operations.sh"
[[ -r "$OPS" ]] || { echo "✋ ConstraintError: git.grove.ssh.operations.sh is absent from $HERE" >&2; exit 2; }

fixture="$(mktemp -d)" || { echo "💥 MalfunctionError: could not make a temp dir" >&2; exit 1; }
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/bin" "$fixture/.git.forest/groves"

# a stub ssh: `-G <alias>` reads the owned file's block for <alias> first, then
#   falls back to the block "another writer" laid (env OTHER_USER/HOST/PORT)
cat > "$fixture/bin/ssh" <<'STUB'
#!/usr/bin/env bash
[[ "${1:-}" == "-G" ]] || { echo "stub ssh: only -G is expected here" >&2; exit 99; }
own="$HOME/.ssh/config.d/grove.conf"
blk=""
[[ -f "$own" ]] && blk="$(awk -v a="$2" '$1=="Host"{on=($2==a); next} on' "$own")"
if [[ -n "$blk" ]]; then
  echo "$blk" | awk '{k=tolower($1)} k=="user"||k=="hostname"||k=="port"||k=="identityfile"{print k, $2}'
  exit 0
fi
printf 'user %s\nhostname %s\nport %s\nidentityfile ~/.ssh/id_rsa\n' "$OTHER_USER" "$OTHER_HOST" "$OTHER_PORT"
STUB
chmod +x "$fixture/bin/ssh"

# one registry entry — $1 = name · $2 = user · $3 = host ('' for an --alias seat)
reg() {
  jq -n --arg n "$1" --arg u "$2" --arg h "$3" \
    '{name: $n, sshAlias: $n, user: $u, host: (if $h == "" then null else $h end), port: 22}' \
    > "$fixture/.git.forest/groves/$1.json"
}
reg grove-fix camper grove-fix
reg grove-fix-infra camper ""

failed=0
transcript=""
cry() { echo "$1" >&2; transcript+="$1"$'\n'; }

echo "🌲 prove.seat-ready-heals-or-refuses"

# one row — $1 = label · $2 = grove · $3 = other block's user · $4 = its host
#           $5 = exit wanted · $6 = text the output must hold · $7 = seat wanted after
row() {
  local label="$1" grove="$2" out rc seat
  out="$(HOME="$fixture" PATH="$fixture/bin:$PATH" OTHER_USER="$3" OTHER_HOST="$4" OTHER_PORT=22 bash -c '
    source "$1"
    grove_ssh_seat_ready "$2"' _ "$OPS" "$grove" 2>&1)" && rc=0 || rc=$?
  out="${out//$fixture/<home>}"
  seat="$(HOME="$fixture" PATH="$fixture/bin:$PATH" OTHER_USER="$3" OTHER_HOST="$4" OTHER_PORT=22 bash -c '
    source "$1"; grove_ssh_seat_effective "$2"' _ "$OPS" "$grove" 2>/dev/null)"
  transcript+=$'\n'"## $label"$'\n'"rc=$rc seat=$seat"$'\n'"$out"$'\n'
  if [[ "$rc" -eq "$5" && "$out" == *"$6"* && "$seat" == "$7" ]]; then
    echo "   • $label → rc=$rc, seat=$seat ✔"
    return 0
  fi
  cry "   💥 MalfunctionError: $label → rc=$rc (want $5), seat=$seat (want $7), holds '$6': $([[ "$out" == *"$6"* ]] && echo yes || echo no)"
  failed=1
}

row "a tailnet seat with no owned block, another block names ground → laid to camper" \
  grove-fix ground grove-fix 0 "🔧 alias 'grove-fix' laid to the registry's seat" "camper@grove-fix:22"
row "the same seat, run again → kept, silent" \
  grove-fix ground grove-fix 0 "" "camper@grove-fix:22"

# the owned block points at a host the box has left (the -1 suffix it moved off)
mkdir -p "$fixture/.ssh/config.d"
printf 'Host grove-fix\n  HostName grove-fix-1\n  Port 22\n  User camper\n  IdentityFile ~/.ssh/id_ed25519\n' \
  > "$fixture/.ssh/config.d/grove.conf"
row "a tailnet seat whose owned block names a stale host → relaid to the registry's host" \
  grove-fix ground grove-fix 0 "laid to the registry's seat" "camper@grove-fix:22"

row "an --alias seat whose block names another user → refused" \
  grove-fix-infra ground infra-host 2 "✋ ConstraintError: ssh alias 'grove-fix-infra' dials ground@infra-host:22" "ground@infra-host:22"
row "the refusal names the fix" \
  grove-fix-infra ground infra-host 2 "fix: rhx git.grove.wake grove-fix-infra" "ground@infra-host:22"
row "an --alias seat whose block names its user → passes" \
  grove-fix-infra camper infra-host 0 "" "camper@infra-host:22"
row "a grove the registry does not hold → passes, the caller names the absence" \
  grove-absent ground nowhere 0 "" "ground@nowhere:22"

# shellcheck source=/dev/null
source "$HERE/.play/permanent/play.snap.operations.sh"
play_snap_verify dir="$HERE/.play/permanent/prove.seat-ready-heals-or-refuses.snap" name=transcript actual="$transcript" \
  || failed=1

[[ "$failed" -eq 0 ]] && echo "🌲 all claims held ✔"
exit "$failed"

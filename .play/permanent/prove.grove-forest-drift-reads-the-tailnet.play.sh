#!/usr/bin/env bash
######################################################################
# .what = drive the forest's drift read and `git grove sync` against a stubbed
#         tailnet, and fail unless each row names the right fix and sync writes
#         only what a box DECLARES
#
# .why  = the forest is a cache of hand writes. a replaced box leaves a dead row
#         and no live one, and `git grove list` once printed the dead row as a 🌳
#         while every reach dialed it. the drift read names each gap; sync closes
#         what it can prove and never deletes
#
# guarantee:
#   - HERMETIC: a temp HOME holds the registry; `tailscale` and `ssh` are stubs
#     first on PATH, so no tailnet and no box is reached
#   - each path is driven: a dead entry, a new hetzner peer, a peer that declares
#     naught, an ec2 entry the tailnet cannot judge, a tailnet with no grove peer,
#     and no tailnet at all
######################################################################

set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

stubs="$(mktemp -d)"
home="$(mktemp -d)"
trap 'rm -rf "$stubs" "$home"' EXIT

# tailscale: `status --json` answers the case's peers, or fails
cat > "$stubs/tailscale" <<'STUB'
#!/usr/bin/env bash
[[ -n "${STUB_TS_RC:-}" ]] && exit "$STUB_TS_RC"
printf '%s' "$STUB_TS_JSON"
STUB
# ssh: `camper@<box> cat /etc/grove/platform` — a box in STUB_HETZNER declares hetzner
cat > "$stubs/ssh" <<'STUB'
#!/usr/bin/env bash
target=""
for a in "$@"; do [[ "$a" == camper@* ]] && target="${a#camper@}"; done
[[ " ${STUB_HETZNER:-} " == *" $target "* ]] && { echo hetzner.hetzbot; exit 0; }
echo "camper@$target: Permission denied (publickey)." >&2
exit 255
STUB
chmod +x "$stubs/tailscale" "$stubs/ssh"

peers_json() {
  local out='{"Peer":{' sep="" n
  for n in "$@"; do out+="$sep\"$n\":{\"DNSName\":\"$n.tailnet.example.\",\"Online\":true}"; sep=","; done
  printf '%s}}' "$out"
}

failed=0
transcript=""
fail() { echo "   💥 MalfunctionError: $1" >&2; failed=1; }
claim() { local label="$1"; shift; if "$@"; then echo "   • $label ✔"; else fail "$label"; fi; }

# run a git grove verb in a fresh shell with the checkout's aliases, the temp HOME, the stubs
OUT="" RC=0
grove() {
  OUT="$(env HOME="$home" PATH="$stubs:$PATH" timeout -k 2 30 bash -c \
           'source "$1" >/dev/null 2>&1; shift; git_alias_grove "$@"' _ \
           "$HERE/src/grove.provision/2.shell/2.7.aliases/bash_aliases.sh" "$@" </dev/null 2>&1)" && RC=0 || RC=$?
  OUT="$(printf '%s\n' "$OUT" | sed -e "s#$home#<home>#g")"
}
drift() {
  OUT="$(env HOME="$home" PATH="$stubs:$PATH" timeout -k 2 30 bash -c \
           'source "$1" >/dev/null 2>&1; _git_grove_drift' _ \
           "$HERE/src/grove.provision/2.shell/2.7.aliases/bash_aliases.sh" </dev/null 2>&1)" && RC=0 || RC=$?
}
snap() { transcript+=$'\n'"## $1"$'\n'"rc=$RC"$'\n'"$OUT"$'\n'; }
has() { [[ "$OUT" == *"$1"* ]]; }
lacks() { [[ "$OUT" != *"$1"* ]]; }

echo "🌲 prove.grove-forest-drift-reads-the-tailnet"

# the registry: a live hetzner grove and its seat, a dead one, and an ec2 grove on its tunnel
grove set grove-a        --at camper@grove-a:22    --platform hetzner.hetzbot
grove set grove-a.ground --at ground@grove-a:22    --platform hetzner.hetzbot
grove set grove-dead     --at camper@grove-dead:22 --platform hetzner.hetzbot
grove set grove-ec2      --exid grove-ec2 --at camper@localhost:36000
reg="$home/.git.forest/groves"
claim "the registry holds four entries" test "$(find "$reg" -name '*.json' | wc -l)" -eq 4

export STUB_TS_JSON STUB_HETZNER STUB_TS_RC
STUB_TS_JSON="$(peers_json grove-a grove-new grove-other)"
STUB_HETZNER="grove-new"
STUB_TS_RC=""

drift
claim "drift · reads, rc 0" test "$RC" -eq 0
claim "drift · the dead entry is gone"            has $'gone\tgrove-dead'
claim "drift · the live grove is not gone"        lacks $'gone\tgrove-a'
claim "drift · its seat lives with it"            lacks "grove-a.ground"
claim "drift · an ec2 entry is never judged"      lacks "grove-ec2"
claim "drift · the new hetzner peer is new"       has $'new\tgrove-new'
claim "drift · the undeclared peer is new"        has $'new\tgrove-other'

grove sync; snap "sync · plan"
claim "sync plan · rc 0"                           test "$RC" -eq 0
claim "sync plan · names the dead row's del"       has "git grove del grove-dead"
claim "sync plan · would register the hetzner box" has "would register grove-new and grove-new.ground"
claim "sync plan · the undeclared peer is a ?, with ssh's cause" has "ssh said: camper@grove-other: Permission denied"
claim "sync plan · writes naught"                  test ! -f "$reg/grove-new.json"

grove sync --mode apply; snap "sync · apply"
claim "sync apply · rc 0"                                     test "$RC" -eq 0
claim "sync apply · registers the camper seat, as hetzner"    test "$(jq -r .platform "$reg/grove-new.json" 2>/dev/null)" = hetzner.hetzbot
claim "sync apply · registers the ground seat"                test -f "$reg/grove-new.ground.json"
claim "sync apply · never registers an undeclared box"        test ! -f "$reg/grove-other.json"
claim "sync apply · never deletes the dead row"               test -f "$reg/grove-dead.json"

grove sync --mode apply; snap "sync · apply again"
claim "sync apply again · the hetzner box is no longer new"   lacks "grove-new —"

grove list; snap "list · against the tailnet"
claim "list · names the dead row with its del"  has "git grove del grove-dead"

# the two skills a human runs: git.grove.list warns on STDOUT when the installed aliases
#   differ from this checkout; network.tailnet.peers.get prints each peer's acl tags
SKILLS="$HERE/.agent/repo=.this/role=any/skills"
skill() {
  local name="$1"; shift
  OUT="$(env HOME="$home" PATH="$stubs:$PATH" timeout -k 2 30 bash "$SKILLS/$name.sh" "$@" </dev/null 2>/dev/null)" && RC=0 || RC=$?
  OUT="$(printf '%s\n' "$OUT" | sed -e "s#$home#<home>#g")"
}
cp "$HERE/src/grove.provision/2.shell/2.7.aliases/bash_aliases.sh" "$home/.bash_aliases"
skill git.grove.list; snap "git.grove.list · aliases match"
claim "git.grove.list · aliases match · rc 0"    test "$RC" -eq 0
claim "git.grove.list · aliases match · no warn" lacks "differs from this checkout"
printf '\n# a stale copy\n' >>"$home/.bash_aliases"
skill git.grove.list; snap "git.grove.list · aliases differ"
claim "git.grove.list · aliases differ · rc 0"               test "$RC" -eq 0
claim "git.grove.list · aliases differ · warns on stdout"    has "~/.bash_aliases differs from this checkout"
claim "git.grove.list · aliases differ · names the bundle"   has "--what 2.7.aliases"
STUB_TS_JSON='{"Peer":{"a":{"DNSName":"grove-a.tailnet.example.","Online":true,"Tags":["tag:grove","tag:hetzner"]},"b":{"DNSName":"laptop-1.tailnet.example.","Online":false,"LastSeen":"2026-01-02T03:04:05Z"}}}'
skill network.tailnet.peers.get; snap "network.tailnet.peers.get · tags"
claim "peers.get · rc 0"                       test "$RC" -eq 0
claim "peers.get · a tagged peer shows its tags" has "grove-a  online ✔  · tag:grove,tag:hetzner"
claim "peers.get · an untagged peer shows none" has "laptop-1  offline · last seen 2026-01-02T03:04"

# a tailnet that holds NO grove peer is likely another tailnet: it judges no entry dead
STUB_TS_JSON="$(peers_json laptop-1)"
drift
claim "no grove peer · reads, rc 0"              test "$RC" -eq 0
claim "no grove peer · no entry is called gone"  lacks "gone"

# no tailnet at all: the read refuses, and sync names the bundle that lays tailscale
STUB_TS_RC=1
drift
claim "no tailnet · drift refuses, rc 2"         test "$RC" -eq 2
grove sync; snap "sync · no tailnet"
claim "no tailnet · sync refuses, rc 2"          test "$RC" -eq 2
claim "no tailnet · sync names its fix"          has "5.23.tailscale"

# shellcheck source=/dev/null
source "$HERE/.play/permanent/play.snap.operations.sh"
play_snap_verify dir="$HERE/.play/permanent/prove.grove-forest-drift-reads-the-tailnet.snap" name=transcript actual="$transcript" \
  || failed=1

[[ "$failed" -eq 0 ]] && echo "🌲 all claims held ✔"
exit "$failed"

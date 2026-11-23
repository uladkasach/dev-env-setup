#!/usr/bin/env bash
######################################################################
# .what = drive the forest's tailnet and ssh readers against the REAL tailnet and a
#         REAL hetzner grove, and fail unless each answers in the shape its code reads
#
# .why  = `prove.grove-forest-drift-reads-the-tailnet` and `prove.play-stop-reads-three-answers`
#         stub `tailscale` and `ssh`, so a drift in `tailscale status --json` (a field
#         renamed) or in the ssh transport (an option refused, an exit code moved) would
#         pass both while every live read broke. this play reads the real ones
#
# .the claims
#   1. `tailscale status --json` parses, holds `.Peer`, and each peer carries the fields
#      the readers use: `.DNSName` a string, `.Online` a boolean; `.Tags` and `.LastSeen`,
#      where present, an array and a string
#   2. `_git_grove_tailnet_groves` reads it, rc 0, and names at least one grove peer
#   3. `_git_grove_platform_of` reads a live hetzner grove's `/etc/grove/platform` over ssh
#   4. `git.grove.play.stop` on that grove, for a play no process holds: rc 0, `stopped: none`
#   5. `git.grove.sync`, in plan: rc 0, and the forest registry is byte-equal after
#
# guarantee:
#   - READ-ONLY on this box: the registry is hashed before and after
#   - on the grove: a pgrep that matches naught, and a `df`; no kill lands, no file moves
#   - declines (exit 2, named) where no tailnet answers, or no registered hetzner grove
#     is online on it — a decline proves no claim, and says which subject is absent
######################################################################

set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ALIASES="$HERE/src/grove.provision/2.shell/2.7.aliases/bash_aliases.sh"
SKILLS="$HERE/.agent/repo=.this/role=any/skills"
REG="$HOME/.git.forest/groves"

scratch="$(mktemp -d)" || { echo "💥 MalfunctionError: could not make a temp dir" >&2; exit 1; }
trap 'rm -rf "$scratch"' EXIT

failed=0
fail() { echo "   💥 MalfunctionError: $1" >&2; failed=1; }
claim() { local label="$1"; shift; if "$@"; then echo "   • $label ✔"; else fail "$label"; fi; }
jqtrue() { jq -e "$1" "$2" >/dev/null 2>&1; }
decline() { echo "🌙 prove.grove-reach-answers-live declined: $1" >&2; echo "   └─ $2" >&2; exit 2; }

echo "🌲 prove.grove-reach-answers-live"

######################################################################
# 1. the real tailnet answers, in the shape the readers read
######################################################################
command -v tailscale >/dev/null 2>&1 \
  || decline "no tailscale on this box" "run it on a box that holds the tailnet: rhx grove.provision --what 5.23.tailscale"
timeout -k 2 10 tailscale status --json </dev/null >"$scratch/status.json" 2>"$scratch/status.err" \
  || decline "tailscale did not answer: $(head -n 1 "$scratch/status.err")" "start the tailnet on this box, then rerun"
claim "tailnet · status --json parses, and holds .Peer" jqtrue '.Peer | type == "object"' "$scratch/status.json"
claim "tailnet · each peer's .DNSName is a string, .Online a boolean" \
  jqtrue '[.Peer[] | (.DNSName | type == "string") and (.Online | type == "boolean")] | all' "$scratch/status.json"
claim "tailnet · .Tags, where present, is an array; .LastSeen, a string" \
  jqtrue '[.Peer[] | ((.Tags // []) | type == "array") and ((.LastSeen // "") | type == "string")] | all' "$scratch/status.json"

######################################################################
# 2. the reader the drift and sync stand on
######################################################################
groves="$(bash -c 'source "$1" >/dev/null 2>&1; _git_grove_tailnet_groves' _ "$ALIASES" </dev/null)"; rc=$?
claim "reader · _git_grove_tailnet_groves reads the tailnet, rc 0" test "$rc" -eq 0
claim "reader · it names at least one grove peer, each online|offline" \
  bash -c '[[ -n "$1" ]] && ! grep -qvE "^grove-[^[:space:]]+	(online|offline)$" <<<"$1"' _ "$groves"

# the subject for 3–5: an online grove peer the forest registers as hetzner
target=""
while IFS=$'\t' read -r name state; do
  [[ "$state" == online && -f "$REG/$name.json" ]] || continue
  [[ "$(jq -r '.platform // empty' "$REG/$name.json")" == hetzner.hetzbot ]] || continue
  target="$name"; break
done <<<"$groves"
[[ -n "$target" ]] \
  || decline "no registered hetzner grove is online on this tailnet" "wake one (rhx git.grove.wake <grove> --mode apply), then rerun"
echo "   └─ subject: an online hetzner grove the forest registers"

######################################################################
# 3. the platform read, over the real ssh
######################################################################
platform="$(bash -c 'source "$1" >/dev/null 2>&1; _git_grove_platform_of "$2" "$3"' _ "$ALIASES" "$target" "$scratch/ssh.err" </dev/null)"
claim "ssh · the grove declares hetzner.hetzbot, read as camper" test "$platform" = hetzner.hetzbot
[[ "$platform" == hetzner.hetzbot ]] || sed 's/^/      │ /' "$scratch/ssh.err" >&2

######################################################################
# 4. a stop, for a play no process holds
######################################################################
out="$(timeout -k 5 90 bash "$SKILLS/git.grove.play.stop.sh" "$target" --play prove.no-process-holds-this-play </dev/null 2>&1)"; rc=$?
claim "stop · rc 0 over the real transport" test "$rc" -eq 0
claim "stop · the grove answers: stopped: none" bash -c '[[ "$1" == *"stopped: none"* ]]' _ "$out"
claim "stop · the grove reports its disk after" bash -c '[[ "$1" == *"disk after:"* ]]' _ "$out"
[[ "$rc" -eq 0 ]] || printf '%s\n' "$out" | sed 's/^/      │ /' >&2

######################################################################
# 5. a sync plan reads both, and writes naught
######################################################################
sum_reg() { find "$REG" -maxdepth 1 -type f -name '*.json' -print0 2>/dev/null | sort -z | xargs -0 -r sha256sum | sha256sum; }
before="$(sum_reg)"
# this checkout's `git grove sync`, never the box's installed copy, which may predate it
out="$(timeout -k 5 120 bash -c 'source "$1" >/dev/null 2>&1; git_alias_grove sync' _ "$ALIASES" </dev/null 2>&1)"; rc=$?
claim "sync · a plan over the real tailnet, rc 0" test "$rc" -eq 0
claim "sync · the forest registry is byte-equal after the plan" test "$(sum_reg)" = "$before"
[[ "$rc" -eq 0 ]] || printf '%s\n' "$out" | sed 's/^/      │ /' >&2

echo
[[ "$failed" -eq 0 ]] || { echo "💥 prove.grove-reach-answers-live — a claim missed" >&2; exit 1; }
echo "🌲 all claims held ✔"

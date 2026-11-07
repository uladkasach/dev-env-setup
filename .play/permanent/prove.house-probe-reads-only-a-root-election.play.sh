#!/usr/bin/env bash
######################################################################
# .what = drive `grove_env_probe_house` through its trust bar and its one yes
#
# 🛑 .why the probe needs a clamp
#   - the house election is the one input that turns off every "a human is
#     here" gate for its user. a probe that trusts the wrong file lets a seat
#     choose its own tier
#   - the answer cannot come from the hardware: a house seat IS its host's
#     hardware. so the probe must run BEFORE the desktop probe, or a seat that
#     holds a forwarded DISPLAY calls itself `local@unix`
#   - a real house grove exercises only the yes path. every refusal below is a
#     path no healthy box takes, so only a fixture can reach it
#
# .the claims
#   1. no election dir        → the probe declines
#   2. an election the seat owns, that names the seat → declines (the seat
#      cannot elect itself; vision case=2, `[t3]`)
#   3. the trust bar itself   → root 0755 and 0640 pass; a 1777 dir and a
#      user-owned path fail
#   4. a root-owned election that names this user → `house@unix`, and it wins
#      over a forwarded DISPLAY (vision case=2, `[t2]`)
#   5. a root-owned election that names some OTHER user → not `house@*`
#
# ⚠️ .why claims 4 and 5 need `sudo -n`, and why its absence FAILS
#   - a root-owned fixture can only be written by root. there is no honest way
#     to fake one; a probe that trusted a non-root fixture would be the defect
#   - so where `sudo -n true` fails, this play fails loud and names the fix. a
#     silent skip would report the yes path proven on a box that never ran it
#     (`rule.forbid.failhide`)
#   - a ci runner and a grove's ground seat hold `sudo -n`. on a laptop the
#     human warms it first: `sudo -v && rhx play.run --play <this>`
#
# guarantee:
#   - it writes ONLY fixtures under a fresh `mktemp -d`, and a trap removes them,
#     root-owned ones included. no file outside those dirs is touched
#   - it never writes `/etc/grove/house.d`; the probe is pointed at the fixture
#     via `GROVE_HOUSE_ELECTION_DIR`, which moves where it reads, never whom it
#     trusts
######################################################################

set -u

# the checkout: this play's own, else the cwd, else a pushed wip, else main —
# the ladder `prove.every-bundle-is-dispatched` paved, since a duct-sent play
# runs from a copy under ~/.local/state, far from any checkout
_self="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." 2>/dev/null && pwd)" || _self=""
if   [[ -n "$_self" && -f "$_self/src/grove.env.sh" ]];            then _root="$_self"
elif [[ -f "$PWD/src/grove.env.sh" ]];                             then _root="$PWD"
elif [[ -f "$HOME/git/more/dev-env-setup.wip/src/grove.env.sh" ]]; then _root="$HOME/git/more/dev-env-setup.wip"
else                                                                   _root="$HOME/git/more/dev-env-setup"
fi

# 🛑 an absent probe must FAIL, never read as a decline. with the function
#    unset, `grove_env_probe_house` answers "command not found" — non-zero, the
#    same exit a correct decline gives. so three of the five claims below would
#    report ✔ on a box that never ran the probe (measured on first send)
# shellcheck source=/dev/null
source "$_root/src/grove.env.sh" 2>/dev/null
if ! declare -F grove_env_probe_house grove_env_probe_house_trusted >/dev/null; then
  echo "   ✋ ConstraintError: no house probe in $_root/src/grove.env.sh" >&2
  echo "      ⇒ every claim below would read an absent function as a decline" >&2
  echo "      fix: rhx git.grove.push <grove> --from . --into git/more/dev-env-setup.wip --mode apply" >&2
  exit 2
fi

echo "🌲 prove.house-probe-reads-only-a-root-election"
echo "   • checkout: $_root"

failed=0
me="$(id -un)"

# a fixture dir the play owns; the root-owned one, if any, is made later
mine="$(mktemp -d)"
rooted=""
grove_house_probe_cleanup() {
  rm -rf "$mine"
  [[ -n "$rooted" ]] && sudo -n rm -rf "$rooted"
}
trap grove_house_probe_cleanup EXIT

# .what = derive the server in a clean subshell, with the probe aimed at $1
# .why  = `grove_env_derive` exports, and a second derive in this shell would
#         read the first one's answer back. a subshell starts each arm fresh
grove_house_probe_server() {
  (
    unset GROVE_ENV_SERVER GROVE_ENV_TIER_NATURAL
    export GROVE_HOUSE_ELECTION_DIR="$1"
    [[ -n "${2:-}" ]] && export DISPLAY="$2"
    grove_env_derive >/dev/null 2>&1 && echo "$GROVE_ENV_SERVER"
  )
}

# claim 1 — no election dir at all
if GROVE_HOUSE_ELECTION_DIR="$mine/absent" grove_env_probe_house; then
  echo "   ✋ claim 1: the probe answered yes with no election dir" >&2
  failed=1
else
  echo "   • claim 1: no election dir → declines ✔"
fi

# claim 2 — the seat writes its own election, and names itself
printf 'camper %s\n' "$me" | tee "$mine/self-elected" >/dev/null
chmod 0644 "$mine/self-elected"
chmod 0755 "$mine"
if GROVE_HOUSE_ELECTION_DIR="$mine" grove_env_probe_house; then
  echo "   ✋ claim 2: an election owned by $me elected $me" >&2
  echo "      ⇒ a seat that writes its own marker chooses its own tier" >&2
  failed=1
else
  echo "   • claim 2: a self-written election → declines ✔"
fi

# claim 3 — the trust bar, on paths whose owner and mode the box already fixes
claim3=0
grove_env_probe_house_trusted /etc        || { echo "   ✋ claim 3: /etc (root, 0755) was refused" >&2; claim3=1; }
grove_env_probe_house_trusted /etc/passwd || { echo "   ✋ claim 3: /etc/passwd (root, 0644) was refused" >&2; claim3=1; }
grove_env_probe_house_trusted /tmp        && { echo "   ✋ claim 3: /tmp (1777) was trusted" >&2; claim3=1; }
grove_env_probe_house_trusted "$mine"     && { echo "   ✋ claim 3: a dir owned by $me was trusted" >&2; claim3=1; }
if [[ "$claim3" -eq 0 ]]; then
  echo "   • claim 3: root 0755/0644 trusted; 1777 and user-owned refused ✔"
else
  failed=1
fi

# claims 4 and 5 — a root-owned election, which only root can write
if ! sudo -n true 2>/dev/null; then
  echo "   ✋ ConstraintError: claims 4 and 5 need a root-owned fixture, and sudo -n cannot answer" >&2
  echo "      ⇒ the yes path is unproven here; a skip would report it proven" >&2
  echo "      fix: sudo -v && rhx play.run --play prove.house-probe-reads-only-a-root-election" >&2
  exit 2
fi

rooted="$(sudo -n mktemp -d)"
sudo -n chmod 0755 "$rooted"
printf 'camper %s\nground %s\n' "$me" "house-fixture-ground" | sudo -n tee "$rooted/house-fixture" >/dev/null
sudo -n chmod 0644 "$rooted/house-fixture"

got="$(grove_house_probe_server "$rooted")"
if [[ "$got" == "house@unix" ]]; then
  echo "   • claim 4: a root election that names $me → house@unix ✔"
else
  echo "   ✋ claim 4: a root election that names $me → '${got:-<halt>}', expected house@unix" >&2
  failed=1
fi

got="$(grove_house_probe_server "$rooted" ":0")"
if [[ "$got" == "house@unix" ]]; then
  echo "   • claim 4: … and it wins over a forwarded DISPLAY ✔"
else
  echo "   ✋ claim 4: with DISPLAY=:0 → '${got:-<halt>}', expected house@unix" >&2
  echo "      ⇒ the desktop probe ran first, and a grove seat called itself a laptop" >&2
  failed=1
fi

# claim 5 — the same election, for a user it does not name
printf 'camper %s\n' "house-fixture-other" | sudo -n tee "$rooted/house-fixture" >/dev/null
got="$(grove_house_probe_server "$rooted")"
if [[ "$got" != house@* ]]; then
  echo "   • claim 5: a root election that names another user → ${got:-<halt>}, not house ✔"
else
  echo "   ✋ claim 5: a root election for another user made $me a house seat" >&2
  failed=1
fi

[[ "$failed" -eq 0 ]] && echo "🌲 all five claims held ✔"
exit "$failed"

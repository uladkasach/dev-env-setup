#!/usr/bin/env bash
######################################################################
# .what = prove EVERY reader of "is this port bound" consults BOTH address
#         families, and reddens the day a new one is written v4-only
#
# 🛑 .why a play, and not a brief
#   - `/proc/net/tcp` holds ipv4 rows ONLY
#   - a listener on `::1` — what `ssh -L` gives when the local end resolves v6-first — lands in `/proc/net/tcp6` and no other file
#   - a v4-only reader answers `unbound` about a bound port, and every caller downstream inherits that
#   - the cost is NOT uniform across callers:
#
#     | site                      | a v4-only miss costs            |
#     | git.grove.wake            | a wrong row                     |
#     | git.grove.trust.gen       | ssh-keyscan aimed at no family  |
#     | git.grove.stop            | 🛑 A SKIPPED KILL               |
#
#   - `stop` is the destructive one: an empty `$BOUND` skips both `pkill` lines
#   - the tunnel survives a `stop` that then halts the box it points at
#   - the human reads `duct [KEEP] no tunnel bound` — a bound-but-mute duct, made by the command whose job was to close it
#
# 📜 2026-09-02: round 18 added the tcp6 arm to `git.grove.wake` but left `git.grove.stop` v4-only — the DESTRUCTIVE half kept the defect for one hour, one screen below the comment written to close that exact drift (`gotcha.a-check-that-cries-wolf-gets-silenced`, m.9)
#
#   ⚠️ no brief catches this: a peer is recognized by SHAPE, never text
#      - a rule that says "read both families" is read only by whoever already went to look
#      - this play looks on every run (`inventory.security-checks.md`, the quarantined-lesson heuristic)
#
# .what it does to the box
#   - READS tracked files and reports — no write, no kill, no network
#   - safe on a laptop and on a grove alike
#
# guarantee:
#   - it DISCOVERS its subjects rather than holds a list, so a fourth reader written tomorrow is measured tomorrow (`rule.require.bundle-as-sole-declaration` — the same reason a count is never written into a brief)
#   - it decouples the two halves it asks: a file that names `/proc/net/tcp` must also name `/proc/net/tcp6`, and the reverse
#   - it HALTS (exit 2) when it finds no reader at all, rather than report a clean page about an empty set (`gotcha…`, m.12 — a total is only true of the set the reader could reach)
#
# usage:
#   rhx play.run --play prove.port-reads-span-both-families
#
# exit:
#   0 = every reader spans both families
#   1 = at least one reads one family only
#   2 = the subject could not be read, so no claim was proven
######################################################################

set -uo pipefail

echo "🔎 prove.port-reads-span-both-families"
echo "   └─ subject: every /proc/net/tcp reader in this repo"
echo ""

######################################################################
# 0. stand in the repo root, so the subject is THIS tree
#
# ⚠️ a relative path measures whatever tree it was invoked from
#   - `git rev-parse` names the tree under test explicitly (`prove.plays-read-the-tree-under-test`)
######################################################################
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo "")"
if [[ -z "$ROOT" ]]; then
  echo "   └─ 🌙 not inside a git checkout, so the subject tree is unnamed" >&2
  echo "      · run this from within the dev-env-setup checkout" >&2
  exit 2
fi
cd "$ROOT" || exit 2

######################################################################
# 1. DISCOVER the readers — never a hand-written list
#
# 🛑 a hand list cannot report the member nobody added
#   - the only member this play exists to catch (`rule.require.one-command-provision` grades a hand-written tool list a blocker for exactly this reason)
#
# .why the discriminator
#   - the v4 path is matched as a whole token: `/proc/net/tcp` not followed by `6`
#   - that separates the two halves — a file that names only the v6 path is just as wrong, and the same walk catches it
######################################################################
######################################################################
# 1a. PROVE THE CLASSIFIER BITES, before it is aimed at a real file
#
# 🛑 a check proven in one direction only is half proven
#   - every LIVE row below is a ✔ on a healthy tree
#   - a green page is evidence about the pass path alone, silent on whether a real v4-only reader reddens (`gotcha.a-check-that-cries-wolf-gets-silenced`, `.the corollary for anyone who writes a check`)
#
# 📜 first cut of this play lacked this arm: its classifier was broken by `pipefail` (see `:2`), and the broken verdict read indistinguishable from a true finding
#
# ⚠️ the fixtures are STRINGS, not planted files
#   - a planted file needs `git add` to enter the walk
#   - a crash mid-probe leaves a fabricated reader in the index
#   - a string costs no write at all
######################################################################
_classify() {
  local body="$1" v4=0 v6=0
  grep -qE '/proc/net/tcp([^6]|$)' <<<"$body" && v4=1
  grep -qE '/proc/net/tcp6'        <<<"$body" && v6=1
  echo "$v4$v6"
}

FIX_BOTH='awk "" /proc/net/tcp 2>/dev/null
awk "" /proc/net/tcp6 2>/dev/null'
FIX_V4ONLY='awk "" /proc/net/tcp 2>/dev/null'
FIX_V6ONLY='awk "" /proc/net/tcp6 2>/dev/null'

SELFTEST=0
[[ "$(_classify "$FIX_BOTH")"   == "11" ]] || SELFTEST=$((SELFTEST + 1))
[[ "$(_classify "$FIX_V4ONLY")" == "10" ]] || SELFTEST=$((SELFTEST + 1))
[[ "$(_classify "$FIX_V6ONLY")" == "01" ]] || SELFTEST=$((SELFTEST + 1))

if [[ "$SELFTEST" -gt 0 ]]; then
  echo "   └─ 💥 the classifier fails its own fixtures ($SELFTEST of 3)" >&2
  echo "      · it cannot tell a both-family reader from a one-family one" >&2
  echo "      · every verdict below would be unfounded, so none is offered" >&2
  exit 2
fi
echo "   ├─ classifier: ✔ discriminates (3/3 fixtures)"

######################################################################
# 1b. DISCOVER the live readers
######################################################################
mapfile -t SUBJECTS < <(
  git grep -l -E '/proc/net/tcp' -- '*.sh' 2>/dev/null | sort -u
)

if [[ "${#SUBJECTS[@]}" -eq 0 ]]; then
  echo "   └─ 🌙 no file in this tree names /proc/net/tcp" >&2
  echo "      · either the readers were renamed, or this walk went blind" >&2
  echo "      · a clean page over an empty set proves no claim" >&2
  exit 2
fi

echo "   ├─ readers found: ${#SUBJECTS[@]}"
echo "   │"

######################################################################
# 2. ask each one BOTH halves
#
# ⚠️ this play is its OWN subject — it names both paths in its header, matches the walk, and must pass its own test
#   - deliberate: a clamp exempt from its own rule is a clamp nobody has read
######################################################################
FAILED=0
for f in "${SUBJECTS[@]}"; do
  # a `#`-led line is prose, not a reader — strip comments before the ask
  #   - unstripped, a block that DESCRIBES the defect reads as the defect
  #     (`gotcha.a-check-that-cries-wolf-gets-silenced`, m.7 — the exact shape
  #     that made the kitty clamp report a moved gate as a revert, same day)
  code="$(sed 's/#.*$//' "$f")"

  ####################################################################
  # 🛑 a `<<<` REDIRECT, never `printf … | grep -q`
  #
  # .why
  #   - `grep -q` exits the instant it matches, SIGPIPEing whatever still writes into it
  #   - under `set -o pipefail` the pipeline reports 141, so `&& has_v6=1` never runs and the file scores as v4-only
  #   - the race is by FILE SIZE: a SIGPIPE fires only when more text follows the match than the pipe buffer holds — silent on a short subject, fires on a long one
  #   - a `<<<` is a REDIRECT, not a pipeline: `pipefail` has no pipeline to grade, and `grep`'s own exit is the only verdict (`gotcha.pipefail-grep-q`)
  #
  # 📜 2026-09-02, this play's first run: reported `git.grove.stop.sh` as v4-only SIXTY SECONDS after both arms were written into it — a false ✋ against the repair it protects, two of three subjects passed despite the bug (`gotcha.a-check-that-cries-wolf-gets-silenced`)
  ####################################################################
  # the SAME classifier the fixtures above proved — one reader, so a fix to
  # the discriminator reaches proof and measurement together
  # (`rule.forbid.two-writers-on-one-artifact`)
  verdict="$(_classify "$code")"
  has_v4="${verdict:0:1}"; has_v6="${verdict:1:1}"

  # a file whose only mention was in prose has no reader to judge — skip it,
  # and SAY so, rather than score it either way
  if [[ "$has_v4" -eq 0 && "$has_v6" -eq 0 ]]; then
    echo "   ├─ 🌙 $f"
    echo "   │     names the path in prose only — no reader to judge"
    continue
  fi

  if [[ "$has_v4" -eq 1 && "$has_v6" -eq 1 ]]; then
    echo "   ├─ ✔ $f"
    echo "   │     spans both families"
    continue
  fi

  FAILED=$((FAILED + 1))
  if [[ "$has_v6" -eq 0 ]]; then
    echo "   ├─ ✋ $f"
    echo "   │     reads /proc/net/tcp and NOT /proc/net/tcp6"
    echo "   │     · a listener on ::1 reads as unbound"
    echo "   │     · fix: add the tcp6 arm beside the tcp one"
  else
    echo "   ├─ ✋ $f"
    echo "   │     reads /proc/net/tcp6 and NOT /proc/net/tcp"
    echo "   │     · a listener on 127.0.0.1 reads as unbound"
    echo "   │     · fix: add the tcp arm beside the tcp6 one"
  fi
done

echo "   │"

######################################################################
# 3. the verdict
######################################################################
if [[ "$FAILED" -gt 0 ]]; then
  echo "   └─ ✋ $FAILED reader(s) read ONE address family" >&2
  echo "      · every such reader answers 'unbound' about a bound port" >&2
  echo "      · in git.grove.stop that is a SKIPPED KILL, not a wrong row" >&2
  exit 1
fi

echo "   └─ ✔ every reader spans both address families"
exit 0

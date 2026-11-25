#!/usr/bin/env bash
######################################################################
# .what = prove `git.commit.push --auth as-human` asks the human's gh login for the
#         push credential, on a seat whose own https helper declines
#
# .why  = the upstream verb (rhachet-roles-ehmpathy 1.43.0) applied as-human to the
#         pr open alone; its push rode the seat's helper. on a laptop that helper is
#         keyrack, which declines there, so the push died on a username prompt.
#         patches/rhachet-roles-ehmpathy@1.43.0.patch scopes gh's credential to the
#         one push command; upstream: ehmpathy/rhachet-roles-ehmpathy#1471
#
# .the stand-ins
#   - .mock = `gh` — answers `auth git-credential get` with a fake login, and records
#             that it was asked
#     .why  = a real login would push for real
#     .real = the branch push of this tree, via the same verb, under the human's gh
#   - .mock = the seat's https helper — a decliner, as keyrack declines on a laptop
#     .why  = the real keyrack helper would read the human's rack
#     .real = `2.2.git`'s `git-credential-keyrack`, which declines on `local@*`
#
# .what it does to the box
#   - none: a throwaway HOME and repo, removed on exit. the fixture HOME's org meter
#     allows the fixture org; no real meter is read or written. the push goes to an absent
#     github repo under fake creds, so github refuses it; the claim grades the ask
#
# usage:
#   rhx play.run --play prove.git-commit-push-as-human-asks-gh-at-the-push
#
# exit:
#   0 = every claim held · 1 = a claim failed · 2 = the subject is unreadable
######################################################################

set -uo pipefail

echo "🔎 prove.git-commit-push-as-human-asks-gh-at-the-push"
echo "   └─ subject: rhachet-roles-ehmpathy git.commit.push --auth as-human"
echo ""

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo "")"
[[ -n "$ROOT" ]] || { echo "   └─ ✋ ConstraintError: not inside a git checkout" >&2; exit 2; }
VERB="$ROOT/node_modules/rhachet-roles-ehmpathy/dist/domain.roles/mechanic/skills/git.commit/git.commit.push.sh"
if [[ ! -f "$VERB" ]]; then
  echo "   └─ ✋ ConstraintError: the verb is absent: $VERB" >&2
  echo "      fix: rhx pnpm.modules.sync --mode apply" >&2
  exit 2
fi

failed=0; passed=0
claim() {
  local label="$1"; shift
  if "$@"; then echo "   ✔ $label"; passed=$((passed + 1)); return 0; fi
  echo "   💥 MalfunctionError: $label" >&2; failed=$((failed + 1))
}

FIX="$(mktemp -d)" || { echo "   └─ 💥 MalfunctionError: could not build a fixture dir" >&2; exit 1; }
trap 'rm -rf "$FIX"' EXIT
HOME_FIX="$FIX/home"; BIN="$FIX/bin"; REPO="$FIX/repo"
mkdir -p "$HOME_FIX" "$BIN" "$REPO"

# the seat's helper declines, as keyrack does on a laptop
printf '#!/usr/bin/env bash\necho "decliner: no token here" >&2\nexit 0\n' > "$BIN/git-credential-decline"
# gh answers the credential ask with a fake login, and records the ask
printf '#!/usr/bin/env bash\nif [[ "$1 $2" == "auth git-credential" ]]; then echo asked >> "%s/gh.asked"; [[ "$3" == get ]] && printf "username=x-access-token\\npassword=fake\\n"; exit 0; fi\nexit 1\n' "$FIX" > "$BIN/gh"
chmod +x "$BIN/git-credential-decline" "$BIN/gh"

cat > "$HOME_FIX/.gitconfig" <<EOF
[user]
	name = seaturtle[bot]
	email = seaturtle@example.com
[credential "https://github.com"]
	helper = $BIN/git-credential-decline
[init]
	defaultBranch = main
EOF

# a repo on a feature branch, one seaturtle commit, a push grant, an absent origin
(
  export HOME="$HOME_FIX"
  cd "$REPO" || exit 1
  git init -q
  git commit -q --allow-empty -m 'fix(clamp): one commit'
  git checkout -q -b clamp/as-human
  git remote add origin "https://github.com/ehmpathy/clamp-absent-$RANDOM$RANDOM.git"
  mkdir -p .meter
  printf '{"uses":"infinite","push":"allow","stage":"allow"}' > .meter/git.commit.uses.jsonc
  mkdir -p .agent "$HOME/.rhachet/storage/repo=ehmpathy/role=mechanic/.meter"
  printf 'org: ehmpathy\n' > .agent/keyrack.yml
  printf '{"orgs":{"ehmpathy":"allowed"}}' > "$HOME/.rhachet/storage/repo=ehmpathy/role=mechanic/.meter/git.commit.uses.org.jsonc"
) || { echo "   └─ 💥 MalfunctionError: could not build the fixture repo" >&2; exit 1; }

out="$(cd "$REPO" && env -u GH_TOKEN -u GITHUB_TOKEN HOME="$HOME_FIX" PATH="$BIN:$PATH" \
  GIT_TERMINAL_PROMPT=0 timeout 60 bash "$VERB" --mode apply --auth as-human 2>&1)"

claim "the verb reached its push (no gate refused first)" \
  bash -c '[[ "$1" != *"push not allowed"* && "$1" != *"not authored"* && "$1" != *"ConstraintError"* ]]' _ "$out"
claim "as-human: the push asked the human's gh for its credential" \
  test -s "$FIX/gh.asked"
claim "as-human: the push never fell to a username prompt" \
  bash -c '[[ "$1" != *"could not read Username"* ]]' _ "$out"

echo ""
[[ $failed -eq 0 ]] || { echo "🌊 $passed held · $failed failed"; echo "$out" | tail -n 12 >&2; exit 1; }
echo "🌊 $passed held · 0 failed"

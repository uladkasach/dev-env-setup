#!/usr/bin/env bash
######################################################################
# git-credential-keyrack — let plain `git` over https draw from the rack
#
# .what = a git credential helper. git runs it with a verb (`get`/`store`/
#         `erase`) and feeds it a key=value block on stdin; for `get` it answers
#         with a username and password on stdout, or answers with silence.
# .why
#   - the rack already holds the token, age-encrypted — this is the seam that
#     lets git read it, with no shell export, no gh hosts.yml, no ssh key
#   - it reads `@all.camp.GITHUB_TOKEN`. `@all` is a REQUIREMENT, since git
#     runs a helper from whatever clone the human stands in
#   - ⚠️ it DECLINES on every unhappy path — exit 0, empty stdout, the reason on
#     stderr — so a PUBLIC clone never breaks on it
#   - ⚠️ every call is BOUNDED, since a helper that hangs hangs git
#   - 🛑 never answer a read failure with a switch to `@this`
# .refs = gotcha.2-2-git.demo=helper-ladder-and-its-reads — m1-m9, measured
#
# .the contract (git's, not ours)
#         stdin   protocol=https\nhost=github.com\n[path=org/repo.git]\n\n
#         stdout  username=x-access-token\npassword=<token>\n
#
# usage (git calls this; a human rarely does):
#   printf 'protocol=https\nhost=github.com\n\n' | git-credential-keyrack get
######################################################################
set -uo pipefail

VERB="${1:-}"

# ── store / erase are no-ops, and must still exit 0 — the rack is not a cache,
#    and a non-zero exit makes git report a failure on a good fetch (m3)
case "$VERB" in
  get) ;;
  store|erase) exit 0 ;;
  *)
    echo "git-credential-keyrack: unknown verb '${VERB:-（none）}'" >&2
    echo "  git calls this with get|store|erase" >&2
    exit 0
    ;;
esac

# ── read git's key=value block, up to git's blank-line terminator (m3)
declare -A REQ=()
while IFS='=' read -r k v; do
  [[ -z "$k" ]] && break
  REQ["$k"]="$v"
done

HOST="${REQ[host]:-}"
PROTOCOL="${REQ[protocol]:-}"

# ── only github, over HTTPS, is served here
# 🛑 the PROTOCOL is asked too: an `http` request would put the pat on the wire
#    in CLEARTEXT, and the helper is the last component that can refuse (m4)
if [[ "$HOST" != "github.com" || "$PROTOCOL" != "https" ]]; then
  exit 0
fi

# ── the pnpm bin dir, then NODE, for a caller whose PATH carries neither —
#    git execs this from any shell, so no rc is common to all callers. each is
#    APPENDED, so a caller's own choice still wins (m5)
if ! command -v rhx >/dev/null 2>&1; then
  PNPM_DIR="${PNPM_HOME:-$HOME/.local/share/pnpm}"
  [[ -d "$PNPM_DIR" ]]     && PATH="$PATH:$PNPM_DIR"
  [[ -d "$PNPM_DIR/bin" ]] && PATH="$PATH:$PNPM_DIR/bin"
  export PATH
fi

# fnm's `aliases/default/bin`, never the per-shell `fnm env` dir
if ! command -v node >/dev/null 2>&1; then
  FNM_DEFAULT="${FNM_DIR:-$HOME/.local/share/fnm}/aliases/default/bin"
  [[ -d "$FNM_DEFAULT" ]] && export PATH="$PATH:$FNM_DEFAULT"
fi

# ── an absent rhx is a normal window: this helper lands at 2.2, brains at 5.3
if ! command -v rhx >/dev/null 2>&1; then
  echo "git-credential-keyrack: rhx absent — declining" >&2
  echo "  keyrack ships inside rhachet; 5.3.brains puts it on a box" >&2
  exit 0
fi

# ── a checkout to stand in — the ladder runs MOST-OWNED first
#   1. `$GIT_CREDENTIAL_KEYRACK_REPO` — a human's declaration wins
#   2. THIS repo's checkout — the one manifest that declares the key
#   3. …then it REFUSES
# 🛑 rhachet LOADS the cwd's manifest before it reads the org sigil, so a clone
#    whose manifest `extends` an absent file kills the read (m6)
# 🛑 rung 2 tests the MANIFEST, never `.git` — a pushed copy has no `.git` (m7)
# 🛑 no rung for "whatever repo the human is in" — it let an outside party's
#    manifest shape a credential read, and it caused a duct wedge (m8)
# 🛑 no `credential.keyrackRepo` git config — the env var is the one holder (m8)
REPO=""
if [[ -n "${GIT_CREDENTIAL_KEYRACK_REPO:-}" && -d "${GIT_CREDENTIAL_KEYRACK_REPO}" ]]; then
  REPO="$GIT_CREDENTIAL_KEYRACK_REPO"
elif [[ -f "$HOME/git/more/dev-env-setup/.agent/keyrack.yml" ]]; then
  REPO="$HOME/git/more/dev-env-setup"
elif [[ -f "$HOME/git/more/dev-env-setup.wip/.agent/keyrack.yml" ]]; then
  REPO="$HOME/git/more/dev-env-setup.wip"
fi

if [[ -z "$REPO" ]]; then
  echo "git-credential-keyrack: no declared dev-env-setup checkout — declining" >&2
  echo "  why: this helper reads the rack from THIS repo's .agent/keyrack.yml," >&2
  echo "       and neither ~/git/more/dev-env-setup nor .wip holds one here." >&2
  echo "  ⇒ it will NOT fall back to the repo you happen to be standing in: that" >&2
  echo "    checkout's manifest would then shape a credential read, and its" >&2
  echo "    'extends' may point anywhere. the source is declared, never guessed." >&2
  echo "  fix: export GIT_CREDENTIAL_KEYRACK_REPO with the checkout's path." >&2
  echo "    for this shell only:" >&2
  echo "      export GIT_CREDENTIAL_KEYRACK_REPO=\$HOME/git/more/dev-env-setup" >&2
  echo "    to make it stick, declare it in 2.5.zsh's zshenv.sh and apply the bundle —" >&2
  echo "    NOT by an edit to ~/.zshenv, which this repo owns and diffs:" >&2
  echo "      rhx grove.provision --what 2.5.zsh --mode apply" >&2
  exit 0
fi

# ── ask the rack, from $REPO, in a SUBSHELL so the `cd` does not leak
#   `--unlock`: a key at rest is LOCKED. `--allow-dangerous`: phase 1's debt for
#   a classic pat. `2>/dev/null`: git reads stdout strictly (m9)
TOKEN="$( cd "$REPO" && timeout -k 5 20 rhx keyrack get \
  --owner ehmpath \
  --key GITHUB_TOKEN \
  --org @all \
  --env camp \
  --unlock \
  --allow-dangerous \
  --value 2>/dev/null < /dev/null | tail -1)"

if [[ -z "$TOKEN" ]]; then
  echo "git-credential-keyrack: no readable @all.camp.GITHUB_TOKEN — declines" >&2
  echo "  ⚠️ this message CANNOT name the cause, and must not pretend to." >&2
  echo "     the get above is run with stderr discarded, because git must never" >&2
  echo "     see keyrack's chatter on a decline path. so what reached here is one" >&2
  echo "     empty string, and at least four different faults produce it." >&2
  echo "" >&2
  echo "  ⇒ ask the box, which CAN tell them apart:" >&2
  echo "      rhx git.grove.send <grove> --play diagnose.grove-github-credential" >&2
  echo "    or run the same get by hand, with its stderr kept:" >&2
  echo "      cd $REPO && rhx keyrack get --owner ehmpath --key GITHUB_TOKEN \\" >&2
  echo "        --org @all --env camp --unlock --allow-dangerous --value" >&2
  echo "" >&2
  echo "  the four it will be, and the fix for each — measured 2026-08-06:" >&2
  echo "    locked 🔒   the session lapsed (540m). a re-unlock is the whole fix:" >&2
  echo "                  rhx keyrack unlock --owner ehmpath --env camp" >&2
  echo "    errored 💥  the aws.params vault cannot load its peers. fix at cause:" >&2
  echo "                  rhx grove.provision --what 5.3.brains --mode apply" >&2
  echo "    absent 🫧   no value was ever stored. a set is the fix:" >&2
  echo "                  cd $REPO && rhx keyrack set --owner ehmpath \\" >&2
  echo "                    --key GITHUB_TOKEN --org @all --env camp --vault aws.params" >&2
  echo "                  (answer BOTH prompts at a tty; never pipe them)" >&2
  echo "    refused     the value is there and github rejects it — mint a fresh" >&2
  echo "                pat, then re-set the same slug" >&2
  echo "" >&2
  echo "  ⚠️ the pat needs scope 'repo' to serve this helper. 'read:org' is a" >&2
  echo "     SEPARATE capability that serves gh's discovery, not the clone" >&2
  exit 0
fi

# ── answer. `x-access-token` is the username github's own docs use (m9)
printf 'username=x-access-token\n'
printf 'password=%s\n' "$TOKEN"

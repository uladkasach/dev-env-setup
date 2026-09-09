#!/usr/bin/env bash
######################################################################
# git.grove.auth.keys.set — place this box's required keys onto a grove's rack
#
# .what = for every row `5.16.keys` declares required, read the value from THIS
#         box's rack and write it into the GROVE's rack, over one encrypted hop.
#         a row this box cannot read is a HALT that names the fix, never a skip.
#
# 🛑 .the act is "PLACE A REPLICA", and `forward` is a FORBIDDEN word for it
#   `term=relay._.choice._.md:6` forbids `forward` outright, and the collision is
#   an OVERLOAD rather than a synonym: a relay carries untrusted bytes to a
#   human's terminal; this carries a value box → box. two concepts, one word.
#
#   ⇒ the concept earns NO coinage — keyrack already names it. the mechanism is
#     `PERMANENT_VIA_REPLICA` and `os.secure` is a replica store, so the act is
#     **place a replica** (`term=relay._.choice.reason.md`, dispute resolved
#     2026-09-07).
#
# .why  = `5.16.keys` reports which keys a grove cannot read. that is the
#         failfast half. this is the PLACE half — and the two are split
#         because the seam has an owner, and it is not the grove
#         (`rule.require.seam-claims-have-an-owner`):
#
#           the grove CANNOT read this rack. an `os.secure` value is age-encrypted
#           per `$HOME`, and `aws.params` under a named org is addressed through
#           that org's account. either way the value's only holder is the laptop,
#           so the laptop is the one box that can hand it over.
#
#         ⇒ a bundle could never do this, and that is a fact about the vault
#           rather than a gap in the tree.
#
# 🛑 .why `os.secure` on the far side, and never `aws.params`
#         `aws.params` under a NAMED org routes to that org's account, read from
#         the rack's own `AWS_PROFILE`. on a grove ehmpathy's is `ambient` — the
#         camp badge — so a write lands in camp's store and a read of the org's
#         store answers empty. that is the whole of #123, and this skill must not
#         wait on it (`term=entry`, the FIFTH cause).
#
#         `os.secure` is a REPLICA: an age file on the grove, sealed to the
#         grove's own recipients, readable with the grove's own identity and no
#         aws grant at all. its cost is real and is the right trade here —
#         a rotation must be re-placed per box, which is what this skill is
#         for, and `--refresh` is how you drive it.
#
# 🛑 .the SECRET PATH — three properties, each load-bear
#
#   1. it never becomes an ARGUMENT. `ps aux` on either box shows the flags and
#      no value; /proc is readable by every process of that uid.
#   2. it never touches a DUCT. a duct IS tmux, so a value sent there lands in
#      the pane's scrollback and that pane's history, and both outlive the
#      session. this skill uses `ssh` directly — the secret rides ssh's own
#      encrypted stdin channel.
#   3. it is never assigned to a VARIABLE in this shell, and never printed.
#      the read is piped STRAIGHT into the ssh that writes it, so no step of
#      this process holds the plaintext and no transcript can carry it.
#
#   ⇒ property 3 is why the "is it held?" check is a SEPARATE read that counts
#     bytes (`| wc -c`) and discards them. a check that captured the value to
#     test it would defeat the property it exists to protect.
#
# 🛑 .`--mech` is REQUIRED on every set below, or the first prompt eats the key
#     a piped `keyrack set` stores correctly — `promptHiddenInput.js:61` reads
#     ALL of stdin when stdin is not a tty:
#
#       // non-TTY mode: read ALL stdin content for multiline secrets (e.g., PEM files)
#
#     measured against a throwaway key at rhachet 1.47.3: 18 bytes in, 18 out.
#
#   ⚠️ but keyrack asks for the MECHANISM first when `--mech` is absent, and that
#     prompt consumes the pipe. the secret's own prompt then reads an exhausted
#     stdin, keyrack stores an EMPTY value, and it prints `✔ set` either way.
#
#   ⇒ so the failure is silent and looks like success. pass `--mech` and the
#     secret's prompt is the only one left.
#
# usage:
#   rhx git.grove.auth.keys.set <grove>                  # plan — which rows would be placed
#   rhx git.grove.auth.keys.set <grove> --mode apply     # place the absent rows
#   rhx git.grove.auth.keys.set <grove> --mode apply --refresh   # re-place every row
#   rhx git.grove.auth.keys.set help
#
# options:
#   --mode     plan (default) or apply
#   --refresh  re-place a row the grove already answers for (a rotated key)
#   --owner    keyrack owner; default ehmpath
#
# guarantee:
#   - the required rows come from `5.16.keys`, never from a list spelled here
#     (`rule.forbid.two-writers-on-one-artifact`)
#   - idempotent: a row the grove already reads is skipped unless --refresh
#   - no value is ever an argument, a duct payload, a variable, or a printed byte
#   - a row THIS box cannot read halts and names the fix; it is never skipped
#   - exit 0 = every required row is readable on the grove
#   - exit 1 = malfunction (grove unreachable, a write refused)
#   - exit 2 = constraint (bad args, absent grove, a row this box cannot read)
######################################################################
set -uo pipefail

# ⚠️ read the whole ARG VECTOR, never `$1` — rhachet injects `--skill <slug>`
#    ahead of the caller's args, so a `$1` test never fires
if [[ " $* " == *" help "* || " $* " == *" --help "* || " $* " == *" -h "* ]]; then
  echo "git.grove.auth.keys.set — place this box's required keys onto a grove's rack"
  echo ""
  echo "usage:"
  echo "  rhx git.grove.auth.keys.set <grove> [--mode plan|apply] [--refresh]"
  echo ""
  echo "options:"
  echo "  --mode     plan (default) or apply"
  echo "  --refresh  re-place a row the grove already answers for"
  echo "  --owner    keyrack owner; default ehmpath"
  echo ""
  echo "the rows come from 5.16.keys. a value is piped straight from this box's"
  echo "rack into the grove's over ssh — never an argument, never a duct, never"
  echo "held in a variable. see the header for why each of those matters."
  exit 0
fi

GROVE=""
MODE="plan"
REFRESH="false"
KR_OWNER="ehmpath"
# the checkout every remote `rhx` must run from — rhachet resolves a git root
# before it dispatches, so a bare call from $HOME dies "Not inside a Git repository"
KR_REPO="git/more/dev-env-setup"
# the scratch git root on EITHER box. a named-org read resolves against the
# `keyrack.yml` in scope, and neither box's real checkout declares these orgs
KR_GITROOT_REL=".local/state/keyrack.gitroot"
# 🛑 explicit, and see the header: without it the MECHANISM prompt eats the pipe
KR_MECH="PERMANENT_VIA_REPLICA"
KR_VAULT="os.secure"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)    MODE="$2"; shift 2 ;;
    --refresh) REFRESH="true"; shift ;;
    --owner)   KR_OWNER="$2"; shift 2 ;;
    --skill|--repo|--role) shift 2 ;;
    --) shift ;;
    -*) echo "✋ unknown flag '$1'" >&2; exit 2 ;;
    *) [[ -z "$GROVE" ]] && GROVE="$1"; shift ;;
  esac
done

[[ "$MODE" == "plan" || "$MODE" == "apply" ]] || {
  echo "✋ invalid --mode: $MODE (plan|apply)" >&2; exit 2; }

if [[ -z "$GROVE" ]]; then
  echo "✋ usage: rhx git.grove.auth.keys.set <grove> [--mode apply]" >&2
  echo "   list them: rhx git.grove.list" >&2
  exit 2
fi

REPO_ROOT="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"

######################################################################
# the required rows come from `5.16.keys`, sourced — never respelled
#
# 🛑 a second copy of this list is the defect `rule.forbid.two-writers-on-one-artifact`
#   names, and the one this repo re-learns most: the verify and the placer would
#   drift, and the input they disagree on is the row the placer exists to place.
######################################################################
KEYS_BUNDLE="$REPO_ROOT/src/grove.provision/5.devtools/5.16.keys/_.sh"
if [[ ! -r "$KEYS_BUNDLE" ]]; then
  echo "✋ 5.16.keys is absent from this checkout, so the required rows are unknown" >&2
  echo "   looked at: $KEYS_BUNDLE" >&2
  # ⚠️ "the required rows", never "the allowlist" — `allowlist` is a forbidden
  #   synonym of `disposition`, AND it is backwards here on its own terms: an
  #   allowlist SILENCES its members, where a required row that cannot be read
  #   HALTS this skill. the list makes its members loud, which is the opposite
  echo "   ⇒ it OWNS the required rows; this skill must never spell a second copy" >&2
  exit 1
fi
# shellcheck disable=SC1090
source "$KEYS_BUNDLE"

REQUIRED="$(grove_provision_5_16_keys_required)"
[[ -n "$REQUIRED" ]] || { echo "✋ 5.16.keys declares no required rows" >&2; exit 2; }

######################################################################
# the grove's ssh alias, clamped before ssh reads it as a positional
#
# .why = ssh takes a first positional that starts with `-` as an OPTION, and one
#        of them (`-oProxyCommand=`) runs a command HERE. the registry's own
#        write grammar admits a `-` at the front, so the READ clamps
######################################################################
REGISTRY="${GIT_FOREST_DIR:-$HOME/.git.forest}/groves/$GROVE.json"
if [[ ! -f "$REGISTRY" ]]; then
  echo "✋ grove '$GROVE' is not registered" >&2
  echo "   list them: rhx git.grove.list" >&2
  exit 2
fi
SSH_ALIAS=$(jq -r '.sshAlias // .name' "$REGISTRY")
if [[ -z "$SSH_ALIAS" || "$SSH_ALIAS" == -* || "$SSH_ALIAS" == *[!A-Za-z0-9._@-]* ]]; then
  echo "✋ grove '$GROVE' names an ssh alias that is not a host: '$SSH_ALIAS'" >&2
  echo "   └─ ssh reads a '-' at the front as an option, and one of them" >&2
  echo "      (-oProxyCommand=) runs a command on THIS box" >&2
  echo "   fix: rhx git.grove.set $GROVE --at <user>@<host>" >&2
  exit 2
fi

######################################################################
# the sink, for any byte a GROVE chose
#
# .why = a terminal OBEYS what it is sent, and `src/tmux.conf` sets
#        `set-clipboard on` — so one OSC 52 in a grove's output rewrites this
#        human's clipboard. every relay below goes through the sink
######################################################################
if ! command -v __duct_strip_escapes >/dev/null 2>&1; then
  _keys_ductwork="$REPO_ROOT/src/grove.provision/2.shell/2.7.aliases/ductwork.sh"
  if [[ -r "$_keys_ductwork" ]]; then
    # shellcheck disable=SC1090
    source "$_keys_ductwork"
  else
    echo "✋ ductwork is absent from this checkout, so grove bytes cannot be stripped" >&2
    echo "   looked at: $_keys_ductwork" >&2
    exit 1
  fi
fi

# .what = run one command on the grove, non-interactive, verdict by exit code
#
# ⚠️ `bash -lc`, never the bare command. `ssh host 'cmd'` runs a NON-login,
#    NON-interactive shell that sources no rc at all, and the grove keeps its
#    pnpm dir on PATH via `~/.profile` — read only by a LOGIN shell. a bare
#    probe reports `rhx` ABSENT on a box that holds it
#    (`gotcha.a-tool-found-by-path-answers-only-a-human`)
_ask() {
  ssh -o BatchMode=yes -o ConnectTimeout=15 "$SSH_ALIAS" \
      "bash -lc $(printf '%q' "$*")" >/dev/null 2>&1
}

# .what = the same question, but keeps both streams so a malfunction can be quoted
# ⚠️ stripped AT CAPTURE, never at the print site — a strip at the print site is
#    the one-set-two-readers shape, where the reader nobody re-reads drifts
_ask_loud() {
  ssh -o BatchMode=yes -o ConnectTimeout=15 "$SSH_ALIAS" \
      "bash -lc $(printf '%q' "$*")" 2>&1 | __duct_strip_escapes
}

# .what = the one-org, one-key scratch `keyrack.yml` a named-org call needs
#
# 🛑 one org per file, REWRITTEN per row. a named-org call resolves against the
#   yml in scope, so a call for org B against org A's declaration answers empty
#   — and an undeclared KEY answers absent forever however cleanly it was set
_declare_local() {
  local gitroot="$1" org="$2" env="$3" key="$4"
  mkdir -p "$gitroot/.agent" || return 1
  {
    printf '# .written by git.grove.auth.keys.set — a scratch git root, NOT a checkout\n'
    printf 'org: %s\n' "$org"
    printf 'env.%s:\n' "$env"
    printf '  - %s\n' "$key"
    printf '  - AWS_PROFILE\n'
  } | tee "$gitroot/.agent/keyrack.yml" >/dev/null
}

# .what = the same declaration, written ON the grove
# .why  = the grove's real checkout declares org `ahbode`, so a named-org set for
#         any other org is refused there before it reaches a vault
_declare_remote() {
  local org="$1" env="$2" key="$3" root="\$HOME/$KR_GITROOT_REL"
  _ask "mkdir -p $root/.agent && git -C $root rev-parse --git-dir >/dev/null 2>&1 || git init -q $root" || return 1
  _ask "printf 'org: %s\\nenv.%s:\\n  - %s\\n  - AWS_PROFILE\\n' $(printf '%q' "$org") $(printf '%q' "$env") $(printf '%q' "$key") > $root/.agent/keyrack.yml"
}

LOCAL_GITROOT="$HOME/$KR_GITROOT_REL"
mkdir -p "$LOCAL_GITROOT" || { echo "💥 could not make $LOCAL_GITROOT" >&2; exit 1; }
git -C "$LOCAL_GITROOT" rev-parse --git-dir >/dev/null 2>&1 || git init -q "$LOCAL_GITROOT"

echo "🐢 heres the wave..."
echo ""
echo "🔑 git.grove.auth.keys.set $GROVE --mode $MODE"
echo "   ├─ owner: $KR_OWNER"
echo "   ├─ vault: $KR_VAULT on the grove (a replica — no aws grant needed)"
echo "   └─ rows:  from 5.16.keys"
echo ""

# 0. is the box reachable at all?
if ! _ask true; then
  echo "💥 grove '$GROVE' does not answer at ssh alias '$SSH_ALIAS'" >&2
  echo "   why: the box is asleep, or its tunnel is not bound" >&2
  echo "   fix: wake it — a wake is idempotent" >&2
  echo "     rhx git.grove.wake $GROVE" >&2
  exit 1
fi

# 1. does rhx RUN on the box? presence on PATH is a different fact
#
# ⚠️ a broken TOOL reported as an EMPTY RACK is `rule.forbid.failhide`: the fix
#    offered would repair no part of it. so this rung asks the tool to answer
if ! RHX_RUNS="$(_ask_loud "cd \$HOME/$KR_REPO && rhx keyrack list --owner $KR_OWNER")"; then
  echo "✋ rhx does not run on the grove, so it has no rack to write into" >&2
  echo "" >&2
  echo "  the box's own error:" >&2
  printf '%s\n' "$RHX_RUNS" | grep -m3 -E 'Error|Cannot find|BadRequest|✋' | sed 's/^/    /' >&2
  echo "" >&2
  echo "  ⇒ this is a broken tool, not an empty rack — no set repairs it" >&2
  echo "  fix: re-apply the bundle that owns its PATH, then re-run this" >&2
  # 🛑 the DRIVER BY PATH, and its trigger is this branch itself
  #    (`rule.forbid.the-driver-by-path`, and `rule.require.exemptions-name-their-trigger`):
  #    we reach this line ONLY because the rung above proved `rhx` does not RUN on
  #    that box. so `rhx grove.provision` is exactly the surface that is broken, and
  #    the path is the only one left. every OTHER fix-text in this file names `rhx`.
  #  ⚠️ when this skill is tracked, this site is owed an entry in `CARVED` in
  #    `prove.the-driver-is-never-named-by-path` AND in the rule's carve-out list —
  #    two holders, and the play reddens if either drifts
  echo "    rhx git.grove.send $GROVE --what 'bash \$HOME/$KR_REPO/src/grove.provision._.sh --what 5.1.node --mode apply'" >&2
  exit 1
fi

######################################################################
# the rows
######################################################################
PLANNED=0 SKIPPED=0 PLACED=0 HALTS=0
HALT_LINES=""

# 🛑 this box's rack, READ rather than hardcoded — a hand-written list of which
#   slug carries which mechanism cannot report the row nobody added to it, and
#   the mechanism is the one fact that decides whether a row may be placed at all
#
# ⇒ one call, before the loop. a per-row call would ask the same question N times
RACK_LIST="$(env -C "$REPO_ROOT" rhx keyrack list --owner "$KR_OWNER")" || RACK_LIST=""

for row in $REQUIRED; do
  IFS=':' read -r org env key <<<"$row"
  if [[ -z "$org" || -z "$env" || -z "$key" ]]; then
    echo "💥 malformed row in 5.16.keys: '$row' (want <org>:<env>:<key>)" >&2
    exit 1
  fi

  slug="${org}.${env}.${key}"

  # 0. is this row EVEN PLACEABLE? read the mechanism first, and refuse any
  #    that is not a replica
  #
  # 🛑 a placement is a `get` piped into a `set`, so it carries the DELIVERED
  #   secret — and only under `PERMANENT_VIA_REPLICA` is that the same string
  #   the rack stores. the two halves are declared apart in rhachet's own
  #   contract (`KeyrackHostVaultAdapter.d.ts:40-41`):
  #
  #     set calls mech.acquireForSet internally; secret never exposed to caller
  #     get calls mech.deliverForGet  internally; transforms source → usable secret
  #
  #   ⇒ so for every OTHER mechanism the source cannot be read at all, and what
  #     a placement would carry is the transformed output.
  #
  # 🛑 .the worked case, and it is why this is a GUARD rather than a note
  #   `EHMPATH_BEAVER_GITHUB_TOKEN` is `EPHEMERAL_VIA_GITHUB_APP` on all five of
  #   its prep orgs. `mechAdapterGithubApp.deliverForGet` MINTS an installation
  #   token and stamps `expiresAt` at 55 minutes, so a placement of that value
  #   writes a CORPSE: green on the apply, dead within the hour, and the bundle
  #   verify green forever after — because a dead token is still bytes, and the
  #   verify counts bytes (`rule.forbid.failhide`).
  #
  # ⇒ the repair for such a row is never a placement. `acquireForSet` guards its
  #   own prompt on `process.stdin.isTTY`, so the key must be SET on the far box
  #   at a terminal — and a duct pane is one, since a duct is tmux
  local_mech="$(printf '%s\n' "$RACK_LIST" | awk -v s="$slug" '
    { line = $0; sub(/^[^A-Za-z@]*/, "", line) }
    line == s     { hit = 1 }
    hit && mech == "" && line ~ /^mech: / { mech = $NF }
    END { print mech }
  ')"
  if [[ -n "$local_mech" && "$local_mech" != "$KR_MECH" ]]; then
    echo "   ✋ $slug — mech is $local_mech, and only $KR_MECH can be placed"
    HALTS=$((HALTS + 1))
    # 🛑 `$'\n'`, never a literal `\n` — `printf '%s'` renders this block, so a
    #   backslash-n arrives on screen as two characters and the fix reads as one
    #   unusable line (📜 measured 2026-09-07, on this guard's first run)
    HALT_LINES+="     # $slug — set it ON the grove, in a duct pane (a tty):"$'\n'
    HALT_LINES+="     rhx duct.open $GROVE"$'\n'
    HALT_LINES+="     #   then, in that pane:"$'\n'
    HALT_LINES+="     env -C \$HOME/$KR_REPO rhx keyrack set --owner $KR_OWNER --key $key --org $org --env $env --mech $local_mech"$'\n'
    continue
  fi

  # 1. can THIS box read it? a byte count, so no step holds the value
  #
  # 🛑 `| wc -c` and never a capture. the whole point of the pipe below is that
  #   the plaintext exists in no variable of this process; a check that assigned
  #   it to test it would give that away for a convenience
  #
  # 🛑 .and STDERR is kept, because a zero byte count collapses TWO states that
  #   want OPPOSITE repairs — `locked 🔒` and `absent 🫧` both exit 2 with empty
  #   stdout, and only the rack's own stderr tells them apart
  #   (`rule.require.github-token-at-all-camp`, `.the two rows the exit code
  #   CANNOT separate`).
  #
  #   ⚠️ measured 2026-09-07, on this very skill: `ehmpathy.test` reported
  #   *"THIS box cannot read it"* with a `keyrack set` fix-text, and minutes
  #   later the same row read fine with no change to the rack between. the
  #   session had simply been locked.
  #
  #   ⇒ that fix-text was the DANGEROUS half. `keyrack set` has no entry-only
  #     mode, so a human who followed it would have re-pasted over a live value
  #     to cure a lock (`term=entry`). a wrong verdict is cheap; a wrong fix
  #     that a human can act on is not.
  #
  #   ⚠️ stderr is safe to hold — it carries a STATUS, never the value. the
  #     value's own channel is stdout, and it still goes straight to `wc -c`.
  _declare_local "$LOCAL_GITROOT" "$org" "$env" "$key" || exit 1
  _keys_err="$(mktemp -t keys.set.err.XXXXXX)" || exit 1
  local_bytes="$(env -C "$LOCAL_GITROOT" rhx keyrack get --owner "$KR_OWNER" \
                   --key "$key" --org "$org" --env "$env" --unlock --value \
                   2>"$_keys_err" | wc -c | tr -d '[:space:]')"
  local_bytes="${local_bytes:-0}"
  local_why="$(cat "$_keys_err" 2>/dev/null)"
  rm -f "$_keys_err"

  # the LOCKED branch — a live value behind a lapsed session. its repair is an
  # unlock, and never a set
  #
  # ⚠️ `branch`, never `arm`. an `arm` is a member of a PLAY's measurement and a
  #   play runs every arm it declares; these two are ALTERNATIVES, which is what
  #   `branch` names and why `term=arm` forbids the two words for each other
  if [[ "$local_bytes" -eq 0 ]] && printf '%s' "$local_why" | grep -qi 'locked'; then
    echo "   🔒 $slug — held here, and this box's session is LOCKED"
    HALTS=$((HALTS + 1))
    HALT_LINES+="     rhx keyrack unlock --owner $KR_OWNER --env $env"$'\n'
    continue
  fi

  if [[ "$local_bytes" -eq 0 ]]; then
    echo "   ✋ $slug — THIS box cannot read it, so there is none to place"
    HALTS=$((HALTS + 1))
    # 🛑 name NO --vault and NO --mech here. this skill cannot know either for a
    #   slug it has never seen: a `5.16.keys` row is `<org>:<env>:<key>` and
    #   carries no mechanism, and step 0's rack read answered EMPTY — which is
    #   how we reached this branch.
    #
    #   🛑 .a NAMED VAULT here would pick the mechanism, silently
    #     keyrack infers the mech from the vault, so `--vault os.secure` reads as
    #     `PERMANENT_VIA_REPLICA`. a key that ought to be `EPHEMERAL_VIA_GITHUB_APP`
    #     would then be stored as a PERMANENT replica — a credential that works
    #     today, wrong by construction, and which no later check can tell from a
    #     right one.
    #
    #   ⇒ a fix-text may only assert what its author can know. keyrack asks when
    #     it cannot infer, so the bare form is both shorter and the only honest one
    HALT_LINES+="     rhx keyrack set --owner $KR_OWNER --key $key --org $org --env $env"$'\n'
    continue
  fi

  # 2. does the GROVE already read it? then the work is done
  #
  #    ⚠️ the exit code, never the value — a `--value` relayed here would put the
  #    secret in this skill's stdout, which is the transcript hazard the header names
  remote_root="\$HOME/$KR_GITROOT_REL"
  if _declare_remote "$org" "$env" "$key" && \
     _ask "cd $remote_root && rhx keyrack get --owner $KR_OWNER --key $key --org $org --env $env --unlock --value | head -c1 | grep -q ."; then
    if [[ "$REFRESH" != "true" ]]; then
      echo "   ✔ $slug — the grove already reads it"
      SKIPPED=$((SKIPPED + 1))
      continue
    fi
    echo "   ↻ $slug — the grove reads it, and --refresh was asked"
  fi

  if [[ "$MODE" == "plan" ]]; then
    echo "   → $slug — held here ($local_bytes bytes), would place"
    PLANNED=$((PLANNED + 1))
    continue
  fi

  ####################################################################
  # 3. the placement — ONE pipeline, and its shape is the security property
  #
  # 🛑 the value goes: local keyrack's stdout → ssh's encrypted stdin → the
  #   remote keyrack's stdin. it is in no argv on either box, in no variable of
  #   this shell, on no pane, and in no log.
  #
  # ⚠️ `bash -lc` on the far side reads the login rc for PATH — and it PASSES
  #   stdin through, which is the whole mechanism. a `--mech` is passed so the
  #   only prompt left is the secret's; without it the mechanism prompt eats the
  #   pipe
  ####################################################################
  REMOTE_SET="cd $remote_root && rhx keyrack set --owner $KR_OWNER --key $key --org $org --env $env --vault $KR_VAULT --mech $KR_MECH"

  if ! env -C "$LOCAL_GITROOT" rhx keyrack get --owner "$KR_OWNER" \
         --key "$key" --org "$org" --env "$env" --unlock --value 2>/dev/null \
       | ssh -o BatchMode=yes "$SSH_ALIAS" "bash -lc $(printf '%q' "$REMOTE_SET")" \
         >/dev/null 2>&1; then
    echo "   💥 $slug — the grove refused the write" >&2
    echo "      read the box's own view —" >&2
    echo "        rhx git.grove.send $GROVE --what 'rhx keyrack list --owner $KR_OWNER'" >&2
    exit 1
  fi

  ####################################################################
  # 4. prove the READ, never trust the `✔ set`
  #
  # 🛑 a `✔ set` proves the STORE and says none of the READ. two prior sessions
  #   read one as "the credential is placed" and were wrong both times, at the
  #   cost of a real key each (`term=entry`). so the row is not counted placed
  #   until the grove hands the value back
  ####################################################################
  if ! _ask "cd $remote_root && rhx keyrack get --owner $KR_OWNER --key $key --org $org --env $env --unlock --value | head -c1 | grep -q ."; then
    echo "   💥 $slug — stored, and the grove still reads it EMPTY" >&2
    echo "      ⇒ a set that stores a blank prints ✔ all the same; this is that" >&2
    exit 1
  fi

  echo "   ✔ $slug — placed, and the grove reads it back"
  PLACED=$((PLACED + 1))
done

echo ""

if [[ "$HALTS" -gt 0 ]]; then
  # 🛑 the headline names NO cause, and that is deliberate. three land here and
  #   they are not one fact:
  #     🔒 a live value behind a lapsed session
  #     ✋ no readable value on this box
  #     ✋ a value this box reads FINE and may not be placed, per its mechanism
  #   ⇒ the third row is why no cause may be named here: the box reads it
  #     perfectly, so a headline that blamed the read would be a correct verdict
  #     under a wrong subject — `gotcha.a-check-that-cries-wolf-gets-silenced`
  #     m.4. the row's own line above is where the cause belongs
  echo "✋ $HALTS row(s) were not placed" >&2
  echo "" >&2
  echo "  why: to skip one quietly would leave a grove short a key its first suite" >&2
  echo "       needs (rule.forbid.failhide). each row above names its own cause" >&2
  echo "" >&2
  # ⚠️ ONE fix-line per row, each keyed to that row's OWN cause — a 🔒 gets an
  #   unlock, a ✋ gets a set. a single blanket instruction would tell a human to
  #   overwrite a live value to cure a lapsed session
  echo "  fix: run the line(s) beside each row below, then re-run this skill:" >&2
  printf '%s' "$HALT_LINES" >&2
  exit 2
fi

if [[ "$MODE" == "plan" ]]; then
  echo "🔑 plan — $PLANNED row(s) would be placed, $SKIPPED already read"
  echo "   └─ drive it: rhx git.grove.auth.keys.set $GROVE --mode apply"
  exit 0
fi

echo "🌳 grove '$GROVE' reads every required key!"
echo "   ├─ placed:  $PLACED"
echo "   ├─ already:   $SKIPPED"
echo "   └─ prove it from the grove's own side —"
# 🛑 `env -C`, and NOT a bare `rhx`. two constraints meet here and only this
#   shape satisfies both (📜 measured 2026-09-07, the bare form errored):
#     - the duct's pane sits at $HOME, and rhachet resolves a git root before it
#       dispatches — so a bare call answers `no skill "grove.provision" found`
#     - a duct refuses `&&`, so this cannot borrow rung 4's `cd … && rhx …`
#   ⇒ `$KR_REPO` is the SAME declaration rung 4 reads, so the two cannot drift
echo "      rhx git.grove.send $GROVE --reply --what 'env -C \$HOME/$KR_REPO rhx grove.provision --what 5.16.keys --mode plan'"

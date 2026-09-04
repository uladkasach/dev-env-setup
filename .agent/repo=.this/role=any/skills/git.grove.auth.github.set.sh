#!/usr/bin/env bash
######################################################################
# git.grove.auth.github.set — put a github token on a grove's rack, securely
#
# .what = drive a grove to "holds a github credential": init its keyrack if the
#         box has no rack yet, then hand the human an interactive tty on the box
#         to TYPE the value into `keyrack set`.
#
# .why  = `5.4.gh` halts with the exact command a human owes. this skill is that
#         command, driven over one connection, with the checks a human would
#         otherwise have to remember (is the box awake? does it have a rack? is
#         the slug already set?).
#
# ⚠️ .why the slug is `@all.camp.GITHUB_TOKEN` (rule.require.github-token-at-all-camp)
#      .key   a key must be DECLARED in a `keyrack.yml` before it can be read —
#             an undeclared one still prints `✔ set`, and every later get answers
#             `status: absent 🫧`, so the swap looks done and reads empty forever
#             (`prove.keyrack.roundtrip`, grove-1). `GITHUB_TOKEN` is declared
#             under `env.camp` in `.agent/keyrack.yml`
#
#      .env   `camp` is this repo's word for grove infrastructure — the same
#             manifest declares `AWS_PROFILE` there for every `git.grove.*` skill.
#             deliberately NOT `prep.EHMPATHY_SEATURTLE_GITHUB_TOKEN`, which is
#             the MECHANIC's commit token: a different credential, a different
#             owner, a different rotation. to reuse it would tie a grove's ability
#             to clone to a robot's commit identity
#
#             ONE slug serves all three consumers — `gh` (5.4.gh), plain https git
#             (`git-credential-keyrack`, declared by 2.2.git), and this skill
#
#      .org   `@all` is a REQUIREMENT, not a preference. `@this` resolves only
#             from a checkout that holds `.agent/keyrack.yml`, and the primary
#             consumer — git, through `git-credential-keyrack` — is invoked from
#             whatever clone the human stands in, almost none of which carry an
#             `.agent/`. `@all` is also what the credential IS: one classic pat
#             already spans every org its human belongs to.
#
#             ✔ PROVEN to read at rhachet@1.45.1, cold from `~` on grove-1:
#               get --org @all --env camp --key GITHUB_TOKEN --unlock \
#                   --allow-dangerous --value | wc -c   → 40   # a classic pat
#
#             a literal `--org <name>` is accepted too, but only when it equals
#             the manifest org — so it is `@this` spelled out, never a selector.
#
#             📜 keyrack below 1.45.1 could unlock no value under `@all`.
#             resolved upstream. two lessons outlive it:
#               1. part of that evidence was OUR defect — the probe wrote a FAKE
#                  classic-pat-shaped value and never confirmed it landed, so the
#                  pat firewall had likely refused the store
#               2. ⚠️ a `✔ set` proves the STORE and says none of the READ. THIS
#                  skill printed that `✔` over a pat that was never once
#                  retrievable. see `domain.terms/term=entry`
#
#             the ConstraintError behind `@this` is real, and is answered by a
#             cwd rather than by a sigil: every call below is prefixed with a
#             `cd` into the checkout, and `git-credential-keyrack` does the same.
#
#             ⇒ re-proven on every provision by `git.grove.provision test`,
#               whose suite step needs a private clone over plain https
#
# ⚠️ .why the token is TYPED on the box and never travels as an argument
#         three places a secret must never land, and what each would cost:
#
#           1. argv          — `ps aux` on the grove shows it to every process
#                              that can read /proc, for as long as the call runs
#           2. a duct        — a duct IS tmux, so the value lands in the pane's
#                              scrollback and in the shell history of that pane,
#                              and both persist after the session
#           3. a transcript  — whatever a robot types is in ITS transcript too,
#                              which is a copy nobody rotates
#
#         so this skill opens `ssh -t` — a DIRECT interactive tty over the grove's
#         own tunnel, not a duct — and lets `keyrack set` read the value from
#         that tty. keyrack writes it age-encrypted. the secret crosses one
#         encrypted hop and is never seen by this skill, this shell, or any log.
#
#         the tty is a REQUIREMENT, not a courtesy: set's secret prompt masks its
#         echo, so it reads the terminal rather than stdin. driven by a pipe it
#         takes the mechanism answer, SKIPS the secret, stores an empty value, and
#         prints `✔ set` all the same — a blank that only surfaces later, as a
#         token github rejects (measured on grove-1, 2026-08-02).
#
#         this is the same reason `plan.grove-credentials.md` says a credential
#         goes over the TUNNEL and never through the duct.
#
# .why `--vault aws.params` — a CENTRAL store, and this skill only ever targets a grove
#         a grove is exclusively ec2, so IMDS is always there — and IMDS is the one
#         identity `aws.params` accepts for an `@all` slug
#         (`asKeyrackAwsParamIdentity.js:17`). a laptop has no IMDS, but a laptop
#         is human-backed and authed itself with `gh auth login` on the way past,
#         so it never reaches this skill at all.
#
#         ⇒ the alternative, `os.secure`, is an age-encrypted file ON the box: it
#           beats gh's plaintext `hosts.yml` and is still a REPLICA, so every grove
#           that holds a copy holds a stale one the moment the pat rotates, and a
#           rotation must reach each box. `aws.params` is one write.
#
#         ⚠️ the vault is NOT what phase 2 is about. a pat in `aws.params` is still
#         a long-lived pat, still `--allow-dangerous`, still one credential for
#         every org. phase 2 is the per-org app token and `--scope`, and neither
#         has shipped.
#
# usage:
#   rhx git.grove.auth.github.set grove-1                 # plan — say what it would do
#   rhx git.grove.auth.github.set grove-1 --mode apply    # drive it, prompt on the box
#   rhx git.grove.auth.github.set grove-1 --mode apply --refresh   # replace a stale pat
#   rhx git.grove.auth.github.set help
#
# options:
#   --mode     plan (default) or apply
#   --refresh  re-set a slug that already answers (a rotated or expired pat).
#              set is an upsert, so this flag only lifts the early no-op exit
#   --env      keyrack env for the slug; default prep
#   --owner    keyrack owner; default ehmpath
#   --org      org sigil for the slug; @this (default) or @all. ⚠️ @all can be
#              written and never read — `keyrack unlock` takes no --org, so a
#              value stored there is unreachable forever. see the header
#
# guarantee:
#   - idempotent: a grove whose rack already answers for this slug is a no-op
#     unless --refresh is passed
#   - the token value is never an argument, never echoed, never logged
#   - exit 0 = the grove's gh accepts github
#   - exit 1 = malfunction (grove unreachable, keyrack broke, github refused)
#   - exit 2 = constraint (bad args, absent grove, a human declined the prompt)
######################################################################
set -uo pipefail

# ⚠️ read the whole ARG VECTOR, never `$1` — rhachet injects `--skill <slug>` ahead
#    of the caller's args, so a `$1` test never fires (measured 2026-08-30; ten
#    skills in this dir carried it, and each read `help` as its SUBJECT instead)
if [[ " $* " == *" help "* || " $* " == *" --help "* || " $* " == *" -h "* ]]; then
  echo "git.grove.auth.github.set — put a github token on a grove's rack, securely"
  echo ""
  echo "usage:"
  echo "  rhx git.grove.auth.github.set <grove> [--mode plan|apply] [--refresh]"
  echo ""
  echo "options:"
  echo "  --mode     plan (default) or apply"
  echo "  --refresh  re-set a slug that already answers (rotated or expired pat)"
  echo "  --env      keyrack env; default prep"
  echo "  --owner    keyrack owner; default ehmpath"
  echo "  --org      org sigil for the slug: @this (default) or @all"
  echo "             ⚠️ @all stores but never reads — unlock takes no --org"
  echo ""
  echo "the value is TYPED on the box over an interactive ssh tty — never passed"
  echo "as an argument, never sent down a duct. see the header for why."
  exit 0
fi

GROVE=""
MODE="plan"
REFRESH="false"
KR_ENV="camp"
KR_OWNER="ehmpath"
KR_ORG="@all"
KR_KEY="GITHUB_TOKEN"
# central, not a replica — and safe here because this skill only targets a grove,
# which is always ec2 and so always has the IMDS identity aws.params wants.
# see the `.why --vault aws.params` block in the header
KR_VAULT="aws.params"
# the checkout every remote `rhx` must run from — see the ⚠️ in the header
KR_REPO="git/more/dev-env-setup"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)    MODE="$2"; shift 2 ;;
    --refresh) REFRESH="true"; shift ;;
    --env)     KR_ENV="$2"; shift 2 ;;
    --owner)   KR_OWNER="$2"; shift 2 ;;
    --org)     KR_ORG="$2"; shift 2 ;;
    --skill|--repo|--role) shift 2 ;;
    --) shift ;;
    -*) echo "✋ unknown flag '$1'" >&2; exit 2 ;;
    *) [[ -z "$GROVE" ]] && GROVE="$1"; shift ;;
  esac
done

[[ "$MODE" == "plan" || "$MODE" == "apply" ]] || { echo "✋ invalid --mode: $MODE (plan|apply)" >&2; exit 2; }

if [[ -z "$GROVE" ]]; then
  echo "✋ usage: rhx git.grove.auth.github.set <grove> [--mode apply]" >&2
  echo "   list them: rhx git.grove.list" >&2
  exit 2
fi

source ~/.bash_aliases 2>/dev/null || true

######################################################################
# 🛑 this skill RELAYS a grove's own output, so it owes the sink
#
# 📜 measured 2026-08-31. it had none. two sites printed grove-chosen bytes
#    to a terminal raw — `_ask_loud`'s capture, and the `5.4.gh` apply below
#    — and both run at the exact minute a human has just pasted a pat and
#    reads the screen for the verdict.
#
#   a terminal OBEYS bytes. `src/tmux.conf` sets `set-clipboard on`, so one
#   OSC 52 in that output writes this human's clipboard, and the next paste
#   is a command the grove chose. a `bash -lc` runs the box's login rc, so a
#   compromised grove needs no verb of ours to emit it.
#
# ⚠️ .why a GREP is not a sink
#    `_ask_loud`'s reader filters on `Error|Cannot find|…`, which constrains
#    WHICH LINES print and says none of what BYTES they hold. the payload
#    rides the same line as the word.
#
# ⚠️ the CHECKOUT's copy, never `~/.bash_aliases.ductwork.sh` — a skill in
#    this tree is judged against this tree, and an installed copy may be
#    older. the `source ~/.bash_aliases` above is for `git_alias_grove`, and
#    it is exactly the stale-copy hazard this block refuses to inherit.
######################################################################
if ! command -v __duct_strip_escapes >/dev/null 2>&1; then
  _auth_gh_ductwork="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)/src/ductwork.sh"
  if [[ -r "$_auth_gh_ductwork" ]]; then
    # shellcheck disable=SC1090
    source "$_auth_gh_ductwork"
  else
    echo "✋ ductwork is absent from this checkout, so grove bytes cannot be stripped" >&2
    echo "   looked at: $_auth_gh_ductwork" >&2
    echo "   ⇒ it owns __duct_strip_escapes, the one sink between a grove's" >&2
    echo "     output and a terminal that OBEYS what it is sent" >&2
    exit 1
  fi
fi

REGISTRY="${GIT_FOREST_DIR:-$HOME/.git.forest}/groves/$GROVE.json"
if [[ ! -f "$REGISTRY" ]]; then
  echo "✋ grove '$GROVE' is not registered" >&2
  echo "   list them: rhx git.grove.list" >&2
  exit 2
fi
SSH_ALIAS=$(jq -r '.sshAlias // .name' "$REGISTRY")

######################################################################
# 🛑 the alias is CLAMPED before ssh reads it as a positional
#
# .why  = `ssh` treats its first positional as a host ONLY IF it does not begin
#         with `-`. one that does is parsed as an OPTION — and ssh has one that
#         runs a command HERE, on the laptop, before any connection is
#         attempted: `-oProxyCommand=<cmd>`.
#
#         this value is read out of a registry FILE, and the write side's own
#         grammar (`[A-Za-z0-9._-]`) ADMITS a `-` at the front. so the registry
#         can hold one today, and four ssh calls below take it as a positional.
#
# ⚠️ .why the READ side clamps at all, when the write side has a grammar
#      a grammar on the write path is a claim about every writer that ever ran
#      — the ones that predate it too, and any hand edit of the json. the read
#      is where the value becomes an ARGUMENT, so the read is where the claim
#      can be true (`rule.require.solve-at-cause`).
#
# .note = it reuses termwork's `__term_as_ssh_host` rather than spell a second
#         copy of the grammar (`rule.forbid.two-writers-on-one-artifact`), and
#         falls back inline only where termwork is not loaded
######################################################################
if command -v __term_as_ssh_host >/dev/null 2>&1; then
  SSH_ALIAS="$(__term_as_ssh_host "$SSH_ALIAS")" || exit 2
elif [[ -z "$SSH_ALIAS" || "$SSH_ALIAS" == -* || "$SSH_ALIAS" == *[!A-Za-z0-9._@-]* ]]; then
  echo "✋ grove '$GROVE' names an ssh alias that is not a host: '$SSH_ALIAS'" >&2
  echo "   └─ ssh reads a '-' at the front as an option, and one of them" >&2
  echo "      (-oProxyCommand=) runs a command on THIS box" >&2
  echo "   fix: rhx git.grove.set $GROVE --at <user>@<host>" >&2
  exit 2
fi

echo "🐢 heres the wave..."
echo ""
echo "🔑 git.grove.auth.github.set $GROVE --mode $MODE"
echo "   ├─ slug:  owner=$KR_OWNER  ${KR_ORG}.${KR_ENV}.${KR_KEY}"
echo "   ├─ vault: $KR_VAULT  (central; a grove is ec2, so IMDS is always there)"
echo "   └─ drive"

# .what = run one command on the grove, non-interactive, and hand back its output
#
# .why  = a probe must not open a tty; only the FILL step gets one
#
# ⚠️ .why `bash -lc` and not the bare command
#         `ssh host 'cmd'` runs a NON-login, NON-interactive shell, which sources
#         no rc file at all. the grove keeps its pnpm dir on PATH via `~/.profile`
#         (measured 2026-08-02), and `.profile` is read only by a LOGIN shell — so
#         a bare probe reported `rhx` ABSENT on a box that holds it at
#         /home/camper/.local/share/pnpm/rhx. this skill then halted with "5.3.brains
#         never ran" about a box where 5.3.brains ran fine: the probe measured the
#         SHELL and reported it as a fact about the MACHINE
#
# ⚠️ .why every caller reads the EXIT CODE and not the output
#         a login shell on this box prints `keynav started` from the `.profile`
#         line `1.1.keybinds` appends, so login-shell STDOUT carries a banner that
#         belongs to no probe. an exit code carries no banner
_ask() {
  ssh -o BatchMode=yes -o ConnectTimeout=15 "$SSH_ALIAS" "bash -lc $(printf '%q' "$*")" >/dev/null 2>&1
}

# .what = the same question, but keeps stderr so a MALFUNCTION can be quoted
# .why  = a silenced probe can only say yes or no, and some failures are neither.
#         see the ⚠️ on the `rhx runs` rung below
# ⚠️ stripped AT CAPTURE, never at print. the bytes are grove-chosen and every
#    reader of this answer is downstream of one seam — a strip at the print
#    site is the m.9 shape, where the reader nobody re-reads is the one that
#    drifts. `2>&1` first, so BOTH streams meet the sink (ssh relays the remote
#    command's stderr byte for byte, and the pipe alone would carry neither)
_ask_loud() {
  ssh -o BatchMode=yes -o ConnectTimeout=15 "$SSH_ALIAS" "bash -lc $(printf '%q' "$*")" 2>&1 \
    | __duct_strip_escapes
}

# 0. is the box reachable at all? a woken grove relays on its tunnel
if ! _ask true; then
  echo "      └─ 💥 grove '$GROVE' does not answer at ssh alias '$SSH_ALIAS'" >&2
  echo "" >&2
  echo "  why: the box is asleep, or its tunnel is not bound" >&2
  echo "  fix: wake it — a wake is idempotent" >&2
  echo "    rhx git.grove.wake $GROVE" >&2
  exit 1
fi
echo "      ├─ box  reachable at '$SSH_ALIAS'"

# 1. is keyrack even ON the box? it ships inside rhachet, which 5.3.brains installs
if ! _ask 'command -v rhx'; then
  echo "      ├─ ✋ rhx is not on the grove's PATH, so it has no keyrack to fill" >&2
  echo "" >&2
  echo "  why: keyrack ships INSIDE rhachet; 5.3.brains is what puts it on a box" >&2
  echo "  fix: drive the bundle that owns it, then re-run this —" >&2
  echo "    rhx git.grove.send $GROVE --play prove.bundles.plan-apply-apply" >&2
  exit 2
fi
echo "      ├─ rhx  present"

# 1b. does rhx actually RUN? presence on PATH is not the same fact
#
# ⚠️ .why this rung exists — the failhide it closes, measured 2026-08-03
#      `command -v rhx` proves a FILE is on PATH. it does not prove that file
#      works, and on this box it did not: pnpm leaves a shim in BOTH
#      $PNPM_HOME and $PNPM_HOME/bin, only the `/bin` copy is refreshed by a
#      current global install, and the bare copy hardcodes a NODE_PATH at the
#      old store layout. `bash -lc` found the bare one and died with
#        Error: Cannot find module 'with-simple-cache'
#
#      without this rung that crash fell through to the slug probe below, whose
#      non-zero exit was then reported as
#        `rack does NOT answer for … — a human is owed`
#      so a BROKEN TOOL was announced as an EMPTY RACK, and the fix offered was
#      one that would have repaired no part of it. that is `rule.forbid.failhide`
#      — a probe that cannot tell "no" from "could not ask" must not answer at
#      all (term=probe: one question, answered from evidence)
if ! RHX_RUNS="$(_ask_loud "cd \$HOME/$KR_REPO && rhx keyrack list --owner $KR_OWNER")"; then
  echo "      ├─ ✋ rhx is on PATH but does NOT run" >&2
  echo "" >&2
  echo "  the box's own error:" >&2
  # printf, never echo — `$RHX_RUNS` is a GROVE's answer (`term=relay`, property 2).
  # ⚠️ this file is `#!/usr/bin/env bash` run as an executable, so bash's `echo`
  #    would expand no backslash escape here. `printf` anyway: under `echo` the
  #    guarantee rests on WHICH SHELL runs the file rather than on the verb —
  #    a claim no reader of this line could check.
  printf '%s\n' "$RHX_RUNS" | grep -m3 -E 'Error|Cannot find|BadRequest|✋' | sed 's/^/    /' >&2
  echo "" >&2
  echo "  why: this is a broken TOOL, not an empty rack — so no 'keyrack set'" >&2
  echo "       repairs it, and a pat spent here would be spent for no gain" >&2
  echo "  ⇒ if it says 'Cannot find module', the shell found a STALE pnpm shim." >&2
  echo "    pnpm keeps one in both \$PNPM_HOME and \$PNPM_HOME/bin and refreshes" >&2
  echo "    only the '/bin' copy; whichever dir PATH names first wins. note that" >&2
  echo "    a duct is zsh while this skill uses 'bash -lc', so the two shells can" >&2
  echo "    disagree and a duct-borne check will look green" >&2
  echo "  fix: re-apply the bundle that OWNS that PATH order — 5.1.node — then" >&2
  echo "    re-run this. there is no play for it and there must not be: a shim on" >&2
  echo "    the box is machine state, and machine state is a bundle's job alone" >&2
  echo "    (rule.forbid.repair-plays)." >&2
  echo "    rhx git.grove.push $GROVE --from src --into git/more/dev-env-setup/src --mode apply" >&2
  # ⚠️ ONE step, with the path spelled out. `git.grove.send` REFUSES a chain
  #    inside --what:
  #      ✋ --what takes ONE step; this command chains several
  #    so a `--what 'cd ~/… && bash …'` fix names the very tool that rejects it.
  #    a `bash <abs-path>` needs no cd (`rule.require.errors-name-the-fix`)
  echo "    rhx git.grove.send $GROVE --what 'bash \$HOME/$KR_REPO/src/grove.provision._.sh --what 5.1.node --mode apply'" >&2
  exit 1
fi
echo "      ├─ rhx  runs (keyrack answered)"

# 2. does the box already answer for this slug? then the work is already done
#
#    ⚠️ this reads the EXIT CODE, never the value. a `--value` printed here would
#    put the token in this skill's stdout, which is the transcript hazard above
if _ask "cd \$HOME/$KR_REPO && rhx keyrack get --owner $KR_OWNER --key $KR_KEY --org $KR_ORG --env $KR_ENV --unlock --allow-dangerous --value >/dev/null"; then
  if [[ "$REFRESH" != "true" ]]; then
    echo "      └─ ✔ the rack already answers for ${KR_KEY} — no work"
    echo ""
    echo "🔑 already set!"
    echo "   ├─ to replace a rotated or expired pat: --refresh"
    echo "   └─ to prove gh accepts it:"
    echo "      rhx git.grove.send $GROVE --what 'gh auth status'"
    exit 0
  fi
  echo "      ├─ rack answers already, and --refresh was asked — it will be replaced"
else
  echo "      ├─ rack does NOT answer for ${KR_KEY} — a human is owed"
fi

# 3. does the box have a rack at all? `~/.rhachet` absent means init is owed first
NEEDS_INIT="false"
if ! _ask 'test -d "$HOME/.rhachet/keyrack"'; then
  NEEDS_INIT="true"
  echo "      ├─ ⚠️ the box has NO rack yet (~/.rhachet/keyrack is absent)"
  echo "      │     the binary and the STORAGE are two facts; 5.3.brains gives"
  echo "      │     only the first, so an init is owed before a set"
fi

if [[ "$MODE" == "plan" ]]; then
  echo "      └─ plan — this is what apply would run ON THE BOX:"
  echo ""
  echo "         cd ~/$KR_REPO"
  [[ "$NEEDS_INIT" == "true" ]] && \
  echo "         rhx keyrack init --owner $KR_OWNER --prikey ~/.ssh/id_ed25519 --org $KR_OWNER"
  echo "         rhx keyrack set  --owner $KR_OWNER --key $KR_KEY \\"
  echo "                          --org $KR_ORG --env $KR_ENV --vault $KR_VAULT"
  echo ""
  echo "      the set PROMPTS twice on the box's own tty — mechanism (answer 1),"
  echo "      then the token. mint it at https://github.com/settings/tokens with"
  echo "      scopes: repo, read:org"
  echo ""
  echo "      ⚠️ one set, and no 'keyrack fill' after it. set stores the value"
  echo "         itself; fill re-drives those same two prompts, so a chained fill"
  echo "         takes the pat as its MECHANISM answer and keyrack rejects it with"
  echo "         expected: \"1-2\""
  echo ""
  echo "      re-run with --mode apply to be handed that prompt."
  exit 0
fi

# 4. apply — one interactive session, so the human types the value straight into
#    keyrack's prompt on the box
#
#    ⚠️ `-t` is the load-bear flag. without a tty keyrack cannot prompt, and it
#    would either read this skill's stdin (which is closed) or fall back to a
#    non-interactive path — both of which end with an empty or wrong secret stored
echo "      └─ apply — opens an interactive tty on '$SSH_ALIAS'"
echo ""
echo "🔑 a human is owed here"
echo "   ├─ mint a pat: https://github.com/settings/tokens"
echo "   ├─ scopes:     repo, read:org"
echo "   ├─ prompt 1:   which mechanism? → answer 1 (PERMANENT_VIA_REPLICA)"
echo "   └─ prompt 2:   enter secret     → paste the pat"
echo "                  it is read by the BOX's tty, not by this shell"
echo ""

# ⚠️ .why the chain is `cd` + ONE set, and no `keyrack fill`
#      .cd    rhachet's cli resolves the git repo root before it dispatches any
#             subcommand, so a bare `rhx keyrack …` from the login shell's $HOME
#             dies with `BadRequestError: Not inside a Git repository` — an error
#             that names the CWD and reads like a broken keyrack
#      .one   `set` prompts for the value and stores it; that is the whole act.
#             `fill` is for a key this host does not hold yet, and it re-drives
#             those same prompts — so a `set && fill` chain sends the pat into
#             fill's mechanism question and keyrack refuses it (`expected: "1-2"`)
REMOTE_STEPS="cd \$HOME/$KR_REPO && "
[[ "$NEEDS_INIT" == "true" ]] && REMOTE_STEPS+="rhx keyrack init --owner $KR_OWNER --prikey \$HOME/.ssh/id_ed25519 --org $KR_OWNER && "
REMOTE_STEPS+="rhx keyrack set --owner $KR_OWNER --key $KR_KEY --org $KR_ORG --env $KR_ENV --vault $KR_VAULT"

if ! ssh -t "$SSH_ALIAS" "bash -lc $(printf '%q' "$REMOTE_STEPS")"; then
  echo "" >&2
  echo "💥 the rack was not filled" >&2
  echo "   ⇒ keyrack refused, or the prompt was declined" >&2
  echo "   read the box's own view —" >&2
  echo "     rhx git.grove.send $GROVE --what 'rhx keyrack list --owner $KR_OWNER'" >&2
  exit 1
fi

# 5. does github accept it? a stored string is not an accepted credential
#
#    ⚠️ this one is NOT `_ask`: its output is the bundle's own verdict, which a
#    human needs to read. the probes above are silenced because a login shell on
#    this box prints a `keynav started` banner from `.profile`
#
#    🛑 and "a human needs to read it" is the REASON it must be sunk, never a
#       reason to relay it raw. a stream nobody reads harms nobody; this is the
#       one that reaches a terminal, in the minute after a pat was pasted.
#       `ssh -t` above is exempt because a pty IS escape traffic; this call has
#       no pty, so every byte here is the grove's prose and none of it is
#       control the terminal was promised.
#
#    .note `2>&1` INTO the sink, so the two streams interleave in the order the
#          bundle wrote them — a human reads an apply as one narrative. and
#          `set -o pipefail` (line 133) keeps this `if !` on ssh's own status
echo ""
echo "🔑 stored. now: does github accept it?"
# ⚠️ the DRIVER by path, and this is one of the two sites
#    `rule.forbid.the-driver-by-path` carves out. the send below is a `bash -lc`,
#    which reads no `.zshrc`, so `rhx` is NOT on PATH on the far side
#    (`gotcha.a-tool-found-by-path-answers-only-a-human`, rung 4). a skill that
#    OWNS the drive may name the driver; a human never does
PROVE_ONE_BUNDLE="cd \$HOME/$KR_REPO && bash src/grove.provision._.sh --what 5.4.gh --mode apply"
if ! ssh -o BatchMode=yes "$SSH_ALIAS" "bash -lc $(printf '%q' "$PROVE_ONE_BUNDLE")" 2>&1 \
     | __duct_strip_escapes; then
  echo "💥 the token stored, but 5.4.gh could not auth gh with it" >&2
  echo "   ⇒ a SET token is not an ACCEPTED token: an expired or under-scoped pat" >&2
  echo "     passes storage and fails at the first api call" >&2
  echo "   fix: mint a fresh pat with 'repo' + 'read:org', then —" >&2
  echo "     rhx git.grove.auth.github.set $GROVE --mode apply --refresh" >&2
  exit 1
fi

echo ""
echo "🌳 grove '$GROVE' holds a github credential!"
echo "   ├─ stored: ${KR_ORG}.${KR_ENV}.${KR_KEY}, in ${KR_VAULT}"
echo "   ├─ gh:     authed from the rack, and github accepted it"
echo "   └─ next:   clone the orgs —"
echo "      rhx git.grove.send $GROVE --what 'bash \$HOME/$KR_REPO/src/grove.provision._.sh --what 5.10.repos --mode apply'"

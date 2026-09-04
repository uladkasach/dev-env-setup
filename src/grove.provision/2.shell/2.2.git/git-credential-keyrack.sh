#!/usr/bin/env bash
######################################################################
# git-credential-keyrack — let plain `git` over https draw from the rack
#
# .what = a git credential helper. git runs it with a verb (`get`/`store`/
#         `erase`) and feeds it a key=value block on stdin; for `get` it answers
#         with a username and password on stdout, or answers with silence.
#
# .why  = without it, https access to a private repo needs one of: a token
#         exported into the shell (dies with that shell, reproducible by no
#         bundle), `gh auth setup-git` (ties git to gh's plaintext hosts.yml), or
#         an ssh key (a second credential to place on every box). the rack
#         already holds the token, age-encrypted — this is the seam that lets git
#         read it.
#
# .the slug it reads
#         @all.camp.GITHUB_TOKEN
#
#         `@all` is a REQUIREMENT. a box credential belongs to no single org, and
#         git invokes a credential helper from whatever clone the human stands
#         in — most of which carry no `.agent/keyrack.yml` for `@this` to read.
#
# ✔ .PROVEN end to end — 2026-08-05, rhachet@1.45.1
#         a private clone over plain https, from BOTH orgs, on grove-1: no ssh
#         key, no gh, no token exported into a shell. the read itself, cold:
#
#           get --org @all --env camp --key GITHUB_TOKEN --unlock \
#               --allow-dangerous --value | wc -c        → 40   # a classic pat
#
#         ⚠️ the pat needs scope `repo` for this helper. `read:org` serves gh's
#         DISCOVERY and is a separate capability — see
#         `define.github-auth-two-paths`. one pat, one protocol, two outcomes.
#
#         this is also why the `cd` below carries weight rather than tidiness:
#         the read path validates the slug against the manifest, so keyrack must
#         be asked from a checkout that holds one.
#
# 📜 .the `@all` read — keyrack below 1.45.1 refuses it
#         measured 2026-08-03: the read path answered `absent 🫧` and
#         `BadRequestError: slug org '@all' does not match manifest org`.
#         fixed at 1.45.1. two lessons outlive it:
#
#         1. part of that evidence was OUR defect. the probe that
#            answered `absent` wrote a FAKE classic-pat-shaped value and never
#            confirmed it landed — so the pat firewall had likely refused the
#            store. `absent` was a truthful answer about an entry that may never
#            have existed (`rule.require.clamp-edge-cases`: a probe that cannot
#            fail the way the defect fails proves only that it ran).
#
#         2. ⚠️ a `✔ set` is a claim about the ENTRY — the stored record — and
#            says none of the SLUG that names it. two sessions read it as "the
#            credential is placed" and were wrong both times, at the cost of a
#            real pat each. that lesson stands, and
#            `domain.terms/term=entry._.choice._.md` exists because of it.
#
#         ⚠️ the refusal that still holds: do NOT answer a FUTURE read failure by
#         a switch to `@this`. `@this` resolves only from a checkout that holds
#         `.agent/keyrack.yml`, and git invokes this helper from whatever clone
#         the human stands in. that substitution was attempted on 2026-08-03 and
#         reverted — a tool that passes by discard of the requirement has not
#         passed. (`git.grove.provision test` re-proves the read on every
#         provision — its suite step clones a private repo over plain https)
#
#         ⚠️ `camp` and `GITHUB_TOKEN` name the BOX's credential, deliberately not
#         the mechanic's `prep.EHMPATHY_SEATURTLE_GITHUB_TOKEN`. tying a grove's
#         ability to clone to a robot's commit-token rotation would make one
#         rotation break the other's job. see `.agent/keyrack.yml`.
#
# ⚠️ .why it DECLINES rather than fails, on every unhappy path
#         git treats an empty answer as "this helper has none" and moves to the
#         next helper, or to a prompt. that is the correct outcome whenever the
#         rack cannot answer — an absent rhx, an unfilled slug, a host this box
#         does not serve. an ERROR here would break `git clone` of a PUBLIC repo,
#         which needs no credential at all.
#
#         so: exit 0, empty stdout, and the reason on stderr where a human can
#         read it without git parsing it. that is the roadmap's rung 3, and it is
#         what makes the helper safe to install on every box unconditionally.
#
# ⚠️ .why every call is BOUNDED by `timeout`
#         a credential helper that hangs hangs GIT — every fetch, every push, and
#         inside whatever script called them. the rack can hit a locked key or a
#         daemon that does not answer, so an unbounded read is a stall with a
#         question mark on it (rule.require.bounded-probes-in-verifies,
#         term=probe: "a probe that can hang is not a probe").
#
# ⚠️ .why it must cd into a git repo before it calls rhx
#         rhachet's cli resolves the git repo root BEFORE it dispatches any
#         subcommand, so `rhx` from a non-repo dies with `Not inside a Git
#         repository`. git usually invokes a helper with the repo as cwd — but
#         NOT for `git clone`, where cwd is the parent dir and no repo exists yet.
#         clone is the single most important case for this helper, so the cwd is
#         chosen deliberately rather than inherited.
#
# .the contract (git's, not ours)
#         stdin   protocol=https\nhost=github.com\n[path=org/repo.git]\n\n
#         stdout  username=x-access-token\npassword=<token>\n
#
# usage (git calls this; a human rarely does):
#   printf 'protocol=https\nhost=github.com\n\n' | git-credential-keyrack get
#
# .refs
#   .agent/repo=.this/role=any/briefs/creds/grove.auth.github.roadmap.md   # phase 1 vs 2
#   src/grove.provision/2.shell/2.2.git/configure.upsert.sh           # declares the helper
######################################################################
set -uo pipefail

VERB="${1:-}"

# ── store / erase are no-ops, and must still exit 0
#
# .why the rack is not a cache. git offers a credential back for storage after a
#      successful auth, and asks for erasure after a rejection. this helper is a
#      READER of a declared credential, so it has no business writing one — but a
#      non-zero exit here makes git report a helper failure on an otherwise
#      successful fetch.
case "$VERB" in
  get) ;;
  store|erase) exit 0 ;;
  *)
    echo "git-credential-keyrack: unknown verb '${VERB:-（none）}'" >&2
    echo "  git calls this with get|store|erase" >&2
    exit 0
    ;;
esac

# ── read git's key=value block
#
# .why the loop stops on a blank line: that is git's terminator, and a helper
#      that reads to EOF instead can block when git keeps the pipe open
declare -A REQ=()
while IFS='=' read -r k v; do
  [[ -z "$k" ]] && break
  REQ["$k"]="$v"
done

HOST="${REQ[host]:-}"
PROTOCOL="${REQ[protocol]:-}"

# ── only github, over https, is served here
#
# .why decline rather than answer: another helper may serve gitlab or a corporate
#      host, and a helper that answers for a host it has no credential for would
#      hand git a wrong token and turn a clean fallthrough into a 401
#
# 🛑 .why the PROTOCOL is asked too, as of 2026-08-31
#      the host test alone answered for ANY scheme git names — `http`, `ftp`, and
#      any future one. the token here is a github pat with `repo` + `read:org`
#      (`rule.require.github-token-at-all-camp`), so an `http` request would put
#      it on the wire in CLEARTEXT, to a host a downgrade or a poisoned resolver
#      chose.
#
#      ⚠️ git does not protect this for us: a `url.<base>.insteadOf`, a redirect
#        a server sends, or a plain `git clone http://github.com/…` each reach a
#        helper with `protocol=http`, and the helper is the last component that
#        can refuse. a credential helper is an EGRESS boundary — it is the one
#        place that decides where a secret goes.
#
#      the decline is silent and exit 0, exactly like the host decline: git then
#      falls through to the next helper, and the failure a human sees is the
#      ordinary "could not read Username" rather than a leaked token.
if [[ "$HOST" != "github.com" || "$PROTOCOL" != "https" ]]; then
  exit 0
fi

# ── the pnpm bin dir, in case the CALLER's PATH does not carry it
#
# ⚠️ .measured 2026-08-10 on grove-ahbode-v20260810
#      `git ls-remote https://github.com/<org>/<repo>` over ssh printed
#
#        git-credential-keyrack: rhx absent — declines
#        fatal: could not read Username for 'https://github.com/…'
#
#      and `rhx` was installed, executable, and one directory away. `PNPM_HOME`
#      reaches PATH from `~/.zshrc`, which zsh sources for an INTERACTIVE shell
#      alone — so this helper answered a human at a keyboard and declined for
#      ssh, cron, and every suite.
#
#      that is the SAME defect one layer out: a git that finds this file by PATH
#      answers the same narrow set. both are named directly instead.
#
# .why here and not in a shell rc: this helper is exec'd BY GIT, and git may be
#      run from bash, zsh, a node child, or a cron — no rc is common to all of
#      them. the dependency is this file's, so this file names it
#
# .why it APPENDS rather than prepends: a caller who already carries a pnpm dir
#      has chosen one, and this must not outrank that choice — it only supplies
#      a dir when the caller supplied none
if ! command -v rhx >/dev/null 2>&1; then
  PNPM_DIR="${PNPM_HOME:-$HOME/.local/share/pnpm}"
  [[ -d "$PNPM_DIR" ]]     && PATH="$PATH:$PNPM_DIR"
  [[ -d "$PNPM_DIR/bin" ]] && PATH="$PATH:$PNPM_DIR/bin"
  export PATH
fi

# ── and NODE, because `rhx` is a node shim and cannot run without one
#
# ⚠️ .why this is a SECOND rung and not the same one
#      the block above put `rhx` on PATH and the very next call still died:
#
#        /usr/bin/env: 'node': No such file or directory
#
#      `rhx` opens `#!/usr/bin/env node`, so a shim that is FOUND and cannot
#      run is indistinguishable, from git's side, from a shim that is absent —
#      both end as one empty token and the decline below names neither.
#
# ⚠️ .why the fnm ALIAS dir and not the multishell dir
#      `fnm env` mints a per-shell symlink dir and exports it, so the dir that
#      serves an interactive shell is EPHEMERAL and belongs to that shell
#      alone. `aliases/default/bin` is the one fnm path that outlives a shell,
#      so it is the only one a helper exec'd by git may name
if ! command -v node >/dev/null 2>&1; then
  FNM_DEFAULT="${FNM_DIR:-$HOME/.local/share/fnm}/aliases/default/bin"
  [[ -d "$FNM_DEFAULT" ]] && export PATH="$PATH:$FNM_DEFAULT"
fi

# ── is rhx even here? keyrack ships inside rhachet, which `5.3.brains` installs
#
# .why this is not an error: `2.2.git` declares this helper at position 2 and
#      brains arrives at 5.3, so on a fresh box the helper exists before its
#      reader does. that window is normal, and git must keep at work through it
if ! command -v rhx >/dev/null 2>&1; then
  echo "git-credential-keyrack: rhx absent — declining" >&2
  echo "  keyrack ships inside rhachet; 5.3.brains puts it on a box" >&2
  exit 0
fi

# ── a git repo to stand in — see the ⚠️ above
#
# ⚠️ .the ladder runs MOST-OWNED first, and that order is the whole point
#
#      a cwd-first ladder rests on the claim "the cwd is already right for
#      fetch/push, and only clone needs the fallback". that holds for the CWD
#      and fails for the RACK, and the difference cost a `git tree set`:
#
#        cd ~/git/ahbode/svc-chat && rhx keyrack get … --org @all …
#          → BadRequestError: extended keyrack not found
#             path: .agent/repo=bhrain/role=reviewer/keyrack.yml
#             from: /home/camper/git/ahbode/svc-chat/.agent/keyrack.yml
#          → 0 bytes
#
#        cd ~ …the same get, from a dir this helper controls  → 40 bytes ✔
#
#      rhachet LOADS `.agent/keyrack.yml` from the cwd before it considers the
#      org sigil at all, so a clone whose manifest `extends` a file it does not
#      vendor kills the read — and the helper's `2>/dev/null` turns that throw
#      into one empty string, indistinguishable from an absent credential.
#
#      ⇒ and "the cd is harmless because `@all` needs no manifest" is only HALF
#      right. `@all` needs no manifest for the ORG; it still needs the cwd's
#      manifest to LOAD. every clone on a grove is a repo whose
#      `.agent/` this helper does not control, which is exactly the population
#      the `@all` requirement exists to serve.
#
# .why this order
#      1. the explicit declaration, if a box made one — a human's word wins
#      2. THIS repo's checkout — it owns `.agent/keyrack.yml`, the one manifest
#         that declares the key, so it is the only cwd guaranteed to load
#      3. …and then it REFUSES. every rung names a source somebody DECLARED;
#         a rung that reads "whatever repo the shell is in" declares no source
#         at all, and that is why it is gone (see the 🛑 at the ladder itself)
#
# 🛑 .why rung 2's two paths test the MANIFEST, never `.git`
#
#      a `[[ -d "$p/.git" ]]` tests for a `.git` DIRECTORY. that is a PROXY for
#      "is this a checkout", and the rung needs a different fact:
#      "does this dir hold the manifest that declares the key". the proxy is
#      false for the very population the rung was written to serve:
#
#        | how this repo lands on a box        | `.git`        |
#        |-------------------------------------|---------------|
#        | `git clone`                         | a directory ✔ |
#        | `git.grove.push --from . --into …`  | ABSENT      ✋ |
#        | a git worktree                      | a FILE      ✋ |
#
#      and the middle row is what `rule.require.one-command-provision` states as
#      THE provision: push, then apply. a push copies files, so a grove built by
#      this repo's own procedure holds a checkout with no `.git` at all.
#
# 📜 .measured 2026-08-15 on grove-ahbode-v20260811, built from scratch
#      (`diagnose.credential-helper-ladder`):
#
#        · rung 2  /home/camper/git/more/dev-env-setup
#          ├─ shape:              pushed copy (NO .git)
#          ├─ holds the manifest: YES   ← what the rung NEEDS
#          └─ passes [[ -d .git ]]: no  ← what the rung TESTED
#        ⇒ rung 4 (the cwd — correct only by luck) → …/git/ahbode/svc-chat
#
#      so every private fetch on that box fell to rung 4, and svc-chat's own
#      `.agent/keyrack.yml` extends a role manifest it does not vendor:
#
#        ✋ …/git/ahbode/svc-chat — 0 bytes
#        ✔ …/git/more/dev-env-setup — 40 bytes
#
#      0 bytes is a DECLINE, and a decline ends in git's terminal prompt. on a
#      duct that prompt sits on the pane and eats every command sent afterward —
#      which is how `git.grove.provision test` step 1 wedged, on a converged box.
#
# ⚠️ .why a manifest test is SAFE here, on evidence rather than on hope
#      this file's own header records that *"rhachet's cli resolves the git repo
#      root BEFORE it dispatches any subcommand, so `rhx` from a non-repo dir
#      dies with `Not inside a Git repository`"* — which would make a `.git`-less
#      dir useless as a cwd. the same measurement disproves it for this call:
#      the pushed copy answered 40 bytes, and so did `$HOME`, neither of which is
#      a repo (`rule.require.trust-but-verify`, applied to a note in this file).
#
#      the rung still points at a CHECKOUT and not at `$HOME`, because the read
#      path validates the slug against the manifest — see the ✔ block above
# 🛑 .the ladder has THREE rungs. the fourth — "whatever repo the human is in" —
#    was DELETED 2026-08-31, and its removal is a fix in both directions
#
# .the security half
#    the line below `cd`s into $REPO and runs `rhx`, and rhachet LOADS that
#    directory's `.agent/keyrack.yml` before it reads anything else. that
#    manifest may `extends:` other paths. so a rung that accepts ANY checkout
#    means: the config a credential helper loads is picked by whichever
#    directory a human's shell happened to be sitting in when git fired.
#
#    ⇒ that is an ingress seam, and a quiet one. a clone the human made from a
#      public repo is a directory an outside party authored — and this helper
#      runs on EVERY private fetch, with the rack unlocked, on the laptop. no
#      step in that flow asks the human which repo should shape it.
#
# .the functional half — and this is the part that makes the delete free
#    the measurement above IS rung 4 misfired. on that grove every private
#    fetch fell to rung 4, landed in `…/git/ahbode/svc-chat`, whose own
#    `.agent/keyrack.yml` extends a role manifest it does not vendor — so the
#    read returned 0 bytes, which is a DECLINE, which is git's terminal prompt,
#    which on a duct ate every command sent afterward.
#
#    ⇒ so the rung this file already called "correct only by luck" was not
#      merely lucky, it was the recorded cause of a wedge. it never earned a ✔.
#
# ⚠️ .what replaces it: no rung at all, deliberately
#    rung 1 (`$GIT_CREDENTIAL_KEYRACK_REPO`) already names any location rungs
#    2-3 do not — a worktree, a non-standard clone, a grove that holds the repo
#    elsewhere. so the escape hatch is a DECLARATION a human makes once, rather
#    than a guess this helper makes on every call
#    (`rule.require.solve-at-cause`). a refusal with a copy-paste fix beats a
#    read from a source neither party chose.
#
# 🛑 .there is NO `credential.keyrackRepo` git config, and there must not be
#    📜 measured 2026-08-31: this comment and the refusal's fix-text below both
#      named one, and the fix-text LED with it — so a human who followed the
#      only instruction this helper gives would set a key no line here reads,
#      re-run, and get the identical refusal. a fix-text that cannot fix is the
#      false ✋ shape one layer out (`rule.require.errors-name-the-fix`).
#
#    ⇒ and it is not a key to add. `git config --get` reads the config of the
#      repo the caller STANDS IN, which is the exact source the paragraph above
#      refuses; a `--global` read would be a SECOND holder of one fact, free to
#      disagree with the env var with no signal (m.9). one declaration, one
#      reader (`rule.forbid.two-writers-on-one-artifact`).
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
  echo "    to make it stick, declare it in src/zshenv.sh and apply the bundle —" >&2
  echo "    NOT by an edit to ~/.zshenv, which this repo owns and diffs:" >&2
  echo "      rhx grove.provision --what 2.5.zsh --mode apply" >&2
  exit 0
fi

# ── ask the rack
#
# .why `--unlock`: a key at rest is LOCKED, and without this the get returns an
#      empty string and exit 0 — which would read as "no credential" forever
# .why `--allow-dangerous`: keyrack refuses a long-lived token through a replica
#      vault (`detected github classic pat (ghp_*)`). the refusal is CORRECT; the
#      flag is phase 1's debt, and phase 2's app token retires it
# .why `2>/dev/null`: keyrack's own chatter is not this helper's answer, and git
#      reads stdout strictly
#
# ⚠️ .why the `cd` is inside a SUBSHELL, and why it is not optional
#      `--org @this` means "the root manifest's org", so keyrack reads
#      `.agent/keyrack.yml` relative to the CWD. run from anywhere else it cannot
#      build the slug at all. the ladder above chose $REPO precisely so this line
#      has somewhere to stand — a $REPO computed and then never used is $REPO
#      wasted.
#
#      ⚠️ and "that is harmless, because `@all` needs no manifest" is FALSE:
#      rhachet LOADS the cwd manifest before it reads the
#      org sigil, so a cwd whose `.agent/keyrack.yml` extends an absent file
#      throws and this get answers empty. see the ladder's ⚠️ above, and note
#      that the ladder — not this cd — is what makes the cwd safe.
#      the subshell keeps the cd from leaking into the rest of this helper.
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

# ── answer
#
# .why `x-access-token` as the username: github accepts any non-empty username
#      when the password is a token, and this is the name its own docs use — so a
#      reader of `git config` output or a server log sees what the credential is
printf 'username=x-access-token\n'
printf 'password=%s\n' "$TOKEN"

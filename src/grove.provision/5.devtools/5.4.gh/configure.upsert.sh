#!/usr/bin/env bash
######################################################################
# .what = make `gh` hold a credential — from the RACK where the box has one,
#         by login where a human waits, and by a named halt where neither holds
#
# 🛑 the rack is the ONLY source, and an exported GH_TOKEN is not a rung
#   - a token a human exports into a shell dies with that shell
#   - ⇒ no bundle reproduces it, and the next duct pane starts unauthed
#   - an `export GH_TOKEN=…` instruction is a one-off where a bundle exists
#   - an env GH_TOKEN still WORKS, since gh reads it itself
#   - ⇒ rung 0 below sees an authed gh and this bundle owes no work
#   - that is how `local@cicd` authenticates, with a runner token and no rack
#   - (`rule.require.repo-as-source-of-truth`, `rule.require.install-via-procedures`)
#
# .the halt names one `keyrack set`, never a token to paste
#   - a pasted token lands in tmux scrollback, shell history, and a transcript
#   - `keyrack set` reads from a TTY and writes it age-encrypted
#
# ⚠️ the login is gated on INTENT, never on a tty
#   - a duct is tmux, and a tmux pane HAS a tty
#   - 📜 `[[ ! -t 0 ]]` read false on a headless grove and the prompt opened
#   - ⇒ it ate the NEXT command sent to that duct as its answer
#   - `cloud@*` already means "no human present" (`term=--for`)
#
# .this bundle sits at 5.4, never at 2.4
#   - it reads the rack, and keyrack ships inside the rhachet `5.3.brains` installs
#   - ⇒ at 2.4 this phase fails on every grove run
#
# guarantee:
#   - an already-authed gh is left alone
#   - the token is piped over STDIN, so `ps` shows no secret
######################################################################

grove_provision_5_4_gh_configure_upsert() {
  # .what = the one rack SLUG this repo's github token lives at (`term=slug`)
  #   - the halt below must print the SAME slug the get reads
  #   - these are locals, never `readonly`, since a file may be sourced twice
  #   - (`rule.require.idempotent-install-procedures`)
  #
  # ⚠️ only a key DECLARED in a `keyrack.yml` can be read
  #   - 📜 a set of an UNDECLARED key prints `✔ set` and its get says `absent 🫧`
  #   - ⇒ a set alone proves no read (`term=entry`)
  #   - `--org` is a sigil axis, `@this` or `@all`
  #
  # ✔ `@all` is a REQUIREMENT, never a preference
  #   - `@this` resolves only from a checkout that holds `.agent/keyrack.yml`
  #   - the credential helper runs from whatever clone the human stands in
  #   - a grove stands in many clones, almost none of which carry an `.agent/`
  #   - `@all` is also what the credential IS, since one pat spans every org
  #   - 📜 PROVEN to read 40 bytes cold from `~` on grove-1, 2026-08-05
  #   - 🛑 do NOT answer a future read failure by a switch to `@this`
  #
  # ⚠️ `camp` / `GITHUB_TOKEN`, never `prep` / `EHMPATHY_SEATURTLE_*`
  #   - the seaturtle key is the mechanic's own commit token, with its own rotation
  #   - this one belongs to the BOX
  #   - ⇒ to point gh at the mechanic's key ties a grove to a robot identity
  #   - `camp` is this repo's word for grove infrastructure
  #   - ONE slug serves gh, git over https, and `git.grove.auth.github.set`
  local GH_KEYRACK_OWNER="ehmpath"
  local GH_KEYRACK_KEY="GITHUB_TOKEN"
  local GH_KEYRACK_ORG="@all"
  local GH_KEYRACK_ENV="camp"
  # ⚠️ `aws.params`, never `os.secure` — shipped on purpose, never an interim
  #   - every box that reaches THIS halt is a grove, and a grove is ec2
  #   - IMDS is the one identity `aws.params` accepts for an `@all` slug
  #   - a LOCAL box never arrives here, since `gh auth login` ran on the way past
  #   - ⇒ a laptop's absence of IMDS costs this bundle no capability
  #   - `os.secure` is a REPLICA, so a rotation must reach each holder
  #   - 📜 `aws.params` proven live on grove-1 2026-08-05
  local GH_KEYRACK_VAULT="aws.params"

  ####################################################################
  # 0. already authed? then the declaration holds
  #   - this rung absorbs an env GH_TOKEN too, since gh reads it for itself
  #   - so a cicd runner that injects one arrives here already authed
  ####################################################################
  if gh auth status >/dev/null 2>&1; then
    echo "   • gh already authed — no work"
    return 0
  fi

  ####################################################################
  # 1. the rack, the only reproducible source
  #   - `--value` prints the bare token, and the pipe keeps it off argv
  #
  # ⚠️ `--unlock` and `--allow-dangerous` are both required
  #   - a key at rest is LOCKED, so without `--unlock` the get returns empty
  #   - the `[[ -n "$token" ]]` guard below is the only stop on that
  #   - keyrack refuses a classic pat through a replica vault, correctly
  #   - `--allow-dangerous` is the deliberate bypass phase 1 needs
  #   - ⇒ at phase 2 the app token mints itself and THIS FLAG COMES OUT
  #
  # 🛑 the CWD is part of this read, and is NOT the caller's to choose
  #   - rhachet loads `.agent/keyrack.yml` from the CWD before the org sigil
  #   - a duct pane carries whatever cwd its last command left
  #   - 📜 grove-ahbode-v20260811 read 0 bytes from a clone with no role file
  #   - `2>/dev/null` turns that throw into an empty string
  #   - ⇒ the branch below reads it as "no credential" on a healthy rack
  #   - ⇒ `env -C "$gitroot"` names a dir `5.12.rack` creates before this bundle
  #   - (`rule.forbid.failhide`, `term=keyrack.gitroot`)
  ####################################################################
  if command -v rhx >/dev/null 2>&1; then
    local token gitroot
    gitroot="$(grove_provision_5_12_rack_gitroot)"
    if token="$(env -C "$gitroot" rhx keyrack get \
      --owner "$GH_KEYRACK_OWNER" \
      --key "$GH_KEYRACK_KEY" \
      --org "$GH_KEYRACK_ORG" \
      --env "$GH_KEYRACK_ENV" \
      --unlock \
      --allow-dangerous \
      --value 2>/dev/null)" && [[ -n "$token" ]]; then

      if printf '%s' "$token" | gh auth login --with-token; then
        unset token
        echo "   • gh authed from the rack (${GH_KEYRACK_ORG}.${GH_KEYRACK_ENV}.${GH_KEYRACK_KEY})"
        return 0
      fi

      unset token
      echo "   ✋ the rack HELD a github token and github refused it" >&2
      echo "      ⇒ this is not an absent credential — it is a rejected one, so a" >&2
      echo "        'keyrack set' would repair no part of it" >&2
      echo "      ⇒ usual cause: the pat expired, was revoked, or lacks the scopes" >&2
      echo "        a repo read needs" >&2
      echo "      fix: mint a fresh pat, then re-set the same slug — set overwrites," >&2
      echo "        and answering its two prompts is the whole act:" >&2
      echo "        cd ~/git/more/dev-env-setup && rhx keyrack set \\" >&2
      echo "          --owner $GH_KEYRACK_OWNER --key $GH_KEYRACK_KEY \\" >&2
      echo "          --org $GH_KEYRACK_ORG --env $GH_KEYRACK_ENV --vault $GH_KEYRACK_VAULT" >&2
      ##################################################################
      # 🛑 step 2 is not optional, and no rotation text may omit it
      #   - a re-set reaches the ssm VALUE and `git`, which asks the rack per fetch
      #   - it does NOT reach `gh`, whose login persists a cleartext copy
      #   - that copy survives a locked rack, a lapsed session, and the ssm write
      #   - ⇒ a rotation EVICTS no copy unless the old pat is revoked at github
      #   - (`rule.require.github-token-at-all-camp`)
      ##################################################################
      echo "      🛑 then REVOKE the old pat — a re-set does NOT evict it:" >&2
      echo "        https://github.com/settings/tokens" >&2
      echo "        every grove holds gh's own cleartext copy at" >&2
      echo "        ~/.config/gh/hosts.yml, and no re-set reaches it" >&2
      return 1
    fi
  fi

  ####################################################################
  # 2. a login may only open where a human waits
  #
  # ⚠️ the test is `!= local@unix`, never `== cloud@*`, so it FAILS CLOSED
  #   - an unset GROVE_ENV_SERVER makes `[[ "" == cloud@* ]]` FALSE
  #   - ⇒ that form falls through and opens a login on an unknown box
  #   - `local@unix` is the only value that means a human is at a keyboard
  #   - `local@cicd` is a local TIER with no human, so `local@*` fails open too
  #
  # ⚠️ the TTY is the second conjunct, and both are load-bear
  #   - the tier says a human COULD be at this box, never that one is here NOW
  #   - a laptop is `local@unix` under a cron, a unit, or a detached job alike
  #   - `gh auth login` opens a device-flow prompt and BLOCKS on an answer
  #   - ⇒ a tty proves no human, and a tier proves no PRESENCE
  #   - (`rule.forbid.tty-as-a-proxy-for-a-human`)
  ####################################################################
  if [[ "$GROVE_ENV_SERVER" != "local@unix" || ! -t 0 ]]; then
    echo "   ✋ gh is unauthed, and the rack holds no '$GH_KEYRACK_KEY' to give it" >&2
    if [[ "$GROVE_ENV_SERVER" == "local@unix" ]]; then
      echo "      ⇒ this box CAN hold a human, and no terminal is attached to THIS" >&2
      echo "        run — a cron, a unit, or a detached job. 'gh auth login' blocks" >&2
      echo "        on an answer, so it would hang here rather than fail" >&2
    else
      echo "      ⇒ this box is '$GROVE_ENV_SERVER'; only 'local@unix' confirms a" >&2
      echo "        human at a keyboard, so no login prompt may open here" >&2
    fi
    echo "      ⇒ a login prompt is deliberately NOT opened: a duct is tmux, so" >&2
    echo "        the question would sit on the pane and then consume the next" >&2
    echo "        command sent down the duct as its answer" >&2
    echo "      ⇒ until a token lands, every github reach fails on auth: the org" >&2
    echo "        clone, the issue read, the pr open — most of what a grove does" >&2

    if ! command -v rhx >/dev/null 2>&1; then
      echo "      ✋ AND rhx is not on PATH, so the rack cannot even be read" >&2
      echo "        ⇒ keyrack ships inside rhachet, which 5.3.brains installs" >&2
      echo "        fix: rhx grove.provision --what 5.3.brains --mode apply" >&2
      return 1
    fi

    echo "" >&2
    echo "      🙋 A HUMAN IS OWED HERE — run this ON THIS BOX, from the checkout:" >&2
    echo "" >&2
    echo "        cd ~/git/more/dev-env-setup && rhx keyrack set \\" >&2
    echo "          --owner $GH_KEYRACK_OWNER --key $GH_KEYRACK_KEY \\" >&2
    echo "          --org $GH_KEYRACK_ORG --env $GH_KEYRACK_ENV --vault $GH_KEYRACK_VAULT" >&2
    echo "" >&2
    echo "      it asks two questions, in this order:" >&2
    echo "        1. which mechanism?  → 1 (PERMANENT_VIA_REPLICA)" >&2
    echo "        2. enter secret      → paste the pat" >&2
    echo "" >&2
    echo "      ⚠️ ANSWER BOTH AT THE PROMPTS. do not pipe them in: the secret" >&2
    echo "         prompt masks its echo, so it reads the terminal, not stdin. fed" >&2
    echo "         a pipe, set takes the mechanism answer, SKIPS the secret, stores" >&2
    echo "         an EMPTY value, and prints '✔ set' regardless — and the blank" >&2
    echo "         only surfaces later, as a token github rejects" >&2
    echo "" >&2
    echo "      ⚠️ there is NO second 'keyrack fill' step. set stores the value" >&2
    echo "         itself; fill re-drives the very same prompts, so a set-then-fill" >&2
    echo "         chain sends the pat into fill's FIRST question — which asks for" >&2
    echo "         a mechanism — and keyrack rejects it with expected: \"1-2\"." >&2
    echo "" >&2
    echo "      the value is never an argument, so it reaches neither 'ps' nor the" >&2
    echo "      shell history; keyrack writes it age-encrypted" >&2
    echo "" >&2
    echo "      mint the pat at https://github.com/settings/tokens with 'repo' +" >&2
    echo "      'read:org'. see grove.auth.github.roadmap.md — the pat is phase 1," >&2
    echo "      and phase 2 replaces it with a per-org app token that mints itself" >&2
    return 1
  fi

  ####################################################################
  # 3. the interactive login, where a human can answer it
  ####################################################################
  if ! gh auth login; then
    echo "   ✋ gh auth login did not complete" >&2
    echo "      ⇒ gh holds no credential, so every github reach fails on auth" >&2
    echo "      read why: gh auth status" >&2
    return 1
  fi

  echo "   • gh authed by login"
}

#!/usr/bin/env bash
######################################################################
# .what = declare the protocol git speaks to github, and repair the ONE origin
#         the bootstrap could not set: this checkout's own
#
# ⚠️ this phase exists because the bootstrap cannot set an ssh origin
#   - `grove.bootstrap.sh` clones ANONYMOUSLY over https, before any credential
#   - ⇒ a bootstrapped laptop pushes from https and is asked for a password
#   - ⇒ this phase is where the ssh origin lands
#
# .ssh, never the gh https credential helper
#   - both make a push work, and only ssh keeps the credential off the disk
#   - on this human's laptop the key is the yubikey behind `SSH_AUTH_SOCK`
#   - (`rule.require.security-paramount`)
#
# ⚠️ the ~200 org clones under ~/git are deliberately NOT touched
#   - a sweep of all of them is a blast radius no one asked for
#   - ⇒ the `git_protocol` set below converges the fleet through FUTURE clones
#
# guarantee:
#   - an origin already on ssh is left alone, and `gh config set` converges
#   - it DECLINES where no key exists, or where github accepts none
######################################################################

GROVE_REPOS_ORIGIN_SSH="git@github.com:uladkasach/dev-env-setup.git"

grove_provision_5_10_repos_configure_upsert() {
  ####################################################################
  # 0. is there a key at all? without one, no claim below can be true
  #   - it declines rather than fails, since an https origin WORKS
  ####################################################################
  local key_dir="$HOME/.ssh" found="" candidate
  for candidate in id_ed25519 id_ecdsa id_rsa; do
    [[ -f "$key_dir/$candidate" ]] && { found="$candidate"; break; }
  done

  if [[ -z "$found" ]]; then
    ##################################################################
    # ⚠️ this names `2.3.ssh`, never a second apply of this bundle
    #   - `2.3.ssh` runs BEFORE this bundle, so it has ALREADY had its turn
    #   - ⇒ a re-run of THIS bundle meets the same absent key, forever
    #   - (`rule.require.errors-name-the-fix`)
    #
    # .it stays a 🌙 rather than a ✋, though the box IS defective
    #   - `2.3.ssh.configure.verify` already reports the absent key as a ✋
    #   - ⇒ a second ✋ here would be one cause with two claims
    #   - (`rule.require.solve-at-cause`)
    ##################################################################
    echo "   🌙 no ssh key on this box, so the https origin stands"
    echo "      ⇒ a push still prompts for a credential; none of it is broken"
    echo "      ⇒ 2.3.ssh generates one and runs BEFORE this bundle, so an absent"
    echo "        key means THAT bundle did not converge — a re-apply of this one"
    echo "        would find the same absence"
    echo "      fix: rhx grove.provision --what 2.3.ssh --mode apply"
    return 0
  fi

  ####################################################################
  # 1. does github ACCEPT that key? asked, never assumed
  #
  # ⚠️ the exit code is not the answer
  #   - `ssh -T git@github.com` exits 1 on SUCCESS, since github offers no shell
  #   - ⇒ an `if ssh -T …` test reads every healthy box as a failure
  #   - ⇒ the GREETING is the only truthful signal
  #
  # .the probe takes BOTH bounds
  #   - `BatchMode=yes` forbids a passphrase ask, which a duct would eat
  #   - ⚠️ `ConnectTimeout` alone is NOT the bound, and a bare one is a blocker
  #   - it caps a DEAD network, the case that fails anyway
  #   - it says no word about a live host that handshakes and then goes quiet
  #   - ⇒ ssh has no total-time option, so the bound comes from outside
  #   - (`rule.require.bounded-probes-in-verifies`)
  ####################################################################
  local greeting
  greeting="$(timeout -k 5 20 ssh -T -o BatchMode=yes -o ConnectTimeout=5 \
    -o StrictHostKeyChecking=accept-new git@github.com 2>&1)"

  if [[ "$greeting" != *"successfully authenticated"* ]]; then
    ##################################################################
    # ⚠️ this branch SPLITS on whether git already draws from the rack
    #   - on a grove the box's token holds no `admin:public_key`
    #   - ⇒ a `gh ssh-key add` fix names a step that credential may not perform
    #   - on a racked box there is no step to name at all, since git already
    #     reaches github through the keyrack helper
    #   - (`rule.require.errors-name-the-fix`; `_.sh` holds the measurement)
    ##################################################################
    if grove_provision_5_10_repos_https_is_racked; then
      echo "   🌙 github does not accept this box's key, and no step is owed"
      echo "      ⇒ github said: ${greeting%%$'\n'*}"
      echo "      ⇒ git already reaches github through the keyrack helper, so https"
      echo "        here is authorized by a CENTRAL secret, not by one on disk"
      echo "      ⇒ an ssh origin is a laptop concern — the yubikey behind"
      echo "        SSH_AUTH_SOCK; it adds no reach a racked box lacks"
      return 0
    fi

    echo "   🌙 github does not accept this box's key yet, so the https origin stands"
    echo "      ⇒ github said: ${greeting%%$'\n'*}"
    echo "      ⇒ the key exists; github has not been told about it"
    echo "      ⇒ this box CANNOT register it: its token holds 'repo' + 'read:org',"
    echo "        and 'gh ssh-key add' needs 'admin:public_key'. a human with that"
    echo "        scope owes the step — no re-apply of this bundle reaches it"
    echo "      fix: register the public half, from a session that holds the scope —"
    echo "        gh ssh-key add ~/.ssh/$found.pub --title \"\$(hostname)\""
    return 0
  fi
  echo "   • github accepts this box's ssh key ✔"

  ####################################################################
  # 2. every FUTURE clone comes down over ssh
  #
  # .this is the lever that converges the fleet, with no bulk rewrite
  #   - `gh repo clone` reads this config, so the next repo arrives on ssh
  ####################################################################
  if [[ "$(gh config get git_protocol 2>/dev/null)" == "ssh" ]]; then
    echo "   • gh already clones over ssh"
  elif gh config set git_protocol ssh; then
    echo "   • gh declared to clone over ssh"
  else
    echo "   ✋ could not set gh's clone protocol" >&2
    echo "      ⇒ every repo cloned from here keeps an https origin, so each one" >&2
    echo "        needs a credential at push time" >&2
    echo "      read why: gh config set git_protocol ssh" >&2
    return 1
  fi

  ####################################################################
  # 3. this checkout's own origin — the one the bootstrap could not set
  #
  # .git is ASKED where it is, never told a ~/git/more path
  #   - this repo runs from a WORKTREE as often as from the clone
  #   - ⇒ a question to git beats an assertion about the layout
  #   - (`howto.setup-from-worktree`)
  ####################################################################
  local repo_dir="${GROVE_SRC%/src}"
  if ! git -C "$repo_dir" rev-parse --git-dir >/dev/null 2>&1; then
    echo "   🌙 $repo_dir is no git checkout, so it declares no origin"
    echo "      ⇒ this src arrived by 'grove.push', not by clone — expected on a grove"
    return 0
  fi

  local origin
  origin="$(git -C "$repo_dir" remote get-url origin 2>/dev/null || true)"

  if [[ "$origin" == git@github.com:* ]]; then
    echo "   • this checkout already pushes over ssh ✔ ($origin)"
    return 0
  fi

  if [[ -z "$origin" ]]; then
    echo "   🌙 this checkout declares no 'origin', so there is none to repair"
    return 0
  fi

  if git -C "$repo_dir" remote set-url origin "$GROVE_REPOS_ORIGIN_SSH"; then
    echo "   • this checkout's origin moved to ssh ✔"
    echo "     was: $origin"
    echo "     now: $GROVE_REPOS_ORIGIN_SSH"
    echo "     ⇒ the bootstrap clones anonymously over https by necessity; this is"
    echo "       where that gets undone, now that a key exists and github took it"
  else
    echo "   ✋ could not move this checkout's origin to ssh" >&2
    echo "      ⇒ pushes from the repo this human edits most keep asking for a" >&2
    echo "        credential, or lean on a token sat in cleartext on disk" >&2
    echo "      fix: git -C $repo_dir remote set-url origin $GROVE_REPOS_ORIGIN_SSH" >&2
    return 1
  fi
}

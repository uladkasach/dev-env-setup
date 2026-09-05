#!/usr/bin/env bash
######################################################################
# .what = clone every repo of each org in GROVE_GIT_ORGS
#
# guarantee:
#   - a repo that OPENS as a checkout is left alone, never re-cloned
#   - a dir with a `.git` and no readable HEAD is moved aside and re-cloned
#   - ⇒ so one apply converges the box
#   - one repo's failure does not end the org's loop
######################################################################

GROVE_GIT_ORGS_DEFAULT="ehmpathy ahbode whodisio"

grove_provision_5_10_repos_provision_upsert() {
  # .the default holds when the caller stays silent, so a bare call is the case
  #   - (`rule.prefer.defaults-match-common-case`)
  local orgs="${GROVE_GIT_ORGS:-$GROVE_GIT_ORGS_DEFAULT}"
  local cloned=0 present=0 failed=0 quarantined=0

  ####################################################################
  # preflight, so a miss is named once rather than repeated per org
  #   - an absent or unauthed gh is NOT repaired inline: `5.4.gh` owns both
  #   - ⇒ a repair here would give one concern two homes
  #   - (`rule.require.bundle-as-sole-declaration`)
  ####################################################################
  if ! command -v gh >/dev/null 2>&1; then
    echo "   ✋ gh is absent — cannot list org repos" >&2
    echo '      ⇒ the binary is 5.4.gh'"'"'s claim, and this bundle is 5.10 — so gh' >&2
    echo "        should already be here. its provision phase failed above" >&2
    echo "      fix: rhx grove.provision --what 5.4.gh --mode apply" >&2
    return 1
  fi

  # .an unauthed gh fails per-org with an opaque error, so say it once up front
  if ! gh auth status >/dev/null 2>&1; then
    echo "   ✋ gh is present but unauthed — cannot list org repos" >&2
    echo '      ⇒ the credential is 5.4.gh'"'"'s claim; it reads the token from the' >&2
    echo "        rack, and prints the exact 'rhx keyrack set' a human owes when" >&2
    echo "        the rack holds none" >&2
    echo "      fix: rhx grove.provision --what 5.4.gh --mode apply" >&2
    echo "           and do what its ✋ tells you, then re-run this bundle" >&2
    return 1
  fi

  local organization repo into seen
  for organization in $orgs; do
    echo "   ├─ $organization"

    # .read from a process substitution, NOT a pipe
    #   - a piped `while` runs in a subshell, so every count is discarded
    seen=0
    while read -r repo _; do
      [[ -z "$repo" ]] && continue
      seen=$(( seen + 1 ))
      into="$HOME/git/$repo"

      # .`gh repo clone` fails outright on a non-empty dir
      #   - ⇒ without this guard a second run errors once per repo
      #   - (`rule.require.idempotent-install-procedures`)
      #
      # ⚠️ the question is "does this open as a checkout", never "is there a .git"
      #   - 📜 a `-d .git` guard counted a HALF-CLONED dir as done
      #   - ⇒ that made the box unrepairable by any apply
      local state; state="$(grove_provision_5_10_repos_state "$into")"
      if [[ "$state" == whole ]]; then
        present=$(( present + 1 ))
        continue
      fi

      ################################################################
      # a `.git` with no readable HEAD — a clone cut partway
      #
      # 🛑 it is MOVED aside, never deleted
      #   - a half-clone holds no commit, so `rm -rf` would lose no history
      #   - that rm is still unattended and under a human's `$HOME`
      #   - a dir a human dropped files into looks the same from here
      #   - ⇒ a move is reversible, and frees the path just as well
      #
      # ⚠️ the quarantine is NAMED so the space is reclaimable
      #   - every loop here iterates the names `gh repo list` returns
      #   - `<repo>.half.<stamp>` is not one of them, so it is never revisited
      #   - ⇒ silent disk use is its own defect (`rule.forbid.failhide`)
      ################################################################
      if [[ "$state" == half ]]; then
        local aside="$into.half.$(date +%Y%m%dT%H%M%S)"
        if ! mv "$into" "$aside"; then
          failed=$(( failed + 1 ))
          echo "   │  ✋ $repo — half-cloned, and the dir could not be moved aside" >&2
          echo "   │     ⇒ $into holds a .git with no readable HEAD, so no git" >&2
          echo "   │       command opens it and a re-clone cannot use the path" >&2
          echo "   │     read why: ls -ld $into ; touch $into/.probe" >&2
          continue
        fi
        quarantined=$(( quarantined + 1 ))
        echo "   │  • $repo — half-cloned; moved aside, re-clone follows"
        echo "   │    kept at: $aside"
      fi

      # .one repo's failure must not end the org's loop
      #   - a single archived or permission-odd repo must not cost the other 200
      ################################################################
      # 🛑 `GIT_TERMINAL_PROMPT=0`, because a git that cannot authenticate ASKS
      #   - without it git prints `Username for 'https://github.com/…':` and WAITS
      #   - this loop runs ~600 times on a fresh grove
      #   - a duct IS tmux, so that prompt EATS every command sent afterward
      #   - ⇒ the box reads as hung rather than as broken
      #   - 📜 2026-08-15 on grove-ahbode-v20260811, via `git.grove.provision test`:
      #
      #       camper@…:~$ { zsh -ic git -C $HOME/git/ahbode/svc-chat fetch … }
      #       Username for 'https://github.com/ahbode/svc-chat.git':
      #
      #   - ⇒ with the flag, git fails at once and the `else` names the repo
      #   - (`rule.forbid.tty-as-a-proxy-for-a-human`, `rule.prefer.prevent-over-correct`)
      #
      # ⚠️ this guarantee is duplicated here, deliberately
      #   - `src/grove.web.sh`'s `git_clone` carries it for every other caller
      #   - this call cannot use it, since `gh` picks the org and the protocol
      #   - `prove.git-never-prompts` clamps the copies
      #
      # ⚠️ `</dev/null` is NOT a second floor for this
      #   - git opens `/dev/tty` DIRECTLY, so a closed stdin cannot stop the ask
      #   - ⇒ the redirect stays only because `gh`'s children may read stdin
      ################################################################
      if GIT_TERMINAL_PROMPT=0 gh repo clone "$repo" "$into" </dev/null; then
        cloned=$(( cloned + 1 ))
      else
        failed=$(( failed + 1 ))
        echo "   │  ✋ $repo — clone failed; the rest carry on" >&2
      fi
    done < <(gh repo list "$organization" --limit 1000)

    # .the cap truncates in silence, so say so rather than under-clone quietly
    if [[ "$seen" -ge 1000 ]]; then
      echo "   │  ✋ $organization hit the 1000-repo cap — some repos were not seen" >&2
    fi
  done

  echo "   └─ cloned: $cloned, already present: $present, failed: $failed"

  # ⚠️ named on its own line, and only when it happened
  #   - a quarantine is bytes a human may reclaim, invisible to every later run
  #   - ⇒ the run that made it is the only one that can report it
  if [[ "$quarantined" -gt 0 ]]; then
    echo "      ⇒ $quarantined half-cloned dir(s) were moved aside and re-cloned."
    echo "        each is kept at '<repo>.half.<stamp>' beside its repo — they hold"
    echo "        no commit, so they are safe to remove once you have looked"
  fi

  ####################################################################
  # ⚠️ a FULL DISK wears the exact costume of N unlucky repos
  #   - the per-repo tolerance above is right, and it prints one ✋ per repo
  #   - ⇒ no part of that report says "disk", so a human hunts the credentials
  #   - it is a HINT beside the ✋, never a claim, since disk is one cause of many
  #   - ⇒ an assertion would cry wolf on the common single-archived-repo case
  #   - (`gotcha.a-check-that-cries-wolf-gets-silenced`)
  ####################################################################
  if [[ "$failed" -gt 0 ]]; then
    local avail
    avail="$(df -h --output=avail "$HOME" 2>/dev/null | tail -1 | tr -d ' ')"
    echo "      ⇒ $failed clone(s) failed. free space on \$HOME: ${avail:-unknown}" >&2
    echo "        a full disk fails EVERY clone one at a time, so it reads here as" >&2
    echo "        many unlucky repos rather than as one cause — read the space" >&2
    echo "        first, before you suspect a credential" >&2
  fi

  [[ "$failed" -eq 0 ]]
}

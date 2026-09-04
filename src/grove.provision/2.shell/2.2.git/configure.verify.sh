#!/usr/bin/env bash
######################################################################
# .what = prove git holds an identity, both safety defaults, and every alias
#
# .why the identity is asserted and not merely reported
#   - git refuses to commit with either half absent
#   - ⇒ an unconfigured identity is a box that cannot do the work it exists for
#   - the failure arrives at commit time, far from here
#
# .why each ALIAS is checked by name rather than by a count
#   - a count would pass on the wrong ten aliases
#   - an absent `git tree` reads as "the worktree command is broken"
#   - ⇒ never as "an alias was never written"
#
# .why the delegates' FILE is not checked here, but their TARGET is
#   - `git tree` expands to a line that sources `~/.bash_aliases`
#   - whether that FILE exists is `2.7.aliases`'s claim, and its own verify makes it
#   - ⇒ to assert it here would give one fact two verdicts
#   - whether the alias names a DEFINED function is a third fact
#   - it belongs to neither bundle by default
#   - 📜 both verifies stay green while `git tree` fails, because each points at the other
#
# guarantee:
#   - READ-ONLY. it reads git's config and repairs no state
#
# exit:
#   0 = identity, defaults, and every alias present
#   1 = a claim failed, and which is named
######################################################################

grove_provision_2_2_git_configure_verify() {
  local failed=0

  ####################################################################
  # ⚠️ the IDENTITY is claimed by `5.15.identity`, never here
  #   - the credential arrives in section 5
  #   - ⇒ a ✋ here would be red on every new grove's first apply
  #   - a 🌙 branch would ENCODE that defect of order rather than remove it
  #   - the claim could never be made on a first apply
  #   - `rule.require.one-command-provision` allows only one
  #   - ⇒ a verify whose verdict depends on where its bundle sits is in the wrong bundle
  #   - it belongs with its upsert, where gh is authed and an absence reads one way
  ####################################################################

  ####################################################################
  # 1. the two defaults whose stock values have cost real work
  ####################################################################
  local ff branch
  ff="$(git config --global pull.ff 2>/dev/null || true)"
  branch="$(git config --global init.defaultBranch 2>/dev/null || true)"

  if [[ "$ff" == "only" ]]; then
    echo "   • pull.ff = only ✔"
  else
    echo "   ✋ pull.ff is '$ff', not 'only'" >&2
    echo "      ⇒ a stock 'git pull' on a diverged branch makes a merge commit" >&2
    echo "        nobody asked for, which then has to be rebased out" >&2
    failed=$(( failed + 1 ))
  fi

  if [[ "$branch" == "main" ]]; then
    echo "   • init.defaultBranch = main ✔"
  else
    echo "   ✋ init.defaultBranch is '$branch', not 'main'" >&2
    echo "      ⇒ a fresh repo would be born on a branch that matches no remote" >&2
    echo "        and no ci workflow here" >&2
    failed=$(( failed + 1 ))
  fi

  ####################################################################
  # 2. every alias, by name — and every DELEGATE names a DEFINED function
  #
  # ⚠️ the delegate's TARGET is judged here, though the FILE is 2.7's claim
  #   - the body belongs to `2.7.aliases`, and that is true of the FILE
  #   - it is not true of the SEAM between them
  #   - 📜 2026-07-30:
  #
  #       2.2.git     asserts `git config --get alias.tree` succeeds     → ✔
  #       2.7.aliases asserts the file is present, current, and parses   → ✔
  #
  #   - rename `git_alias_tree` in `bash_aliases.sh` and BOTH stay green
  #   - the config still holds the alias, and the file still parses and matches
  #   - yet `git tree` answers `git_alias_tree: command not found`
  #   - ⇒ "this alias names a defined function" was a claim NO bundle owned
  #   - each verify pointed at the other
  #   - (rule.require.identical-bundle-composition, `.two lists drift`)
  #
  # .why it belongs HERE rather than in 2.7.aliases
  #   - the alias is 2.2's artifact, so "my handle names a defined function" is 2.2's claim
  #   - the FILE stays 2.7's, so an absence reports 🌙 here and ✋ there
  #
  # .why the function name is EXTRACTED from the alias value, never listed again
  #   - a hand-kept roster would be a THIRD copy, beside the upsert's and this loop's
  #   - the alias value already names its function
  #   - ⇒ it is read rather than restated
  ####################################################################
  local aliases_file="$HOME/.bash_aliases"
  local alias_name value fn
  local absent=() undefined=()
  local delegates=0

  for alias_name in lg root recommit shove release tree grove grab graft backup; do
    if ! value="$(git config --global --get "alias.$alias_name" 2>/dev/null)"; then
      absent+=("$alias_name")
      continue
    fi

    # a delegate names a shell function; the four pure-git aliases name none
    [[ "$value" =~ (git_alias_[a-z_]+) ]] || continue
    fn="${BASH_REMATCH[1]}"
    delegates=$(( delegates + 1 ))

    # the file's own presence is 2.7.aliases's verdict — see the ⚠️ above
    [[ -f "$aliases_file" ]] || continue

    # ⚠️ grep reads the FILE directly and sits in no pipeline
    #   - ⇒ `-q`'s early exit SIGPIPEs no producer and pipefail reads no 141
    #   - (gotcha.pipefail-grep-q)
    grep -qE "^${fn}\(\)" "$aliases_file" || undefined+=("$alias_name → $fn")
  done

  if [[ "${#absent[@]}" -eq 0 ]]; then
    echo "   • all 10 git aliases declared ✔"
  else
    echo "   ✋ a git alias is ABSENT: ${absent[*]}" >&2
    echo "      ⇒ each absence reads as a broken command rather than as an" >&2
    echo "        unwritten alias — 'git tree' returns 'tree is not a git command'" >&2
    echo "      fix: rhx grove.provision --what 2.2.git --mode apply" >&2
    failed=$(( failed + 1 ))
  fi

  if [[ "${#undefined[@]}" -gt 0 ]]; then
    echo "   ✋ a git alias names a function that is NOT defined: ${undefined[*]}" >&2
    echo "      ⇒ the alias exists, so git accepts the command and THEN fails with" >&2
    echo "        'git_alias_x: command not found' — which reads as a broken tool," >&2
    echo "        never as a handle whose body was renamed out from under it" >&2
    echo "      ⇒ ~/.bash_aliases is present and parses, so 2.7.aliases is green;" >&2
    echo "        this seam is the one thing only this bundle can see" >&2
    echo "      fix: define it in 2.7.aliases's bash_aliases.sh, or drop the alias from" >&2
    echo "        2.2.git/configure.upsert.sh — the two must name one set" >&2
    failed=$(( failed + 1 ))
  elif [[ ! -f "$aliases_file" ]]; then
    echo "   🌙 whether the $delegates delegates are defined cannot be observed —"
    echo "      no ~/.bash_aliases to read. that absence is 2.7.aliases's ✋"
  else
    echo "   • all $delegates delegates name a defined function ✔"
  fi

  ####################################################################
  # 3. the credential helper — declared, CURRENT, and named by full path
  #
  # ⚠️ .why three checks and not one
  #   - each can be true while the others are false
  #   - each failure reads to a human as "git cannot authenticate"
  #   - one symptom, three different repairs:
  #
  #       config only   → git looks for `git-credential-keyrack` and finds none
  #       file only     → git never runs it, because no config names it
  #       stale file    → it runs, and reads a slug this repo no longer declares
  #
  #   - the third is the one a presence test cannot see
  #   - ⇒ a copied asset must be DIFFED against the checkout
  #   - otherwise a verify green-lights a box on last week's logic
  #   - (rule.require.upgrade-entries-verify-themselves)
  ####################################################################
  local helper_src="$GROVE_SRC/grove.provision/2.shell/2.2.git/git-credential-keyrack.sh"
  local helper_dst="$HOME/.local/bin/git-credential-keyrack"
  local helper_cfg
  helper_cfg="$(git config --global --get credential."https://github.com".helper 2>/dev/null || true)"

  if [[ "$helper_cfg" != "$helper_dst" ]]; then
    echo "   ✋ git names no keyrack credential helper for github (got '${helper_cfg:-（unset）}')" >&2
    echo "      ⇒ expected the ABSOLUTE path: $helper_dst" >&2
    echo "      ⇒ https git falls back to a prompt, or to an exported token that" >&2
    echo "        dies with its shell — neither of which a bundle reproduces" >&2
    echo "      ⇒ a bare 'keyrack' makes git hunt PATH for it, so the helper" >&2
    echo "        answers a human's shell and vanishes for ssh, cron, and every" >&2
    echo "        suite (see the upsert's ⚠️)" >&2
    echo "      fix: rhx grove.provision --what 2.2.git --mode apply" >&2
    failed=$(( failed + 1 ))
  elif [[ ! -x "$helper_dst" ]]; then
    echo "   ✋ git names the keyrack helper, but no executable answers to it" >&2
    echo "      ⇒ expected: $helper_dst" >&2
    echo "      ⇒ git reports only that it could not authenticate; it never says" >&2
    echo "        that the helper it was told to run is absent" >&2
    echo "      fix: rhx grove.provision --what 2.2.git --mode apply" >&2
    failed=$(( failed + 1 ))
  elif [[ -f "$helper_src" ]] && ! cmp -s "$helper_src" "$helper_dst"; then
    echo "   ✋ the installed credential helper DIFFERS from the checkout" >&2
    echo "      ⇒ $helper_dst" >&2
    echo "      ⇒ it runs, so git authenticates — with whatever slug the STALE" >&2
    echo "        copy names. a wrong slug reads as an empty rack, never as an" >&2
    echo "        out-of-date file" >&2
    echo "      fix: rhx grove.provision --what 2.2.git --mode apply" >&2
    failed=$(( failed + 1 ))
  else
    ####################################################################
    # 🛑 there is no FOURTH claim, and "…and on PATH" may not become one
    #   - the config names the ABSOLUTE path (see the upsert's ⚠️)
    #   - ⇒ no PATH can hide the helper, and there is no fourth fact to read
    #   - ⚠️ a `command -v git-credential-keyrack` would be SELF-REFERENTIAL
    #   - it reads the PATH of whatever shell runs the verify
    #   - never the PATH of the shell that will run git
    #   - 📜 it reported ✋ over the duct and ✔ from a terminal, one box, one minute
    #   - ⇒ a verdict about the CALLER, dressed as a verdict about the box
    ####################################################################
    echo "   • git credential helper declared, current, and named by full path ✔"
  fi

  [[ "$failed" -eq 0 ]] || return 1
}

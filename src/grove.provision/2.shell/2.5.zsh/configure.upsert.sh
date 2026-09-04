#!/usr/bin/env bash
######################################################################
# .what = put this repo's zshrc on the box, as `~/.zshrc`
#
# .why the source is `$GROVE_SRC` and not a hardcoded home path
#   - 📜 a `${DEV_ENV_SETUP_DIR:-$HOME/git/more/dev-env-setup}` default is WRONG in a worktree
#   - it copied MAIN's zshrc while the run came from `_worktrees/…`
#   - ⇒ a pushed branch's change under test never landed
#   - the symptom is "my edit had no effect", which reads as a broken rc
#   - `$GROVE_SRC` is the run's own checkout, derived once by the root dispatch
#   - ⇒ every bundle that copies a checked-in file reads one answer
#
# .why the rc is OVERWRITTEN rather than merged
#   - `src/zshrc.sh` is the whole declaration
#   - a merge leaves a past revision's line beside its replacement
#   - zsh takes the LAST assignment
#   - ⇒ the live shell would depend on read order rather than on this repo
#   - (rule.require.judge-declared-state-not-live-state)
#
# .note = the copy takes effect on the NEXT shell
#   - no reload is attempted here
#   - a `source ~/.zshrc` from a bash run would fail on zsh syntax, or half-apply
#   - this run's own shell is not the one the human is about to use
#
# guarantee:
#   - idempotent: one copy of one file, so a re-run converges
######################################################################

grove_provision_2_5_zsh_configure_upsert() {
  local bundle_dir="$GROVE_SRC/grove.provision/2.shell/2.5.zsh"
  local rc_src="$bundle_dir/zshrc.sh"

  if [[ ! -f "$rc_src" ]]; then
    echo "   ✋ no zshrc to copy at $rc_src" >&2
    echo "      ⇒ \$GROVE_SRC is this run's own checkout, so an absent file here" >&2
    echo "        means the checkout is incomplete rather than that the path is" >&2
    echo "        wrong" >&2
    echo "      fix: confirm the checkout is complete, or re-push the worktree" >&2
    return 1
  fi

  if ! cp "$rc_src" "$HOME/.zshrc"; then
    echo "   ✋ could not write ~/.zshrc" >&2
    echo "      ⇒ the shell keeps its PRIOR rc, so this run's declaration sits in" >&2
    echo "        the checkout with no effect — and a reader who opens a new shell" >&2
    echo "        sees the old behavior with no error to explain it" >&2
    return 1
  fi

  echo "   • zshrc declared (~/.zshrc — open a new shell to load it)"

  ####################################################################
  # ~/.zshenv — the env that must reach EVERY zsh
  #
  # ⚠️ .why this is a SECOND file and not more lines in the rc
  #   - zsh sources `~/.zshrc` for INTERACTIVE shells only
  #   - it sources `~/.zshenv` for every invocation
  #   - ⇒ an env pointer a PROGRAM must read has to be in the second
  #   - `zsh -c`, `sg docker -c`, an npm run, and jest never open the rc
  #   - 📜 grove-1 2026-08-06: `AWS_PROFILE=ambient` sat in ~/.zshrc
  #   - the integration suite still died `AWS_PROFILE not set`
  #   - the export was correct, readable by a human's shell, and absent from the shell that needed it
  #
  # 📜 that measurement stands and its FIX did not
  #   - `AWS_PROFILE` moved here 2026-08-06 and was removed entirely 2026-08-08
  #   - keyrack checks `os.envvar` FIRST
  #   - ⇒ one exported value outranked every rack entry and pinned all four envs to `ambient`
  #   - what this file still carries is `AWS_SDK_LOAD_CONFIG=1`
  #   - a program genuinely must read that from a non-interactive shell
  #   - see `src/zshenv.sh`'s own 📜 block
  ####################################################################
  local env_src="$bundle_dir/zshenv.sh"

  if [[ ! -f "$env_src" ]]; then
    echo "   ✋ no zshenv to copy at $env_src" >&2
    echo "      ⇒ a non-interactive zsh would carry none of the env a program" >&2
    echo "        reads, and the failure lands in that program rather than here" >&2
    return 1
  fi

  if ! cp "$env_src" "$HOME/.zshenv"; then
    echo "   ✋ could not write ~/.zshenv" >&2
    return 1
  fi

  echo "   • zshenv declared (~/.zshenv — read by EVERY zsh, interactive or not)"
}

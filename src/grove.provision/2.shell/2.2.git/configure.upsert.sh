#!/usr/bin/env bash
# .what = declare git's two safety defaults and the alias suite this repo's
#   own workflow is built on
# .why the IDENTITY belongs to `5.15.identity`, never to this phase — it
#   derives from this box's github credential, which `5.4.gh` wires three
#   sections later, so here it could never converge on a first apply
# .why `pull.ff only` and `init.defaultBranch main` live here — a stock
#   `pull` creates a merge commit on a diverged branch, and a stock `init`
#   names the branch `master` while every remote here expects `main`
# .why the aliases delegate to `~/.bash_aliases` — `git tree`/`grab`/`grove`
#   are hundreds of lines each, and a git alias is a single-line config
#   value, so the body lives in the shell file `2.7.aliases` installs
#
# guarantee:
#   - idempotent: every line sets one `git config --global` key, so a re-run overwrites

grove_provision_2_2_git_configure_upsert() {
  # 🛑 an outcome is CARRIED in a variable, never returned early — this phase
  #   declares twelve things, and an early `return 1` would report unrelated
  #   declarations as failed rather than as skipped by this function's own exit
  local failed=0

  # 1. the two defaults whose stock values have cost real work
  # a stock `git pull` on a diverged branch makes a merge commit nobody asked for
  git config --global pull.ff only
  # every remote here expects `main`; git's stock `master` matches no upstream
  git config --global init.defaultBranch main
  echo "   • git defaults declared (pull.ff=only, init.defaultBranch=main)"

  # 2. the alias suite — the first four are pure git; the rest delegate into
  #   `~/.bash_aliases`, whose body `2.7.aliases` declares
  # a log one reader can scan: hash, date, author, refs, subject
  git config --global alias.lg "log --pretty=format:'%C(yellow)%h %Cred%ad %C(cyan)%an%Cgreen%d %Creset%s' --date=short"
  # e.g. `cd $(git root)` from any depth in a repo
  git config --global alias.root 'rev-parse --show-toplevel'
  # amend in place with no editor — for a fix to the commit just made
  git config --global alias.recommit 'commit --amend --no-edit'
  # a force-push that refuses to clobber a commit this box has not seen
  git config --global alias.shove 'push origin HEAD --force-with-lease'

  # the compound aliases: each sources ~/.bash_aliases and calls its function,
  # so the logic has ONE home; `--` ends bash's option list so `$@` reaches it
  git config --global alias.release '!bash -c "source ~/.bash_aliases && git_alias_release \"\$@\"" --'
  git config --global alias.tree    '!bash -c "source ~/.bash_aliases && git_alias_tree \"\$@\"" --'
  git config --global alias.grove   '!bash -c "source ~/.bash_aliases && git_alias_grove \"\$@\"" --'
  git config --global alias.grab    '!bash -c "source ~/.bash_aliases && git_alias_grab \"\$@\"" --'
  git config --global alias.graft   '!bash -c "source ~/.bash_aliases && git_alias_graft \"\$@\"" --'
  git config --global alias.backup  '!bash -c "source ~/.bash_aliases && git_alias_backup \"\$@\"" --'

  echo "   • git aliases declared (lg, root, recommit, shove + 6 delegates)"

  # 3. the credential helper — so plain https git draws from the RACK. lives
  #   here, not in `5.4.gh` (which authenticates the `gh` CLI, a different
  #   consumer); may be declared 40 bundles before keyrack exists because it
  #   is a FILE, needs no rack to be placed, and reads the rack only when git
  #   runs it — with rhx absent it DECLINES (exit 0, empty stdout), so git
  #   falls through to its next option rather than failing every public clone
  local helper_src="$GROVE_SRC/grove.provision/2.shell/2.2.git/git-credential-keyrack.sh"
  local helper_dst="$HOME/.local/bin/git-credential-keyrack"

  if [[ ! -f "$helper_src" ]]; then
    echo "   ✋ the credential helper is absent from the checkout" >&2
    echo "      ⇒ expected: $helper_src" >&2
    echo "      ⇒ without it, https git falls back to a prompt or an exported" >&2
    echo "        token, neither of which any bundle reproduces" >&2
    failed=1
  else
    mkdir -p "$HOME/.local/bin"
    if cp "$helper_src" "$helper_dst" && chmod +x "$helper_dst"; then
      # named by ABSOLUTE PATH, never the bare word `keyrack` — a bare name
      # makes the helper's reach a property of the CALLER'S SHELL, and a
      # rename of the file breaks this silently unless verify diffs it
      # .refs = gotcha.2-2-git.demo=credential-helper-by-absolute-path, m1
      git config --global credential."https://github.com".helper "$helper_dst"

      # useHttpPath puts `path=org/repo.git` in the block git feeds the
      # helper — phase 2 reads the org from it (`${path%%/*}`); phase 1 ignores it
      git config --global credential."https://github.com".useHttpPath true

      echo "   • git credential helper declared (https://github.com → keyrack)"
    else
      echo "   ✋ could not install the credential helper to $helper_dst" >&2
      echo "      ⇒ https git cannot reach the rack until it lands" >&2
      failed=1
    fi
  fi

  # the helper is the only part above that depends on a checked-in file, so
  # it is the only part that can have failed; the twelve declarations land either way
  return $failed
}

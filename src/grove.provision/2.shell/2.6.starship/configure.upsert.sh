#!/usr/bin/env bash
# .what = put this repo's starship config at ~/.config/starship.toml
# .why the binary draws a DEFAULT prompt with no config — no git-state colors,
#   no truncated path, none of the layout every other box shows
# .why a copy, not a symlink — the copy's DIRECTION satisfies
#   `rule.require.repo-as-source-of-truth`; a symlink would make the live
#   prompt follow whatever branch the worktree sits on
# .why the source is `$GROVE_SRC`, never a `${DEV_ENV_SETUP_DIR:-…}` default —
#   a worktree raises the box to ITS OWN config, and a defaulted var installs
#   main's file instead, and the copy still exits 0
#   .refs = gotcha.2-6-starship.demo=worktree-source-and-parse-check, m1
#
# guarantee:
#   - idempotent: the copy converges; a second run leaves the same bytes

grove_provision_2_6_starship_configure_upsert() {
  local src="$GROVE_SRC/grove.provision/2.shell/2.6.starship/starship.toml"

  if [[ ! -f "$src" ]]; then
    echo "   ✋ the checkout has no starship.toml" >&2
    echo "      ⇒ \$GROVE_SRC is this run's own checkout, so an absent file here" >&2
    echo "        means the checkout is incomplete rather than that the path is" >&2
    echo "        wrong (looked in: $GROVE_SRC)" >&2
    echo "      fix: git.repo.pull   # or re-push the worktree to this box" >&2
    return 1
  fi

  mkdir -p "$HOME/.config"
  cp "$src" "$HOME/.config/starship.toml"
  echo "   • starship.toml upgraded from $GROVE_SRC"

  grove_provision_2_6_starship_bashrc_upsert
}

# .what = findsert the starship init into ~/.bashrc, by marker
# .why zsh is served by `2.5.zsh/zshrc.sh`, which that bundle byte-owns. a BASH
#   terminal — a pane a tmux server opened before the login shell became zsh, or a
#   human who types `bash` — read only ~/.bashrc and drew a bare `user@host:~$`
#   (📜 2026-11-20, a hetzner grove). no bundle byte-owns ~/.bashrc
#   (`4.3.1.terminfo` findserts there the same way), so a marked block is the one seam
# .why the full path: a non-login bash (a tmux pane) may hold no ~/.local/bin on PATH
GROVE_STARSHIP_BASHRC_MARKER="# grove.provision:2.6.starship"
grove_provision_2_6_starship_bashrc_upsert() {
  local rc="$HOME/.bashrc"
  [[ -f "$rc" ]] || : >"$rc" || { echo "   💥 MalfunctionError: could not make $rc" >&2; return 1; }
  if grep -qF "$GROVE_STARSHIP_BASHRC_MARKER" "$rc"; then
    echo "   • ~/.bashrc already inits starship — no work"
    return 0
  fi
  cat >>"$rc" <<'EOF' || { echo "   💥 MalfunctionError: could not append the starship init to $rc" >&2; return 1; }

# grove.provision:2.6.starship
# .what — the starship prompt in an interactive bash, as zshrc does for zsh
[[ $- == *i* && -t 1 && -x "$HOME/.local/bin/starship" ]] && eval "$("$HOME/.local/bin/starship" init bash)"
EOF
  echo "   • ~/.bashrc — starship init appended ✔ (the next bash reads it)"
}

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
}

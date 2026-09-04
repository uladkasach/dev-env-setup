#!/usr/bin/env bash
# .what = put this repo's pqivrc at ~/.config/pqivrc
# .why a copy, not a symlink — the copy's DIRECTION satisfies
#   `rule.require.repo-as-source-of-truth`
# .why the source is `$GROVE_SRC`, never a hardcoded main checkout — a
#   worktree raises the box to ITS OWN config
#
# guarantee:
#   - idempotent: the copy converges; a second run leaves the same bytes

grove_provision_4_6_pqiv_configure_upsert() {
  local src="$GROVE_SRC/grove.provision/4.terminal/4.6.pqiv/pqivrc"

  if [[ ! -f "$src" ]]; then
    echo "   ✋ the checkout has no pqivrc" >&2
    echo "      ⇒ \$GROVE_SRC is this run's own checkout, so an absent file here" >&2
    echo "        means the checkout is incomplete (looked in: $GROVE_SRC)" >&2
    echo "      fix: git.repo.pull   # or re-push the worktree to this box" >&2
    return 1
  fi

  mkdir -p "$HOME/.config"
  cp "$src" "$HOME/.config/pqivrc"
  echo "   • pqivrc upgraded from $GROVE_SRC"
}

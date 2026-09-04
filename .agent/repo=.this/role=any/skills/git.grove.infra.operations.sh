#!/usr/bin/env bash
######################################################################
# git.grove.infra.operations — shared lookup for the infra-owned grove skills
#
# .what = find the ahbode/infrastructure checkout that owns the grove
#         lifecycle skills (wake, stop, auth), so a thin forwarder in this
#         repo can invoke them with that repo as cwd.
#
# .why  = wake/stop are NOT copyable. each is a bash front over a
#         declastruct WISH (`git.grove.wake.ts`) that imports
#         declastruct-aws + declastruct-unix-network, and `npx declastruct`
#         looks those up from the cwd's node_modules. this repo declares
#         none of them, so a copied skill dies on import and a symlinked one
#         dies on the npx lookup. worse, git.grove.auth reads a
#         repo-relative wish (provision/aws.infra/account=camp/...) that
#         only exists there.
#
#         so the boundary holds: infra OWNS the lifecycle (it owns the
#         wishes, the camp account guard, and the aws deps); this repo
#         FORWARDS to it. one source of truth, no drift, no vendored copy
#         to fall out of date.
#
# .note = this file is sourced, never executed.
######################################################################

# .what = look up the infrastructure checkout that holds the grove skills
# .why  = a forwarder needs the repo's root as cwd, so `npx declastruct` finds
#         its deps and its repo-relative wish paths still land
_git_grove_infra_dir() {
  # an explicit override always wins, so a human can point at any checkout
  if [[ -n "${GROVE_INFRA_DIR:-}" ]]; then
    echo "$GROVE_INFRA_DIR"
    return 0
  fi

  # otherwise search the paved spots, worktrees included (a worktree is where
  # in-flight infra work lives, so prefer whichever actually holds the skill)
  local candidate
  for candidate in \
    "$HOME/git/ahbode/infrastructure" \
    "$HOME"/git/ahbode/_worktrees/infrastructure.*; do
    if [[ -f "$candidate/.agent/repo=.this/role=any/skills/git.grove.wake.sh" ]]; then
      echo "$candidate"
      return 0
    fi
  done

  return 1
}

# .what = forward a grove lifecycle command into the infra checkout
# .why  = every forwarder does the same three moves — look up the repo, fail
#         loud with the fix when absent, then run the skill with that repo as
#         cwd. kept here so the forwarders stay one line of intent each
# usage: _git_grove_infra_forward <skill-name> [args...]
_git_grove_infra_forward() {
  local skill="${1:-}"; shift 2>/dev/null || true

  local dir
  if ! dir="$(_git_grove_infra_dir)"; then
    echo "🐢 bummer dude — cannot find the infrastructure checkout" >&2
    echo "" >&2
    echo "  why: $skill is owned by ahbode/infrastructure, which holds the" >&2
    echo "       declastruct wish and the aws deps it needs. this repo forwards" >&2
    echo "       to it rather than vendor a copy that would drift" >&2
    echo "  fix: clone it beside your other ahbode repos —" >&2
    echo "    git clone git@github.com:ahbode/infrastructure.git ~/git/ahbode/infrastructure" >&2
    echo "  or point at an extant checkout —" >&2
    echo "    GROVE_INFRA_DIR=/path/to/infrastructure rhx $skill ..." >&2
    return 2
  fi

  local entry="$dir/.agent/repo=.this/role=any/skills/$skill.sh"
  if [[ ! -f "$entry" ]]; then
    echo "🐢 bummer dude — $skill is absent from the infrastructure checkout" >&2
    echo "" >&2
    echo "  looked in: $entry" >&2
    echo "  fix: pull the latest infra main, which carries the grove skills —" >&2
    echo "    git -C $dir pull" >&2
    return 2
  fi

  # run with the infra repo as cwd so `npx declastruct` finds its deps there,
  # and its repo-relative wish paths (provision/aws.infra/...) still land
  ( cd "$dir" && bash "$entry" "$@" )
}

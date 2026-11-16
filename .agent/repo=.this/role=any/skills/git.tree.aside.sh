#!/usr/bin/env bash
######################################################################
# .what = set a tree's uncommitted edits aside under a tag, then lay them back
#
# .why
#   - `git.branch.rebase begin` refuses a tree with unstaged edits, and a tree
#     often holds edits that belong to no commit (a machine's settings, a lock)
#   - a bare `git stash` / `git stash pop` is unsafe here: every worktree shares
#     one stash stack, so a pop can take another session's entry
#   - so this skill holds the entry by its SHA, never by its stack position
#
# usage:
#   rhx git.tree.aside set --tag <tag> --path <file> [--path <file> …]
#   rhx git.tree.aside get --tag <tag>     # lay the edits back, then drop the entry
#   (verbs are set|get: a bare `list` is rhx's own command)
#   rhx git.tree.aside get                 # every entry this skill holds
#
# guarantee:
#   - set stores only the paths named; refuses a tag already held, exit 2
#   - get applies by sha (a 3-way apply, so edits made since survive), and drops
#     the entry only after the apply succeeds; a conflict keeps the entry, exit 1
#   - every entry's message starts `tree.aside:`, so a bare get shows no foreign entry
######################################################################
set -uo pipefail

PREFIX='tree.aside:'

usage() {
  echo "git.tree.aside — set a tree's uncommitted edits aside under a tag, then lay them back"
  echo ""
  echo "usage:"
  echo "  rhx git.tree.aside set --tag <tag> --path <file> [--path <file> …]"
  echo "  rhx git.tree.aside get --tag <tag>"
  echo "  rhx git.tree.aside get                 # every entry held"
}

if [[ " $* " == *" help "* || " $* " == *" --help "* || " $* " == *" -h "* ]]; then
  usage
  exit 0
fi

git rev-parse --show-toplevel >/dev/null 2>&1 || {
  echo "✋ ConstraintError: no git repo here" >&2
  exit 2
}

# the verb is the one bare word, wherever it sits: rhachet injects its own flags first
VERB=""
TAG=""
PATHS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --tag)  TAG="${2:-}"; shift 2 ;;
    --path) PATHS+=("${2:-}"); shift 2 ;;
    # rhachet injects these three into every skill it runs
    --skill|--repo|--role) shift 2 ;;
    set|get) [[ -z "$VERB" ]] || { echo "✋ ConstraintError: name one verb" >&2; exit 2; }
             VERB="$1"; shift ;;
    *) echo "✋ ConstraintError: unknown argument '$1'" >&2
       echo "   └─ see: rhx git.tree.aside --help" >&2; exit 2 ;;
  esac
done

# .what = print the sha of the entry that holds this tag, or naught
sha_of_tag() {
  git stash list --format='%H %gs' | while read -r sha subject; do
    [[ "$subject" == *"$PREFIX $1" ]] && { echo "$sha"; break; }
  done
}

echo "🐢 lets set it aside..."
echo ""

case "$VERB" in
  set)
    [[ -n "$TAG" ]] || { echo "✋ ConstraintError: set needs --tag" >&2; exit 2; }
    [[ "${#PATHS[@]}" -gt 0 ]] || { echo "✋ ConstraintError: set needs at least one --path" >&2; exit 2; }
    [[ -z "$(sha_of_tag "$TAG")" ]] || {
      echo "✋ ConstraintError: tag '$TAG' is already held" >&2
      echo "   └─ lay it back first: rhx git.tree.aside get --tag $TAG" >&2
      exit 2
    }
    git stash push -m "$PREFIX $TAG" -- "${PATHS[@]}" >/dev/null || {
      echo "💥 MalfunctionError: git stash push refused the paths" >&2; exit 1; }
    sha="$(sha_of_tag "$TAG")"
    [[ -n "$sha" ]] || { echo "💥 MalfunctionError: the entry for '$TAG' did not land" >&2; exit 1; }
    echo "🐚 git.tree.aside set --tag $TAG"
    echo "   ├─ sha: $sha"
    echo "   └─ paths"
    for i in "${!PATHS[@]}"; do
      glyph="├─"; [[ "$i" -eq $(( ${#PATHS[@]} - 1 )) ]] && glyph="└─"
      echo "      $glyph ${PATHS[$i]}"
    done
    ;;

  get)
    if [[ -z "$TAG" ]]; then
      echo "🐚 git.tree.aside get"
      held="$(git stash list --format='%H %gs' | while read -r sha subject; do
        [[ "$subject" == *"$PREFIX "* ]] && echo "$sha ${subject##*"$PREFIX "}"
      done)"
      [[ -n "$held" ]] || { echo "   └─ (none held)"; exit 0; }
      echo "$held" | while read -r sha tag; do echo "   ├─ $tag ($sha)"; done
      exit 0
    fi
    sha="$(sha_of_tag "$TAG")"
    [[ -n "$sha" ]] || {
      echo "✋ ConstraintError: no entry holds tag '$TAG'" >&2
      echo "   └─ see what is held: rhx git.tree.aside list" >&2
      exit 2
    }
    git stash apply "$sha" >/dev/null || {
      echo "💥 MalfunctionError: the apply of '$TAG' ($sha) hit a conflict" >&2
      echo "   ├─ the entry is KEPT, so no edit is lost" >&2
      echo "   └─ settle the conflict, then: rhx git.tree.aside get --tag $TAG" >&2
      exit 1
    }
    # re-find the stack position by sha at drop time; another session may have moved it
    ref="$(git stash list --format='%gd %H' | while read -r gd h; do [[ "$h" == "$sha" ]] && { echo "$gd"; break; }; done)"
    [[ -n "$ref" ]] && git stash drop "$ref" >/dev/null
    echo "🐚 git.tree.aside get --tag $TAG"
    echo "   ├─ sha: $sha"
    echo "   └─ laid back, entry dropped"
    ;;

  *)
    echo "✋ ConstraintError: name a verb: set or get" >&2
    usage >&2
    exit 2
    ;;
esac

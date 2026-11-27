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
#     the entry only after the apply succeeds; a conflict keeps the entry, exit 2
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

# .what = refuse with a constraint, and point at the help
refuse() {
  echo "✋ ConstraintError: $1" >&2
  echo "   └─ ${2:-see: rhx git.tree.aside --help}" >&2
  exit 2
}

# .what = the glyph a tree row takes: └─ for the last of $2 rows, ├─ for the rest
tree_glyph() { [[ "$1" -eq $(( $2 - 1 )) ]] && printf '└─' || printf '├─'; }

git rev-parse --show-toplevel >/dev/null 2>&1 \
  || refuse "no git repo here" "run it from inside the repo whose tree it is"

# the verb is the one bare word, wherever it sits: rhachet injects its own flags first
VERB=""
TAG=""
PATHS=()
while [[ $# -gt 0 ]]; do
  # a value flag with no value refuses: `shift 2` past the last arg shifts naught,
  # so the loop would read the same flag forever
  [[ "$1" =~ ^--(tag|path|skill|repo|role)$ && $# -lt 2 ]] && {
    echo "✋ ConstraintError: $1 needs a value" >&2
    echo "   └─ see: rhx git.tree.aside --help" >&2; exit 2; }
  case "$1" in
    --tag)  TAG="${2:-}"; shift 2 ;;
    --path) PATHS+=("${2:-}"); shift 2 ;;
    # rhachet injects these three into every skill it runs
    --skill|--repo|--role) shift 2 ;;
    set|get) [[ -z "$VERB" ]] || refuse "name one verb"
             VERB="$1"; shift ;;
    *) echo "✋ ConstraintError: unknown argument '$1'" >&2
       echo "   └─ see: rhx git.tree.aside --help" >&2; exit 2 ;;
  esac
done

# .what = print the sha of the entry that holds this tag, or naught
# .note = the subject reads `On <branch>: tree.aside: <tag>`. the compare is exact on
#         all after the first `: `, so a foreign entry whose message merely ENDS in
#         `tree.aside: <tag>` (`On main: wip tree.aside: feat`) never answers for it
sha_of_tag() {
  git stash list --format='%H %gs' | while read -r sha subject; do
    [[ "${subject#*: }" == "$PREFIX $1" ]] && { echo "$sha"; break; }
  done
}

# .what = did HEAD move <path> since the entry <sha> was set? its copy then differs from the stash's base
path_moved_since() {
  local sha="$1" p="$2"
  [[ "$(git rev-parse -q --verify "$sha^1:$p" 2>/dev/null)" != "$(git rev-parse -q --verify "HEAD:$p" 2>/dev/null)" ]]
}

# .what = the vibe line, named for the act this run performs
banner_of_verb() {
  case "$VERB:${TAG:+tag}" in
    set:*)   echo "lets set it aside..." ;;
    get:tag) echo "lets lay it back..." ;;
    get:)    echo "lets see what is aside..." ;;
  esac
}

[[ -z "$VERB" ]] || { echo "🐢 $(banner_of_verb)"; echo ""; }

case "$VERB" in
  set)
    [[ -n "$TAG" ]] || refuse "set needs --tag"
    [[ "${#PATHS[@]}" -gt 0 ]] || refuse "set needs at least one --path"
    [[ -z "$(sha_of_tag "$TAG")" ]] || {
      echo "✋ ConstraintError: tag '$TAG' is already held" >&2
      echo "   └─ lay it back first: rhx git.tree.aside get --tag $TAG" >&2
      exit 2
    }
    # a path git sees no change in saves no entry: that is the caller's to know, never a fault
    if [[ -z "$(git status --porcelain -- "${PATHS[@]}")" ]]; then
      echo "✋ ConstraintError: naught to set aside: no named path differs from HEAD" >&2
      echo "   └─ name a path you changed: git status --short" >&2
      exit 2
    fi
    git stash push -m "$PREFIX $TAG" -- "${PATHS[@]}" >/dev/null || {
      echo "💥 MalfunctionError: git stash push refused the paths" >&2; exit 1; }
    sha="$(sha_of_tag "$TAG")"
    [[ -n "$sha" ]] || { echo "💥 MalfunctionError: the entry for '$TAG' did not land" >&2; exit 1; }
    echo "🐚 git.tree.aside set --tag $TAG"
    echo "   ├─ sha: $sha"
    echo "   └─ paths"
    for i in "${!PATHS[@]}"; do
      echo "      $(tree_glyph "$i" "${#PATHS[@]}") ${PATHS[$i]}"
    done
    ;;

  get)
    if [[ -z "$TAG" ]]; then
      echo "🐚 git.tree.aside get"
      held="$(git stash list --format='%H %gs' | while read -r sha subject; do
        [[ "${subject#*: }" == "$PREFIX "* ]] && echo "$sha ${subject#*: "$PREFIX "}"
      done)"
      [[ -n "$held" ]] || { echo "   └─ (none held)"; exit 0; }
      # the last row closes the tree (└─), as every other list here does
      held_rows=()
      mapfile -t held_rows <<<"$held"
      for i in "${!held_rows[@]}"; do
        read -r sha tag <<<"${held_rows[$i]}"
        echo "   $(tree_glyph "$i" "${#held_rows[@]}") $tag ($sha)"
      done
      exit 0
    fi
    sha="$(sha_of_tag "$TAG")"
    [[ -n "$sha" ]] || {
      echo "✋ ConstraintError: no entry holds tag '$TAG'" >&2
      echo "   └─ see what is held: rhx git.tree.aside get" >&2
      exit 2
    }
    # 🛑 refuse BEFORE the apply when HEAD moved a held path since the set: a 3-way
    #   apply then writes conflict markers into the live file, and a held file is often
    #   live config (measured 2026-11-20: a rebase moved .claude settings, the apply
    #   wrote markers into them, and every permission check failed to parse)
    # the held paths: a read that fails refuses, else an empty list would pass the guard
    held_paths="$(git stash show --name-only "$sha")" || {
      echo "💥 MalfunctionError: could not read the paths '$TAG' holds ($sha); no file was touched" >&2
      exit 1; }
    moved=()
    while IFS= read -r p; do
      [[ -n "$p" ]] || continue
      path_moved_since "$sha" "$p" && moved+=("$p")
    done <<<"$held_paths"
    if [[ "${#moved[@]}" -gt 0 ]]; then
      noun="held paths"; [[ "${#moved[@]}" -eq 1 ]] && noun="held path"
      echo "✋ ConstraintError: HEAD moved ${#moved[@]} $noun since '$TAG' was set" >&2
      # the moved paths nest under their label; the verdict and the fix are its peers
      echo "   ├─ moved since the set" >&2
      for i in "${!moved[@]}"; do
        [[ "$i" -eq $(( ${#moved[@]} - 1 )) ]] && echo "   │  └─ ${moved[$i]}" >&2 || echo "   │  ├─ ${moved[$i]}" >&2
      done
      echo "   ├─ the entry is KEPT, and no file was touched" >&2
      echo "   └─ fix: read what it holds, then settle each path by hand: git stash show -p $sha" >&2
      exit 2
    fi

    git stash apply "$sha" >/dev/null || {
      echo "✋ ConstraintError: the apply of '$TAG' ($sha) hit a conflict" >&2
      echo "   ├─ the entry is KEPT, so no edit is lost" >&2
      echo "   └─ settle the conflict, then: rhx git.tree.aside get --tag $TAG" >&2
      exit 2
    }
    # re-find the stack position by sha at drop time; another session may have moved it
    ref="$(git stash list --format='%gd %H' | while read -r gd h; do [[ "$h" == "$sha" ]] && { echo "$gd"; break; }; done)"
    [[ -n "$ref" ]] && git stash drop "$ref" >/dev/null
    echo "🐚 git.tree.aside get --tag $TAG"
    echo "   ├─ sha: $sha"
    echo "   └─ laid back, entry dropped"
    ;;

  *)
    # the same shape as every other refusal here: the glyph, then one pointer to the help
    refuse "name a verb: set or get"
    ;;
esac

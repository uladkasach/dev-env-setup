#!/usr/bin/env bash
######################################################################
# .what = prove every PATH-SHAPED pointer at a brief reaches a file that
#         exists
#
# .why
#   - a brief is cited by NAME (`rule.forbid.repair-plays`) or by PATH
#     (`.../briefs/grove/play/rule.forbid.repair-plays.md`)
#   - a NAME survives a move; a PATH does not
#   - no reader in this repo reads the PATH form
#   - a brief move leaves every path-shaped citation aimed at open air
#   - no check reddens on that — the human who follows it is the only
#     detector
#
# 🛑 .why this play must exist
#   - 📜 2026-09-02: `.agent/playbooks/` moved to `.play/`; FOUR readers went
#     quietly blind (`play.run`, `git.grove.send`, `shell.syntax.verify`,
#     `.gitignore`); every verdict stayed green
#   - a move is a READER-SCOPE event
#   - this repo paid for that lesson twice
#     (`gotcha.a-check-that-cries-wolf-gets-silenced`, q11 — a count is only
#     as big as the reader's reach)
#   - the briefs dir is the same shape at 10x the size: 52 paths in
#     boot.yml, plus citations across briefs, skills, src/, readme.md,
#     .claude/settings.json, .behavior/, .route/
#
# .the TWO pointer forms it reads
#   - absolute-from-root: .agent/repo=<r>/role=<x>/briefs/<name>.md
#   - role-relative: briefs/<name>.md (boot.yml's form)
#   - the role-relative form is ambiguous alone; read against the role dir
#     of the file that holds it — the booter's own rule
#
# .what it does to the box
#   - reads only; writes no file, installs no package, touches no machine
#     state
#   - a plain `prove.*`, owed no carve-out from `rule.forbid.repair-plays`
#
# guarantee:
#   - names the SOURCE file and line for every dead pointer — the fix is one
#     edit away
#   - prints the corpus it read BESIDE its verdict, so a reader can judge
#     the reach (`rule.forbid.failhide`)
#   - declines (exit 2) rather than pass when it cannot read the tree, and
#     rather than pass on a scan that found zero pointers — an unread corpus
#     proves no claim
#
# usage:
#   rhx play.run --play prove.brief-pointers-reach
#
# exit:
#   0 = every path-shaped brief pointer reaches a file
#   1 = at least one is dead
#   2 = the corpus could not be read, so no claim is proven
######################################################################

set -uo pipefail

######################################################################
# .what = the root: own location first, then cwd, then the paved checkout
#
# .why
#   - every permanent play here uses the same ladder
#   - a play sent to a grove lands outside any checkout
#   - a bare `git rev-parse` from the play's own dir answers empty on the
#     box it most needs to run on
######################################################################
_self="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." 2>/dev/null && pwd)" || _self=""
if   [[ -n "$_self" && -d "$_self/.agent" ]]; then ROOT="$_self"
elif [[ -d "$PWD/.agent" ]];                  then ROOT="$PWD"
else                                               ROOT="$HOME/git/more/dev-env-setup"
fi

echo "🔎 prove.brief-pointers-reach"
echo "   └─ root: $ROOT"
echo ""

if [[ ! -d "$ROOT/.agent" ]]; then
  echo "   ✋ no .agent/ under $ROOT" >&2
  echo "      ⇒ an unread corpus proves no claim, so this declines" >&2
  exit 2
fi

cd "$ROOT" || { echo "   ✋ cannot enter $ROOT" >&2; exit 2; }

######################################################################
# .what = the corpus: every TRACKED text file
#
# .why
#   - an untracked scratch file that holds a stale path is nobody's defect
#   - `git ls-files` reports the INDEX — the right store here
#   - a pointer reaches another reader only once tracked
#     (`gotcha.a-check-that-cries-wolf-gets-silenced`, q13 — name the store)
######################################################################
mapfile -t FILES < <(git ls-files -- '*.md' '*.yml' '*.yaml' '*.json' '*.sh' 2>/dev/null)

if [[ "${#FILES[@]}" -eq 0 ]]; then
  echo "   ✋ git ls-files reported an empty corpus" >&2
  echo "      ⇒ either this is no checkout, or the index is empty. either" >&2
  echo "        way there is no text to read, so no verdict is claimed" >&2
  exit 2
fi

echo "   ├─ corpus"
echo "   │  └─ ${#FILES[@]} tracked text file(s)"

######################################################################
# .what = the scan
#
# 🛑 .why
#   - the pattern must not match a bare-name citation
#   - it demands the `briefs/` segment
#   - a name that merely LOOKS like a brief (`rule.forbid.repair-plays`, in
#     backticks) is a NAME and survives a move
#   - flagging it would be a false ✋
#   - a false ✋ decays into a false ✔ the day somebody silences this play
######################################################################
dead=0
seen=0
vague=0
declare -A REPORTED=()

# every role dir, for the role-relative form held OUTSIDE any role dir
mapfile -t ROLEDIRS < <(git ls-files -- '.agent/repo=*/role=*/*' 2>/dev/null | cut -d/ -f1-3 | sort -u)

for f in "${FILES[@]}"; do
  [[ -r "$f" ]] || continue

  # the source file's own role dir, when it has one
  roledir=""
  case "$f" in
    .agent/repo=*/role=*/*) roledir="$(echo "$f" | cut -d/ -f1-3)" ;;
  esac

  while IFS=: read -r lineno hit; do
    [[ -z "$hit" ]] && continue

    # a single line may hold several pointers
    for raw in $(echo "$hit" | grep -oE '(\.agent/repo=[^ `"'"'"']*/)?briefs/[A-Za-z0-9._=/-]+\.md'); do

      ######################################################################
      # 🛑 .what = three line shapes are NOT pointers
      #
      # .why
      #   - 📜 2026-09-02: each drew a false ✋ on this play's first run
      #   - `<` = a TEMPLATE (`<org>`, `<any|mechanic>`) — names a shape a
      #     human fills in; no file was ever meant to sit there
      #   - `…` = an ELIDED path — unreachable by construction, only ever a
      #     shape; `.agent/…/briefs/x.md` quotes another check's output and
      #     aims at open air
      #   - `👎` = a COUNTER-EXAMPLE — the repo's marker for "this is the
      #     wrong form"; a path under it is cited to be condemned
      #   - `👎` is the sharp one: `define.cry-wolf-measurements` m.10 — a
      #     correction that QUOTES the dead pointer it corrects re-creates it
      #   - that file's own 👎 line spelled the bad path in full; this play
      #     read the measurement about the trap as an instance of the trap
      #   - the file now names the SHAPE; this skip is the second belt for
      #     the next author who spells one
      ######################################################################
      case "$hit" in *'<'*|*'…'*|*'👎'*) continue ;; esac

      seen=$(( seen + 1 ))

      key="$f:$lineno:$raw"
      [[ -n "${REPORTED[$key]:-}" ]] && continue

      # form 1 — absolute from root. unambiguous, so it must exist
      if [[ "$raw" == .agent/* ]]; then
        [[ -f "$raw" ]] && continue
        REPORTED[$key]=1
        echo "   │  ✋ $f:$lineno" >&2
        echo "   │     └─ $raw" >&2
        dead=$(( dead + 1 ))
        continue
      fi

      # form 2 — role-relative, held INSIDE a role dir. read against that role
      if [[ -n "$roledir" ]]; then
        [[ -f "$roledir/$raw" ]] && continue
        REPORTED[$key]=1
        echo "   │  ✋ $f:$lineno" >&2
        echo "   │     └─ $roledir/$raw" >&2
        dead=$(( dead + 1 ))
        continue
      fi

      ######################################################################
      # 🛑 .what = form 3 — role-relative, held OUTSIDE any role dir
      #
      # .why
      #   - it names no role, so it is read against EVERY role
      #   - a hit in one is a reach
      #   - a miss here is NOT a dead pointer — the first cut of this play
      #     said it was
      #   - 📜 2026-09-02: `.claude/settings.json` holds
      #     `--from briefs/rule.md` inside a permission EXAMPLE, a command
      #     shape never a citation; it drew a ✋ against a file nobody meant
      #     to exist — four false rows of eleven
      #   - a false ✋ is the corrosive half: it fails every run where it did
      #     not matter, until a human silences the play and takes its
      #     credibility with it (`gotcha.a-check-that-cries-wolf-gets-silenced`)
      #   - an unplaceable reference reports as 🌙 and does NOT fail the run
      ######################################################################
      hit_any=0
      for rd in "${ROLEDIRS[@]}"; do
        [[ -f "$rd/$raw" ]] && { hit_any=1; break; }
      done
      [[ "$hit_any" -eq 1 ]] && continue

      REPORTED[$key]=1
      echo "   │  🌙 $f:$lineno — '$raw' names no role, and matches no role's briefs" >&2
      vague=$(( vague + 1 ))
    done
  done < <(grep -nE 'briefs/[A-Za-z0-9._=/-]+\.md' "$f" 2>/dev/null)
done

echo "   │  ├─ $seen path-shaped pointer(s) read"
echo "   │  └─ $vague unplaceable (🌙 — reported, not failed)"
echo ""

######################################################################
# .what = the verdict
#
# .why
#   - the count of pointers READ sits above, beside the verdict, on purpose
#   - a green row over `0 pointers read` means a reader that saw none, never
#     a clean corpus
#   - the number on screen is the only way to tell the two apart
######################################################################
if [[ "$seen" -eq 0 ]]; then
  echo "   ✋ zero path-shaped pointers found across ${#FILES[@]} files" >&2
  echo "      ⇒ boot.yml alone holds dozens, so a zero here means the SCAN" >&2
  echo "        is broken rather than the corpus clean. read the pattern in" >&2
  echo "        this play, not the tree" >&2
  exit 2
fi

if [[ "$dead" -eq 0 ]]; then
  echo "🌲 every brief pointer reaches a file ✔"
  echo "   └─ $seen pointer(s) across ${#FILES[@]} tracked file(s)"
  exit 0
fi

echo "   ✋ $dead of $seen brief pointer(s) reach no file" >&2
echo "      ⇒ each row above names the SOURCE file and line. a moved brief" >&2
echo "        keeps its NAME, so the fix is the path segment alone" >&2
exit 1

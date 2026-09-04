#!/usr/bin/env bash
######################################################################
# .what = prove no DUAL-SHELL file holds syntax that reads differently under
#         zsh, and prove the `git backup` changed-file parse agrees in BOTH
#
# 🛑 .the class
#   - `src/bash_aliases.sh`, `src/ductwork.sh`, `src/termwork.sh` are sourced by BOTH shells: an agent's bash, and via `src/zshrc.sh:204` the human's INTERACTIVE zsh
#   - every line in them is read twice, by two dialects
#   - `rule.forbid.bare-globs-in-dual-shell-files` records six members of this family
#   - five FAIL LOUD under zsh, one does not:
#
#     | syntax                | bash        | zsh                        |
#     | ${!arr[@]}            | array keys  | bad substitution           |
#     | local status          | fine        | read-only variable         |
#     | for f in dir/*.ext    | literal     | no matches found, ABORTS   |
#     | ${BASH_REMATCH[1]}    | the capture | 🛑 EMPTY, and SILENT       |
#
#   - the last row is why this play exists
#   - both shells HAVE `[[ =~ ]]`; they disagree only on where the capture lands
#   - zsh runs the line, exits 0, and yields an empty string
#   - every test downstream then tests ""
#
# 📜 2026-09-02 — `src/bash_aliases.sh:3704`
#   - `git backup`'s changed-file patch read `${BASH_REMATCH[1]}`
#   - under zsh every changed member became a blank
#   - `[[ -e "$HOME/$name" ]]` then tested `$HOME/`, a directory, and passed — each blank filed as FOUND
#   - the patch printed `patched N changed files` and handed tar N empty operands
#   - the archive was short exactly the files the patch exists to catch
#   - `rule.forbid.failhide` on the one command a human runs when the work is too precious to lose
#   - reintroduced by the dialect of the shell it ships to, inside the repair written to close it
#
# 🛑 .why a play rather than the rule alone
#   - the rule is prose, read by whoever already suspects a dialect split
#   - the member nobody suspects is the member that ships
#   - five prior rounds trained the instinct that zsh ERRORS
#   - that read makes a silent member invisible
#   - this reader looks on every run, over a set it DISCOVERS (`inventory.security-checks.md`, the quarantined-lesson heuristic)
#
# .what it does to the box
#   - it READS tracked files, and runs one pure parse in a subshell of each installed shell
#   - no write, no network, no change to the caller's shell
#
# guarantee:
#   - it proves each pattern DISCRIMINATES against fixtures before it is aimed at a real file, so a broken reader halts rather than reports
#   - it asks the BEHAVIOR too, not only the text: the `git backup` parse runs under bash and under zsh and the two answers must agree
#   - a zsh not installed is a DECLINE on that arm, never a pass — the human's shell is the one this class breaks in
#
# usage:
#   rhx play.run --play prove.dual-shell-files-hold-no-bash-only-syntax
#
# exit:
#   0 = no bash-only syntax, and both dialects parse alike
#   1 = at least one dual-shell file splits by dialect
#   2 = the subject could not be read, so no claim was proven
######################################################################

set -uo pipefail

echo "🔎 prove.dual-shell-files-hold-no-bash-only-syntax"
echo "   └─ subject: every file both bash and zsh source"
echo ""

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo "")"
if [[ -z "$ROOT" ]]; then
  echo "   └─ 🌙 not inside a git checkout, so the subject tree is unnamed" >&2
  exit 2
fi
cd "$ROOT" || exit 2

######################################################################
# .what = 1. the SET — declared once, in the only place that can be authoritative
#
# ⚠️ .why
#   - a grep cannot discover this set: "sourced by zsh" is a fact about `src/zshrc.sh`, not the file itself
#   - the set reads OUT of zshrc rather than a hand-typed list
#   - a hand list could not report the file somebody adds to zshrc tomorrow
######################################################################
ZSHRC="$ROOT/src/zshrc.sh"
if [[ ! -r "$ZSHRC" ]]; then
  echo "   └─ 🌙 no src/zshrc.sh, so the dual-shell set cannot be derived" >&2
  exit 2
fi

####################################################################
# .what = THE CLOSURE IS TRANSITIVE — one hop is not the set
#
# 🛑 .why
#   - `src/zshrc.sh:203-204` names ONE file:
#
#       # note: ~/.bash_aliases sources ductwork + termwork itself, so zsh gets
#       #       them via this
#       source ~/.bash_aliases
#
#   - `ductwork` and `termwork` are dual-shell by INHERITANCE
#   - a reader that scans zshrc alone finds one subject, reports `dual-shell files: 1`
#   - that reader prints a clean page over two thirds of its own subject
#
# 📜 2026-09-02: this play's first run reported 1 of 3
#   - a count is a claim about a SET, bounded by the reader's reach (`gotcha.a-check-that-cries-wolf-gets-silenced`, m.12)
#   - the page looked complete, which makes a partial walk worse than an absent one
#   - it happened inside a clamp written that hour to catch exactly this family
#
# .why the fix
#   - the walk FOLLOWS the sources, from the one root zsh actually reads
#   - it maps each installed path back to the tracked file that produces it
#   - a fourth file added to that chain is measured the day it is added
####################################################################
_tracked_for() {   # installed path -> tracked source, or empty
  case "$1" in
    *.bash_aliases.ductwork.sh) echo "src/ductwork.sh" ;;
    *.bash_aliases.termwork.sh) echo "src/termwork.sh" ;;
    *.bash_aliases)             echo "src/bash_aliases.sh" ;;
    *)                          echo "" ;;
  esac
}

# breadth-first over the source chain, rooted at what zshrc reads
QUEUE=("$ZSHRC")
SUBJECTS=()
SEEN=""
UNMAPPED=()
while [[ "${#QUEUE[@]}" -gt 0 ]]; do
  cur="${QUEUE[0]}"; QUEUE=("${QUEUE[@]:1}")
  [[ -r "$cur" ]] || continue
  case " $SEEN " in *" $cur "*) continue ;; esac
  SEEN="$SEEN $cur"

  while IFS= read -r inst; do
    [[ -n "$inst" ]] || continue
    tracked="$(_tracked_for "$inst")"
    if [[ -z "$tracked" ]]; then
      # an unmapped sourced path is an UNJUDGED subject — reported, not dropped silent
      UNMAPPED+=("$inst")
      continue
    fi
    case " ${SUBJECTS[*]-} " in *" $tracked "*) ;; *) SUBJECTS+=("$tracked") ;; esac
    QUEUE+=("$ROOT/$tracked")
  done < <(sed 's/#.*$//' "$cur" | grep -oE '(source|\.) +~?/?[^ ;&|)"]*\.bash_aliases[^ ;&|)"]*' | awk '{print $2}')
done

if [[ "${#SUBJECTS[@]}" -eq 0 ]]; then
  echo "   └─ 🌙 the source chain from src/zshrc.sh reaches no tracked file" >&2
  echo "      · either the source lines moved, or this derivation went blind" >&2
  echo "      · a clean page over an empty set proves no claim" >&2
  exit 2
fi

if [[ "${#UNMAPPED[@]}" -gt 0 ]]; then
  echo "   ├─ 🌙 ${#UNMAPPED[@]} sourced path(s) map to no tracked file:" >&2
  for u in "${UNMAPPED[@]}"; do echo "   │     · $u" >&2; done
  echo "   │     they are dual-shell and were NOT judged" >&2
fi

######################################################################
# .what = 2. the PATTERNS — each must discriminate before it is trusted
#
# 🛑 .why
#   - every live row below is a ✔ on a healthy tree
#   - a green page says only that the pass path works
#   - each pattern is first shown a string it MUST flag and a string it must NOT (`gotcha.a-check-that-cries-wolf-gets-silenced`, the corollary)
######################################################################
PAT_REMATCH='\$\{?BASH_REMATCH'
PAT_ARRKEYS='\$\{![A-Za-z_][A-Za-z0-9_]*\[@\]\}'

######################################################################
# .what = THE BARE GLOB — the family's loudest member, most live instances
#
# 🛑 .why
#   - `for f in <dir>/*.ext` leaves the pattern as LITERAL text in bash
#   - it is a HARD ERROR in zsh that aborts the whole function
#   - the `[[ -f "$f" ]] || continue` everyone writes reads as the defense and is never reached
#   - `rule.forbid.bare-globs-in-dual-shell-files` grades this a blocker by name
#
# 📜 2026-09-02: fourteen instances stood in `src/bash_aliases.sh`
#   - the rule's own `.where to look` had predicted them exactly: "worktree walks, `*.json`, `*.patch`"
#   - the rule named them and no reader counted them
#   - they sat while the rule read as enforced
#
# ⚠️ .the ONE exemption, argued rather than assumed
#   - `/proc/[0-9]*` cannot match zero: `/proc` always holds PID 1, so zsh never aborts there
#   - the rule calls it "the low-risk end of the same defect"
#   - it is exempt by a fact about the SUBJECT, not by taste
#   - named here rather than left to whoever next runs this play (`rule.require.exemptions-name-their-trigger`)
######################################################################
PAT_BAREGLOB='^[^#]*for +[A-Za-z_][A-Za-z0-9_]* +in +[^;]*[^ ]\*'
PAT_EXEMPT='in +/proc/'

_hits() { grep -qE "$2" <<<"$1"; }   # redirect, never pipe: `grep -q` + pipefail = false verdict by file size (`gotcha.pipefail-grep-q`)

SELFTEST=0
  _hits 'name="${BASH_REMATCH[1]}"'  "$PAT_REMATCH" || SELFTEST=$((SELFTEST+1))
  _hits 'x=$BASH_REMATCH'            "$PAT_REMATCH" || SELFTEST=$((SELFTEST+1))
  _hits 'name="${line#tar: }"'       "$PAT_REMATCH" && SELFTEST=$((SELFTEST+1))
  _hits 'for k in "${!arr[@]}"'      "$PAT_ARRKEYS" || SELFTEST=$((SELFTEST+1))
  _hits 'for k in "${arr[@]}"'       "$PAT_ARRKEYS" && SELFTEST=$((SELFTEST+1))
  # the bare glob must be caught in each shipped form, and not claimed against
  # the `find`-fed replacement or an array walk
  _hits 'for f in "$dir"/*.json; do'          "$PAT_BAREGLOB" || SELFTEST=$((SELFTEST+1))
  _hits 'for d in "$b"/*/_worktrees; do'      "$PAT_BAREGLOB" || SELFTEST=$((SELFTEST+1))
  _hits 'for d in "$w"/"$repo".*; do'         "$PAT_BAREGLOB" || SELFTEST=$((SELFTEST+1))
  _hits 'done < <(find "$dir" -name "x.json")' "$PAT_BAREGLOB" && SELFTEST=$((SELFTEST+1))
  _hits 'for f in "${arr[@]}"; do'            "$PAT_BAREGLOB" && SELFTEST=$((SELFTEST+1))
  # and the exemption must recognize only what it claims
  _hits 'for p in /proc/[0-9]*; do'           "$PAT_EXEMPT"   || SELFTEST=$((SELFTEST+1))
  _hits 'for f in "$dir"/*.json; do'          "$PAT_EXEMPT"   && SELFTEST=$((SELFTEST+1))

if [[ "$SELFTEST" -gt 0 ]]; then
  echo "   └─ 💥 the patterns fail their own fixtures ($SELFTEST)" >&2
  echo "      · they cannot tell bash-only syntax from portable syntax" >&2
  echo "      · every verdict below would be unfounded, so none is offered" >&2
  exit 2
fi
echo "   ├─ patterns: ✔ discriminate (12/12 fixtures)"
echo "   ├─ dual-shell files: ${#SUBJECTS[@]}"
echo "   │"

######################################################################
# 3. ask each file
######################################################################
FAILED=0
for f in "${SUBJECTS[@]}"; do
  if [[ ! -r "$f" ]]; then
    echo "   ├─ 🌙 $f"
    echo "   │     zshrc sources it and this tree does not hold it"
    continue
  fi
  # prose is not code — a comment that names the hazard is not the hazard
  # (m.7; same strip the kitty clamp needed same day)
  code="$(sed 's/#.*$//' "$f")"

  bad=""
  _hits "$code" "$PAT_REMATCH" && bad="$bad \${BASH_REMATCH…}"
  _hits "$code" "$PAT_ARRKEYS" && bad="$bad \${!arr[@]}"

  # the bare glob minus the one argued exemption: exempt lines are SUBTRACTED
  # from the subject rather than the pattern loosened, so a `/proc/` line
  # cannot mask a real one on the same read
  globs="$(grep -E "$PAT_BAREGLOB" <<<"$code" | grep -vE "$PAT_EXEMPT" || true)"
  nglobs=0
  [[ -n "$globs" ]] && nglobs="$(grep -c . <<<"$globs")"
  [[ "$nglobs" -gt 0 ]] && bad="$bad ${nglobs}×bare-glob"

  # 🛑 .why the PARSE itself, in the dialect that matters
  #    - a text scan says known forms are absent; only zsh says the file LOADS
  #    - `-n` parses and executes not one line, safe against a file full of side effects
  parse=""
  bash -n "$f" 2>/dev/null || parse="$parse bash"
  if command -v zsh >/dev/null 2>&1; then
    zsh -n "$f" 2>/dev/null || parse="$parse zsh"
  fi
  [[ -n "$parse" ]] && bad="$bad no-parse:$parse"

  if [[ -z "$bad" ]]; then
    echo "   ├─ ✔ $f"
    continue
  fi
  FAILED=$((FAILED+1))
  echo "   ├─ ✋ $f"
  echo "   │     holds bash-only syntax:$bad"
  if [[ "$nglobs" -gt 0 ]]; then
    while IFS= read -r g; do
      [[ -n "$g" ]] && echo "   │     · ${g#"${g%%[![:space:]]*}"}"
    done <<<"$globs"
    echo "   │     · fix: while IFS= read -r x; do … done < <(find …)"
  fi
  echo "   │     · zsh reads these differently, and \${BASH_REMATCH…} does so SILENTLY"
done

echo "   │"

######################################################################
# .what = 4. the BEHAVIOR arm — the text is not the claim, the parse is
#
# ⚠️ .why
#   - a text scan proves the syntax is absent
#   - it does not prove the replacement is CORRECT in both dialects
#   - this arm drives the actual `git backup` changed-file parse under each shell and demands one answer
#   - the input carries the two hard cases the parse must keep:
#       · a name with a space
#       · a name that itself holds the phrase `: file changed`, which pins `%` (shortest suffix, longest name) against `%%`
######################################################################
_PARSE='
line="tar: a space: file changed: file changed as we read it"
case "$line" in
  "tar: "*": file changed"*) ;;
  *) echo "NOMATCH"; exit 0 ;;
esac
name="${line#tar: }"
name="${name%: file changed*}"
echo "[$name]"
'
EXPECT='[a space: file changed]'

got_bash="$(bash -c "$_PARSE" 2>/dev/null)"
if [[ "$got_bash" != "$EXPECT" ]]; then
  echo "   ├─ ✋ bash parses the tar line as $got_bash, expected $EXPECT" >&2
  FAILED=$((FAILED+1))
else
  echo "   ├─ ✔ bash parse: $got_bash"
fi

if command -v zsh >/dev/null 2>&1; then
  got_zsh="$(zsh -c "$_PARSE" 2>/dev/null)"
  if [[ "$got_zsh" != "$EXPECT" ]]; then
    echo "   ├─ ✋ zsh parses the tar line as $got_zsh, expected $EXPECT" >&2
    FAILED=$((FAILED+1))
  else
    echo "   ├─ ✔ zsh  parse: $got_zsh"
  fi
else
  # a DECLINE, never a pass: zsh is the shell this class breaks in; its
  # absence removes the only arm that measures the human's dialect
  echo "   ├─ 🌙 zsh is absent — the dialect arm could not run" >&2
  echo "   │     this box proved bash only, so the claim is HALF proven" >&2
fi

echo "   │"

######################################################################
# 5. the verdict
######################################################################
if [[ "$FAILED" -gt 0 ]]; then
  echo "   └─ ✋ $FAILED dual-shell defect(s)" >&2
  echo "      · read rule.forbid.bare-globs-in-dual-shell-files for the family" >&2
  exit 1
fi

echo "   └─ ✔ every dual-shell file reads alike in both shells"
exit 0

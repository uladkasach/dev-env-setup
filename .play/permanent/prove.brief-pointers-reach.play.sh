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
# .the THREE pointer forms it reads
#   - absolute-from-root: .agent/repo=<r>/role=<x>/briefs/<name>.md
#   - role-relative: briefs/<name>.md (boot.yml's form)
#   - the role-relative form is ambiguous alone; read against the role dir
#     of the file that holds it — the booter's own rule
#   - dream: .dream/<name>.dream.md — a brief's peer record, cited BY path
#     and only by path (a dream has no bare-name form to fall back on)
#   - artifact: src/<path>.<ext> — a file in the bundle tree, cited by path
#     and only by path; like a dream, it has no bare-name form
#
# 🛑 .why the `src/` form was added — measured 2026-09-29
#   - the bundle cutover moved every flat `src/<file>` artifact into its own
#     bundle dir: `src/<file>` → `src/grove.provision/<n>.<bundle>/<file>`
#   - ~200 citations across briefs, skills, plays, and src/ itself kept the
#     flat path, and every one aimed at open air
#   - ⚠️ the SHAPE is named above, never an instance — m.10: a correction that
#     quotes the dead pointer it corrects re-creates it, and this play's own
#     header is the surface that lesson lands on hardest
#   - TWO were fix-texts a human pastes, so the cost was not merely a dead
#     link: a `--glob 'src/<file>.sh'` returns a clean `0 matches`,
#     exit 0 — a false ✔ handed out with a brief's authority behind it
#     (`gotcha.grepsafe-glob-goes-quiet`)
#   - and one was the nvim lockfile's bump instruction, whose own next
#     paragraph names the silent pin-loss its stale path would cause
#   - ⇒ the reader's reach WAS the count again (`…cries-wolf`, q11)
#
# 🛑 .the THREE classes a `src/` row falls into, and a count cannot sort them
#   - a MOVED file — the path is repairable, and the repair is computable:
#     its basename still sits somewhere under `src/`. this is the ✋
#   - a RETIRED file — `src/install_env._.sh` was deleted in the 2026-07-30
#     hard cut, so NO live path exists. to "repair" it would invent one
#   - a RECORD — a verbatim transcript, a git ref at a historical commit, a
#     retired alias body. the dead path IS the evidence; to repair it would
#     fabricate a measurement nobody took
#   - ⇒ retired and record report 🌙. only a MOVED row fails the run
#
# ⚠️ .how a RECORD declares itself — the `📜` glyph, reused not coined
#   - `rule.require.briefs-obey-the-prose-rules` already carves out a `📜`
#     as "a fact about the WORLD, with a date" — that IS this class
#   - so a line marked `📜` has its `src/` paths read as evidence
#   - the glyph law forbids a second symbol for one concept
#     (`term=glyph`), and a record is what `📜` already names
#
# 🛑 .why the `.dream/` form was added — measured 2026-09-29
#   - this play held at 245 across four runs while fresh `.dream/` pointers
#     landed in tracked files
#   - the pattern DEMANDED a `briefs/` segment, so the form was out of reach
#     by construction — honest, never blind, and still a gap
#   - 18 `.dream/…` pointers sat in the corpus; THREE reached open air:
#     a renamed dream (`…-to-grove-provision` vs the real `…-to-a-converge-verb`),
#     a dream that never existed at all, and a dream QUOTED as evidence that
#     never existed — `gotcha.my-own-note-became-my-evidence`, exactly
#   - ⇒ the reader's reach WAS the count (`gotcha.a-check-that-cries-wolf-gets-silenced`,
#     q11: a count is only as big as the reader's reach), and the three dead
#     rows are this widen's BITE — it goes red on the tree as it stood
#
# ⚠️ .the NAME is kept, deliberately
#   - `brief-pointers` reads as "pointers a brief carries", which is what
#     these are: every `.dream/…` row found sits in a brief, a manifest, or
#     a skill header
#   - and a rename is a READER-SCOPE event — the very defect this play
#     exists to catch. it would move a name cited from settings, howtos,
#     and `.readme.md`, to buy one word
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

######################################################################
# .what = a basename → live-path index over the tracked `src/` tree, plus a
#         count per basename
#
# 🛑 .why the COUNT is load-bear
#   - it is what parts a MOVED row from a RETIRED one, and it must not
#     INVENT a repair
#   - `_.sh` sits at dozens of paths in the bundle tree, so a lone basename
#     lookup would hand a reader a confident, arbitrary, wrong fix
#   - ⇒ one match = a computable repair (✋, with the fix named)
#     zero matches = retired, no live path exists (🌙)
#     many matches = ambiguous, a human decides which bundle owns it (🌙)
#   - a wrong fix in a fix-text is worse than an absent one: a bare
#     complaint gets ignored, a named fix gets applied
#     (`…cries-wolf`, q7)
######################################################################
declare -A SRCONE=()
declare -A SRCNUM=()
while IFS= read -r p; do
  b="${p##*/}"
  SRCNUM["$b"]=$(( ${SRCNUM["$b"]:-0} + 1 ))
  SRCONE["$b"]="$p"
done < <(git ls-files -- 'src/*' 2>/dev/null)

######################################################################
# 🛑 .what = a file may declare that EVERY `src/` path in it is a RECORD
#
# .why a FILE-level declaration, and not a line-level `📜` per row
#   - some artifacts take a set of dead paths as their SUBJECT: a dream
#     that maps each cutover-moved path to its new home spells the dead
#     path in the left column of the map that IS its deliverable
#   - to repair those paths destroys the map; to mark each of them costs a
#     glyph per row and still reads as a dozen separate judgments
#   - ⇒ one declaration, in the file it covers, is the honest shape
#
# ⚠️ .why NOT a `.dream/**` dir skip
#   - 📜 measured 2026-09-29: this play BIT a real MOVED path inside a
#     dream — a `current` column that still named the pre-cutover home of
#     a live file. a dir-wide skip would have blinded it to exactly the
#     defect it exists to catch (`…cries-wolf`, q11)
#   - so the exemption is OPT-IN, per file, and its trigger sits in the
#     file it exempts (`rule.require.exemptions-name-their-trigger`)
#
# 🛑 .TWO guards part a DECLARATION from a MENTION, and both are measured
#
#   1. a BACKTICK before the glyph disqualifies it
#      - the house style quotes a term it discusses; a declaration does not
#      - 📜 m.10, FIFTH order: the first cut matched the token anywhere, so
#        the play that DEFINES it claimed it — its own two `src/` rows went
#        from RETIRED / route-RECORD to record-marked, waved through by a
#        declaration nobody made
#
#   2. the token is SPLIT in this file, and that is not obfuscation
#      - 📜 m.10, SIXTH order, measured the same minute: with the backtick
#        guard in place the play STILL claimed it — because the grep
#        PATTERN spells the token, and a `)` is not a backtick. **a reader
#        that matches a literal matches its own pattern line**
#      - ⇒ the one surface that must never spell the token contiguously is
#        the file that READS it. adjacent quoted halves compose it at run
#        time and leave no contiguous literal on disk
######################################################################
RECTOKEN="📜 record""-file:"

for f in "${FILES[@]}"; do
  [[ -r "$f" ]] || continue

  # the source file's own role dir, when it has one
  roledir=""
  case "$f" in
    .agent/repo=*/role=*/*) roledir="$(echo "$f" | cut -d/ -f1-3)" ;;
  esac

  # does this file DECLARE that its `src/` paths are its subject?
  recfile=0
  if grep -qE '(^|[^`])'"$RECTOKEN" "$f" 2>/dev/null; then
    recfile=1
  fi

  while IFS=: read -r lineno hit; do
    [[ -z "$hit" ]] && continue

    # a single line may hold several pointers
    for raw in $(echo "$hit" | grep -oE '(\.agent/repo=[^ `"'"'"']*/)?briefs/[A-Za-z0-9._=/-]+\.md|\.dream/[A-Za-z0-9._=/-]+\.md|src/[A-Za-z0-9._/-]+\.(sh|toml|conf|lua|zsh|json|xml|ron|css|md|policy)'); do

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

      ######################################################################
      # .what = form 4 — a `src/` artifact path, absolute from root
      #
      # .why it is sorted THREE ways rather than two
      #   - the classes are declared in this play's header: MOVED, RETIRED,
      #     RECORD. only MOVED is a defect
      #   - a `📜` line is a RECORD by the repo's own glyph, so its dead path
      #     is the evidence and reports 🌙
      ######################################################################
      if [[ "$raw" == src/* ]]; then
        [[ -f "$raw" ]] && continue

        base="${raw##*/}"
        key="$f:$lineno:$raw"
        [[ -n "${REPORTED[$key]:-}" ]] && continue
        REPORTED[$key]=1

        ######################################################################
        # 🛑 .what = a route's authored RECORDS are read as evidence
        #
        # .why
        #   - a `0.wish.md`, a `*.yield.md`, a `review/**` file is a DATED
        #     deliverable of a closed route; its prose states what was DONE
        #   - measured 2026-09-29: one yield reads "added `git_alias_graft()`
        #     📜 to `src/bash_aliases.sh` and alias to `src/install_env.sh`" — one
        #     path moved, the other was DELETED. to repair the first alone
        #     yields a sentence about an act nobody took at a path that did not
        #     exist that day
        #   - ⇒ a half-modernized transcript is worse than a stale one
        #
        # ⚠️ .the STONES and GUARDS stay in scope, deliberately
        #   - a stone is a live instruction a driver reads, not a record
        #   - so a dir-wide skip would blind this play to the one file in a
        #     route that a human still acts on
        #
        # 🛑 .the record set is EVERY authored deliverable, never only the yields
        #   - 📜 measured 2026-09-29: the first cut matched `0.wish`, `*.yield`,
        #     and `review/**`, and left `3.blueprint*`, `5.1.execution*`,
        #     `5.3.verification*`, `blocker/*`, `handoff*`, and a route's
        #     `0.tasklist.md` reporting ✋ — each as frozen as the yields beside
        #     them, and each in the same closed dir
        #   - ⇒ the discriminator is not the FILENAME but whether a human still
        #     ACTS on the file. a stone and a guard are acted on; a dated
        #     deliverable is read
        ######################################################################
        case "$f" in
          .behavior/*/0.wish.md|.route/*/0.wish.md|*.yield.md \
          |.behavior/*/review/*|.route/*/review/* \
          |.behavior/*/blocker/*|.route/*/blocker/* \
          |.behavior/*/*handoff*|.route/*/*handoff* \
          |.behavior/*/0.tasklist.md|.route/*/0.tasklist.md \
          |.behavior/*/[0-9]*.blueprint*.md|.route/*/[0-9]*.blueprint*.md \
          |.behavior/*/[0-9]*.execution*.md|.route/*/[0-9]*.execution*.md \
          |.behavior/*/[0-9]*.verification*.md|.route/*/[0-9]*.verification*.md)
            echo "   │  🌙 $f:$lineno — '$raw' sits in a route RECORD; read as evidence" >&2
            vague=$(( vague + 1 ))
            continue
            ;;
        esac

        if [[ "$recfile" == 1 ]]; then
          echo "   │  🌙 $f:$lineno — '$raw' sits in a 📜 record-file; read as evidence" >&2
          vague=$(( vague + 1 ))
          continue
        fi

        case "$hit" in
          *'📜'*)
            echo "   │  🌙 $f:$lineno — '$raw' is 📜 RECORD-marked; read as evidence" >&2
            vague=$(( vague + 1 ))
            continue
            ;;
        esac

        ######################################################################
        # 🛑 .what = a FENCED line is a capture unless it is command-shaped
        #
        # .why the `📜` marker cannot serve this class
        #   - a captured transcript is verbatim by contract, so a glyph added
        #     INSIDE the fence would corrupt the evidence
        #   - and the prose that declares it verbatim sits on a DIFFERENT line,
        #     which a line-by-line reader cannot associate
        #   - ⇒ the fence itself is the declaration, and it is machine-readable
        #
        # 🛑 .why a COMMAND inside a fence STAYS in scope
        #   - the two costliest rows this widen found were fenced commands:
        #     a `--glob 'src/<file>.sh'` (a silent `0 matches`, exit 0) and
        #     the nvim lockfile's copy-back instruction
        #   - a blanket fence skip would have missed both, which is the whole
        #     defect (`…cries-wolf`, q11 — the reader's reach IS the count)
        #   - so the test is the LINE's shape, never the block's
        ######################################################################
        if [[ -z "${FENCED_OF:-}" || "${FENCED_OF}" != "$f" ]]; then
          FENCED_OF="$f"
          unset FENCED
          declare -A FENCED=()
          unset FENCEMARK
          declare -A FENCEMARK=()
          while IFS=' ' read -r fl fm; do
            FENCED["$fl"]=1
            [[ "$fm" == 1 ]] && FENCEMARK["$fl"]=1
          done < <(awk '
            /^[[:space:]]*```/ {
              if (inb) { inb = 0 } else { inb = 1; mark = index($0, "📜") ? 1 : 0 }
              next
            }
            inb { print NR " " mark }
          ' "$f" 2>/dev/null)
        fi

        ######################################################################
        # 🛑 .the command word is ANCHORED, never matched as a substring
        #
        # 📜 measured 2026-09-29: a bare `*'sh '*` glob read a row of the form
        #      ├─ ✔ src/<file>.sh    bash, zsh
        #    as command-shaped, because `.sh` plus its padding IS `sh `. so a
        #    captured REPORT — whose subject is a set of `.sh` files — was
        #    handed the paste-me exemption, and drew a ✋ on verbatim evidence
        #
        #   - ⇒ the word must start the line or follow whitespace, a quote, or a
        #     backtick. a filename extension can satisfy neither
        ######################################################################
        cmdshaped=0
        if [[ "$hit" =~ (^|[[:space:]\'\"\`])(rhx|bash|zsh|sh|git|npx|source|cp|cat)[[:space:]] ]]; then
          cmdshaped=1
        fi

        if [[ -n "${FENCED[$lineno]:-}" ]]; then
          case "$cmdshaped" in
            1)
              # command-shaped — a human pastes this, so it must reach…
              #
              # 🛑 …unless the FENCE ITSELF is 📜 RECORD-marked
              #   - a retired alias BODY is command-shaped and reaches no file;
              #     its dead path is the evidence for the hazard beside it
              #   - the marker cannot sit on the line (it would corrupt the
              #     verbatim body), so it sits on the fence — one unit, one
              #     declaration, and machine-readable from either end
              if [[ -n "${FENCEMARK[$lineno]:-}" ]]; then
                echo "   │  🌙 $f:$lineno — '$raw' sits in a 📜 RECORD-marked fence; read as evidence" >&2
                vague=$(( vague + 1 ))
                continue
              fi
              ;;
            *)
              echo "   │  🌙 $f:$lineno — '$raw' sits in a fenced CAPTURE; read as evidence" >&2
              vague=$(( vague + 1 ))
              continue
              ;;
          esac
        fi

        case "${SRCNUM[$base]:-0}" in
          0)
            echo "   │  🌙 $f:$lineno — '$raw' names a RETIRED artifact; no live path exists" >&2
            vague=$(( vague + 1 ))
            ;;
          1)
            echo "   │  ✋ $f:$lineno" >&2
            echo "   │     ├─ $raw" >&2
            echo "   │     └─ fix: ${SRCONE[$base]}" >&2
            dead=$(( dead + 1 ))
            ;;
          *)
            echo "   │  🌙 $f:$lineno — '$raw' moved, and '$base' sits at ${SRCNUM[$base]} paths; a human picks" >&2
            vague=$(( vague + 1 ))
            ;;
        esac
        continue
      fi

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

      ######################################################################
      # .what = the dream form — absolute from root, so it must exist
      #
      # .why it is not folded into form 1
      #   - form 1 keys on `.agent/`, and a dream lives at `.dream/`
      #   - and a dream has NO bare-name form to fall back on: a brief is
      #     cited by name (`rule.forbid.repair-plays`) or by path, where a
      #     dream is only ever a path
      #   - ⇒ a dead dream pointer is strictly worse than a dead brief one:
      #     there is no name left for a reader to grep for
      ######################################################################
      if [[ "$raw" == .dream/* ]]; then
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
  done < <(grep -nE '(briefs/|\.dream/)[A-Za-z0-9._=/-]+\.md|src/[A-Za-z0-9._/-]+\.(sh|toml|conf|lua|zsh|json|xml|ron|css|md|policy)' "$f" 2>/dev/null)
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

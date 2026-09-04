#!/usr/bin/env bash
######################################################################
# .what = parse every shell file this repo ships, and name each one
#
# .why  = this repo's whole product is shell. `src/*.sh` is COPIED onto a machine
#         and sourced into every interactive shell, and `src/grove.provision/**`
#         is sourced by the driver on every run. so a syntax error does not fail
#         one command — it breaks the shell itself, or makes a bundle read as
#         absent. the repo declares no test or lint command, so without this
#         there is no gate at all.
#
# ⚠️ .why a SKILL and not a hand-rolled loop
#         the ad-hoc form, `for f in <glob>; do bash -n "$f"; done`, is wrong in
#         three ways every time a human retypes it:
#           1. the glob shrinks silently — `src/grove.provision/**/*.sh` expands
#              one level without `globstar`, so ~150 bundle files go unparsed
#              while the loop prints a clean verdict
#           2. it reports no COUNT, so a glob that matched no file looks
#              identical to a glob that matched everything and passed
#           3. it reads the wrong tree — a hardcoded `$HOME/git/more/dev-env-setup`
#              parses MAIN's files during a worktree run
#         each of those is a check that cannot fail, which is worse than an
#         absent check (`rule.forbid.failhide`, `rule.require.wrap-cli-in-skills`).
#
# ⚠️ .what this does NOT do — it never executes a line of the files it reads
#         `bash -n` parses and exits. it installs no package, writes no file, and
#         changes no machine state. safe on a human's own laptop, so it needs no
#         grove.
#
# .note = SYNTAX only. it cannot catch an unset variable, a bad path, or a wrong
#         exit code — those need a real run (`grove.provision --mode plan`, or a
#         push to a grove). this is the floor, not the ceiling.
#
# usage:
#   rhx shell.syntax.verify                 # this checkout (cwd), all three trees
#   rhx shell.syntax.verify --path src      # narrow to one subtree
#   rhx shell.syntax.verify --root <dir>    # name the checkout explicitly
#   rhx shell.syntax.verify --quiet         # only the failures and the tally
#
# exit:
#   0 = every file parses, and at least one file was checked
#   1 = at least one does not parse — each is named with its error
#   2 = no repo found, or the glob matched no file (proves no claim)
######################################################################
set -uo pipefail

ROOT=""
QUIET=0
PATHS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --root)  ROOT="${2:-}"; shift 2 ;;
    --path)  PATHS+=("${2:-}"); shift 2 ;;
    --quiet) QUIET=1; shift ;;
    --help|-h)
      # the header IS the help; print its usage block
      sed -n '/^# usage:/,/^#####/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//;$d'
      exit 0
      ;;
    # rhx injects --repo/--role/--skill; step over them
    --repo|--role|--skill) shift 2 ;;
    ####################################################################
    # 🛑 .why an unknown flag HALTS, and what `*) shift ;;` cost —
    #    measured 2026-08-13
    #
    #    a `*) shift ;;` arm swallows `--paths src` — one character off from
    #    `--path` — in silence. `PATHS` stays empty and the run walks the WHOLE
    #    repo behind a header that reads as narrowed. it reported 311 files, the
    #    same as the unnarrowed run, and that identity was the only tell.
    #
    #    ⚠️ the failure direction is the bad one for a NARROWING flag: a
    #    swallowed `--root` would read the wrong tree, and a swallowed
    #    `--path` reads more than asked. either way the verdict is about a
    #    subject the caller never named (`rule.forbid.failhide`).
    #
    #    ⇒ a flag this skill does not know is a caller error, so it says so
    #      and names the ones it does know
    ####################################################################
    *)
      echo "   ✋ unknown flag: $1" >&2
      echo "      ⇒ it would be ignored, and the run would report a verdict" >&2
      echo "        about a subject you never named" >&2
      echo "      valid: --root <dir>  --path <subtree>  --quiet  --help" >&2
      echo "      note:  the flag is --path, singular — repeat it per subtree" >&2
      exit 2
      ;;
  esac
done

######################################################################
# ⚠️ .why the root is SEARCHED and not hardcoded
#      a hardcoded `$HOME/git/more/dev-env-setup` names MAIN's checkout on every
#      box. run from a worktree on 2026-07-30, that form reported
#
#        ✔ src/install_env.pt1.system.basics.sh
#        ✔ src/install_env._.sh          … 16 more
#        🌲 syntax: all 29 files parse
#
#      the tree under test had DELETED every one of those files. it parsed
#      main's copies, called them ✔, and read as a pass for a checkout it never
#      opened. a proof that reads the wrong tree is worse than no proof.
#
#      so: an explicit --root wins, then the cwd when it IS this repo (a local
#      run from a worktree), then the wip checkout a grove under test carries,
#      then the settled one
######################################################################
#
# ⚠️ .the MARKER is the repo's entrypoint, and a RENAME of it breaks this
#    silently — measured 2026-08-31, on the `grove.provision` cutover
#
#    a marker that names a stale entrypoint no longer matches the worktree
#    under test, so the `$PWD` arm misses, the search falls through to the
#    settled checkout, and the run reports
#
#        🌲 shell.syntax.verify
#           └─ root: /home/vlad/git/more/dev-env-setup      ← NOT the worktree
#        🌲 syntax: all 23 files parse ✔
#
#    a green tally for a tree it never opened — the exact 2026-07-30 defect
#    recorded above, re-created by a rename rather than by a hardcoded path.
#
# ⇒ the tell is the ROOT LINE, which is why it is printed before the verdict.
#   read it. a fall-through prints a plausible path and a plausible count.
######################################################################
if [[ -z "$ROOT" ]]; then
  if [[ -f "$PWD/src/grove.provision._.sh" ]]; then
    ROOT="$PWD"
  elif [[ -f "$HOME/git/more/dev-env-setup.wip/src/grove.provision._.sh" ]]; then
    ROOT="$HOME/git/more/dev-env-setup.wip"
  else
    ROOT="$HOME/git/more/dev-env-setup"
  fi
fi

echo "🌲 shell.syntax.verify"
echo "   └─ root: $ROOT"
echo ""

if [[ ! -d "$ROOT" ]]; then
  echo "   ✋ no repo at $ROOT" >&2
  echo "      ⇒ every file below would be unparsed, and a tally of 0 would read" >&2
  echo "        as a pass to anyone who skimmed it" >&2
  echo "      fix: run from a checkout, or name one:" >&2
  echo "        rhx shell.syntax.verify --root ~/git/more/dev-env-setup" >&2
  exit 2
fi

CHECKED=0
BROKEN=0

SKIPPED=0

# a tracked path the disk does not hold. counted here so it can be REPORTED
# beside the verdict rather than folded into it (see the 🛑 at `walk_tracked`)
GONE=0

######################################################################
# 🛑 .why the PARSER is chosen per file, and not fixed at `bash -n`
#    — measured 2026-08-14
#
#    one fixed `bash -n`, with discovery keyed on `*.sh` plus a shebang regex
#    anchored at `bash|/sh| sh`, leaves two holes in opposite directions. the
#    emoji bundle walked into both:
#
#      src/emoji.zsh        `.zsh`, and `#!/usr/bin/env zsh` ends in "zsh",
#      src/emoji.test.zsh   which the regex does NOT match. so two of this
#                           bundle's three implementation files were parsed by
#                           NOBODY, behind a green tally
#
#      …/skills/emoji.get.sh  a ZSH file with a `.sh` extension, so it was
#                             parsed by BASH. it holds `${${(f)HITS}%%…}`,
#                             which only zsh can evaluate
#
#    ⚠️ the second is the subtler one, and it fails BOTH ways. `bash -n` does
#    not evaluate a `${…}` body, so a broken zsh expansion passes — a false ✔.
#    and a zsh-only STRUCTURE (`always { }`, `foreach … end`) would make bash
#    reject a correct file — a false ✋, which is the direction that gets a
#    check silenced (`gotcha.a-check-that-cries-wolf-gets-silenced`).
#
#    ⇒ an EXTENSION is not an interpreter, and a file's own shebang is the one
#      declaration of which parser owns it. so the shebang picks the parser,
#      and the extension is only a fallback for a file that carries none
#
# ✔ .this reader was SEEN to discriminate, in both directions
#    a check proven one way is half proven
#    (`gotcha.a-check-that-cries-wolf-gets-silenced`, `.the corollary`), so it
#    ran against a two-file fixture:
#
#      a valid `.zsh` whose body is `} always { … }`  → SPARED
#        (`bash -n` rejects that file with rc=2 — measured — so a bash-only
#         reader goes red on correct code, once it discovers the file at all)
#
#      a BROKEN zsh under a `.sh` name                → FLAGGED, and the row
#        named the parser: `✋ … (parsed by zsh)`. that is emoji.get.sh's exact
#        shape, which a bash-only reader mis-parses
######################################################################

# .what = which interpreter owns this file — `bash`, `zsh`, or empty for none
# .why  = read from the shebang first, since that is the file's own declaration.
#         an extension is a weaker tell and is consulted only where no shebang
#         names an interpreter
interpreter_of() {
  local file="$1" first=""
  { read -r first < "$file"; } 2>/dev/null || true

  case "$first" in
    '#!'*zsh*)  echo zsh;  return 0 ;;
    '#!'*bash*) echo bash; return 0 ;;
  esac

  # a shebang that names `sh` (never `zsh`/`bash`) is posix — bash parses it
  if [[ "$first" =~ ^#!.*(/sh|[[:space:]]sh)$ ]]; then
    echo bash
    return 0
  fi

  # no shebang, or one this skill does not own (a python kitten, say).
  # fall back to the extension
  case "$file" in
    *.zsh) echo zsh  ;;
    *.sh)  echo bash ;;
    *)     echo ""   ;;
  esac
}

# .what = parse one file with the interpreter that owns it, name it either way
# .why  = a silent pass hides which files were even looked at, so a shrunken
#         glob would read as success (rule.forbid.failhide)
check() {
  local file="$1" lang="$2"
  local out

  ####################################################################
  # ⚠️ a box with no zsh SKIPS, loudly, rather than falls back to bash
  #
  #    a fallback would parse a zsh file with bash and report ✔ — the exact
  #    false ✔ this repair exists to close, re-created by the handler for its
  #    own edge case. `2.5.zsh` installs zsh, so this is near-unreachable on a
  #    converged box; where it fires, the skip is counted and printed at the
  #    end, so it can never read as a pass (`rule.forbid.failhide`)
  ####################################################################
  if [[ "$lang" == zsh ]] && ! command -v zsh >/dev/null 2>&1; then
    SKIPPED=$(( SKIPPED + 1 ))
    [[ "$QUIET" -eq 1 ]] || echo "   🌙 ${file#"$ROOT"/} — zsh is absent, so its parser is too"
    return 0
  fi

  CHECKED=$(( CHECKED + 1 ))
  if out=$("$lang" -n "$file" 2>&1); then
    [[ "$QUIET" -eq 1 ]] || echo "   ✔ ${file#"$ROOT"/}"
    return 0
  fi
  echo "   ✋ ${file#"$ROOT"/} (parsed by $lang)" >&2
  echo "$out" | sed 's/^/        /' >&2
  BROKEN=$(( BROKEN + 1 ))
  return 1
}

# .what = is this file shell?
# .why  = an extension is not the only tell. the payloads this repo installs into
#         `~/.local/bin` carry NO extension — `kitty_snap_lowbatt`,
#         `machine_usage_snapshot` — because a human types them as commands. a
#         `-name '*.sh'` filter skips every one of them, silently, and still
#         prints a green tally (`rule.forbid.failhide`).
#
#         ⇒ so it delegates to `interpreter_of`, and the two questions — is this
#           mine, and who parses it — cannot disagree. two readers over one set
#           cost a miss on 2026-08-14
#           (`gotcha.a-check-that-cries-wolf-gets-silenced`, m.9)
is_shell() {
  [[ -n "$(interpreter_of "$1")" ]]
}

######################################################################
# 🛑 .why `.cache` is PRUNED, and what its absence cost — measured 2026-08-13
#
#    `rhx rmsafe` does not delete; it MOVES the file into a trash under
#    `.agent/.cache/…/skill=rmsafe/trash/`, which is gitignored. so the walk of
#    `.agent` below descended into it and parsed every file this repo had ever
#    deleted.
#
#    the tell: the ptyxis bundle (4 files) was deleted, and this skill reported
#    the SAME 399 files before and after. a count that cannot fall when code is
#    deleted does not measure the code.
#
#    ⚠️ and the failure direction is the bad one. a syntax error in a DELETED
#    file would fail this verify — a ✋ against a file no machine will ever
#    source, which is the false-✋ that decays into a silenced check
#    (`gotcha.a-check-that-cries-wolf-gets-silenced`).
#
#    ⇒ the subject is what a machine SOURCES. a cache is not that, and neither
#      is a trash can. `node_modules` and `.git` are pruned for the same reason
######################################################################
PRUNE=( -name .git -o -name .cache -o -name node_modules -o -name .log -o -name .temp )

# .what = walk one subtree
# .why  = `find` is used rather than a glob because `**` expands ONE level
#         without `globstar`, and that shrink is silent — the exact defect this
#         skill exists to stop a caller from re-introduction
walk() {
  local dir="$1" depth="${2:-}" label="$3"
  [[ -d "$dir" ]] || return 0
  [[ "$QUIET" -eq 1 ]] || echo "  $label"
  local file lang
  while IFS= read -r file; do
    # ⚠️ ONE call, and its answer is both the filter and the parser choice. two
    #    calls could disagree, silently — see `is_shell`
    lang="$(interpreter_of "$file")"
    [[ -n "$lang" ]] || continue
    check "$file" "$lang"
  # shellcheck disable=SC2086
  done < <(find "$dir" $depth \( "${PRUNE[@]}" \) -prune -o -type f -print | sort)
  [[ "$QUIET" -eq 1 ]] || echo ""
}

# .what = walk every shell file this repo SHIPS, as git lists them
# .why  = "ships" means "tracked", and git holds that set already. a second
#         declaration of it is free to drift — see the 📜 at the caller
#
# ⚠️ the LABEL is derived from the path, never typed. a group header typed here
#    would be a third declaration of the tree's shape, and a new top-level dir
#    would land under a stale heading with no signal
walk_tracked() {
  local file lang label last=""
  while IFS= read -r file; do
    # 🛑 the index says a path; the disk may not hold it. count and report
    #
    # ⚠️ but count ONLY what would have been SUBJECT. `interpreter_of` reads a
    #    shebang, so it needs the file — and an absent file cannot be classified
    #    by the one test this reader trusts. an absent `.md` was never in scope,
    #    and to count it would redden this reader over a doc it does not read
    #    (`gotcha.a-check-that-cries-wolf-gets-silenced` — a false ✋ decays into
    #    a silenced check)
    #
    #    ⇒ the NAME is the only evidence left, so `.sh` is the bound. RESIDUE,
    #      stated: an absent shell file with NO extension (`src/machine/*` are
    #      seven such) is invisible to this count. the honest close is that the
    #      name is a weaker test than the shebang, never that it is the same one
    #
    # 🛑 `-e`, not `-f` — they answer DIFFERENT questions, and to fuse them
    #    reports a tracked DIRECTORY as absent. measured 2026-09-02 on `.radio`,
    #    a tracked symlink at a dir: a false ✋ that never clears on any box.
    #    the 📜 lives in `dox.verify`'s sweep, where it was found
    if [[ ! -e "$ROOT/$file" ]]; then
      [[ "$file" == *.sh ]] && GONE=$(( GONE + 1 ))
      continue
    fi
    [[ -f "$ROOT/$file" ]] || continue   # a dir holds no shell to parse
    # ⚠️ ONE call, its answer both the filter and the parser choice — as in `walk`
    lang="$(interpreter_of "$ROOT/$file")"
    [[ -n "$lang" ]] || continue
    if [[ "$QUIET" -eq 0 ]]; then
      label="${file%/*}"
      [[ "$label" == "$file" ]] && label="."     # a file at the repo root
      label="${label%%/*}"
      [[ "$label" == "." ]] && label="<repo root> — what a stranger curls first"
      if [[ "$label" != "$last" ]]; then
        [[ -n "$last" ]] && echo ""
        echo "  $label"
        last="$label"
      fi
    fi
    check "$ROOT/$file" "$lang"
  done < <(git -C "$ROOT" ls-files)
  [[ "$QUIET" -eq 1 ]] || echo ""
}

if [[ "${#PATHS[@]}" -gt 0 ]]; then
  ####################################################################
  # a narrowed run — the caller named the subtrees
  ####################################################################
  for p in "${PATHS[@]}"; do
    walk "$ROOT/$p" "" "$p"
  done
else
  ####################################################################
  # 🛑 THE CORPUS IS `git ls-files`, AND NOT A LIST OF ROOTS
  #
  #    this header claims "every shell file this repo SHIPS". SHIPS means
  #    TRACKED, and git already holds that set — so the reader asks git rather
  #    than re-declares the answer.
  #
  # 📜 .measured 2026-09-02 — five hand-written roots, and one file outside all
  #    they read: `src` (maxdepth 1), `src/machine`, `src/grove.provision`,
  #    `.agent`, `.play/permanent`. each was added the day a file under it went
  #    unparsed behind a green verdict — the bundle tree on 2026-07-30, the
  #    `~/.local/bin` payloads on 2026-07-31, the tracked plays when they moved
  #    out of `.agent/`.
  #
  #    the sixth was `grove.bootstrap.sh`, at the REPO ROOT — the one file a
  #    stranger `curl`s, and the only shell file no root reached.
  #
  #    ⚠️ `wire.verify` carves that same file in BY NAME, so one reader held it
  #      and the other could not see it. one fact, two holders, and the holder
  #      with no name for the file is the one that drifted in silence
  #      (`gotcha.a-check-that-cries-wolf-gets-silenced`, m.9).
  #
  #    ⇒ this is the shape `rule.require.one-command-provision` grades a blocker:
  #      a hand-written list "cannot report the member nobody added". a sixth
  #      root would close ONE gap and keep the shape that produced all six. so
  #      there is no list, and the two readers derive one corpus from one store.
  #
  # ⚠️ `.play/temporary` still drops out, and for a REASON rather than by luck:
  #    it is gitignored, so it is not shipped, so `git ls-files` never names it.
  #    a directory walk earns that by omission; this reader earns it by
  #    definition.
  #
  # 🛑 an ABSENT tracked file is COUNTED and REPORTED, never skipped in silence
  #    a set with two stores has two true answers: the index lists a path, the
  #    disk may not hold it. a `-f` guard that just `continue`s reports ✔ over
  #    files it never opened (`gotcha.a-check-that-cries-wolf-gets-silenced`,
  #    q13 — the same defect `wire.verify` measured on 2026-08-31, at 197 files)
  ####################################################################
  walk_tracked
fi

if [[ "$CHECKED" -eq 0 ]]; then
  echo "🌲 checked 0 files — the glob matched none, so this proves no claim" >&2
  echo "   fix: confirm the tree is there — ls $ROOT/src" >&2
  exit 2
fi

######################################################################
# ⚠️ a SKIP is printed beside the verdict, never folded into it
#
#    `$CHECKED` counts files a parser actually read. a skipped file is in
#    neither the pass nor the fail column, so a run with skips must say so —
#    otherwise "all N parse" is true of N and silent about the rest
#    (`rule.forbid.failhide`)
######################################################################
if [[ "$SKIPPED" -gt 0 ]]; then
  echo "   🌙 $SKIPPED zsh file(s) went unparsed — zsh is absent on this box"
  echo "      ⇒ they are neither passed nor failed below"
  echo "      fix: grove.provision --what 2.5.zsh --mode apply"
fi

######################################################################
# 🛑 an ABSENT tracked file BLOCKS the verdict — it does not annotate it
#
#    a skip above is a file this reader OPENED and chose not to parse, so the
#    count it is absent from is still honest. a GONE file was never opened at
#    all, and the index and the disk disagree about whether it is part of the
#    subject — so "all N parse" is a claim about a set nobody can name.
#
#    ⇒ exit 2, and say what to reconcile. a ✔ here would be the q13 false ✔
#      `wire.verify` measured over a quarter of its corpus on 2026-08-31
######################################################################
if [[ "$GONE" -gt 0 ]]; then
  echo "" >&2
  echo "⚠️ $GONE tracked file(s) are ABSENT from disk and were NOT read" >&2
  echo "   ⇒ the index and the tree disagree about the subject, so this" >&2
  echo "     verdict covers $CHECKED files and says none about those $GONE" >&2
  echo "   read why: git status --short" >&2
  echo "🌲 syntax: $CHECKED files parsed, and $GONE could not be opened —" >&2
  echo "   so the sweep proves no claim" >&2
  echo "   fix: reconcile the index with the tree, then re-run" >&2
  exit 2
fi

if [[ "$BROKEN" -eq 0 ]]; then
  echo "🌲 syntax: all $CHECKED files parse ✔"
  exit 0
fi
echo "🌲 syntax: $BROKEN of $CHECKED files do NOT parse (each named above)" >&2
exit 1

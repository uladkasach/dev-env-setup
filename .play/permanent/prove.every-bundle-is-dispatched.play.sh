#!/usr/bin/env bash
######################################################################
# .what = two directions of one invariant, read out of the checkout:
#   1. every entrypoint the tree declares is REACHABLE from the root
#   2. every `bundle.upgrade <slug>` names a function some file declares
#
# 🛑 .why direction 1 is silent
#   - `grove.provision._.sh` sources every file under `$BUNDLE_DIR`, at every depth
#   - a phase file's function is DECLARED whether or not any `_.sh` calls it
#   - the runtime resolves a slug to a function by name:
#
#       bundle.fn.of  2.8.tmux.provision.upsert
#         → grove_provision_2_8_tmux_provision_upsert
#
#   - a bundle's own `_.sh` states which phases run:
#
#       grove_provision_2_8_tmux() {
#         bundle.upgrade 2.8.tmux.provision.upsert
#         bundle.upgrade 2.8.tmux.provision.verify
#         …
#       }
#
#   - a phase whose line is absent from `_.sh` is sourced, declared, and never called
#   - it fails silent: no error, no ✋
#   - the run prints its other phases and still ends `🌲 grove.provision done`
#   - the box never got that phase's work
#   - `rule.forbid.failhide` names this: the run reports convergence that did not happen
#   - `--mode plan` reports what RAN, so it cannot see a phase that never ran
#
# ⚠️ .why direction 2 earns a row though it is loud
#   - a dispatch with no declaration hits the runtime's step 2 and prints `✋ <slug> — undeclared`
#   - a static read costs no box and no apply
#   - a renamed phase file produces both defects at once: the stale dispatch line dangles, the fresh file is dead
#
# .why this is a TWO-LIST clamp, not a collapse
#   - the filesystem declares what a bundle HOLDS
#   - the `_.sh` declares the ORDER its phases run in
#   - order is not derivable from filenames: `2.2.git` runs provision before configure on purpose, `6.apps` dispatches 6.1 → 6.3 → 6.4 → 6.5 → 6.2 on purpose (`.order` block, in file)
#   - a phase body has to live in a file, so neither list can be dropped
#   - follows the `PKG_APT_ENV` precedent: clamp a correct second declaration rather than collapse it (`rule.require.identical-bundle-composition`, `rule.require.every-function-has-a-driver`)
#
# .the rows
#   V   an entrypoint the tree declares that the root cannot reach  — SILENT
#   G   a dispatch whose function no file declares                  — loud
#
# guarantee:
#   - READ-ONLY: reads the checkout, touches no box state
#   - STATIC: no network, no privilege, same answer on every box
#
# usage:
#   rhx git.grove.send <grove> --reply --within 300 \
#     --play prove.every-bundle-is-dispatched
######################################################################
set -uo pipefail

FAILED=0
_fail() { FAILED=1; }

######################################################################
# .what = the tree root defaults to the play's OWN checkout, not a hardcoded path
#
# ⚠️ .why
#   - a hardcoded `$HOME/git/more/dev-env-setup` names MAIN's checkout on every box
#   - a local run from a worktree measured a tree under nobody's hand: 📜 false ✔ on 2026-07-30, false ✋ on 2026-08-14
#   - a prior version cited two plays as its record and its clamp; neither is in this checkout
#   - `rhx play.run --list` names every play that exists, and holds three
#   - a pointer at a guard is not a guard (`gotcha.my-own-note-became-my-evidence`)
#   - the measurement stays HERE, inline: it is a fact about the world this code governs
#   - the clamp is OWED, named as debt rather than fact
######################################################################
_self="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." 2>/dev/null && pwd)" || _self=""
if   [[ -n "$_self" && -f "$_self/src/grove.provision._.sh" ]];            then _root="$_self"
elif [[ -f "$PWD/src/grove.provision._.sh" ]];                             then _root="$PWD"
elif [[ -f "$HOME/git/more/dev-env-setup.wip/src/grove.provision._.sh" ]]; then _root="$HOME/git/more/dev-env-setup.wip"
else                                                                           _root="$HOME/git/more/dev-env-setup"
fi
TREE_DEFAULT="$_root/src/grove.provision"
TREE="${1:-$TREE_DEFAULT}"

######################################################################
# .what = the function name a slug resolves to — the runtime's own derivation
#
# .why
#   - reads `bundle.fn.of` rather than re-implementing it
#   - a change to the runtime's mapping cannot leave this reader judging a stale rule
######################################################################
_fn_of() { printf 'grove_provision_%s\n' "${1//./_}"; }

######################################################################
# .what = every ENTRYPOINT the tree declares — `<fn>\t<file>`
#
# an entrypoint = a function the runtime can ask for by slug, two derived shapes:
#
#   a bundle   its name equals the fn of some directory's basename
#   a phase    its name ends in one of the four phase suffixes
#
# ⚠️ .why the classifier matters
#   - a bundle file may declare OPERATIONS under the same prefix, e.g. `grove_provision_2_8_tmux_plugin_root`, and 14 more in `5.12.rack`
#   - its own phases call those operations, so they need no dispatch
#   - the classifier must not report them
#   - neither shape above matches them
######################################################################
_declared() {
  local tree="$1" d f fn

  # the fn of every directory in the tree — the bundle shape
  local dirfns=" "
  while IFS= read -r d; do
    dirfns="$dirfns$(_fn_of "$(basename "$d")") "
  done < <(find "$tree" -mindepth 1 -type d | sort)

  while IFS= read -r f; do
    while IFS= read -r fn; do
      [[ -n "$fn" ]] || continue
      case "$fn" in
        *_provision_upsert|*_provision_verify|*_configure_upsert|*_configure_verify) ;;
        *) [[ "$dirfns" == *" $fn "* ]] || continue ;;
      esac
      printf '%s\t%s\n' "$fn" "$f"
    done < <(grep -hoE '^grove_provision_[A-Za-z0-9_]+\(\)' "$f" 2>/dev/null | sed 's/()$//')
  done < <(find "$tree" -name '*.sh' -type f | sort)
}

######################################################################
# .what = every dispatch the tree states — `<parent-slug>\t<child-slug>\t<file>:<line>`
#
# .why the PARENT is the dir's basename, not the fn name
#   - a dispatch line's authority comes from the bundle whose dir it sits in
#   - that bundle has to be reached before its line can run
#   - the dir names that bundle, with no parse of the surrounding function
######################################################################
_dispatched() {
  local tree="$1" f parent
  while IFS= read -r f; do
    parent="$(basename "$(dirname "$f")")"
    grep -nE '^[[:space:]]*bundle\.upgrade[[:space:]]+[A-Za-z0-9._]+' "$f" 2>/dev/null |
      awk -F: -v p="$parent" -v file="$f" '
        { line = $1
          $1 = ""
          n = split($0, w, /[ \t]+/)
          printf "%s\t%s\t%s:%s\n", p, w[n], file, line }'
  done < <(find "$tree" -name '*.sh' -type f | sort)
}

######################################################################
# .what = the slugs the root can reach — a closure over the dispatch graph
#
# .why the seed is the FILESYSTEM, not a list
#   - the root is the one depth with no `_.sh`
#   - `grove.provision._.sh` globs `$BUNDLE_DIR/*/` and `sort -V`s it
#   - every top-level dir is a root
#   - a reader that expects a root dispatcher walks an EMPTY tree and calls all 251 references ghosts
#   - 📜 2026-08-13: measured that empty walk; `repo.overview.md` had claimed such a file for six weeks
######################################################################
_reachable() {
  local tree="$1" d slug child parent kid
  declare -A kids=()
  declare -A seen=()

  while IFS=$'\t' read -r parent kid _; do
    kids["$parent"]="${kids[$parent]:-} $kid"
  done < <(_dispatched "$tree")

  local queue=()
  for d in "$tree"/*/; do
    [[ -d "$d" ]] || continue
    queue+=("$(basename "$d")")
  done

  while [[ ${#queue[@]} -gt 0 ]]; do
    slug="${queue[0]}"
    queue=("${queue[@]:1}")
    [[ -n "${seen[$slug]:-}" ]] && continue
    seen["$slug"]=1
    for child in ${kids[$slug]:-}; do
      [[ -n "${seen[$child]:-}" ]] || queue+=("$child")
    done
  done

  for slug in "${!seen[@]}"; do printf '%s\n' "$slug"; done
}

######################################################################
# .what = the typed rows, for one tree
######################################################################
_read() {
  local tree="$1" fn file parent kid where slug

  # the fns the root can reach — a phase slug resolves through the same map
  local reachfns=" "
  while IFS= read -r slug; do
    reachfns="$reachfns$(_fn_of "$slug") "
  done < <(_reachable "$tree")

  # ⚠️ .why no suffix arithmetic here
  #    - a PHASE is reached by its own slug, spelled in full by its parent (e.g. `2.8.tmux.provision.upsert`)
  #    - the closure already holds it
  local declaredfns=" "
  while IFS=$'\t' read -r fn file; do
    declaredfns="$declaredfns$fn "
    [[ "$reachfns" == *" $fn "* ]] && continue
    printf 'V\t%s\t%s\n' "$fn" "$file"
  done < <(_declared "$tree")

  while IFS=$'\t' read -r parent kid where; do
    fn="$(_fn_of "$kid")"
    [[ "$declaredfns" == *" $fn "* ]] && continue
    printf 'G\t%s\t%s\n' "$kid" "$where"
  done < <(_dispatched "$tree")
}

echo "🔭 prove: every bundle and phase the tree declares is reached by the root"
echo "   tree: $TREE"
echo ""

######################################################################
# direction 0 — the SCOPE, and the assumption every later row rests on
######################################################################
echo "── direction 0: the reader sees the tree it thinks it sees"
if [[ ! -d "$TREE" ]]; then
  echo "   ✋ no tree at $TREE"
  echo "      fix: rhx git.grove.push <grove> --from . --into git/more/dev-env-setup --mode apply"
  exit 1
fi

N_DIRS="$(find "$TREE" -mindepth 1 -type d | wc -l)"
N_ROOTS="$(find "$TREE" -mindepth 1 -maxdepth 1 -type d | wc -l)"
N_DECL="$(_declared "$TREE" | wc -l)"
N_DISP="$(_dispatched "$TREE" | wc -l)"
N_REACH="$(_reachable "$TREE" | wc -l)"

echo "   ├─ bundle dirs:   $N_DIRS  (top level: $N_ROOTS)"
echo "   ├─ entrypoints:   $N_DECL"
echo "   ├─ dispatches:    $N_DISP"
echo "   └─ reached slugs: $N_REACH"

if [[ "$N_DIRS" -lt 30 || "$N_DECL" -lt 90 || "$N_DISP" -lt 90 || "$N_REACH" -lt 30 ]]; then
  echo "   ✋ one of those reads is too small to be the real tree"
  echo "      ⇒ an empty read is the failure a bare loop cannot tell from a clean run"
  echo "      fix: confirm the checkout is complete, then re-run"
  _fail
else
  echo "   ✔ the reads are the size of a real tree"
fi

######################################################################
# .what = every dispatch inside the tree must be a LITERAL slug
#
# ⚠️ .why
#   - a `bundle.upgrade "$var"` is invisible to this reader
#   - a bundle reached only that way reports as dead
#   - the one variable dispatch is the root's own glob, in `grove.provision._.sh`, outside this tree
######################################################################
VAR_DISP="$(grep -rnE '^[[:space:]]*bundle\.upgrade[[:space:]]+["$]' "$TREE" 2>/dev/null | wc -l)"
if [[ "$VAR_DISP" -ne 0 ]]; then
  echo "   ✋ $VAR_DISP dispatch(es) inside the tree take a VARIABLE, not a literal"
  grep -rnE '^[[:space:]]*bundle\.upgrade[[:space:]]+["$]' "$TREE" 2>/dev/null | sed 's/^/      | /'
  echo "      ⇒ a static reader cannot follow those, so its verdict would be a guess"
  echo "      fix: spell the slug, or teach this play how that dispatch resolves"
  _fail
else
  echo "   ✔ every dispatch in the tree names a literal slug"
fi
echo ""

######################################################################
# direction 1 + 2 — the real tree
######################################################################
echo "── direction 1: every entrypoint is reached, and every dispatch is declared"
ROWS="$(_read "$TREE")"

N_V="$(printf '%s\n' "$ROWS" | grep -c '^V' || true)"
N_G="$(printf '%s\n' "$ROWS" | grep -c '^G' || true)"

if [[ "$N_V" -eq 0 && "$N_G" -eq 0 ]]; then
  echo "   ✔ all $N_DECL entrypoints are reached, and all $N_DISP dispatches are declared"
else
  printf '%s\n' "$ROWS" | while IFS=$'\t' read -r kind what where; do
    [[ -n "$kind" ]] || continue
    case "$kind" in
      V) echo "   ✋ $what is declared and the root reaches it by no path"
         echo "      | $where"
         echo "      ⇒ it is sourced, so it is silent: no run calls it, and none says so"
         echo "      fix: add its \`bundle.upgrade\` line to the owning bundle's _.sh" ;;
      G) echo "   ✋ $what is dispatched, and no file declares its function"
         echo "      | $where"
         echo "      ⇒ the runtime prints '$what — undeclared' and fails the phase"
         echo "      fix: add the file, or drop the dispatch line" ;;
    esac
  done
  echo "   ⇒ $N_V unreached, $N_G undeclared"
  _fail
fi
echo ""

######################################################################
# .what = direction 2 — a phase's FN NAME and its FILE NAME are one fact
#
# 🛑 .why this is a clamp, not a style note
#   - the runtime resolves a phase by FUNCTION NAME (`bundle.fn.of`)
#   - it does not care which file the body sits in — every `*.sh` under the bundle dir is sourced
#   - a phase body moved into `_.sh` runs correctly, dispatches correctly, and reports as reached by direction 1
#   - a reader keyed on FILENAME instead goes blind to that phase, with no signal
#   - an ungated `sudo` in such a body sits in no row a filename-keyed reader prints (m.12: a subject in a form no pattern matches produces no row, and the count never moves)
#
# 🛑 .why the three plays cited here were a false EXISTENCE claim
#   - a prior version named `prove.sudo-is-gated-or-nonintera`, `prove.every-upsert-is-verified`, and `prove.apt-is-never-interactive` as live readers this direction protects
#   - `rhx play.run --list` names three plays, and none of the three is on that list
#   - the blindness argument still holds: a filename-keyed reader still goes blind, and this direction still clamps it
#   - the EXISTENCE claim was false — the harder half to catch, since a reader who checks the argument finds it sound and never checks whether the cited files exist (`gotcha.my-own-note-became-my-evidence`)
#   - the three are OWED, stated as debt
#   - until they exist, this direction protects a set of filename-keyed readers whose size is ZERO
#   - its value: the invariant stands ready for the first one written
#
# 📜 2026-08-14: 138 phase files, every one declares its phase in the file its suffix names — asserted by nobody, cheapest to clamp
#
# ⚠️ .why one-way
#   - the direction demands a phase FN live in the file its suffix names
#   - it says no word about a file that declares no phase at all
#   - an `_.sh` full of operations is correct and common (`5.12.rack` declares 14)
######################################################################
_misplaced() {
  local tree="$1" fn file want
  while IFS=$'\t' read -r fn file; do
    case "$fn" in
      *_provision_upsert) want='provision.upsert.sh' ;;
      *_provision_verify) want='provision.verify.sh' ;;
      *_configure_upsert) want='configure.upsert.sh' ;;
      *_configure_verify) want='configure.verify.sh' ;;
      *) continue ;;
    esac
    [[ "$(basename "$file")" == "$want" ]] && continue
    printf '%s\t%s\t%s\n' "$fn" "$file" "$want"
  done < <(_declared "$tree")
}

echo "── direction 2: every phase fn sits in the file its suffix names"
MISPLACED="$(_misplaced "$TREE")"
if [[ -z "$MISPLACED" ]]; then
  echo "   ✔ every phase fn sits in the file its suffix names"
else
  while IFS=$'\t' read -r fn where want; do
    [[ -n "$fn" ]] || continue
    echo "   ✋ $fn is declared outside $want"
    echo "      | $where"
    echo "      ⇒ the runtime finds it either way, so this fails no run — and three"
    echo "        plays that read the tree BY FILENAME go blind to this phase"
    echo "      fix: move the body into $want, beside its bundle's other phases"
  done < <(printf '%s\n' "$MISPLACED")
  _fail
fi
echo ""

######################################################################
# .what = direction 3 — the reader discriminates
#
# ⚠️ .why a fixture, not a claim
#   - the three plays written before this one each gave a FALSE verdict on their first run
#   - the play was the defect in every case
#   - a reader that flags each planted shape and leaves the correct bundle alone is the only evidence a green direction 1 means the tree is clean (`gotcha.a-check-that-cries-wolf-gets-silenced`, `.the corollary`)
######################################################################
echo "── direction 3: it flags each planted shape, and leaves the correct one alone"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

T="$WORK/t"

# 9.good — a correct bundle: one phase, declared and dispatched
mkdir -p "$T/9.good"
cat > "$T/9.good/_.sh" <<'EOF'
grove_provision_9_good() {
  bundle.upgrade 9.good.provision.upsert
}
EOF
cat > "$T/9.good/provision.upsert.sh" <<'EOF'
grove_provision_9_good_provision_upsert() { :; }
EOF

# 9.dead — a phase file its own _.sh never names: the SILENT shape
mkdir -p "$T/9.dead"
cat > "$T/9.dead/_.sh" <<'EOF'
grove_provision_9_dead() {
  bundle.upgrade 9.dead.provision.upsert
}
EOF
cat > "$T/9.dead/provision.upsert.sh" <<'EOF'
grove_provision_9_dead_provision_upsert() { :; }
EOF
cat > "$T/9.dead/configure.upsert.sh" <<'EOF'
grove_provision_9_dead_configure_upsert() { :; }
EOF

# 9.ghost — a dispatch with no file behind it: the LOUD shape
mkdir -p "$T/9.ghost"
cat > "$T/9.ghost/_.sh" <<'EOF'
grove_provision_9_ghost() {
  bundle.upgrade 9.ghost.configure.verify
}
EOF

# 9.nest — a CHILD dir its parent never dispatches
mkdir -p "$T/9.nest/9.1.seen" "$T/9.nest/9.2.lost"
cat > "$T/9.nest/_.sh" <<'EOF'
grove_provision_9_nest() {
  bundle.upgrade 9.1.seen
}
EOF
cat > "$T/9.nest/9.1.seen/_.sh" <<'EOF'
grove_provision_9_1_seen() { :; }
EOF
cat > "$T/9.nest/9.2.lost/_.sh" <<'EOF'
grove_provision_9_2_lost() { :; }
EOF

# 9.oper — an OPERATION declared beside the entrypoint; it needs no dispatch,
# flagging it cries wolf
mkdir -p "$T/9.oper"
cat > "$T/9.oper/_.sh" <<'EOF'
grove_provision_9_oper_plugin_root() { :; }
grove_provision_9_oper() {
  bundle.upgrade 9.oper.provision.verify
}
EOF
cat > "$T/9.oper/provision.verify.sh" <<'EOF'
grove_provision_9_oper_provision_verify() { :; }
EOF

# 9.stray — a phase BODY in `_.sh` instead of the file its suffix names
#   - it dispatches, is declared, and RUNS
#   - directions 1 and 3's other arms all pass it
#   - only direction 2 can see it
mkdir -p "$T/9.stray"
cat > "$T/9.stray/_.sh" <<'EOF'
grove_provision_9_stray_provision_upsert() { :; }
grove_provision_9_stray() {
  bundle.upgrade 9.stray.provision.upsert
}
EOF

FIX_ROWS="$(_read "$T")"
echo "   the reader's rows for the fixture:"
printf '%s\n' "$FIX_ROWS" | sed 's/^/      | /'

_want() {
  local kind="$1" what="$2" why="$3" esc
  esc="$(printf '%s' "$what" | sed 's/[.[\*^$]/\\&/g')"
  # ⚠️ .why `grep -E … >/dev/null`, never `grep -qE`
  #    - `-q` exits at the first match, the producer takes SIGPIPE, pipefail turns that into 141 (`gotcha.pipefail-grep-q`)
  #    - a MATCH is the PASS here, so a false 141 reports this reader as blind to a fixture it caught
  #    - the loop below has the opposite polarity: there a match is the failure
  #    - a direction-3 arm that lies in either sense is worse than an absent one
  if printf '%s\n' "$FIX_ROWS" | grep -E "^$kind"$'\t'"$esc"$'\t' >/dev/null; then
    echo "   ✔ $why"
  else
    echo "   ✋ it did NOT flag $what — $why"
    _fail
  fi
}

_want V grove_provision_9_dead_configure_upsert  "a phase file no _.sh names reads as unreached"
_want G 9.ghost.configure.verify                "a dispatch with no file reads as undeclared"
_want V grove_provision_9_2_lost                 "a child dir no parent dispatches reads as unreached"

for CLEAN in grove_provision_9_good \
             grove_provision_9_good_provision_upsert \
             grove_provision_9_oper \
             grove_provision_9_oper_provision_verify \
             grove_provision_9_oper_plugin_root \
             grove_provision_9_1_seen; do
  if printf '%s\n' "$FIX_ROWS" | grep "$CLEAN" >/dev/null; then
    echo "   ✋ it flagged $CLEAN, which is correct as written — a false ✋"
    _fail
  fi
done
echo "   ✔ the correct bundle, its phase, a reached child, and an operation are all spared"

######################################################################
# ⚠️ .why the direction-2 arms ride in this same fixture
#   - `9.stray` dispatches, is declared, and is reached — invisible to every arm above
#   - direction 1 has no row for it, and the CLEAN loop above never names it
#   - an arm that only planted it would prove no property at all (`gotcha.a-check-that-cries-wolf-gets-silenced`, m.8: an arm satisfied incidentally is indistinguishable from one satisfied on purpose)
######################################################################
FIX_MISPLACED="$(_misplaced "$T")"
if printf '%s\n' "$FIX_MISPLACED" \
     | grep 'grove_provision_9_stray_provision_upsert' >/dev/null; then
  echo "   ✔ a phase body in _.sh reads as misplaced, though it dispatches and runs"
else
  echo "   ✋ it did NOT flag 9.stray's phase — a body in _.sh escapes three plays"
  _fail
fi

for CLEAN in grove_provision_9_good_provision_upsert \
             grove_provision_9_oper_provision_verify \
             grove_provision_9_oper_plugin_root \
             grove_provision_9_1_seen; do
  if printf '%s\n' "$FIX_MISPLACED" | grep "$CLEAN" >/dev/null; then
    echo "   ✋ it called $CLEAN misplaced, and it is where it belongs — a false ✋"
    _fail
  fi
done
echo "   ✔ a phase in its own file, an operation, and a bundle fn are all spared"
echo ""

######################################################################
# the verdict
######################################################################
if [[ "$FAILED" -eq 0 ]]; then
  echo "✔ every bundle and phase the tree declares is reached by the root,"
  echo "  and every phase fn sits in the file its suffix names"
  echo "   ⇒ and the reader was seen to flag each planted shape, and to spare each"
  echo "     correct one — the arms are named above, so no count here can go stale"
  exit 0
fi

echo "✋ the dispatch and the filesystem disagree — each row above names its fix"
echo "   ⇒ a V row is the SILENT half: that phase runs on no box, and no run says so"
exit 1

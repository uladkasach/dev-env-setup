#!/usr/bin/env bash
######################################################################
# grove.provision — THE root dispatch
#
######################################################################
# THE WHOLE FRAMEWORK, IN ONE PICTURE
######################################################################
#
#   a grove's state is a TREE OF BUNDLES. that tree is the directory tree:
#
#     src/grove.provision/                 ← THE TREE. it needs no `.bundles`
#     │                                     suffix: a grove's state IS a tree of
#     │                                     bundles, so the dir under
#     │                                     `grove.provision` can only be that
#     ├── 2.shell/                        ← a bundle
#     │   ├── _.sh                          its body: dispatches its children
#     │   └── 2.6.starship/               ← a bundle
#     │       ├── _.sh                      its body: dispatches its children
#     │       ├── provision.upsert.sh     ← a bundle. makes the binary exist
#     │       ├── provision.verify.sh     ← a bundle. proves the binary runs
#     │       ├── configure.upsert.sh     ← a bundle. makes the config exist
#     │       └── configure.verify.sh     ← a bundle. proves the config is read
#     └── 4.terminal/                     ← a bundle
#         └── 4.3.kitty/ ...
#
#   there is ONE operation, and it is the same at every depth:
#
#     bundle.upgrade <slug>     look up the function the slug names. call it.
#
#   a bundle's BODY does one of two things, and the runtime does not care which:
#
#     dispatch      bundle.upgrade <child>      (a bundle made of bundles)
#     do the work   pkg_install, cp, infocmp    (a bundle that acts)
#
#   there are NO node kinds. no leaf, no composite, no tag, no tally. a phase is
#   a bundle. a section is a bundle. turtles all the way down.
#
#   this file is the ROOT of that tree. it holds no list of work: it reads the
#   top-level bundle DIRECTORIES and dispatches each in numeric order. the
#   filesystem IS the inventory, so there is no second list to drift from it.
#
######################################################################
# WHAT EACH PIECE DECIDES
######################################################################
#
#   | question                        | answered by                          |
#   |---------------------------------|--------------------------------------|
#   | which bundles run?              | this file (the dirs) + `--what`      |
#   | does this bundle apply HERE?    | the bundle's own body, via a         |
#   |                                 | `grove_env_*` predicate             |
#   | may this bundle WRITE?          | the runtime, from the slug's verb:   |
#   |                                 | `upsert` writes, `verify` reads      |
#   | what is this machine?           | `grove.env.sh`, derived once        |
#   | did anything fail?              | this file's exit code                |
#
#   applicability is the bundle's OWN business, always. a parent that gated a
#   child would hold a claim it cannot justify: kitty's terminfo entry works on a
#   headless box and kitty itself does not, and only those two bundles know that.
#
######################################################################
# usage
######################################################################
#   bash grove.provision._.sh                        # derive local vs cloud
#   bash grove.provision._.sh --for cloud            # force the headless subset
#   bash grove.provision._.sh --mode plan            # account for it, write none
#   bash grove.provision._.sh --what 2.shell         # one section
#   bash grove.provision._.sh --what 2.6.starship    # one bundle, and its phases
#   bash grove.provision._.sh --what 4.3             # by number, same slug
#
#   bash grove.provision._.sh --include codium       # opt into ONE app of 6.apps
#   bash grove.provision._.sh --include codium,slack # comma-joined, or repeatable
#
#   rhx grove.provision --from tree --mode apply     # the same, from a worktree
#
# ⚠️ .`--what` and `--include` ask DIFFERENT questions, and a run may need both
#      `--what`    = which bundles run
#      `--include` = of a bundle that already runs, does the human want its app
#
#      only `6.apps` reads the second: its five bundles install a human's desktop
#      clients, which are a PREFERENCE rather than a fact about the box, so a run
#      that names no app installs no app. every other bundle ignores it entirely
#      (`define.6-apps-is-laptop-only.md`, `GROVE_OPTIN_APPS` in bundle.upgrade.sh).
#
#      an `--include` that names an app the tree does not offer is REFUSED, with
#      the offered set printed — never absorbed into a run that installs none and
#      reports done
#
# guarantee:
#   - idempotent: every bundle is safe to re-drive
#   - resumable: a failed bundle is named with its fix, and the run carries on
#   - accounted: `--mode plan` names every bundle a run would touch, at every
#     depth, and still RUNS the verifies — because "what does this box already
#     hold?" is the most useful thing a plan can say
######################################################################
set -uo pipefail   # deliberately NOT -e: a bundle reports, then the run decides

######################################################################
# this run is UNATTENDED — declared once, for every bundle
#
# .why  = a bundle that puts a question to a human cannot converge — it stops. and
#         when a run's stdout is a pipe (a `| tail`, a log capture, a
#         `grove.send`) it stops with the question swallowed, so the driver looks
#         alive and emits not one line. so an unattended run declares itself
#         unattended, once, up front.
#
# ⚠️ .note = this guard belongs HERE, at the sole entrypoint, and that is load-bear.
#         when two entrypoints drive the same tree, a guard in one of them is a
#         guard in NEITHER — no reader can tell which one a given run took, so a
#         bundle comment that says "declared once at the driver" is true of one
#         and false of the other, and the guard is silently absent from every run
#         that used the other name. this repo paid for that lesson once, which
#         is why there is exactly one entrypoint
#         (rule.require.grove-provision-as-the-only-entrypoint).
#
# ⚠️ .note = these are a STANDING GUARD, not the cure for any diagnosed defect.
#         on 2026-07-29 `pnpm --version` hung in `ep_poll` on grove-1 and a
#         corepack prompt was ASSUMED to be the cause. the evidence refuted it:
#         the hang reproduced with stdout on a TTY and no prompt on screen. so
#         that hang's real cause is still OPEN — do not read these two lines as
#         its fix. they stay because the guard is right on its own terms
#
# .why HERE and not at each call site: a per-call fix is a second list, and a
#         second list drifts — this repo's most repeated defect.
#         `src/zshrc.sh` carries the CI=1 lesson, and a driver that declares it
#         nowhere inherits none of that — the drift in miniature. one
#         declaration at the top of the run covers every bundle — a bundle
#         invoked alone via `--what` too.
#
# .note = these say "assume yes", never "skip". they are the answer a human at
#         the keyboard would give, so no install is quietly dropped.
#
# ⚠️ .why the apt half is NOT here
#         a lone `export DEBIAN_FRONTEND=noninteractive`, as braces to
#         `PKG_APT_ENV`'s belt, is a HAND COPY of that array that drifts to ONE
#         of its three variables. the two it drops are
#         `DEBCONF_NONINTERACTIVE_SEEN` and, worse, `NEEDRESTART_MODE=a`.
#
#         ⇒ `NEEDRESTART_MODE` is the one that costs an hour. `grove.pkg.sh`
#           records the measurement: needrestart drew its interactive menu, held
#           the dpkg lock, and ate every command sent down the duct — 57 minutes.
#           so the braces cover the variable a bare apt is least likely to hang
#           on, and drop the one it hangs on hardest.
#
#         ⇒ that is `rule.require.identical-bundle-composition` in miniature,
#           and the trap is exact: such a block argues "a per-call fix is a
#           second list, and a second list drifts" while BEING the second list.
#           so the apt exports DERIVE from `PKG_APT_ENV` at the point that
#           array is sourced (below), and there is one declaration.
#
# ⚠️ .why `CI` stays here and the apt half does not
#         `CI` answers corepack and pnpm, which `grove.pkg.sh` never speaks to,
#         so it has no belt to derive from and no list to drift against.
######################################################################
export CI=1                             # corepack/pnpm: assume yes, never ask

######################################################################
# input
######################################################################
FOR="" MODE="apply" WHAT=() INCLUDE=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --for)  FOR="$2"; shift 2 ;;
    --what) WHAT+=("$2"); shift 2 ;;
    --mode) MODE="$2"; shift 2 ;;
    ##################################################################
    # `--include` — opt into an app the tree OFFERS but installs for nobody
    #
    # .why comma-split AND repeatable: a human types one or the other, and to
    #      accept only one form makes the other fail as an unknown app name —
    #      an error about a typo, for a shape that was never wrong
    ##################################################################
    --include)
      IFS=',' read -r -a __inc <<<"$2"
      INCLUDE+=("${__inc[@]}")
      unset __inc
      shift 2 ;;
    # `--help` prints this header, bounded by its own closing fence. a hardcoded
    # line range truncates silently the moment the header grows
    -h|--help) sed -n '3,/^#\{20,\}$/p' "${BASH_SOURCE[0]}"; exit 0 ;;
    --only) echo "✋ --only was renamed to --what" >&2
            echo "   fix: bash $0 --what $2 ${*:3}" >&2
            exit 2 ;;
    *) echo "✋ unknown arg: $1" >&2
       echo "   fix: one of --for cloud|local, --mode plan|apply," >&2
       echo "        --what <slug> (a slug names its whole subtree)," >&2
       echo "        or --include <app> (opt into an app the tree offers)" >&2
       exit 2 ;;
  esac
done

######################################################################
# where the sources are
#
# prefer the dir beside THIS file, so a pushed worktree upgrades a machine to its
# own branch with no clone at all
#
# .why it is EXPORTED as `GROVE_SRC`
#      several bundles declare a dotfile by COPY of a checked-in file — the zshrc,
#      the aliases, the tmux conf, the kitty icon. each needs to know where the
#      checkout is. answered per-bundle with
#      `${DEV_ENV_SETUP_DIR:-$HOME/git/more/dev-env-setup}`, that hardcoded
#      default is WRONG for a worktree run: the files copied come from
#      ~/git/more/dev-env-setup while the run comes from _worktrees/..., so a
#      pushed branch silently installs main's dotfiles.
#
#      so the run answers it ONCE, here, and every bundle reads the same answer —
#      the same rule the machine and the mode already follow. two derivations of
#      one fact is this repo's oldest defect
######################################################################
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="${DEV_ENV_SETUP_DIR:+$DEV_ENV_SETUP_DIR/src}"
SRC="${SRC:-$HERE}"
export GROVE_SRC="$SRC"

######################################################################
# the RUN's PATH — the box's own env, adopted before any bundle runs
#
# 🛑 .without this, ONE apply can never converge a box, and that is measured
#
#    without this the driver inherits whatever PATH its caller happens to hold,
#    and the caller is `ssh <seat> 'bash …grove.provision._.sh'` — a
#    NON-INTERACTIVE, NON-LOGIN shell, which reads no startup file at all. so
#    the run carries the stock `/usr/bin:/bin` and none of the dirs this repo
#    installs INTO:
#
#      ~/.local/bin              ← machine_resource_*, git-credential-keyrack
#      ~/.local/share/fnm        ← node
#      ~/.local/share/pnpm[/bin] ← rhx, and every global shim
#
#    the consequence is a whole class of FALSE ✋: a `provision.upsert` installs
#    a binary, and the `provision.verify` one line below reports it "absent from
#    PATH" — because the dir it landed in was never on this PROCESS's PATH.
#    measured 2026-08-12 on a fresh grove:
#
#      ground, apply #1  →  ✋ 7      ← every one a false ✋ of this shape
#      ground, apply #2  →  ✋ 0      ← "fixed" by a human who ran it twice
#
#    ⚠️ so the second apply was never idempotency. it was a DIFFERENT PATH —
#      the human's second invocation came from a shell that had read an rc. the
#      box was converged after run #1 and the RUN could not see it.
#
# ⇒ a run that judges the box must first hold the PATH the box actually serves.
#   `rule.require.one-command-provision` makes that a gate: one apply, or the
#   bundle tree has a defect.
#
# .why it SOURCES ~/.zshenv's declaration rather than restate it
#    `src/zshenv.sh` is where this repo declares the PATH a PROGRAM must read —
#    every dir, in one canonical order, with the measurements behind each. to
#    list them again here would be a second writer on one claim, and the day the
#    two disagree is the day a run measures a PATH no shell on the box serves
#    (`rule.forbid.two-writers-on-one-artifact`).
#
#    the file is POSIX — `[ -d ]`, `case`, `export` — so bash reads it exactly as
#    zsh does. it is guarded per-dir, so this source is idempotent.
#
# ⚠️ .why the CHECKOUT's copy and not `$HOME/.zshenv`
#    on a fresh box `~/.zshenv` does not exist yet: `2.5.zsh.configure` is what
#    puts it there, and that bundle has not run when this line does. the
#    checkout's copy is the declaration; the home copy is a product of it.
######################################################################
if [ -f "$HERE/zshenv.sh" ]; then
  # shellcheck source=/dev/null
  . "$HERE/zshenv.sh"
fi

# the package boundary must land before the first package ask. it asserts the
# debian-family invariant, so every install routes through one place
source "$HERE/grove.pkg.sh"

######################################################################
# the BRACES to `pkg_apt`'s belt — derived, never copied
#
# `pkg_apt` passes `PKG_APT_ENV` per-call, so every install that routes through
# the boundary is already unattended. this exports the SAME array process-wide,
# for the case the boundary cannot reach: a bundle that shells out to a deb tool
# directly, or a package whose post-install hook invokes one.
#
# 🛑 .why it is an expansion of the array and not a list of exports
#    the hand-written copy that stood at the top of this file drifted to one of
#    three variables, and stayed that way silently — a guarantee that drifts
#    HANGS, where a check that drifts merely reports
#    (`rule.require.every-function-has-a-driver`, `.the second question`).
#    an expansion cannot drift: there is one array, and both readers read it.
#
# ⚠️ so do NOT "clarify" this into three `export` lines. that is the defect,
#    rewritten in the form that caused it.
######################################################################
export "${PKG_APT_ENV[@]}"

# the wire boundary must land before the first fetch. a bare `curl` has NO
# total-time bound, so a stalled transfer waits forever — and a fresh box makes
# twelve fetches with no human to notice (`rule.require.one-command-provision`)
source "$HERE/grove.web.sh"

######################################################################
# the machine — derived ONCE, then read by any bundle that cares
#
# `grove_env_derive` EXPORTS its attributes, so a subshell at any tree depth
# reads the same machine. two derivations of one fact is this repo's oldest defect
######################################################################
source "$HERE/grove.env.sh"
source "$HERE/grove.for.sh"

grove_env_derive --for "$FOR" || exit 2
FOR="${FOR:-$(grove_for_detect)}"

if ! grove_for_valid "$FOR"; then
  echo "✋ --for must be 'cloud' or 'local' (got '$FOR')" >&2
  exit 2
fi

# the mode travels BESIDE the machine, never inside it: plan|apply is a property
# of THIS RUN, not of the box
export GROVE_MODE="$MODE"

######################################################################
# 🛑 a CONTRADICTED `--for` is a LENS, and a lens may not write
#
# .what = `--for` sets only the TIER; the platform comes from a probe alone. so
#         an override cannot name a new box class — it can only contradict the
#         one probed, and there are exactly two such pairs:
#
#           cloud@unix      a box with a desktop session, told to act headless
#           local@aws.ec2   a grove, told a human is at its keyboard
#
#         neither is a machine we own. each is the reader asking "what would the
#         OTHER kind of box get?", which is a legitimate PLAN and never an apply.
#
# .why it must halt on apply, measured 2026-09-03 (redteam round 24, F1/F1b)
#       - `--for cloud` on a laptop → `2.3.ssh` reads `== cloud@*`, installs the
#         `ssh` METAPACKAGE, and returns BEFORE the stop/disable/mask. its verify
#         rung 3 tests `!= cloud@*`, so the one check written to catch this goes
#         silent. end state: sshd on 0.0.0.0:22, enabled at boot, stock config
#       - `--for local` on a grove → the same gate falls the other way and MASKS
#         sshd on a headless box with no console. that is the duct, killed
#
# .why the halt is HERE and not in `grove_env_derive`
#       the block above states it: the mode is a property of this RUN, never of
#       the box. a mode test inside the derivation would put a run's fact inside
#       the machine's, which is the coupling that comment forbids
#
# ⚠️ an EMPTY natural tier means no probe ran — the caller named the box whole
#    via `GROVE_ENV_SERVER`, which `grove.env.sh`'s own fix-text calls the way to
#    override a wrong derivation. no probe answer exists to contradict, so this
#    gate has no subject and must stay silent
######################################################################
if [[ "$MODE" == "apply" && -n "$FOR" \
   && -n "${GROVE_ENV_TIER_NATURAL:-}" && "$FOR" != "$GROVE_ENV_TIER_NATURAL" ]]; then
  echo "✋ --for $FOR contradicts this box, and --mode apply may not act on a lens" >&2
  echo "" >&2
  echo "   the probe says:  $GROVE_ENV_TIER_NATURAL   (platform probed, not guessed)" >&2
  echo "   --for says:      $FOR" >&2
  echo "   so the run would converge this box as: $GROVE_ENV_SERVER" >&2
  echo "" >&2
  echo "   why this is refused rather than applied:" >&2
  echo "     bundles decide by a test of \$GROVE_ENV_SERVER, so a contradicted" >&2
  echo "     pair makes each one converge for a box that is not this one. on the" >&2
  echo "     ssh bundle that means a listener installed on a laptop, or sshd" >&2
  echo "     masked on a headless grove — a box with no console and no way back." >&2
  echo "" >&2
  echo "   fix — pick the one you meant:" >&2
  echo "     rhx grove.provision --for $FOR --mode plan   # the lens: what WOULD a $FOR box get" >&2
  echo "     rhx grove.provision --mode apply             # converge THIS box, as probed" >&2
  echo "" >&2
  echo "   and if the probe is wrong about this box, name it whole — that is the" >&2
  echo "   documented override, and it sets the platform too:" >&2
  echo "     GROVE_ENV_SERVER=cloud@aws.ec2 rhx grove.provision --mode apply" >&2
  exit 2
fi

######################################################################
# the runtime — `bundle.upgrade`, and no other verb
######################################################################
source "$HERE/bundle.upgrade.sh"

######################################################################
# the report is ONE stream
#
# ⚠️ .why fd 2 is folded onto fd 1, before a single line is printed
#      a bundle prints its structure lines to stdout and its ✋ verdicts to stderr.
#      over SSH those are two SEPARATE channels, flushed independently — and a
#      grove is only ever reached over ssh. so the two arrive interleaved by
#      accident of flush order, not by the order they were written.
#
#      measured on grove-1, 2026-07-30. a structure line landed INSIDE a fix
#      instruction and split it in half:
#
#             fix: pass the identity in, then re-run —      ← fd 2
#          ├─ 2.2.git.configure.verify                      ← fd 1, spliced in
#            export GIT_USER_EMAIL='jane.doe@gmail.com'     ← fd 2
#
#      a human reads that as a fix with no command. and two ✋ verdicts from an
#      earlier phase printed AFTER a later phase's ✔, so neither could be
#      attributed to the bundle that raised it.
#
# .why folded rather than each body moved to stdout
#      `>&2` on a verdict earns its place: it marks the line as a failure at the
#      point it is written, which is the honest spot to say so. the defect is not
#      that verdicts go to fd 2 — it is that the two fds are reordered in transit.
#      one `exec` fixes that for every body at once, and no body has to know.
#
# .why this is not a failhide
#      failhide is a failure that goes UNREPORTED. every ✋ still prints, still in
#      full, and still sets the run's exit code. this changes which fd carries it,
#      so that it prints where it belongs — beside the bundle that raised it
######################################################################
exec 2>&1

echo "🌱 grove.provision --mode $MODE"
echo "   ├─ $(grove_env_report)"
echo "   ├─ src: $SRC"
echo "   └─ bundles"

######################################################################
# source every bundle PHASE file, at every depth
#
# .why a RECURSIVE glob and not a list of names: a bundle is a DIRECTORY of files
#      that arrive together, so a hand-kept source list would be a second copy of
#      the same knowledge — and it would drift the first time somebody added a
#      bundle and forgot the line.
#
# .why source order does not matter: a file only DEFINES functions, and bash
#      resolves a callee at call time. EXECUTION order is set by the dispatch
#      below and by each body, never by this glob.
#
# 🛑 .why the basename is filtered to the five phase names
#      a bundle dir may ALSO hold a non-phase PAYLOAD file — a file its own
#      phase copies or execs, never a file meant to be sourced here
#      (`git-credential-keyrack.sh`, `emoji.index.build.sh`, and siblings).
#      such a file is free to hold top-level, unguarded code — a `case` on
#      `$1` that `exit`s, for one — because its own caller runs it as a
#      SUBPROCESS. sourced here instead, that same `exit` kills THIS shell,
#      before a single bundle can dispatch. so this loop sources only the
#      five names a bundle-phase file may ever carry; every other `*.sh` in
#      the tree is a payload, collocated for its bundle to copy/exec, not to
#      be swept.
#
# .note = `globstar` gives `**` its recursive sense; `nullglob` makes an empty dir
#         yield no iterations rather than the literal pattern. both are scoped and
#         restored, because a glob option left on changes every later line
######################################################################
BUNDLE_DIR="$SRC/grove.provision"
if [[ ! -d "$BUNDLE_DIR" ]]; then
  echo "✋ no bundles at $BUNDLE_DIR" >&2
  echo "   ├─ a grove's state IS its bundle tree, so there is no work to name" >&2
  echo "   └─ fix: confirm the checkout is complete, or re-push the worktree" >&2
  exit 1
fi

shopt -s nullglob globstar
for __f in "$BUNDLE_DIR/"**/*.sh; do
  case "${__f##*/}" in
    _.sh|provision.upsert.sh|provision.verify.sh|configure.upsert.sh|configure.verify.sh)
      source "$__f"
      ;;
  esac
done
unset __f
shopt -u nullglob globstar

######################################################################
# hand `--include` to the runtime, and REFUSE a name the tree does not offer
#
# 🛑 .why the refusal is here, and BEFORE the dispatch
#      an app name that matches no bundle would otherwise decline every bundle
#      that could have served it, and the run would print 🌲 done with exactly
#      what a run carrying no flag installs. the human asked for an app, got
#      none, and was told the box converged (`rule.forbid.failhide`).
#
#      ⚠️ it is checked BEFORE any bundle runs, unlike `--what`'s MISSED check,
#      which cannot answer until the last bundle has been offered its slug. the
#      offered set is known the moment every bundle file has been sourced, so
#      the typo is caught before the run does work it will have to explain
#      (`rule.prefer.prevent-over-correct`).
#
# ⚠️ the valid set is READ from `GROVE_OPTIN_APPS`, which the bundles just
#    appended to. it is never listed here — see that array's declaration
######################################################################
GROVE_INCLUDE=("${INCLUDE[@]}")

if [[ ${#GROVE_INCLUDE[@]} -gt 0 ]]; then
  UNOFFERED=()
  for __one in "${GROVE_INCLUDE[@]}"; do
    __ok=""
    for __app in "${GROVE_OPTIN_APPS[@]}"; do
      [[ "$__one" == "$__app" ]] && { __ok=1; break; }
    done
    [[ -n "$__ok" ]] || UNOFFERED+=("$__one")
  done
  unset __one __app __ok

  if [[ ${#UNOFFERED[@]} -gt 0 ]]; then
    echo "" >&2
    echo "✋ --include named no app this checkout offers: ${UNOFFERED[*]}" >&2
    echo "   ⇒ every bundle would decline it, and the run would report done" >&2
    echo "     with only what a run carrying no --include installs" >&2
    echo "   the apps this checkout offers:" >&2
    while read -r __a; do
      [[ -n "$__a" ]] && echo "     $__a" >&2
    done < <(printf '%s\n' "${GROVE_OPTIN_APPS[@]}" | sort)
    unset __a
    echo "   fix: name one of those, comma-joined or repeated:" >&2
    echo "     rhx grove.provision --include codium,slack --mode apply" >&2
    exit 2
  fi
fi

######################################################################
# the dispatch — the top-level bundles, in numeric order
#
# .why read from the FILESYSTEM and not from a list here
#      the directory tree is already the declaration. a list in this file would be
#      a second one, and a bundle added without its line would be dead code that
#      no run reports (rule.require.bundle-as-sole-declaration).
#
# .why `sort -V` and not plain sort
#      lexical order puts `10.x` before `2.x`. the number is a tree PATH, so it
#      must sort as a version does, or the run order silently stops matching the
#      order the numbers declare
######################################################################
shopt -s nullglob
ROOTS=()
for __d in "$BUNDLE_DIR"/*/; do ROOTS+=("$(basename "$__d")"); done
unset __d
shopt -u nullglob

while read -r __slug; do
  [[ -n "$__slug" ]] || continue
  bundle.upgrade "$__slug"
done < <(printf '%s\n' "${ROOTS[@]}" | sort -V)
unset __slug

######################################################################
# did every `--what` reach a bundle?
#
# ⚠️ .why this check exists
#      the scope test skips a slug no `--what` matches, so a `--what` that names
#      no bundle — a typo, or a bare function name from before its concern was a
#      bundle — ran ZERO bundles and this file then printed "🌲 done" and exited 0.
#      the human asked for work, none happened, and the run said it converged
#      (rule.forbid.failhide).
#
#      it is checked HERE and not in the runtime because only the whole run knows
#      the answer: an entry may legitimately match no slug until the last
#      top-level bundle has been offered it
######################################################################
if [[ ${#WHAT[@]} -gt 0 ]]; then
  MISSED=()
  for __i in "${!WHAT[@]}"; do
    [[ -n "${BUNDLE_WHAT_HIT[$__i]:-}" ]] || MISSED+=("${WHAT[$__i]}")
  done
  unset __i

  if [[ ${#MISSED[@]} -gt 0 ]]; then
    echo "" >&2
    echo "✋ --what named no bundle: ${MISSED[*]}" >&2
    echo "   ⇒ zero bundles ran for it, so this run did NO work it was asked for" >&2
    echo "   ⇒ a bare function name is the usual cause. every concern is a bundle" >&2
    echo "     slug now (e.g. '2.8.tmux', not 'configure_tmux')" >&2
    echo "   the top-level bundles on this checkout:" >&2
    printf '     %s\n' "${ROOTS[@]}" >&2
    echo "   a slug at any depth is accepted, and it runs its ancestors too:" >&2
    echo "     rhx grove.provision --what 2.8.tmux --mode plan" >&2
    exit 2
  fi
fi

######################################################################
# the outcome
#
# .why one bit and not a count: each bundle already named its own outcome and its
#      fix, where it happened. a count at the end was what let a parent's `0` read
#      as coverage its children never had
######################################################################
echo ""
if [[ "$BUNDLE_FAILED" -ne 0 ]]; then
  echo "✋ grove.provision finished with failures — each is named above, with its fix" >&2
  exit 1
fi
echo "🌲 grove.provision done — $(grove_env_report)"

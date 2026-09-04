#!/usr/bin/env bash
######################################################################
# .what = install a tree's configs onto this machine
#
# .why  = the `grove.provision.*` aliases live in the shell ALREADY loaded, so a
#         fix to them cannot apply itself — a chicken+egg. (the loaded alias
#         hardcodes main and ignores DEV_ENV_SETUP_DIR; that fix ships in the
#         very file it will not copy.) this skill breaks the cycle: it copies
#         straight from the tree it lives in, and leans on no loaded alias.
#
#         also the way to install a tree's configs and try them here before
#         the branch merges.
#
# usage:
#   rhx grove.provision                        # plan, from this tree
#   rhx grove.provision --mode apply           # apply, from this tree
#   rhx grove.provision --from main            # plan, from the main checkout
#   rhx grove.provision --from main --mode apply
#
# .the --from axis = WHICH COPY OF THE REPO the configs are read out of
#
#   tree   this worktree — this branch, unmerged edits included (default)
#   main   ~/git/more/dev-env-setup — the checkout that tracks main
#
#   `--version local|global` is retired, and it was wrong twice over:
#     - `version` named a PLACE, when a version is `v1.2.3`. `--version global`
#       never meant "the published version"; it meant "the other directory"
#     - `local` collided with `--for local|cloud` on the provision commands beside
#       it, where local means "a machine with a screen and a human".
#       one word, two unrelated concepts, one vocabulary
#
#   `main|tree` is the pair this repo speaks everywhere else (`git tree set
#   --from main`, `git release main`, `duct://grove-1/main/...`), itemized at
#   term=main and term=tree.
#
# guarantee:
#   - --from tree (default) copies from THIS worktree (branch-safe)
#   - --from main copies from ~/git/more/dev-env-setup
#   - plan mode by default (safe preview)
#   - config half only (no tools) — headless safe, no desktop/GUI
#   - idempotent: re-run to refresh
######################################################################
set -o pipefail

MODE="plan"
FROM="tree"
# every flag this skill does not own is FORWARDED to the driver, so `--for`,
# `--what`, and whatever the driver grows later all work through the skill on
# the day they land — with no edit here. a passthrough that must be re-listed
# is a second list, which is the defect this skill was rewritten to remove
PASS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode) MODE="$2"; shift 2 ;;
    --from) FROM="$2"; shift 2 ;;
    # the retired flag fails loud and NAMES its replacement, rather than map
    # quietly onto it. a silent alias keeps two vocabularies alive — the exact
    # defect the rename removes (rule.require.errors-name-the-fix)
    --version)
      echo "✋ --version is retired; the flag is --from" >&2
      case "${2:-}" in
        local)  echo "   └─ fix: --from tree   (this worktree)" >&2 ;;
        global) echo "   └─ fix: --from main   (the main checkout)" >&2 ;;
        *)      echo "   └─ fix: --from tree|main" >&2 ;;
      esac
      echo "      why: a version is v1.2.3; this names a PLACE — and 'local'" >&2
      echo "           collided with '--for local|cloud' (a machine KIND)" >&2
      exit 2
      ;;
    -h|--help)
      echo "grove.provision - install the tree onto this machine"
      echo ""
      echo "usage: rhx grove.provision [--from tree|main] [--mode plan|apply] [driver flags]"
      echo ""
      echo "  --from tree   from THIS worktree, this branch included (default)"
      echo "  --from main   from ~/git/more/dev-env-setup (the main checkout)"
      echo "  --mode plan   list the steps, run none (default)"
      echo "  --mode apply  install — tools AND configs"
      echo ""
      echo "  every other flag goes to grove.provision._.sh, e.g."
      echo "    --for cloud|local     force the machine kind (else auto-detected)"
      echo "    --what <slug>         run just that bundle subtree; repeatable"
      exit 0
      ;;
    # rhachet forwards its own --skill/--repo/--role flags; ignore them
    --skill|--repo|--role) shift 2 ;;
    *) PASS+=("$1"); shift ;;
  esac
done

# pick the source checkout
case "$FROM" in
  tree)
    # the worktree this skill lives in — no hardcoded path, no loaded alias
    SRC="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)/src"
    ;;
  main)
    SRC="${DEV_ENV_SETUP_DIR:-$HOME/git/more/dev-env-setup}/src"
    ;;
  *)
    echo "✋ --from must be 'tree' or 'main' (got '$FROM')" >&2
    echo "   ├─ tree  this worktree, this branch included" >&2
    echo "   └─ main  ~/git/more/dev-env-setup" >&2
    exit 2
    ;;
esac

if [[ ! -d "$SRC" ]]; then
  echo "💥 src/ not found at $SRC" >&2
  exit 1
fi

######################################################################
# drive THE entrypoint — never a second list
#
# .why  = this skill once carried its own array of 7 config file pairs and
#         copied them itself. that was a SECOND implementation of a verb the
#         repo already owns, and it was a strict subset: configs only, no
#         tools. so `rhx grove.provision` on a fresh grove installed dotfiles
#         onto a box with no node, no nvim, and no claude — and reported
#         `cowabunga! <the old noun> installed`, a full-green success line.
#
#         that is the exact drift `install_env._.sh` was written to end (it
#         retired a separate `install_env.grove.sh` for the same reason), and
#         the exact defect `rule.require.grove-provision-as-the-only-verb`
#         forbids. a machine got a confident green for a tree it did not have.
#
#         the driver is already idempotent, already step-tagged (`any` /
#         `local` / `cloud`), and already auto-detects which machine it is on.
#         there was no gap to fill — only a list to delete.
#
# .what  this skill adds, and all it adds: the `--from` axis. the loaded
#         `grove.provision` alias reads from the main checkout, so a fix to the
#         aliases cannot install itself; this drives the SAME driver out of a
#         chosen checkout, which is what makes a branch testable before merge.
######################################################################
DRIVER="$SRC/grove.provision._.sh"
# ⚠️ a checkout older than the rename has ONLY the deprecated name, so this
#    fallback is what keeps `--from main` alive while main is behind this branch.
#    re-verified 2026-07-31 with `git ls-tree --name-only origin/main src/`:
#    main holds `install_env._.sh` + 10 `pt*.sh`, and NONE of this branch's
#    runtime (`grove.provision._.sh`, `bundle.upgrade.sh`, `grove.{for,env,pkg}.sh`).
#    so the line still carries weight TODAY.
#
#    ⚠️ re-run that command before you trust this note — a dated claim about
#       another branch is only true on its date (rule.require.trust-but-verify).
#
#    it dies the moment this branch merges — `install_env._.sh` was deleted here,
#    and a fallback to a path that exists in NO checkout is a branch no run takes
#    while it reads as a compatibility shim somebody must preserve.
[[ -f "$DRIVER" ]] || DRIVER="$SRC/install_env._.sh"
if [[ ! -f "$DRIVER" ]]; then
  echo "💥 no driver at $DRIVER" >&2
  echo "   └─ fix: confirm the checkout is complete — git -C $(dirname "$SRC") status" >&2
  exit 1
fi

echo "🐚 grove.provision --from $FROM --mode $MODE"
echo "   ├─ from: $SRC"
echo "   └─ drive $(basename "$DRIVER")"
echo ""

# DEV_ENV_SETUP_DIR pins the driver's own source lookup to the checkout the
# caller chose, so `--from tree` cannot silently read main's files partway
DEV_ENV_SETUP_DIR="$(dirname "$SRC")" bash "$DRIVER" --mode "$MODE" ${PASS[@]+"${PASS[@]}"}

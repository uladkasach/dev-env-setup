#!/usr/bin/env bash
######################################################################
# git.grove.provision — the ONE entrypoint to raise a grove and gate it
#
# .what = a dispatcher over two verbs, and no third:
#
#           boot   put a bare box into acceptance-grade   (writes)
#           test   ask whether it holds                   (reads)
#
# .why ONE entrypoint = the two halves are a pair, and a split invited a
#         caller to re-state its callee's subject. measured 2026-08-30: the
#         gate halted at `0. box` and printed a correct, per-rung reason;
#         the driver then printed its OWN sentence underneath naming the
#         BOX — and the cause was a lapsed credential on the laptop
#         (`gotcha.a-check-that-cries-wolf-gets-silenced`, m.4).
#
#         with one entrypoint there is no second file to keep in step.
#
# ⚠️ .the verb is `boot`, never `init`. `init` is a forbidden synonym of
#         bootstrap (`term=grove.bootstrap._.choice._.md`), and it is
#         spoken-for by route initiation.
#
# ⚠️ .the slug is NOUN-FIRST, and that is deliberate. `rule.require.treestruct`
#         asks `[verb][...noun]` of a MECHANISM — a function, a type, a file.
#         an `rhx` slug is a different artifact: it is a NAMESPACE ADDRESS,
#         and its job is to group under one `<TAB>` prefix. so an rhx command
#         is `[noun][...subnoun][verb]`, which is why `git.grove.*` keeps
#         fourteen commands together where `wake.git.grove` would scatter them.
#
# usage:
#   rhx git.grove.provision boot <name>                    # plan — name the steps
#   rhx git.grove.provision boot <name> --mode apply
#   rhx git.grove.provision test <name>                    # the gate
#   rhx git.grove.provision help
#
# guarantee:
#   - dispatches via exec, so the subskill owns the process and its exit code
#   - exit 2 = no verb, or a verb this dispatcher does not hold
######################################################################
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── find the verb ANYWHERE in the vector, never at `$1`
#
# 🛑 rhachet INJECTS `--skill <slug>` ahead of the caller's own args, so `$1`
#    is an injected flag on every invocation and no `$1` test can ever fire.
#    ten skills in this dir carried that defect at once; the worst of them took
#    `help` as a positional and planned work against a box of that name. read
#    `$*`, and pad it so `helpdesk` is not read as a help request.
VERB=""
ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --skill|--repo|--role) shift 2 ;;
    boot|test) [[ -z "$VERB" ]] && VERB="$1" || ARGS+=("$1"); shift ;;
    *) ARGS+=("$1"); shift ;;
  esac
done

# ── a verb ROUTES help to its own subskill; only a bare help lands here
if [[ -z "$VERB" ]] && { [[ " ${ARGS[*]-} " == *" help "* ]] \
  || [[ " ${ARGS[*]-} " == *" --help "* ]] || [[ " ${ARGS[*]-} " == *" -h "* ]]; }; then
  echo "git.grove.provision — raise a grove, then gate it"
  echo ""
  echo "usage:"
  echo "  rhx git.grove.provision boot <name> [--mode plan|apply] [--from N] [--trust tofu|replace]"
  echo "  rhx git.grove.provision test <name> [--upto N]"
  echo ""
  echo "the verbs:"
  echo "  boot   bare box -> acceptance-grade, in ONE apply per seat  (writes)"
  echo "  test   the gate: box, tree, deps, fixture, suite            (reads)"
  echo ""
  echo "boot runs test as its last step, with no command in between — that gap"
  echo "is the bar rule.require.one-command-provision exists to hold."
  exit 0
fi

if [[ -z "$VERB" ]]; then
  echo "✋ git.grove.provision needs a verb" >&2
  echo "" >&2
  echo "  fix: name one —" >&2
  echo "    rhx git.grove.provision boot <name> --mode apply" >&2
  echo "    rhx git.grove.provision test <name>" >&2
  echo "" >&2
  echo "  see them all:  rhx git.grove.provision help" >&2
  exit 2
fi

SUB="$HERE/git.grove.provision.$VERB.sh"
[[ -f "$SUB" ]] || {
  echo "✋ git.grove.provision holds no '$VERB' — $SUB is absent" >&2
  exit 2
}

exec bash "$SUB" "${ARGS[@]}"

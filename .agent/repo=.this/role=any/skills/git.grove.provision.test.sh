#!/usr/bin/env bash
######################################################################
# git.grove.provision test — can this box do the work? power it on and find out.
#
# ⚠️ reached through the dispatcher: `rhx git.grove.provision test <name>`.
#    `git.grove.provision.sh` execs this file; it carries no slug of its own.
#
#    `smoketest` names the CONCEPT this gate performs (`term=smoketest`), never
#    a second entrypoint to it.
#
# .what = THE ACCEPTANCE GATE for a grove. it drives one real job end to end —
#         its ORG'S service integration suite, at latest origin/main — and
#         reports whether the box completed it.
#
# 🛑 .the target tree is PER-ORG, and it is DERIVED, never assumed
#         the box declares its org in its own checkout; `_target_repo_for_org`
#         maps that to the tree. an org with no arm halts, and never inherits
#         another org's service (`rule.require.a-grove-reaches-its-own-org-only`)
#
#           0. box      — git.grove.ready.verify rungs 1..5 (registry→creds)
#           1. tree     — the repo is cloned, and synced to latest origin/main
#           2. deps     — pnpm install
#           3. fixture  — the testdb is provisioned, schema applied
#           4. suite    — git.repo.test --what integration, tallied green
#
# .why a SMOKETEST and not another verify = the word is literal. you power the
#         thing on and watch for smoke: it asks CAPABILITY, never correctness.
#         and the two verbs part company on one line —
#
#           verify     READS state and asserts a verdict. it mutates none.
#           smoketest  ESTABLISHES its preconditions, then EXERCISES the box.
#
#         that write is the whole point. `git.grove.ready.verify` HALTS when deps
#         are absent and names the fix, which is right for a diagnostic and
#         useless as a gate: its verdict then depends on who ran what by hand
#         beforehand. this establishes every precondition itself, so the same
#         command on the same box always answers the same question.
#
# ⚠️ .why it may WRITE, when `rule.forbid.repair-plays` forbids exactly that
#         that rule binds PLAYS, and binds them because a play that moves a box
#         toward the DECLARED TREE STATE is a second entrypoint beside
#         `grove.provision`. none of what this writes is grove state:
#
#           node_modules   workspace state — the tree declares node + pnpm,
#                          never any one repo's installed tree
#           the testdb     a TEST FIXTURE — a container built to be torn down
#           the checked-out ref  fixture freshness, not a provisioned fact
#
#         and the line is enforced rather than merely asserted: when the TREE
#         ITSELF is absent this refuses to clone it and halts naming
#         `5.10.repos`, because the clone IS bundle-owned. see step 1.
#
# .why LATEST main, and not a pinned sha = a target's main is green by
#         invariant — cicd gates it. so `latest main` is a fixed point that
#         needs no keeper, where a pin goes stale and needs one.
#
#         ⚠️ the invariant is INHERITED, so read a failure with it in mind: if
#         main ever ships red, this gate blames the box for the target's defect.
#         that is the known cost of the choice. step 4 says so in its halt.
#
#         ⚠️ it is also a BAR on what may be declared a target: a tree whose
#         main is not cicd-gated green makes this gate report on that tree
#         rather than on the box.
#
# usage:
#   rhx git.grove.provision test <name>
#   rhx git.grove.provision test <name> --of <org>/<repo>
#   rhx git.grove.provision test <name> --from 4        # re-run just the suite
#
# options:
#   --of      org/name of the tree to exercise; default = the arm this grove's
#             own declared org carries in `_target_repo_for_org`
#             (NOT `--repo` — rhachet injects that one into every skill it runs)
#   --from    first step to run; default 0
#
# guarantee:
#   - exit 0 = the box did the work — it is an acceptance-grade grove
#   - exit 3 = a step did not hold; it is named, with its fix
#   - exit 2 = bad input
#   - exit 1 = malfunction
#
# .note = step 4 judges the TALLY, never the exit code alone. a suite that
#         reports `0 passed` and exits 0 has proven no test at all, and to read
#         that as green is `rule.forbid.failhide`.
######################################################################
set -uo pipefail

# ⚠️ read the whole ARG VECTOR, never `$1` — rhachet injects `--skill <slug>` ahead
#    of the caller's args, so a `$1` test never fires (measured 2026-08-30; ten
#    skills in this dir carried it, and each read `help` as its SUBJECT instead)
if [[ " $* " == *" help "* || " $* " == *" --help "* || " $* " == *" -h "* ]]; then
  echo "git.grove.provision test — can this box do the work? power it on and find out."
  echo ""
  echo "usage:"
  echo "  rhx git.grove.provision test <name> [--of org/name] [--from N]"
  echo ""
  echo "the steps:"
  echo "  0. box      — git.grove.ready.verify rungs 1..5 (registry→creds)"
  echo "  1. tree     — cloned, and synced to latest origin/main"
  echo "  2. deps     — pnpm install"
  echo "  3. fixture  — testdb provisioned, schema applied"
  echo "  4. suite    — git.repo.test --what integration, tallied green"
  echo ""
  echo "it ESTABLISHES each precondition rather than assume it, so the same"
  echo "command on the same box always answers the same question."
  echo ""
  echo "the TARGET is per-org: the box declares its org in its own checkout,"
  echo "and an org with no declared arm halts rather than borrow another's."
  echo "exit 0 = acceptance-grade | 3 = a step failed | 2 = bad input"
  exit 0
fi

GROVE=""
REPO=""
FROM=0

######################################################################
# 🛑 `--repo` belongs to RHACHET, so this skill's own flag is `--of`
#
# 📜 measured 2026-08-31. this loop matched `--repo` FIRST and stripped a name
#    rhachet never emits (`--repo-rhx`). rhachet injects `--repo <slug>` into
#    every skill it runs, so the injected slug landed in `$REPO` —
#
#      REPO=.this  →  REPO_NAME=.this  →  TREE_DIR=git/.this
#
#    and the gate then cloned, installed, and tested a repo nobody named. it
#    reported on a SUBJECT the caller did not choose, with no line to say so.
#
# ⇒ so the strip names the three flags rhachet really injects
#   (`--skill`, `--repo`, `--role`), as `git.grove.send`'s loop does — one
#   idiom, one shape (`rule.forbid.two-writers-on-one-artifact`).
#
# ⚠️ .why a `--repo org/name` HALTS rather than works
#    a caller who types it would otherwise be silently dropped onto the default
#    repo — the same wrong-subject defect, arrived at from the other side.
#    rhachet's own value is a bare slug and never holds a `/`, so the two are
#    told apart with certainty, and the human gets `--of` by name
#    (`rule.require.errors-name-the-fix`).
######################################################################
while [[ $# -gt 0 ]]; do
  case "$1" in
    --of)   REPO="$2"; shift 2 ;;
    --from) FROM="$2"; shift 2 ;;
    --repo)
      if [[ "${2:-}" == */* ]]; then
        echo "✋ '--repo' is rhachet's flag, not this skill's — use '--of'" >&2
        echo "   rhx git.grove.provision test $GROVE --of $2" >&2
        exit 2
      fi
      shift 2 ;;
    --skill|--role) shift 2 ;;
    --) shift; [[ -z "$GROVE" ]] && { GROVE="${1:-}"; shift 2>/dev/null || true; } ;;
    -*) echo "✋ unknown flag '$1'" >&2; exit 2 ;;
    *) [[ -z "$GROVE" ]] && GROVE="$1"; shift ;;
  esac
done

if [[ -z "$GROVE" ]]; then
  echo "✋ usage: rhx git.grove.provision test <name>" >&2
  echo "   list them: rhx git.grove.list" >&2
  exit 2
fi
if ! [[ "$FROM" =~ ^[0-4]$ ]]; then
  echo "✋ --from must be 0-4" >&2
  exit 2
fi

# the transport, shared with git.grove.ready.verify so the two cannot drift
# (`rule.forbid.two-writers-on-one-artifact`)
source "$(dirname "${BASH_SOURCE[0]}")/git.grove.operations.sh"

# ⚠️ NOT /tmp. a log left there outlives every memory of why it was written.
#    the state dir is where a per-machine artifact belongs, and it is where
#    `git.grove.wake` already keeps its tunnel log.
LOGDIR="${XDG_STATE_HOME:-$HOME/.local/state}/git.grove.provision.test/$GROVE"
mkdir -p "$LOGDIR"

######################################################################
# halt — name the step, why it did not hold, and the command that repairs it
######################################################################
halt() {
  local step="$1" label="$2" why="$3"; shift 3
  echo "      └─ ✋ step $step ($label) does not hold"
  echo ""
  echo "  why: $why"
  echo "  fix:"
  local line
  for line in "$@"; do echo "    $line"; done
  echo ""
  echo "  then run again from here —"
  echo "    rhx git.grove.provision test $GROVE --of $REPO --from $step"
  exit 3
}

_in_range() { [[ "$1" -ge "$FROM" ]]; }

# .what = drive a command ON the box, and get ITS verdict
#
# .why `--reply` — it is BOTH halves at once
#       a smoketest WRITES, unlike every other grove read, so it wants the duct:
#       a step here installs deps and runs a suite, and the duct is what survives
#       a disconnect mid-job. it ALSO needs the real exit code, which a default
#       send discards (`gotcha.the-duct-returns-the-send-not-the-answer`).
#
# ⚠️    a step OFF the duct — `--bare`, with a bespoke `--why` — trades the
#       survival property away to buy a verdict. `--reply` gives both, so
#       neither the trade nor the exemption survives
#       (`rule.forbid.exemption-as-habit`).
#
# .note `--within` is generous, since step 4 runs a full integration suite.
#
######################################################################
# 🛑 .why a reserved exit 97 is read here, exactly as `_ask_at` reads it
#
# a falsy return from here is read as "the step failed ON THE BOX", and every
# halt below names a repair for the box on that basis. but a duct is tmux, and a
# send is a keystroke into ONE pane — so a pane another job already holds
# refuses the send outright, and the command never runs at all.
#
# ⚠️ .measured 2026-08-13 on `_ask_at`, and the cost was a wrong fix
#    a backgrounded `git.grove.provision test` still held the pane when a second one was
#    started. every probe in the second run was refused, and the ladder halted
#    with `seat '…' holds src/ but no package.json beside it` — over a file that
#    was present the whole time, 610 bytes, listed on that box one command
#    later (`gotcha.a-check-that-cries-wolf-gets-silenced`).
#
#    that landed on `_ask_at` because a verify probes more than it drives. this
#    helper has the identical shape, so it had the identical defect, and it was
#    fixed alongside rather than left to be found the expensive way.
#
# ⇒ `git.grove.send --reply` reserves exit **97** for every transport fault it
#   has — refused, quiet, bound elapsed, rc unreadable. 97 ⇒ it never ran ⇒ a
#   halt, instead of a claim against a step that was never attempted. every
#   other code IS the command's own, and is returned untouched.
#
# ⚠️ .why not a marker line in the command
#    a marker wrapper reads `{ cmd ; } && echo __TRUE__ || echo __FALSE__`.
#    `--what` takes ONE step, and the send's guard refuses `;`, `&&`, and `||`
#    in its raw text — so such a wrapper can never be delivered, and the
#    knowledge belongs at the send in any case
#    (`rule.require.solve-at-cause`).
######################################################################
_drive() {
  local cmd="$1"

  # ⚠️ resolved into a variable, and its fault RE-RAISED. inline in a `$( )` the
  #    `exit 3` that `_shell_at` uses to halt kills only the subshell, so the
  #    substitution yields an empty string and this drives on with no shell at
  #    all — see the same repair in `_ask_at` (`rule.forbid.failhide`)
  local shell
  shell="$(_shell_at "$GROVE")" || exit 3
  [[ -n "$shell" ]] || exit 3

  ####################################################################
  # 🛑 `bash "$_grove_ops_send"`, NEVER `rhx git.grove.send` — THIS CAPTURES
  #
  # `--reply`'s contract is that its stdout carries the command's own output
  # and no other byte. `rhx` does not preserve it: the runner writes its own
  # `🪨 run solid skill …` banner to STDOUT before the skill is reached.
  #
  # so a caller that CAPTURES through `rhx` gets the banner prepended to every
  # answer. downstream that is silent corruption, not a visible break:
  #
  #   · the suite tally greps this output, and now greps a banner too
  #   · an EMPTY reply arrives as a non-empty string, so the `-n "$out"` arm
  #     below can never see the empty case
  #
  # ⚠️ `rhx` stays exactly right for a HUMAN at a keyboard — the banner is the
  #    point there. the split is by CALLER, not by preference: a capture must
  #    invoke the file as an executable; a human invokes the skill.
  #
  # 📜 .measured 2026-09-02, and the miss is the shape this file's own header
  #    warns about, one screen up
  #
  #   the round-18 repair moved `_ask_at` and `_shell_at` off `rhx` in
  #   `git.grove.operations.sh:550,679` and left THIS helper on it. `:224-226`
  #   above reads *"this helper has the identical shape, so it had the
  #   identical defect, and it was fixed alongside rather than left to be
  #   found the expensive way"* — written about the 97 repair, true of that
  #   one, and false of this one in the same function
  #   (`gotcha.a-check-that-cries-wolf-gets-silenced`, m.9: one transport,
  #   three callers, and a fix that reached two).
  #
  # ⇒ `$_grove_ops_send` is resolved and readability-checked once, in
  #   `git.grove.operations.sh:81`, which this file sources at `:157` — so
  #   there is ONE declaration of where the send lives, not three.
  ####################################################################
  # ⚠️ `|| rc=$?`, never `|| true` — a `true` would discard the very code this
  #    reads, and leave a real failure indistinguishable from a refused send
  local out rc=0
  out="$(bash "$_grove_ops_send" "$GROVE" --reply --within 1800 \
    --await "${GROVE_ASK_AWAIT:-900}" \
    --what "$shell $(printf '%q' "$cmd")")" || rc=$?

  # the caller's own stdout, handed on untouched — every step that greps this
  # output (the suite tally above all) sees exactly what it saw before
  if [[ -n "$out" ]]; then
    printf '%s\n' "$out"
  fi

  if [[ "$rc" -ne 97 ]]; then
    return "$rc"
  fi

  ####################################################################
  # 🛑 exit 97 — the command never ran, so no step verdict exists
  #
  # a `return 1` here would fault the step; a `return 0` would pass it. both are
  # claims about work that was never attempted (`rule.forbid.failhide`)
  ####################################################################
  echo ""
  echo "  ✋ the command never ran on '$GROVE', so this run can judge no step"
  echo ""
  echo "  why: a duct is tmux, and a send is a keystroke into ONE pane. a pane"
  echo "       another job already holds refuses the send outright, so the"
  echo "       command was never delivered — and its absence of a result is a"
  echo "       fact about the DUCT rather than about this step."
  echo ""
  echo "       it waited ${GROVE_ASK_AWAIT:-900}s for the pane and it did not free."
  echo ""
  echo "  the command it tried to send —"
  echo "    $cmd"
  echo ""
  echo "  fix: see what holds the pane, then run this again —"
  echo "    rhx git.grove.read $GROVE --lines 40"
  echo "    rhx duct.list"
  echo ""
  echo "  ⇒ the usual cause is a SECOND grove read still in flight. a"
  echo "    backgrounded smoketest and a foreground one contend for one pane."
  exit 3
}

######################################################################
# .what = the tree this gate exercises, for the org THIS GROVE declares
#
# 🔴 .it is PER-ORG — 2026-09-24
#   - `REPO` was the scalar `ahbode/svc-chat`, with no org axis at all
#   - ⇒ an AETHER grove was gated on AHBODE's service: it cloned that tree,
#     installed its deps, stood up its testdb, and ran its suite — and the
#     verdict it printed was about ahbode's code on aether's box
#   - the sixth instance of one shape, after `5.13.reach`, `5.12.rack`,
#     `5.16.keys`, and `5.10.repos`. a gate is the worst place for it: every
#     other table wires a capability, and this one decides what PASSING MEANS
#   - (`rule.require.a-grove-reaches-its-own-org-only`)
#
# 🛑 an org with no arm gets NO TARGET, never another org's. it halts and names
#      the file to declare in — clause 3
#
# 🛑 .the BAR a tree must clear to be declared here — or the gate reports on
#      the TREE rather than on the box:
#
#        1. `5.10.repos` clones it for that org — the clone is bundle-owned,
#           and step 1 refuses to make one
#        2. its `main` is cicd-gated green — the inherited invariant above
#        3. it declares `test:integration`, which `git.repo.test` drives
#        4. IF it needs a database, it declares `use.testdb` at
#           `repo=.this role=any`, which supplies both `CONFIG` and `ACCESS`
#           (step 3 says why a hand-roll is wrong). a target with no database
#           declares no such skill, and step 3 then claims none
#
# ⚠️ every measurement quoted in the steps below was taken against
#    `ahbode/svc-chat`. each one states a property of the CLASS above, never of
#    that one repo — a target that clears the bar behaves the same way
######################################################################
# 🛑 the KEY is `GROVE_ORG` (the keyrack's org) and the VALUE is a GITHUB path.
#    the two namespaces differ — `aether` keys a repo under `aether-auctions`
#    — so this is a MAP and never an identity (`5.10.repos/_.sh` says why)
_target_repo_for_org() {
  case "${1:-}" in
    ahbode) printf 'ahbode/svc-chat' ;;
    aether) printf 'aether-auctions/svc-aether-auctions' ;;
    *)      return 0 ;;
  esac
}

######################################################################
# .what = the org this grove DECLARES, read off the box's own checkout
#
# 🛑 .why the box's manifest, and not the grove's NAME
#   - `rule.require.a-grove-reaches-its-own-org-only`: "a grove's org read from
#     any source other than its own declaration — inferred from a repo name, a
#     checkout, or the table that happens to be there = blocker"
#   - `grove-aether-v20260921` parses to `aether` today and is a naming
#     convention, never a declaration. a grove renamed tomorrow would silently
#     change what this gate tests
#   - ⇒ the box's `.agent/keyrack.yml` is the SAME line `grove.provision` reads
#     to settle `GROVE_ORG` (`src/grove.org.sh`), so there is one holder
#
# ⚠️ ONE command, no pipe and no `&&` — the send's guard refuses a chain, and
#    `--what` takes one step (`gotcha.the-duct-returns-the-send-not-the-answer`)
#
# 🛑 the sed EXPRESSION is single-quoted, and `$HOME` deliberately is not
#   - a duct's pane runs an INTERACTIVE zsh, which globs an unquoted
#     `[[:space:]]` and dies with `no matches found` before sed is reached
#   - 📜 measured 2026-09-24, on this very reader's first roll. it swallowed
#     that error and returned empty, so a box that declares `aether` was
#     reported as a box that declares no org — a false ✋ with a fix-text that
#     told a human to push a checkout already present
#     (`gotcha.a-check-that-cries-wolf-gets-silenced`)
#   - ⇒ so the three states are told apart BELOW, and never collapsed
######################################################################
_ORG_MANIFEST='$HOME/git/more/dev-env-setup/.agent/keyrack.yml'

######################################################################
# 🔴 .the PUSHED manifest is NOT the grove's declaration — it is THIS repo's
#
# the block above reasons that the box's `.agent/keyrack.yml` is where a grove
# declares its org, so a read of it honors
# `rule.require.a-grove-reaches-its-own-org-only`. the premise is false, and
# the rule's own enforcement names it:
#
#   > a grove's org read from any source other than its own declaration —
#   > inferred from a repo name, A CHECKOUT, or the table that happens to be
#   > there = blocker
#
# ⚠️ that manifest arrives by `git.grove.push --from .agent`, a straight copy of
#    THIS repo's `.agent/`. this repo declares `org: ahbode`. so the file says
#    `ahbode` on every grove ever pushed to, whatever org the box belongs to —
#    it is "the table that happens to be there", and it cannot answer otherwise.
#
# .measured 2026-09-28 on `grove-aether-v20260921`, both seats converged clean
#  under `--org aether`:
#
#     ├─ repo:  ahbode/svc-chat @ latest origin/main  (org ahbode, declared)
#
#  the word `declared` is the whole defect. an AETHER box was about to stand up
#  ahbode's testdb, run ahbode's suite, and print a verdict about ahbode's code
#  — which that same rule calls the WORST place for a hardcoded org, because
#  this table decides what a PASS MEANS.
#
# ⇒ the grove's own declaration is its REGISTRY ENTRY: a human writes it per
#   grove, beside `account` and `env` (`rhx git.grove.set <g> --org <org>`). it
#   is per-box by construction, so it is the one holder that CAN contradict this
#   repo's manifest — and to contradict it is exactly its job.
#
# ⚠️ the manifest read stays as the FALLBACK, and its source is named out loud.
#    it is right for an ahbode box and cannot be right for any other, so a run
#    that leans on it says so rather than print `declared`.
######################################################################
BOX_ORG=""
ORG_FROM=""

if [[ -z "$REPO" ]]; then
  REG_ORG=$(jq -r '.org // ""' \
    "${GIT_FOREST_DIR:-$HOME/.git.forest}/groves/$GROVE.json" 2>/dev/null) || REG_ORG=""
  [[ "$REG_ORG" == "null" ]] && REG_ORG=""

  if [[ -n "$REG_ORG" ]]; then
    # 🛑 a LIVE clamp — this reaches a `case` key and a remote path
    if [[ "$REG_ORG" == *[!A-Za-z0-9._@-]* ]]; then
      echo "      └─ ✋ the registry's org holds a character this gate cannot carry: '$REG_ORG'"
      echo ""
      echo "  want: [A-Za-z0-9._@-]"
      echo "  fix:  rhx git.grove.set $GROVE --org <org>"
      exit 2
    fi
    BOX_ORG="$REG_ORG"
    ORG_FROM="the registry, declared"
  fi
fi

if [[ -z "$REPO" && -z "$BOX_ORG" ]]; then
  ####################################################################
  # 🛑 THREE states, three verdicts — an absent manifest, an absent line, and
  #    a read that broke are different facts with different repairs
  ####################################################################
  if ! _drive "test -f $_ORG_MANIFEST" >/dev/null 2>&1; then
    echo "      └─ ✋ this box carries no keyrack manifest, so it declares no org"
    echo ""
    echo "  why: the gate's target is PER-ORG, this grove's registry entry names"
    echo "       no org, and the pushed manifest is absent too — so there is no"
    echo "       source left, and to guess from the grove's NAME is the very"
    echo "       inference rule.require.a-grove-reaches-its-own-org-only forbids."
    echo "  fix: declare it, once, where it belongs to the BOX —"
    echo "    rhx git.grove.set $GROVE --org <org>"
    echo "  ⚠️ the fallback below reads the box's pushed .agent/keyrack.yml, which"
    echo "     is a COPY of this repo's and says 'ahbode' on every grove. it can"
    echo "     be right only for an ahbode box, so the registry is the real fix."
    echo "  or name the tree outright, for this run only —"
    echo "    rhx git.grove.provision test $GROVE --of <org>/<repo>"
    exit 3
  fi

  ORG_RC=0
  ORG_RAW="$(_drive "sed -n 's/^org:[[:space:]]*//p' $_ORG_MANIFEST")" || ORG_RC=$?
  BOX_ORG="$(printf '%s' "$ORG_RAW" | tr -d '\r' | grep -m1 -E '^[a-z][a-z0-9._-]*$' || true)"

  if [[ "$ORG_RC" -ne 0 ]]; then
    echo "      └─ ✋ the org read did not complete, so no org was observed"
    echo ""
    echo "  why: the manifest is there and the read of it exited $ORG_RC. that is"
    echo "       a fact about the READ, never about the box's declaration — to"
    echo "       report it as 'no org' would name the wrong subject, and send a"
    echo "       human to repair a checkout that is already correct."
    echo "  what it tried —"
    echo "    sed -n 's/^org:[[:space:]]*//p' $_ORG_MANIFEST"
    echo "  read it by hand —"
    echo "    rhx git.grove.send $GROVE --reply --within 60 --what 'cat $_ORG_MANIFEST'"
    exit 3
  fi

  if [[ -z "$BOX_ORG" ]]; then
    echo "      └─ ✋ this grove declares no org — the registry is silent, and so is"
    echo "         the manifest"
    echo ""
    echo "  why: neither source names one, so an aether box and an ahbode box are"
    echo "       indistinguishable from here. to guess would hand one org's"
    echo "       verdict to the other."
    echo "  fix: declare it where it belongs to the BOX —"
    echo "    rhx git.grove.set $GROVE --org <org>"
    echo "  or name the tree outright, for this run only —"
    echo "    rhx git.grove.provision test $GROVE --of <org>/<repo>"
    exit 3
  fi

  # ⚠️ named for what it IS. the fallback can only ever answer this repo's own
  #    org, so a run that leans on it must not print `declared`
  ORG_FROM="the pushed manifest — a COPY of this repo's, so ahbode on every box"
fi

if [[ -z "$REPO" ]]; then
  REPO="$(_target_repo_for_org "$BOX_ORG")"

  if [[ -z "$REPO" ]]; then
    echo "      └─ ✋ org '$BOX_ORG' declares no acceptance target"
    echo ""
    echo "  why: an org with no declared table gets ZERO rows, never another"
    echo "       org's (rule.require.a-grove-reaches-its-own-org-only, clause 3)."
    echo "       so this gate has no tree to exercise, and it will not borrow one."
    echo "  fix: declare its arm in _target_repo_for_org, beside its reason —"
    echo "    .agent/repo=.this/role=any/skills/git.grove.provision.test.sh"
    echo "  ⇒ and the tree must ALSO sit in 5.10.repos's org set for '$BOX_ORG',"
    echo "    since the clone is bundle-owned and step 1 refuses to make it."
    echo "  or name the tree outright, for this run only —"
    echo "    rhx git.grove.provision test $GROVE --of <org>/<repo>"
    exit 3
  fi
fi

######################################################################
# 🛑 the DIR under `~/git` is the KEYRACK org, and never github's name
#   - `5.10.repos` clones `aether-auctions/svc-x` into `~/git/aether/svc-x`,
#     because every other table in this repo keys on `GROVE_ORG`, and a disk
#     laid out by github's names is a second namespace to hold in your head
#   - ⇒ so the tree this gate reads is NOT `git/$REPO`
#
# 🛑 it SOURCES the one holder rather than carry a copy of the pair
#   - `grove_org_clonedir` is pure: it reads its argument and a const, touches
#     no box and no `GROVE_SRC`, so it is safe to source from this laptop
#   - an inline copy would be one fact with two holders, and this half fails as
#     `🌙 the tree is not cloned` on a box that holds it — a false ✋ against
#     correct code (`gotcha.a-check-that-cries-wolf-gets-silenced`, m.9)
#
# ⚠️ the root is resolved off `BASH_SOURCE`, never `git rev-parse`
#    `rev-parse` answers about the CWD, so it names whatever checkout a human
#    happens to stand in — `git.grove.auth.keys.set` sets this precedent at the
#    same depth, and `wire.verify` records why the other form is wrong
######################################################################
_SELF_REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../../.." && pwd)"

if [[ ! -r "$_SELF_REPO_ROOT/src/grove.org.sh" ]]; then
  echo "✋ this gate cannot read src/grove.org.sh, so it cannot name the tree dir" >&2
  echo "   ⇒ that file holds the ONE keyrack↔github org pair table, and a clone" >&2
  echo "     lands under the KEYRACK name — so a join without it reads the wrong" >&2
  echo "     dir and reports an absent tree on a box that holds one" >&2
  echo "   looked at: $_SELF_REPO_ROOT/src/grove.org.sh" >&2
  echo "   fix: run this from a full checkout of dev-env-setup" >&2
  exit 3
fi

# shellcheck source=/dev/null
. "$_SELF_REPO_ROOT/src/grove.org.sh"

REPO_NAME="${REPO##*/}"
TREE_DIR="git/$(grove_org_clonedir "${REPO%%/*}")/$REPO_NAME"

echo "🐢 heres the wave..."
echo ""
echo "💨 git.grove.provision test $GROVE"
# ⚠️ the report names its SOURCE, never a bare `declared`. this table decides
#    what a PASS means, so a reader must see whether the org came from the box's
#    own registry entry or from a manifest that says ahbode on every grove
echo "   ├─ repo:  $REPO @ latest origin/main${BOX_ORG:+  (org $BOX_ORG)}"
[[ -n "$ORG_FROM" ]] && echo "   │         └─ org from: $ORG_FROM"
echo "   ├─ tree:  ~/$TREE_DIR"
echo "   ├─ steps: $FROM..4"
echo "   └─ run"

######################################################################
# step 0 — box
#
# the whole read-only ladder, up to creds. every step below assumes a box that
# wakes, holds a duct, has converged, and can reach github and aws — and each of
# those has a precise halt of its own, worth far more than one generic "the box
# is not ready".
#
# 🛑 the WHOLE ladder is the box question — no `--upto` narrows it here.
#    a read-only ladder may not judge a precondition its caller is about to
#    ESTABLISH — it would halt on the very state the caller exists to create.
#    that is why the ladder's subject stops at the box
#    (`git.grove.ready.verify`, `.the SUBJECT is the BOX`)
######################################################################
if _in_range 0; then
  echo "      ├─ 0. box"
  if ! rhx git.grove.ready.verify "$GROVE" >"$LOGDIR/box.log" 2>&1; then
    echo "      │  └─ ✋ the ladder halted — its own reason is below"
    echo ""
    sed -n '/^  why:/,$p' "$LOGDIR/box.log"
    echo ""
    # 🛑 .why this does NOT say "that is a fact about the box" — measured 2026-08-13
    #
    #    it said exactly that, unconditionally, for every rung. and the halt it
    #    printed that under was rung 2, `reach`, whose wake had failed because
    #    THIS machine's camp credential had lapsed — an hour-long sts session,
    #    not a defect on the grove. the very next wake reported [KEEP] on every
    #    rung and changed no box state at all.
    #
    # ⚠️ so a correct, precise halt was followed by a generalization that named
    #    the wrong subject, and the reader it misdirects is one who trusts the
    #    conclusion over the evidence directly above it
    #    (gotcha.a-check-that-cries-wolf-gets-silenced).
    #
    #    the rungs do not share one subject, so no single sentence can name it:
    #
    #      1 registry  — an entry on THIS machine
    #      2 reach     — EITHER: this machine's aws credential, or the box
    #      3 duct      — EITHER: this machine's tunnel, or the box's tmux
    #      4 tree    — the box
    #      5 creds     — the box
    #
    #    the halt's own `fix:` lines are already per-rung and already correct,
    #    so the honest move is to point at them rather than talk over them.
    echo "  ⇒ run the fix above, then climb again. note WHICH rung halted:"
    echo "    rungs 1-3 can fail on THIS machine (a lapsed credential, a dead"
    echo "    tunnel) with the grove perfectly healthy; rungs 4-5 are the box."
    exit 3
  fi
  echo "      │  └─ ✔ registry, reach, duct, tree, creds all held"
fi

######################################################################
# step 1 — tree, at latest origin/main
#
# ⚠️ the CLONE is bundle-owned and this refuses to do it. `5.10.repos` clones
#    the org's repos, so an absent tree is an unconverged box, and to clone it
#    here would be the second entrypoint `rule.forbid.repair-plays` forbids —
#    the box would pass this gate while `grove.provision --mode plan` still
#    reported the tree absent.
#
#    the SYNC is different in kind: which ref a test fixture sits on is not a
#    provisioned fact, and no bundle declares it.
#
# ⚠️ and it refuses to reset a DIRTY tree. `reset --hard` would silently destroy
#    a human's in-flight work, and an acceptance gate is exactly the command
#    somebody runs without reading it first.
######################################################################
if _in_range 1; then
  echo "      ├─ 1. tree"
  if ! _drive "test -d \$HOME/$TREE_DIR/.git" >/dev/null 2>&1; then
    halt 1 tree \
      "$REPO is not cloned. the clone is bundle-owned (5.10.repos), so this is an unconverged box rather than a fixture this command may create" \
      "rhx git.grove.send $GROVE --detach --log '\$HOME/repos.log' \\" \
      "  --what 'rhx grove.provision --what 5.10.repos --mode apply'"
  fi

  # ⚠️ THE TREE RE-DIRTIES ITSELF, so a naive dirty check is a false ✋ on every
  #    converged box — forever, which is the shape that gets a guard silenced
  #    (`gotcha.a-check-that-cries-wolf-gets-silenced`).
  #
  #    measured 2026-08-12 on this gate's FIRST run, which halted right here:
  #
  #        $ git -C ~/git/ahbode/svc-chat status --porcelain
  #         M .claude/settings.json
  #
  #        $ git -C ~/git/ahbode/svc-chat diff .claude/settings.json
  #        -    "command": ".../rhachet roles boot --role librarian",
  #        -    "author": "repo=bhrain/role=librarian"
  #
  # 🛑 .the writer is NOT `5.3.brains`, and a grep settles that in one command:
  #    `5.3.brains` writes `$HOME/.claude/settings.json` and no repo-local one.
  #    no bundle in this tree writes a cloned repo's `.claude/`.
  #
  #    the real writer is THE REPO ITSELF. `svc-chat`'s committed `prepare` step
  #    runs `rhachet init --hooks`, which reconciles the hook list against the
  #    role packages actually installed and drops the ones whose role no longer
  #    exists. proven in both directions, on a clean tree:
  #
  #      grove.provision --what 5.3.brains --mode apply   → tree stayed CLEAN
  #      pnpm --dir …/svc-chat install                    → tree went DIRTY, and
  #        the install printed:  ✨ hooks ├── 30 updated └── 1 orphans removed
  #
  # ⇒ so the exclusion below is REQUIRED: the path is not ours to own, it is
  #   the repo's own tool output, regenerated on every `pnpm install`. that is
  #   also why it survives
  #   this gate's own reset — step 1 resets the tree, step 2 installs, and the
  #   install re-dirties it before the NEXT run's step 1 looks.
  #
  # ⚠️ the NAME matters: to name the tree as OWNER asserts an ownership the
  #    measurement disproves — and a wrong name inside a correct guard is the
  #    hardest kind to catch, because the guard's behavior gives no hint
  #    (`gotcha.a-check-that-cries-wolf-gets-silenced`, measurement 4).
  ####################################################################
  # 🛑 .a SECOND regenerated path, and it is a CONVENTION rather than an instance
  #
  # .measured 2026-09-28, `grove-aether-v20260921`, this gate's step 1:
  #
  #     D  .agent/.cache/repo=bhrain/role=learner/skill=learn.domain.terms/progress.md
  #      M .claude/settings.json
  #
  #   the second was excluded and the first was not, so the gate halted with
  #   `1 uncommitted change(s) that no tool regenerates` over a **cache file**.
  #
  # ⇒ `.agent/.cache/` is a cache dir by DECLARED convention, and this repo's own
  #   ignore list is the citation — `.gitignore:14` reads `.agent/.cache/`. so its
  #   contents are tool output by definition, which is the identical ground the
  #   `.claude/settings.json` exclusion above stands on.
  #
  # ⚠️ the target repo still TRACKS that one file, which is why git did not ignore
  #    it there — a commit that predates the convention. the exclusion is about
  #    what the path IS, never about whether one repo's index caught up.
  #
  # 🟡 .a DIRECTORY, deliberately — the alternative goes stale in silence
  #    a per-file entry would have to grow a row per cache artifact any role ever
  #    writes, and each absent row reads as a real claim about a human's work. one
  #    row over the convention covers every artifact under it, extant and future
  #    (`gotcha.a-check-that-cries-wolf-gets-silenced`, m.12 — a hand-written list
  #    reports only what its author could see).
  #
  # ⚠️ .it is STILL a hand-written list, and that hazard is not retired
  #    a third tool-owned path that matches neither row will halt this gate the
  #    same way. what changes is the grain: a convention row ages far slower than
  #    an instance row, so the list is cheaper to keep true.
  ####################################################################
  ####################################################################
  # 🛑 .a THIRD row — the `.claude` SYMLINK, the same writer as the first row
  #
  # .measured 2026-10-01, `grove-aether-v20260921`, step 1 after a step-2 install:
  #
  #      M .agent/.actors/actor.via.slug=.default/brain/.claude/settings.json
  #      D .claude/settings.json
  #     ?? .claude
  #
  #   the repo's `prepare` (rhachet) MOVED its settings into the actor's brain dir
  #   and left `.claude` as a symlink to it. the first two lines already match the
  #   first row; the symlink did not, so the gate halted on rhachet's own output.
  #   this repo's own tree carries the identical migration (`.claude` → a symlink)
  #
  # ⚠️ anchored on the WHOLE path `.claude`, so a human's file UNDER `.claude/`
  #    still halts unless it is the settings file the first row names
  ####################################################################
  SELF_REGENERATED='\.claude/settings\.json$|\.agent/\.cache/| \.claude$'
  _drive "git -C \$HOME/$TREE_DIR status --porcelain" >"$LOGDIR/dirty.log" 2>&1
  DIRTY=$(grep -E '^.[MADRCU?] |^[MADRCU?]. ' "$LOGDIR/dirty.log" 2>/dev/null \
    | grep -cvE "$SELF_REGENERATED" || true)
  if [[ "${DIRTY:-0}" -gt 0 ]]; then
    ##################################################################
    # ⚠️ the why says what a reset DOES, per entry — it used to assert one verb
    #
    # the old text read `a sync to origin/main would destroy them`, and for a
    # DELETION that is simply untrue: a reset RESTORES a tracked file the box
    # removed. so one sentence named the wrong mechanism for half its own
    # subject (`…cries-wolf`, m.4 — a verdict whose reason names another act).
    #
    # ⇒ both are still worth a halt, because both are a human's act this gate
    #   would undo. what differs is which act, so the text now names both and
    #   asserts neither of the other.
    ##################################################################
    halt 1 tree \
      "the tree has ${DIRTY} uncommitted change(s) that no tool regenerates — a sync to origin/main would discard content the box holds, and restore any file the box removed. an acceptance gate must never undo a human's work" \
      "read them —" \
      "cat $LOGDIR/dirty.log" \
      "" \
      "  commit or stash them on the box, then run this again." \
      "" \
      "  ⚠️ if a listed path is TOOL OUTPUT rather than a human's work, the fix" \
      "     is this gate's own exclusion list, never a commit on the box —" \
      "     see the 🛑 block beside \`SELF_REGENERATED\` for the two extant rows" \
      "     and the evidence each stands on."
  fi

  _drive "git -C \$HOME/$TREE_DIR fetch origin main" >"$LOGDIR/tree.log" 2>&1
  if ! _drive "git -C \$HOME/$TREE_DIR reset --hard origin/main" >>"$LOGDIR/tree.log" 2>&1; then
    halt 1 tree \
      "could not sync the tree to origin/main — see $LOGDIR/tree.log" \
      "tail -30 $LOGDIR/tree.log"
  fi
  HEAD=$(_drive "git -C \$HOME/$TREE_DIR log -1 --format=%h\ %s" 2>/dev/null | tail -1)
  echo "      │  └─ ✔ synced to origin/main — $HEAD"
fi

######################################################################
# step 2 — deps
#
# ⚠️ `pnpm install`, never `--frozen-lockfile`. the tree was just reset to
#    origin/main, so its lockfile IS the declared one; a frozen install would
#    add a second opinion about that and fail on a lockfile the repo ships.
#
# 🛑 .the HALT READS THE LOG IT JUST WROTE — it does not guess the cause
#
#    this halt used to assert ONE hypothesis, unconditionally:
#
#      a private dep needs the rack's github token, which step 0 proved —
#      so suspect the lockfile or the registry before the box.
#
#    📜 .measured 2026-09-29 on `grove-aether-v20260921`. the install failed,
#    that text printed, and the log the very same call had written said:
#
#      ✋ ConstraintError: brain-cli 'claude' is 2.1.87 at
#         /home/camper/.local/share/pnpm/claude, below the floor 2.1.277
#
#    ⇒ the verdict was right and its stated SUBJECT was wrong. the failure was
#    a `prepare` lifecycle's version FLOOR, and the fix-text sent the reader to
#    inspect a lockfile and a registry that were both correct
#    (`gotcha.a-check-that-cries-wolf-gets-silenced`, m.4).
#
#    ⚠️ and the cost is not one confused read. `pnpm install` runs a target
#    repo's `prepare`, so this step's failure surface is EVERY assertion that
#    lifecycle makes — a version floor, an absent credential, a peer check. one
#    named hypothesis cannot cover an open set, and a reader who believes the
#    named one stops before the log.
#
#    ⇒ the repair is not a longer hypothesis list. the step already HOLDS the
#    log — it opened it, wrote it, and read its exit code — so it prints the
#    refusal itself and names the guess only when it found none
#    (`gotcha.a-check-withholds-what-it-already-holds`, face 2).
######################################################################
if _in_range 2; then
  echo "      ├─ 2. deps"
  if ! _drive "env -C \$HOME/$TREE_DIR pnpm install" >"$LOGDIR/deps.log" 2>&1; then
    # the refusal the log already carries — a `✋`, a *Error:, or a pnpm ERR_
    DEPS_WHY=$(grep -Eo '(✋ [^"]*|[A-Za-z]*Error: .*|ERR_PNPM_[A-Z_]+ .*)' "$LOGDIR/deps.log" 2>/dev/null \
                 | sed -E 's/^[[:space:]]+//' | tail -3 || true)
    if [[ -n "$DEPS_WHY" ]]; then
      HALT_WHY=("pnpm install failed — see $LOGDIR/deps.log" "tail -40 $LOGDIR/deps.log" "")
      HALT_WHY+=("  what the log says —")
      while IFS= read -r LINE; do
        [[ -n "$LINE" ]] && HALT_WHY+=("    $LINE")
      done <<<"$DEPS_WHY"
      HALT_WHY+=("")
      HALT_WHY+=("  ⚠️ \`pnpm install\` runs the target repo's \`prepare\`, so a refusal above")
      HALT_WHY+=("     may be that lifecycle's and not the install's. read WHICH before you act:")
      HALT_WHY+=("     a version FLOOR is a pin decision, a credential is the rack, and a")
      HALT_WHY+=("     resolution error is the lockfile or the registry.")
      halt 2 deps "${HALT_WHY[@]}"
    fi
    halt 2 deps \
      "pnpm install failed — see $LOGDIR/deps.log" \
      "tail -40 $LOGDIR/deps.log" \
      "" \
      "  ⚠️ no refusal line was found in the log, so the cause is UNREAD — the" \
      "     guesses below are guesses, never a diagnosis." \
      "" \
      "  a private dep needs the rack's github token, which step 0 proved —" \
      "  so suspect the lockfile or the registry before the box."
  fi
  echo "      │  └─ ✔ deps installed"
fi

######################################################################
# step 3 — fixture: the testdb
#
# ⚠️ this drives the TARGET REPO'S OWN SKILL, `rhx use.testdb`, and never a
#    hand-rolled `npm run start:testdb`. the target repo declares that skill
#    precisely because the bare npm target cannot stand alone:
#
#      $ npm run start:testdb
#      Error: UnexpectedCodePathError: could not derive access.
#             tried parsers: getEnvAccessFromEnvar, getEnvAccessFromNodeEnv
#
#    sql-schema-control derives its tier through sdk-environment's parser
#    chain, and on a bare shell NEITHER parser answers. `use.testdb` supplies
#    both `CONFIG=test` and `ACCESS=test`, so it answers.
#
# 📜 .measured 2026-08-12 — this step hand-rolled `ACCESS=test npm run
#    start:testdb` for one session, and that reimplementation was wrong twice:
#      1. it dropped `CONFIG=test`, which the skill also exports
#      2. it framed the absent tier as a BOX defect, with a note that the box
#         should carry a declared access tier
#
#    ⚠️ a box-wide access declaration would have been DESTRUCTIVE. `ACCESS`
#    selects the DATABASE (`connection.config.js` → the service's `getConfig`),
#    and this repo's own default tier is `prep` — so a box-wide export would
#    have aimed a `--force-recreate` schema apply at the shared prep database
#    on every grove. the tier belongs to the CALLER, not to the machine
#    (`rule.require.bounded-contexts`).
#
# ⇒ so a fixture command the target repo already declares is never rewritten
#   here. drive its skill (`rule.require.wrap-cli-in-skills`), and a change to
#   the fixture reaches this gate for free.
#
# ⚠️ `--repo .this --role any` is REQUIRED, not decoration. svc-chat carries TWO
#    skills named `use.testdb`, and a bare `rhx use.testdb` refuses to pick:
#
#      BadRequestError: multiple skills found for "use.testdb":
#        - repo=.this role=any        ← exports CONFIG + ACCESS, then npm
#        - repo=ghlitch role=operator ← clears stale containers, then npm
#
#    the two differ in KIND, so the choice is not a tiebreak. only `.this`
#    supplies the tier, and `.this` is the repo's own declaration of its own
#    fixture — an inherited role's copy is a neighbour's opinion of it.
######################################################################
######################################################################
# 🛑 .a target that declares NO fixture owes none — and the probe is a FILE
#
# not every service holds a database. `aether/svc-aether-auctions` declares no
# `use.testdb` at all, and its suite needs one no more than it needs a docker
# daemon. to halt such a target here would gate it on a precondition its own
# repo says it does not have.
#
# ⚠️ the discriminator is the target's OWN DECLARATION, read as a file on the
#    box — never the exit code of the drive. `rhx use.testdb` exits non-zero
#    for an ABSENT skill and for a DEAD docker alike, so a skip keyed on the
#    code would swallow the second (`rule.forbid.failhide`).
#
# ⇒ declared and it fails → ✋, with docker named. undeclared → 🌙, and the
#   step's claim is simply not owed.
######################################################################
FIXTURE_SKILL="\$HOME/$TREE_DIR/.agent/repo=.this/role=any/skills/use.testdb.sh"

if _in_range 3; then
  echo "      ├─ 3. fixture"

  if ! _drive "test -f $FIXTURE_SKILL" >/dev/null 2>&1; then
    echo "      │  └─ 🌙 $REPO_NAME declares no use.testdb — no fixture is owed"
    echo "      │     ⇒ this judges no database; the target says it has none"
  elif ! _drive "env -C \$HOME/$TREE_DIR rhx use.testdb --repo .this --role any" >"$LOGDIR/fixture.log" 2>&1; then
    halt 3 fixture \
      "the testdb did not come up — see $LOGDIR/fixture.log. without it every suite fails for a reason that has no bearing on the code" \
      "tail -40 $LOGDIR/fixture.log" \
      "" \
      "  docker is the usual culprit; the camper runs a ROOTLESS daemon —" \
      "rhx git.grove.send $GROVE --bare --why 'read the docker endpoint' \\" \
      "  --what 'docker context inspect --format {{.Endpoints.docker.Host}}'"
  else
    echo "      │  └─ ✔ testdb up, schema applied"
  fi
fi

######################################################################
# step 4 — suite
#
# the payoff. every step above exists so that a failure HERE is a fact about
# the TARGET's code rather than a fact about the box.
#
# ⚠️ `--thorough` IS LOAD-BEARING. `git.repo.test` scopes to files changed since
#    `origin/main` by default, and step 1 just reset the tree TO origin/main —
#    so the default run has an empty diff and reports:
#
#        ├─ files: 0 (no test files changed since origin/main)
#        └─ tests: 0 (no tests to run)
#
#    exit 0, no ✋, no red line — on a box whose suite in fact tallies 31/0.
#    the `PASSED -eq 0` guard below catches that false ✔.
#
# ⚠️ the tally is the verdict, never the exit code. a suite that reports
#    `0 passed` and exits 0 proved no test at all (`rule.forbid.failhide`).
######################################################################
if _in_range 4; then
  echo "      └─ 4. suite"
  SUITE_LOG="$LOGDIR/suite.log"
  # `env -C <dir>` rather than `cd <dir> && …`: a `cd` in a login shell can be
  # hooked, and fnm's cd hook switches the node version per repo — so a `cd`
  # here would change which pnpm answers (`5.1.node`'s two-pnpm note)
  _drive "env -C \$HOME/$TREE_DIR rhx git.repo.test --what integration --mode apply --thorough" \
    >"$SUITE_LOG" 2>&1 || true

  PASSED=$(_tally 'passed' "$SUITE_LOG")
  FAILED=$(_tally 'failed' "$SUITE_LOG")
  echo "         ├─ passed: $PASSED"
  echo "         ├─ failed: $FAILED"

  if [[ "$PASSED" -eq 0 ]]; then
    halt 4 suite \
      "the suite tallied 0 passed — it did not run, whatever it exited with. a 0-passed run proves no test" \
      "tail -40 $SUITE_LOG"
  fi
  ####################################################################
  # 🛑 the halt names THREE subjects, and refuses to pick one
  #
  # 📜 .measured 2026-08-15 on grove-ahbode-v20260811. a two-subject halt —
  #    *"every step above held and the fixture is up, so this is svc-chat's
  #    code — UNLESS main shipped red"* — reaches neither, because the truth
  #    was a THIRD that neither branch names:
  #
  #      An error was returned as the lambda invocation response for the lambda
  #      <a dev-account lambda>: "connect ETIMEDOUT <a private rds host>:5432"
  #
  #    all SIX failures carried that one string. the box INVOKED the lambda and
  #    the lambda ANSWERED — so aws reach, credentials, and the route out of
  #    this grove were each proven by the very call that failed. what timed out
  #    was a DOWNSTREAM service reach to its OWN database, inside aws.
  #
  #    ⇒ a `why:` that offers two subjects when three are possible does not
  #      merely under-inform. it sends a reader to blame a repo that is
  #      innocent, on evidence that names the real subject in full
  #      (`gotcha.a-check-that-cries-wolf-gets-silenced`, m.4 — a summary that
  #       generalizes over a set does not get to skip the set)
  #
  # ⚠️ and the ERROR STRING is the discriminator, so the fix-text leads with a
  #    read of it rather than with a verdict. N failures that carry ONE string
  #    have one cause, and that cause is rarely the code under test
  #    (`rule.require.solve-at-cause`, `.a bulk failure is ONE cause repeated`)
  ####################################################################
  ####################################################################
  # 🛑 the ERROR STRINGS are FETCHED, or the fix-text below cannot be followed
  #
  # 📜 measured 2026-09-01: the halt says *"sort the failures by their ERROR
  #   STRING first"* and names `$SUITE_LOG` as where to read them. that file
  #   held 57 lines and NOT ONE error string.
  #
  #   the cause is a seam, not a bug: `rhx git.repo.test` prints a SUMMARY to
  #   stdout — the tally, the timings, and the PATHS of its own logs — and
  #   writes the failure detail into those logs, on the BOX. so the `>` capture
  #   at the drive above can only ever hold the summary.
  #
  #     │  ├─ stdout: .log/…/2026-09-01T21-46-32Z.stdout.log   ← the detail
  #     │  ├─ tests: 25 passed, 6 failed                       ← all we captured
  #
  # ⚠️ two artifacts, written by two authors, each correct alone: the fix-text
  #   names the right SORT, and the capture takes the right STREAM. neither is
  #   wrong; together they send a reader to a file that cannot answer
  #   (`gotcha.a-check-that-cries-wolf-gets-silenced`, m.9).
  #
  # 🛑 and it fails EXACTLY when it matters. a green run needs no error string,
  #   so the gap is invisible until a suite goes red — which is the one moment
  #   the reader has no other source (`rule.require.errors-name-the-fix`).
  #
  # ⇒ so the gate fetches the detail and appends it here, on the failure path
  #   only. a reader who follows the fix-text finds what it promised.
  ####################################################################
  if [[ "$FAILED" -gt 0 ]]; then
    SUITE_ERR_REMOTE="$(sed -n 's/.*stderr: \(\.log[^ ]*\)$/\1/p' "$SUITE_LOG" | tail -1)"
    if [[ -n "$SUITE_ERR_REMOTE" ]]; then
      {
        echo ""
        echo "──────── failure detail, fetched from the box ────────"
        echo "   └─ \$HOME/$TREE_DIR/$SUITE_ERR_REMOTE"
        echo ""
      } >>"$SUITE_LOG"
      _drive "tail -200 \$HOME/$TREE_DIR/$SUITE_ERR_REMOTE" >>"$SUITE_LOG" 2>&1 || true
    else
      # ⚠️ SAY so, rather than leave a reader to find the absence themselves.
      #   an unfetched detail with no note reads exactly like a suite that
      #   printed no errors (`rule.forbid.failhide`)
      {
        echo ""
        echo "⚠️ the suite named no stderr log, so no failure detail was fetched."
        echo "   read it on the box —"
        echo "     rhx git.grove.send $GROVE --reply --what 'ls -t \$HOME/$TREE_DIR/.log/role=mechanic/skill=git.repo.test/what=integration/ | head -4'"
      } >>"$SUITE_LOG"
    fi

    halt 4 suite \
      "${FAILED} test(s) failed. every step above held and the fixture is up, so the box is converged — which leaves THREE subjects, and this gate cannot tell them apart" \
      "tail -60 $SUITE_LOG" \
      "" \
      "  sort the failures by their ERROR STRING first — it names the subject:" \
      "" \
      "    1. ONE string, repeated, that names another SERVICE or HOST" \
      "       ⇒ a downstream environment. not this box, and not $REPO." \
      "         measured 2026-08-15: 6 failures, one rds timeout inside a dev" \
      "         lambda. the box had already reached aws to make that call" \
      "" \
      "    2. main shipped red" \
      "       ⇒ upstream. confirm this before you read one line of code:" \
      "gh run list --repo $REPO --branch main --limit 5" \
      "" \
      "    3. DISTINCT errors, and main is green" \
      "       ⇒ now it is $REPO's code, and only now"
  fi
  echo "         └─ ✔ the suite tallied green"
fi

echo ""
echo "🌳 cowabunga! $GROVE passed the smoketest"
echo "   ├─ steps:  $FROM..4, every one held"
echo "   ├─ proof:  $REPO @ origin/main — ${PASSED:-?} passed, 0 failed"
echo "   └─ logs:   $LOGDIR"

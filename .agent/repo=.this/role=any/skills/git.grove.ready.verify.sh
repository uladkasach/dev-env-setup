#!/usr/bin/env bash
######################################################################
# git.grove.ready.verify — is this grove ready to do work?
#
# .what = a LADDER of five rungs, each a state a grove must hold before
#         the next can be true. it climbs until one rung does not hold,
#         then HALTS and names that rung, why it failed, and the one
#         command that repairs it.
#
#           1. registry — an entry exists, and it names an account
#           2. reach    — the box wakes; the account assertion passes
#           3. duct     — a command sent down the duct comes back
#           4. tree   — every bundle verify passes (--mode plan)
#           5. creds    — the rack answers for github and for aws
#
#         ⚠️ rung 1 reads the ENTRY and puts no question to aws. LIVENESS is
#            rung 2's, through `git.grove.wake` → `_find_by_exid`. so this line
#            must never claim *"its exid is not stale"* — that asserts a live
#            lookup rung 1 never performs. this summary, its twin below, and
#            the body block at `:203` are three holders of one fact
#            (`gotcha.a-check-that-cries-wolf-gets-silenced`, m.9)
#
# .why  = "provision a grove" is a chain, not one act — and a chain reports
#         its breaks badly. a fresh box fails its last rung because it failed
#         rung 1, so a report that names all five names ONE root cause five
#         times. `prove.phase-chain-breaks` forbids that shape: when a phase
#         fails, the rest stand down rather than restate it.
#
#         so this HALTS. the first rung that does not hold is the whole
#         answer, and its fix is the whole next move.
#
# .why verify, not test = `test` is spoken for — `git.repo.test` RUNS suites.
#         this READS state and asserts a verdict, which is what `verify` names
#         (`term=play.verify`).
#
# 🛑 .the SUBJECT is the BOX, and it ends there — this is why there is no rung 6
#
#         every rung above asks about the MACHINE: its registry entry, its
#         reach, its duct, its tree, its rack. not one asks about a repo
#         checked out on it.
#
#         🛑 there is NO `6. tree` (is the target repo cloned, with its deps)
#            and NO `7. suite` (does `git.repo.test --what integration` tally
#            green). the reason is not length:
#
#         | the question | such a rung | `git.grove.provision test` |
#         |---|---|---|
#         | is the tree cloned?  | 6, halts with a `git clone` fix    | step 1, CLONES it     |
#         | are deps installed?  | 6, halts with a `pnpm install` fix | step 2, INSTALLS them |
#         | does the suite pass? | 7                                  | step 4, SAME command  |
#
#         ⇒ they are SYNONYMS — one set with two readers, free to disagree
#           (`gotcha.a-check-that-cries-wolf-gets-silenced` m.9). and the
#           disagreement is invisible: a programmatic caller that passes
#           `--upto 5` leaves 6-7 to a human's bare invocation, the run least
#           likely to be diffed against the other reader.
#
#         ⚠️ and a rung 7 refutes this file's own `.safety` line: it runs
#            `--mode apply` against a live testdb, which is a WRITE.
#            `test` ESTABLISHES what those two merely report absent, so the
#            establisher is the right owner of both questions.
#
#         🛑 do NOT re-add a rung that reads a TREE. the ladder's subject is
#            the box; a question about a repo belongs to `git.grove.provision
#            test`, which can act on the answer.
#
# .safety = every rung WRITES no state of its own. rung 2 wakes the box,
#         which is idempotent and free (`rule.require.wake-the-grove-freely`);
#         every other rung is a read. none installs, clones, or repairs —
#         each names the repair to run.
#
# usage:
#   rhx git.grove.ready.verify <name>
#   rhx git.grove.ready.verify <name> --from 4          # resume at rung 4
#   rhx git.grove.ready.verify <name> --upto 3          # climb no higher than 3
#
# options:
#   --from    first rung to climb; default 1
#   --upto    last rung to climb; default 5
#
# guarantee:
#   - exit 0 = ready — every rung in range held
#   - exit 3 = a rung did not hold; it is named, with its fix
#   - exit 2 = bad input (absent grove name, bad range)
#   - exit 1 = malfunction (a tool this depends on broke)
######################################################################
set -uo pipefail

# ⚠️ read the whole ARG VECTOR, never `$1` — rhachet injects `--skill <slug>` ahead
#    of the caller's args, so a `$1` test never fires. measured 2026-08-30: this
#    very line let `rhx git.grove.ready.verify help` climb the whole ladder against a
#    grove named "help" and halt with `no registry entry names 'help'`
if [[ " $* " == *" help "* || " $* " == *" --help "* || " $* " == *" -h "* ]]; then
  echo "git.grove.ready.verify — is this grove ready to do work?"
  echo ""
  echo "usage:"
  echo "  rhx git.grove.ready.verify <name> [--from N] [--upto N]"
  echo ""
  echo "the ladder:"
  echo "  1. registry — an entry exists, and it names an account (no live lookup)"
  echo "  2. reach    — the box wakes; the account assertion passes"
  echo "  3. duct     — a command sent down the duct comes back"
  echo "  4. tree   — every bundle verify passes (--mode plan)"
  echo "  5. creds    — the rack answers for github and for aws"
  echo ""
  echo "the subject is the BOX. for a question about a repo ON it, reach for"
  echo "  rhx git.grove.provision test <name>"
  echo ""
  echo "it HALTS at the first rung that does not hold, and names its fix."
  echo "exit 0 = ready | 3 = a rung failed | 2 = bad input | 1 = malfunction"
  exit 0
fi

GROVE=""
FROM=1
UPTO=5

while [[ $# -gt 0 ]]; do
  case "$1" in
    --from) FROM="$2"; shift 2 ;;
    --upto) UPTO="$2"; shift 2 ;;
    --skill|--repo|--role) shift 2 ;;
    --) shift; [[ -z "$GROVE" ]] && { GROVE="${1:-}"; shift 2>/dev/null || true; } ;;
    -*) echo "✋ unknown flag '$1'" >&2; exit 2 ;;
    *) [[ -z "$GROVE" ]] && GROVE="$1"; shift ;;
  esac
done

if [[ -z "$GROVE" ]]; then
  echo "✋ usage: rhx git.grove.ready.verify <name>" >&2
  echo "   list them: rhx git.grove.list" >&2
  exit 2
fi
if ! [[ "$FROM" =~ ^[1-5]$ && "$UPTO" =~ ^[1-5]$ ]] || [[ "$FROM" -gt "$UPTO" ]]; then
  echo "✋ --from and --upto must each be 1-5, with --from no greater than --upto" >&2
  exit 2
fi

# where each rung's raw output is kept.
#
# ⚠️ NOT /tmp. this repo forbids a bash read or write under /tmp, and the reason
#    is that /tmp is not temporary — it persists, never auto-cleans, and a log
#    left there outlives every memory of why it was written. the state dir is
#    where a per-machine artifact belongs, and it is where `git.grove.wake`
#    already keeps its tunnel log.
#
# the logs are KEPT rather than discarded, so a rung that halts leaves evidence
# a human can read instead of a verdict they must take on faith.
LOGDIR="${XDG_STATE_HOME:-$HOME/.local/state}/grove.ready/$GROVE"
mkdir -p "$LOGDIR"

echo "🐢 heres the wave..."
echo ""
echo "🪜 git.grove.ready.verify $GROVE"
echo "   ├─ rungs: $FROM..$UPTO"
echo "   └─ climb"

######################################################################
# halt — name the rung, why it did not hold, and the one command that repairs it
#
# every halt carries a resume hint, so the next climb need not redo the rungs
# already proven (`rule.require.errors-name-the-fix`)
######################################################################
halt() {
  local rung="$1" label="$2" why="$3"; shift 3
  echo "      └─ ✋ rung $rung ($label) does not hold"
  echo ""
  echo "  why: $why"
  echo "  fix:"
  local line
  for line in "$@"; do echo "    $line"; done
  echo ""
  echo "  then climb again from here —"
  echo "    rhx git.grove.ready.verify $GROVE --from $rung"
  exit 3
}

# .what = should this rung be climbed?
# .why  = --from lets a caller resume past rungs already proven, and --upto lets
#         a caller stop short — so a repair loop can re-verify one rung cheaply
_in_range() { [[ "$1" -ge "$FROM" && "$1" -le "$UPTO" ]]; }

######################################################################
# the transport and the tallies live in `git.grove.operations.sh`
#
# ⚠️ `git.grove.provision test` needs the same transport, so it has ONE holder.
#    `_shell_at` in particular carries the most expensive lesson in this file —
#    a `bash -lc` that silently loses `rhx` on the boxes that are MOST
#    converged — so a second copy would take the next fix in one place and
#    leave the other stale (`rule.forbid.two-writers-on-one-artifact`).
#
# shared: _ask_at, _shell_at, _count, _count_claims, _tally. local: `_ask`,
# below, because it closes over $GROVE.
######################################################################
source "$(dirname "${BASH_SOURCE[0]}")/git.grove.operations.sh"

# 🛑 the rack holder — rung 2 asks it whether THIS MACHINE holds a profile at
#    all, before it blames the box for a credential it never had
#    (`term=keyrack.gitroot`)
# shellcheck source=/dev/null
source "$(dirname "${BASH_SOURCE[0]}")/git.grove.rack.operations.sh"

######################################################################
# rung 1 — registry
#
# the entry is a LOCAL json record and is never a live read, so it outlives the
# box it names. a name is ours and outlives every rebuild; an exid is infra's
# and dies with the box (`term=exid`).
#
# 🛑 .what this rung does NOT do, and where that check actually lives
#    it reads the DECLARATION and asserts the entry is well formed enough to be
#    addressable: an entry exists, and it names an account. it performs NO live
#    lookup — no `describe-instances`, no api call of any kind — so it cannot
#    and does not confirm the exid still addresses a live box.
#
#    ⇒ rung 2 is where that is settled. `git.grove.wake` resolves the exid
#      against infra's account and refuses when the active credentials point
#      elsewhere, so the live confirmation is one rung down and is not repeated
#      here — a second reader of one fact is free to drift from the first, and
#      the drift is silent (`gotcha.a-check-that-cries-wolf-gets-silenced`, m.9).
#
# ⚠️ .why this note exists at all
#    a header that claims the live confirmation — *"confirms the exid it carries
#    still addresses a live instance"* — has no line beneath it that performs
#    one, and a reader who trusts it reads a green rung 1 as evidence the box is
#    alive.
#
#    ⇒ the guard is not absent and the rung is not wrong. A CLAIM WIDER THAN ITS
#      READER is the hardest shape to see: every line of code is correct, and
#      the sentence above them is not.
######################################################################
######################################################################
# the ENTRY read — hoisted ABOVE every rung, on purpose
#
# .what = one read of the registry entry, into EXID / ACCOUNT / ENV / ORG.
#
# 🛑 .why it is hoisted rather than left inside rung 1
#    `--from N` skips the rungs beneath N. so a read that lives inside rung 1
#    leaves its variables UNSET for every resumed climb — and the resume is the
#    common case here, because the ladder's own halts end in `--from <rung>`.
#
#    ⇒ rung 2 needs ENV and ORG to reach the rack at all, and a `--from 2`
#      climb is exactly the call the previous halt told the human to make.
#
# ⚠️ and it is ONE reader, never a new one. the org was read a second time
#    further down, beside the plan that consumes it; that read is now this
#    block's, and the two cannot drift (`…cries-wolf`, m.9).
#
# 🟡 an ABSENT entry is tolerated here and HALTS AT RUNG 1. this block only
#    reads — every assertion stays in the rung that owns it, so a climb that
#    starts at rung 1 still reports the absence as a rung-1 failure rather
#    than as a bare jq error from above the ladder.
######################################################################
source ~/.bash_aliases 2>/dev/null || true
ENTRY="${GIT_FOREST_DIR:-$HOME/.git.forest}/groves/$GROVE.json"
EXID=""; ACCOUNT=""; ENV="camp"; GROVE_ORG_DECLARED=""
if [[ -f "$ENTRY" ]]; then
  EXID=$(jq -r '.exid // .name // ""' "$ENTRY")
  ACCOUNT=$(jq -r '.account // ""' "$ENTRY")
  ENV=$(jq -r '.env // "camp"' "$ENTRY")
  GROVE_ORG_DECLARED=$(jq -r '.org // ""' "$ENTRY")
  for V in EXID ACCOUNT ENV GROVE_ORG_DECLARED; do
    [[ "${!V}" == "null" ]] && declare "$V="
  done
  [[ -n "$ENV" ]] || ENV="camp"
fi

if _in_range 1; then
  echo "      ├─ 1. registry"
  if [[ ! -f "$ENTRY" ]]; then
    halt 1 registry \
      "no registry entry names '$GROVE', so no command can address it" \
      "rhx git.grove.set $GROVE --exid $GROVE --env camp --account <id>" \
      "" \
      "  see what IS registered —" \
      "rhx git.grove.list"
  fi
  echo "      │  ├─ exid:    $EXID"
  echo "      │  ├─ account: ${ACCOUNT:-<unset>}"
  echo "      │  └─ env:     $ENV"

  # ⚠️ the stale-exid trap. a dead exid does NOT fail as "no such host" — it
  #    fails deep in an aws lookup, or matches some OTHER instance that still
  #    carries the tag. so the address must be checked against infra's account
  #    before anything downstream trusts it (`howto.adopt-a-replacement-grove`).
  #
  # 🛑 .and this test is NOT that check — it is its PRECONDITION
  #    `-z "$ACCOUNT"` asks whether the entry HOLDS an account field. it does
  #    not ask whether that account holds this instance. the second question is
  #    rung 2's, and it needs a live api call this rung never makes.
  #
  #    ⇒ the halt below is worded for what it measures: an entry that names no
  #      account cannot be checked against one, so the ladder stops before rung
  #      2 would fail on a cause rung 1 could already see.
  if [[ -z "$ACCOUNT" ]]; then
    halt 1 registry \
      "the entry names no account, so a wake cannot assert it reached the right one" \
      "rhx git.grove.set $GROVE --exid $EXID --env $ENV --account <id>"
  fi
fi

######################################################################
# rung 2 — reach
#
# a wake is idempotent and cheap, so this rung simply drives it. its account
# assertion is the real test: it refuses when the active credentials point at
# an account other than the one the entry recorded.
#
# 🔴 .but a FAILED wake has TWO subjects, and only one of them is the box
#    measured 2026-09-28 on `grove-aether-v20260921`. this rung printed:
#
#      └─ ✋ rung 2 (reach) does not hold
#        why: the grove did not wake — see …/wake.log for the aws error
#
#    the box was `running`, and its duct answered `up 12 min` one command
#    earlier. the real cause sat in that very log: `aether.camp.AWS_PROFILE
#    status: locked 🔒` — a fact about THIS MACHINE's rack, not about the box.
#
# ⚠️ the verdict was not merely mis-worded, it was WRONG: reach held. and the
#    fix-text it printed was worse than useless — `keyrack unlock --env camp`
#    with no `--org` unlocks ANOTHER account's profile for a foreign-org box,
#    which `_rack_profile_fix` warns about by name. so the gate handed out the
#    one command its own holder says looks like a pass and is not.
#
# ⇒ the cure is to ask the LOCAL subject first. the rack read is free, local,
#   and deterministic, so a halt on it names the credential and the wake is
#   never reached. a wake that fails AFTER it is then genuinely about the box.
#
# 🟡 and this is not a grep of the wake log. keying on another component's
#   stderr would make this rung depend on that component's output FORMAT — the
#   invisible dependency `gotcha.the-duct-returns-the-send-not-the-answer`
#   names. `_rack_profile` is a direct read, so the discriminator reads its own
#   subject (`…cries-wolf`, q15).
#
# ✔ .PROVEN BOTH DIRECTIONS 2026-09-28 — and with NO deliberate break, because
#   a locked credential was already live on one org and not the other:
#     · locked   → `grove-ahbode-v20260811`, org ahbode, `--from 2`:
#         ✋ THIS MACHINE holds no aws profile for env=camp org=ahbode
#            — the box is unjudged, never unwell
#         fix: rhx git.grove.rack.unlock --org ahbode --env camp --key AWS_PROFILE
#     · unlocked → `grove-aether-v20260921`, org aether, rungs 1..5:
#         ✔ awake · ✔ 176 · ✋ 0 on both seats · ✔ every bundle verify held
#
#   ⚠️ the two boxes differ ONLY in whether this laptop held their org's
#     profile, so the pair isolates the discriminator and no other variable.
######################################################################
if _in_range 2; then
  echo "      ├─ 2. reach"

  # the LOCAL subject — does this machine hold a profile for that box's org?
  if ! _rack_profile "$ENV" "$GROVE_ORG_DECLARED" >/dev/null; then
    halt 2 reach \
      "THIS MACHINE holds no aws profile for env=$ENV${GROVE_ORG_DECLARED:+ org=$GROVE_ORG_DECLARED} — the box is unjudged, never unwell" \
      "rhx git.grove.rack.unlock${GROVE_ORG_DECLARED:+ --org $GROVE_ORG_DECLARED} --env $ENV --key AWS_PROFILE" \
      "" \
      "  ⚠️ a plain 'keyrack unlock --env $ENV' is the WRONG command for a" \
      "  foreign-org box: it unlocks another account's profile and looks" \
      "  like a pass. the org-scoped unlock above is the one that reaches."
  fi

  # the REMOTE subject — now a failure here really is about the box
  if ! rhx git.grove.wake "$GROVE" >"$LOGDIR"/wake.log 2>&1; then
    halt 2 reach \
      "the grove did not wake, and the rack DID hand over a profile — so this is the box" \
      "rhx git.grove.wake $GROVE" \
      "" \
      "  a wake is idempotent, so a second attempt is free — and a box resumed" \
      "  from hibernate often needs one, because a large box can outrun the" \
      "  aws waiter's bound on its first descent." \
      "" \
      "  read what it said —" \
      "tail -30 $LOGDIR/wake.log"
  fi
  echo "      │  └─ ✔ awake, and the account assertion passed"
fi

######################################################################
# _ask — run one command ON the grove and RETURN ITS VERDICT
#
# ⚠️ this helper exists because the ladder's first climb printed three false ✔
#    rows, all from one cause.
#
# `git.grove.send` on its DEFAULT path writes the command into a tmux pane and
# returns. the pane keeps the output; the caller gets the SEND's exit code, which
# is 0 whenever the text landed. a rung that judges that exit code judges no
# command at all. measured, on this very grove:
#
#     rhx git.grove.send <g> --what 'test -d /definitely/not/a/real/path'
#     → 🔧 duct://<g>/main/mechanic sent      exit 0
#
#     rhx git.grove.send <g> --bare --what 'test -d /definitely/not/a/real/path'
#     → exit 1
#
# a command that CANNOT succeed returned 0 through the duct. rungs 5 and 6 each
# printed ✔ on that 0, and rung 4's log held two lines of the send's own banner
# and not one line of the plan it asked for.
#
# 🛑 .and the FIX for that is NOT `--bare`
#    "a VERIFY must ride bare" names a third `--bare` trigger: *the duct carries
#    the command perfectly and discards the answer*. true, and an ESCAPE HATCH —
#    which got typed from habit until a human asked "why did you use bare?" and
#    the honest answer was habit (`rule.forbid.exemption-as-habit`).
#
#    so the trigger is solved at cause: `git.grove.send --reply` sends over the
#    DUCT and returns the command's own stdout and exit code, with 97 reserved
#    for "no verdict exists"
#    (`gotcha.the-duct-returns-the-send-not-the-answer`, closed 2026-08-13).
#
# ⇒ `_ask_at` uses `--reply`. every rung that puts a question to a converged box
#   rides the extant ductwork, and no rung judges a bare send's exit code for a
#   VERDICT it could have read.
#
# ⚠️ the measurement above stands, and is why a rung may never judge a DEFAULT
#    send's exit code. the remedy moved; the defect did not.
######################################################################
_ask() { _ask_at "$GROVE" "$1"; }

######################################################################
# _ask_bare — the ONE probe here that may not ride the duct
#
# rung 3 asks whether the box carries tmux, and a duct IS tmux. so that one
# question cannot ride its own subject — which is `--bare`'s first shipped
# trigger, verbatim ('no tmux yet').
#
# 🛑 this is a TRIGGER, never a habit. every other rung uses `_ask`, and a second
#    caller of this helper is a defect until its own trigger is named
#    (`rule.require.exemptions-name-their-trigger`, `rule.forbid.exemption-as-habit`).
#
# .note it needs no `_shell_at`, and that is the point: a bare ssh runs `bash -c`
#    with the default PATH, and tmux sits at `/usr/bin/tmux`. so the probe reaches
#    its subject with no login shell in front of it — and cannot inherit
#    `_shell_at`'s exit-3 halt, which would preempt this rung
#    (`gotcha.a-tool-found-by-path-answers-only-a-human`).
######################################################################
_ask_bare() {
  rhx git.grove.send "$GROVE" --bare --why 'no tmux yet' --what "$1"
}

######################################################################
# ⚠️ WHY THERE IS A `_ask_at` AT ALL — a modern grove image ships TWO login
#    users on one box, and they hold different powers:
#
#      ground  (ALL) NOPASSWD: ALL   converges the box — /etc, apt, systemd
#      camper  no sudo, by design    runs the agent, its ducts, its trees
#
#    camper's sudo-lessness is the POINT of the split, not a defect: a
#    compromised agent must not install a daemon or persist across a reboot
#    (`ahbode/infrastructure` → `rule.forbid.camper-sudo.md`).
#
#    so a convergence read from camper's seat is worthless. measured
#    2026-08-10: an apply from camper closed 6 of 78 claims, and every claim it
#    missed was a system write. worse, each of those reads as "the config is
#    absent" — indistinguishable from a box that genuinely lacks it.
#
#    ⇒ and each seat converges its OWN home and no other, measured 2026-08-12
#      (`term=seat`, fact 5) — so rung 4 climbs BOTH and tallies them apart.
#
# the body lives in `git.grove.operations.sh`, sourced above — with the
# LOGIN-SHELL scar it carries, and `_shell_at`, which picks the remote shell
# that serves a given seat's PATH.
######################################################################

# the convergence seat, by convention `<grove>.ground`. absent is a real answer:
# an older image grants camper sudo, so one seat converges the whole box
GROUND="$GROVE.ground"
GROUND_ENTRY="${GIT_FOREST_DIR:-$HOME/.git.forest}/groves/$GROUND.json"
[[ -f "$GROUND_ENTRY" ]] || GROUND=""

######################################################################
# 🛑 the ORG a plan is judged under is an INPUT, and a grove cannot derive it
#
# .measured 2026-09-28 on `grove-aether-v20260921`, rung 4, after BOTH seats
#  had converged clean with `--org aether`:
#
#     ├─ grove-aether-v20260921.ground — ✔ 233 · ✋ 7
#
#  seven claims on a box whose own applies raised none. every one an
#  ahbode/ehmpathy row: five in `5.13.reach`, two in `5.16.keys`
#  (`ahbode.prep.EHMPATH_BEAVER_GITHUB_TOKEN`, `ehmpathy.prep.…`).
#
# ⚠️ the cause is not the tree. both bundles gate every row on `$GROVE_ORG`,
#    and an AETHER box is owed ZERO rows in each. the plan this rung sends
#    carried no `--org`, so `grove_org_derive` fell back to the PUSHED
#    `.agent/keyrack.yml` — which declares `org: ahbode` — and the box was
#    judged against another org's whole table.
#
# 🔴 and this is the shape that decays a gate. every refusal it printed was
#    AWS-correct, with a named fix and a runnable command, so the page reads
#    as a real 7-claim box. a human who runs those fixes converges no row and
#    learns the gate lies (`gotcha.a-check-that-cries-wolf-gets-silenced`)
#
# ⇒ the registry holds the answer, beside `account` and `env`. read it here,
#   once, and carry it into the plan — the same read `git.grove.provision boot`
#   makes for its applies, so the two cannot disagree on the org of one box
######################################################################
# ⚠️ the read itself is HOISTED — see `the ENTRY read` above the ladder. do NOT
#    restore it here: that makes a SECOND reader of the entry beside rung 1's,
#    and leaves it unset for every rung beneath its own line — so rung 2 cannot
#    name the org it needs (`…cries-wolf`, m.9).

# 🛑 a LIVE clamp — this reaches a command line on a remote box
if [[ -n "$GROVE_ORG_DECLARED" && "$GROVE_ORG_DECLARED" == *[!A-Za-z0-9._@-]* ]]; then
  echo "✋ the registry's org holds a character a send cannot carry: '$GROVE_ORG_DECLARED'" >&2
  echo "   want: [A-Za-z0-9._@-]" >&2
  echo "   fix it: rhx git.grove.set $GROVE --org <org>" >&2
  exit 2
fi

PLAN_ORG_FLAG=""
[[ -n "$GROVE_ORG_DECLARED" ]] && PLAN_ORG_FLAG=" --org $GROVE_ORG_DECLARED"

######################################################################
# rung 3 — duct
#
# a duct is tmux, and a fresh box has none until 2.8.tmux lands. so this rung
# separates "the box is unreachable" from "the box is reachable but bare" —
# two very different repairs that a bare ssh failure would conflate.
#
# 🛑 .THIS RUNG MAY NOT RIDE WHAT IT TESTS — hence `_ask_bare`
#
#    every other rung uses `_ask` → `_ask_at` → `git.grove.send --reply`, which
#    IS the duct. this one cannot: it asks whether the box can hold a duct at
#    all, so a duct-borne probe answers its own question by assumption.
#
# 📜 .MEASURED 2026-08-30 — three defects, one cause, on a REBUILT grove
#
#    when this rung rode `_ask`, a rebuilt box — new host key, so ssh refuses at
#    the tofu check — produced this entire output:
#
#          ├─ 3. duct
#      🪨 run solid skill … git.grove.ready.verify
#         └─ 💥 failed with an error
#
#    no `why:`, no `fix:`, no ssh text, for a cause that is ONE command to
#    repair. the three defects behind it:
#
#    1. neither branch below could fire for its stated cause. with no duct to
#       carry the probe, `_shell_at` took 97 and halted the whole climb FIRST,
#       with `could not learn which shell serves '<seat>' … a pane another job
#       holds refuses the send outright` — a correct halt with a WRONG reason,
#       the costliest kind, because a reader agrees with it and repairs
#       elsewhere (`term=decline._.choice.reason.md`).
#    2. that 97 path returned before either `halt 3` was reached, so `duct.log`
#       — the one artifact that held the ssh text — was written and never read.
#    3. the same cause, put to the transport DIRECTLY, diagnosed in full: the
#       whole `REMOTE HOST IDENTIFICATION HAS CHANGED` block, plus `fix: rhx
#       git.grove.trust.gen`. so the message EXISTED and this rung dropped it
#       (`rule.require.errors-name-the-fix`).
#
# ⇒ all three share one cause and take one repair: a probe that needs no duct.
#   `_ask_bare` cannot reach `_shell_at`, so the halts below stay reachable,
#   `duct.log` is read, and a rebuilt box gets `trust.gen` by name.
#
# ⚠️ the ✔ arm is proven live; the no-tmux ✋ arm is not, because the infra image
#    ships tmux and no such box is at hand. a check proven in one direction is
#    half proven (`gotcha.a-check-that-cries-wolf-gets-silenced`, the corollary)
#    — so treat the first halt below as the unexercised one.
######################################################################
if _in_range 3; then
  echo "      ├─ 3. duct"
  if ! _ask_bare 'command -v tmux' >"$LOGDIR/duct.log" 2>&1; then
    if _ask_bare 'true' >/dev/null 2>&1; then
      halt 3 duct \
        "the box answers a bare ssh but carries no tmux — so it can hold no duct, which is the state of a box before 2.8.tmux lands" \
        # ⚠️ the DRIVER by path, and a carve-out under
        #    `rule.forbid.the-driver-by-path`: a `--bare` send is a
        #    non-interactive ssh, which reads no `.zshrc`, so `rhx` is not on
        #    PATH on the far side. every OTHER fix-text in this file names
        #    `rhx grove.provision`, because those ride the duct's interactive zsh
        "rhx git.grove.send $GROVE --bare --why 'no tmux yet' \\" \
        "  --what 'bash ~/git/more/dev-env-setup/src/grove.provision._.sh --what 2.8.tmux --mode apply'"
    fi
    halt 3 duct \
      "the box is awake per rung 2 and answers no ssh at all — either the endpoint presents an identity we do not trust (a REBUILT box does), or the tunnel bound its port and relays no session" \
      "rhx git.grove.trust.gen --grove $GROVE --mode apply --on-changed replace" \
      "rhx git.grove.stop --prune orphans" \
      "rhx git.grove.wake $GROVE" \
      "" \
      "  read what the ride said — it names which of the two it was —" \
      "tail -20 $LOGDIR/duct.log"
  fi
  echo "      │  └─ ✔ tmux is on the box, so a duct can hold"
fi

######################################################################
# rung 4 — tree
#
# `--mode plan` is a SURVEY: it short-circuits every upsert and still runs every
# verify. so it names exactly what a box lacks without a write. read its output
# for what is ABSENT, not only for what is red
# (`rule.require.every-function-has-a-driver`).
######################################################################
if _in_range 4; then
  echo "      ├─ 4. tree"
  ####################################################################
  # ⚠️ these two are named for WHAT THEY ARE, and neither is `GROVE_SRC`
  #
  #    the bundle runtime exports that name, and there it is the `src/`
  #    DIRECTORY (`grove.provision._.sh` — `export GROVE_SRC="$SRC"`), so
  #    every phase reaches the checkout with ONE dirname:
  #
  #      5.13.reach   checkout="$(dirname "$GROVE_SRC")"
  #
  #    this rung wants the ENTRYPOINT FILE, one level deeper. under the same
  #    name `GROVE_SRC`, one word carries two senses, so the arity that reaches
  #    the checkout differs by file: one dirname there, two here. no run breaks,
  #    since each file is self-consistent. the cost: a reader who carries
  #    `dirname "$GROVE_SRC"` across lands one level off, silently
  #    (`rule.require.ubiqlang` — each term for ONE concept only).
  #
  # ⇒ CHECKOUT is the repo copy on the box — the word 40+ files already use, and
  #   the one this rung's own halts speak. GROVE_ENTRY is the single entrypoint
  #   into the bundle tree (`rule.require.grove-provision-as-the-only-entrypoint`)
  ####################################################################
  CHECKOUT='~/git/more/dev-env-setup'
  GROVE_ENTRY="$CHECKOUT/src/grove.provision._.sh"

  # the seats this rung must satisfy. the bundle tree carries NO target-user
  # axis, so a run from one seat converges the system plus THAT seat's home and
  # leaves the other's bare. so both must read clean — one clean seat alone is a
  # box half converged that reports as whole.
  SEATS=("$GROVE")
  [[ -n "$GROUND" ]] && SEATS=("$GROUND" "$GROVE")   # ground FIRST; see below

  if [[ -n "$GROUND" ]]; then
    echo "      │  ├─ seats: $GROUND (converges), $GROVE (works)"
  else
    echo "      │  ├─ seats: $GROVE only — no .ground entry is registered"
    echo "      │  │         ⚠️ if this image splits its users, a read from a"
    echo "      │  │            sudo-less seat cannot see the system half"
  fi

  # ⚠️ report the org the plan is judged under. an ABSENT one is the loud case,
  #    because its consequence is silent: the plan then derives ahbode off the
  #    pushed manifest, and a foreign-org box is judged against ahbode's table
  if [[ -n "$GROVE_ORG_DECLARED" ]]; then
    echo "      │  ├─ org: $GROVE_ORG_DECLARED (the registry's)"
  else
    echo "      │  ├─ org: <none> — the plan will derive it off the pushed manifest"
    echo "      │  │       set it if this box is not an ahbode one:"
    echo "      │  │         rhx git.grove.set $GROVE --org <org>"
  fi

  # ⚠️ declared OUTSIDE the loop, because the halt comes after it — see the 🛑
  #    block beside `$CLAIMS` for why a per-seat halt left the second seat dark
  SEATS_DIED=()
  SEATS_UNCONVERGED=()

  for SEAT in "${SEATS[@]}"; do
    ##################################################################
    # 🛑 look up the seat's SHELL first, OUT LOUD, before any silenced probe
    #
    # every probe below ends `>/dev/null 2>&1`, which is right for its own
    # output — `test -f` says all it has to say in its exit code. but
    # `_ask_at` calls `_shell_at` FIRST, and `_shell_at` exits 3 with its
    # whole diagnosis on stderr. that `2>&1` swallows the diagnosis, and the
    # `exit 3` then fires with not one line printed.
    #
    # 📜 .MEASURED 2026-09-28 — rung 4, against a grove that was STOPPED
    #
    #        ├─ 4. tree
    #        │  ├─ seats: …ground (converges), … (works)
    #        │  ├─ org: aether (the registry's)
    #      🪨 run solid skill … git.grove.ready.verify
    #         └─ 💥 failed with an error
    #
    #   exit 3, no `why:`, no `fix:`, for a cause that is ONE command to
    #   repair — `rhx git.grove.wake <grove>`. the box was simply asleep.
    #
    # ⚠️ and this is rung 3's measurement, recurred at rung 4. that one was
    #   repaired with `_ask_bare`, which fixed the rung and not the SHAPE:
    #   the shape is a fallible step INSIDE a silenced context, and it recurs
    #   wherever a probe hides stderr it did not author
    #   (`rule.forbid.failhide`, `rule.require.errors-name-the-fix`).
    #
    # ⇒ the repair is to HOIST the fallible step out, un-silenced. asked here,
    #   its fault prints and exits loud; asked inside a probe, it cannot. the
    #   probes below then keep their redirects honestly, because the only
    #   stream left for them to hide is their own stdout.
    #
    # ✔ .PROVEN BOTH DIRECTIONS 2026-09-28, against a box deliberately hibernated
    #
    #   · broken   → the fault PRINTS: `✋ could not learn which shell serves …`
    #     with a `why:` and a `fix:`, exit 3 — where the same cause gave exit 3
    #     and not one line before the hoist
    #   · restored → `✔ 176 · ✋ 0` on both seats, `✔ every bundle verify held`
    #
    # ⚠️ and the break found a SECOND defect the green path CANNOT show: the text
    #   that printed asserted ONE cause (a pane another job holds) for a code with
    #   several, so the repair it named read a pane that never existed while the
    #   box slept. the verdict was right and its reason named another subject —
    #   m.4, recurred INSIDE the repair for a silent halt. `_shell_at` now names
    #   every cause with its own fix, cheapest-first
    #   (`git.grove.operations.sh`, its 97 block)
    #
    # ⇒ so a LOUD fault is not yet a CORRECT one. the hoist bought the first, and
    #   only the deliberate break could show the second was owed.
    ##################################################################
    _shell_at "$SEAT" >/dev/null || exit 3

    # ⚠️ the CHECKOUT first, as its own question. a box with no checkout and a
    #    box whose bundles have not converged both produce "0 ✔", and they take
    #    opposite repairs: one needs the repo pushed onto it, the other an apply
    #    of the repo already there. this rung's first climb reported the second
    #    fix for the first cause — a wrong-fix error, worse than an unhelpful
    #    one (`rule.require.errors-name-the-fix`).
    if ! _ask_at "$SEAT" "test -f $GROVE_ENTRY" >/dev/null 2>&1; then
      halt 4 tree \
        "seat '$SEAT' holds no dev-env-setup checkout — a fresh box is a fresh disk, and each seat has its own home" \
        "rhx git.grove.push $SEAT --from src/ \\" \
        "  --into 'git/more/dev-env-setup/src' --mode apply" \
        "" \
        "  and the three the tree reads BESIDE src/ —" \
        "rhx git.grove.push $SEAT --from package.json --into 'git/more/dev-env-setup' --mode apply" \
        "rhx git.grove.push $SEAT --from .nvmrc --into 'git/more/dev-env-setup' --mode apply" \
        "rhx git.grove.push $SEAT --from .agent --into 'git/more/dev-env-setup/.agent' --mode apply" \
        "" \
        "  ⚠️ push the WORKTREE, not a clone from main — a clone can only run" \
        "     what is merged, so it cannot prove an unmerged branch." \
        "  ⚠️ --into takes a REMOTE-HOME-RELATIVE path. a ~ at the front expands" \
        "     on THIS machine, and the grove's user is its own."
    fi

    ##################################################################
    # ⚠️ a checkout can hold src/ and still be PARTIAL
    #
    # the bundle tree reads three paths at the repo ROOT, beside src/ —
    # `package.json` (5.1.node's pnpm pin), `.nvmrc` (its node pin), and
    # `.agent/` (where `aws.reach.set` lives, which 5.13.reach calls). the
    # documented bootstrap push sends `src/`, so it sends none of them, and
    # the test above passes on a checkout that cannot converge.
    #
    # ⚠️ `.agent/` is the one no grep finds: the first two are read through a
    #    path expression, the third through `rhx aws.reach.set` — an
    #    invisible dependency that appears in no argument or declaration
    #    (`gotcha.a-tool-found-by-path-answers-only-a-human`).
    #
    # .measured 2026-08-12, fresh grove: 12 claims on the first apply, and 5
    #      of them were the one absent package.json —
    #        5.1.node no pnpm → 5.3.brains no rhx → 5.4.gh cannot read the
    #        rack → 5.10.repos unauthed → 5.13.reach declines
    #      every one of those four names a fix for ITS OWN bundle, so the
    #      tally below reports a box that is 5 claims worse than it is, and
    #      points at four innocent bundles (`rule.require.solve-at-cause`).
    #
    # ⇒ so this is asked BEFORE the plan, not read out of it: the plan cannot
    #   name a cause that lives in what was never sent.
    ##################################################################
    for MANIFEST in package.json .nvmrc; do
      if ! _ask_at "$SEAT" "test -f $CHECKOUT/$MANIFEST" >/dev/null 2>&1; then
        halt 4 tree \
          "seat '$SEAT' holds src/ but no $MANIFEST beside it — the checkout is PARTIAL, and 5.1.node reads that file for its pnpm and node pins" \
          "rhx git.grove.push $SEAT --from $MANIFEST --into 'git/more/dev-env-setup' --mode apply" \
          "" \
          "  ⚠️ do NOT work the claims a plan raises until this is sent." \
          "     an absent package.json is the head of a cascade — no pnpm ⇒" \
          "     no rhx ⇒ no keyrack read ⇒ no gh token ⇒ no org clone — and" \
          "     each downstream claim names a fix for its own bundle."
      fi
    done

    # `.agent/` — the third, and the one a grep of the tree never names
    if ! _ask_at "$SEAT" "test -d $CHECKOUT/.agent" >/dev/null 2>&1; then
      halt 4 tree \
        "seat '$SEAT' holds src/ but no .agent/ beside it — 5.13.reach calls \`rhx aws.reach.set\`, a repo=.this skill that lives there" \
        "rhx git.grove.push $SEAT --from .agent --into 'git/more/dev-env-setup/.agent' --mode apply" \
        "" \
        "  ⚠️ without it 5.13.reach reports 'could not give this seat reach'," \
        "     which READS as an infra trust-policy gap and is a push gap." \
        "     the skill never ran, so the box's reach stays UNTESTED." \
        "" \
        "  read which half is broken —" \
        "rhx git.grove.send $SEAT --reply \\" \
        "  --play diagnose.grove-reaches-this-repos-skills"
    fi

    TREE_LOG="$LOGDIR/tree.$SEAT.log"
    # ⚠️ `$PLAN_ORG_FLAG` carries the REGISTRY's org, derived once above. without
    #    it the plan judges a foreign-org box against ahbode's whole table, and
    #    every refusal reads correct — see the 🛑 block beside `GROUND=`
    _ask_at "$SEAT" "bash $GROVE_ENTRY --mode plan$PLAN_ORG_FLAG" >"$TREE_LOG" 2>&1 || true

    # judge the TALLY, never the exit code. a plan that ran no verify at all
    # would exit 0 and prove no bundle (`rule.forbid.failhide`)
    #
    # ⚠️ the ✋ glyph marks TWO different kinds of line, and only one is a claim:
    #
    #   ✋ git identity is INCOMPLETE …          a CLAIM — a phase found a fact
    #   ✋ grove.provision finished with failures  a SUMMARY — the runner totals up
    #
    # a count keyed on the glyph alone sweeps the runner's own sign-off in with
    # the phases, so every failing plan reports one claim more than it holds.
    # measured on grove-ahbode-v20260810, 2026-08-10: rung 4 printed `✋ 4` for a
    # seat with exactly 3 claims (2.2.git ×1, 5.13.reach ×2).
    #
    # ⇒ this is `gotcha.a-check-that-cries-wolf-gets-silenced` measurement 1,
    #   recurring in a second file. the summary is excluded BY NAME, because no
    #   pattern over the glyph can tell a claim from a total.
    CLAIMS=$(_count_claims "$TREE_LOG")
    MARKS=$(_count '✔' "$TREE_LOG")
    echo "      │  ├─ $SEAT — ✔ $MARKS · ✋ $CLAIMS"

    ##################################################################
    # 🛑 print the claims BESIDE the number, and record the seat — never halt here
    #
    # two defects, one edit, and each was measured on this rung:
    #
    # 1. the claims were not printed at all. the halt said `which bundles
    #    claimed — grep -B2 '✋' <log>`, and `grep` is not on a driver's
    #    permitted command set — so the one line that answers *which* was the
    #    one line the driver is refused. a fix-text that cannot be run names no
    #    fix (`rule.require.errors-name-the-fix`). ⇒ the rung already holds the
    #    log, so it prints the headlines itself (`_say_claims`).
    #
    # 2. 🔴 a halt INSIDE this loop leaves the SECOND seat unjudged, forever
    #    the rung halts at the first seat that does not hold, so a claim on
    #    ground hides the camper's whole verdict. that is tolerable for a claim
    #    a driver can clear — the next climb reads it. it is NOT tolerable for a
    #    claim only a HUMAN can clear: ground then fails every climb, and the
    #    camper's state is dark for as long as the credential is owed.
    #
    #    .measured 2026-09-28, grove-ahbode-v20260811: ground carried exactly 2
    #      claims, both `EHMPATH_BEAVER_GITHUB_TOKEN` rows whose repair is a
    #      human's paste on a laptop (a mint-only mech has no rack-readable
    #      source). so rung 4 could never report the camper again, and the
    #      camper's own 2 rows were knowable only by a hand-read of its log.
    #
    # ⇒ so the loop COLLECTS and the halt comes after it. a seat's verdict is
    #   never withheld on account of a seat before it, and the halt names every
    #   seat that failed at once — which is also one fewer remote plan per climb
    #   than a halt-then-resume loop costs.
    ##################################################################
    if [[ "$CLAIMS" -gt 0 ]]; then
      mapfile -t CLAIM_LINES < <(_say_claims "$TREE_LOG")
      for I in "${!CLAIM_LINES[@]}"; do
        if [[ "$I" -eq $(( ${#CLAIM_LINES[@]} - 1 )) ]]; then
          echo "      │  │  └─ ${CLAIM_LINES[$I]}"
        else
          echo "      │  │  ├─ ${CLAIM_LINES[$I]}"
        fi
      done
    fi

    # the checkout is proven present above, so a plan that marks NO ✔ did not
    # merely find a bare box — it never reached a verify at all
    if [[ "$MARKS" -eq 0 ]]; then
      SEATS_DIED+=("$SEAT")
    elif [[ "$CLAIMS" -gt 0 ]]; then
      SEATS_UNCONVERGED+=("$SEAT ($CLAIMS)")
    fi
  done

  # ⚠️ a run that DIED is reported first and alone. its cause is upstream of
  #    every claim, so an apply aimed at it repairs the wrong subject
  #    (`rule.require.solve-at-cause`)
  if [[ "${#SEATS_DIED[@]}" -gt 0 ]]; then
    halt 4 tree \
      "the checkout is on ${SEATS_DIED[*]}, yet the plan marked no ✔ at all — the run died before it reached one verify" \
      "rhx git.grove.send ${SEATS_DIED[0]} --reply \\" \
      "  --what 'bash $GROVE_ENTRY --mode plan$PLAN_ORG_FLAG'" \
      "" \
      "  read what the plan said —" \
      "tail -40 $LOGDIR/tree.${SEATS_DIED[0]}.log"
  fi
  if [[ "${#SEATS_UNCONVERGED[@]}" -gt 0 ]]; then
    halt 4 tree \
      "bundle verify(s) did not hold on ${SEATS_UNCONVERGED[*]} — each claim is named above, under the seat that raised it" \
      "per seat, ground FIRST —" \
      "rhx git.grove.send <seat> --bare --why 'no tmux yet' \\" \
      "  --detach --log '\\\$HOME/grove.provision.log' \\" \
      "  --what 'bash $GROVE_ENTRY --mode apply$PLAN_ORG_FLAG'" \
      "" \
      "  ⚠️ DETACHED on purpose. a full apply outruns an ssh connection, and a" \
      "     grove can sleep mid-run — a detached job owns its own session." \
      "" \
      "  ⚠️ read each claim before you apply. a claim whose repair is a HUMAN's" \
      "     paste — a mint-only credential has no rack-readable source — is one" \
      "     no apply on this box can ever clear, and a tty on the provision" \
      "     path is itself a blocker." \
      "" \
      "  ⚠️ if a seat has NO sudo, the apply will claim on every system" \
      "     bundle and each claim will read as 'the config is absent'. prove" \
      "     the seat before you trust its verdict —" \
      "rhx git.grove.send <seat> --reply --play prove.ground-seat-converges"
  fi
  echo "      │  └─ ✔ every bundle verify held"
fi

######################################################################
# rung 5 — creds
#
# two consumers, two routes. `gh` holds a login taken ONCE at apply time; plain
# https git asks the rack on EVERY fetch. so one can be green while the other
# prompts, and a human sees only "it asked me for a password" with no clue which
# half broke (`rule.require.github-token-at-all-camp`). test each.
######################################################################
if _in_range 5; then
  echo "      ├─ 5. creds"
  if ! _ask 'gh auth status' >"$LOGDIR/gh.log" 2>&1; then
    halt 5 creds \
      "gh holds no auth — its login is taken once at apply time, so a rack rotation does not reach it on its own" \
      "rhx git.grove.send $GROVE \\" \
      "  --what 'rhx grove.provision --what 5.4.gh --mode apply'" \
      "" \
      "  if the rack itself is empty, place the token first —" \
      "rhx git.grove.auth.github.set"
  fi
  echo "      │  ├─ ✔ gh authed"

  if ! _ask 'aws sts get-caller-identity' >"$LOGDIR/aws.log" 2>&1; then
    halt 5 creds \
      "the box cannot name its own aws identity — an ambient role is absent, or the aws cli is not configured" \
      "rhx git.grove.send $GROVE \\" \
      "  --what 'rhx grove.provision --what 5.6.aws --mode apply'" \
      "" \
      "  read what it said —" \
      "tail -20 $LOGDIR/aws.log"
  fi
  echo "      │  └─ ✔ aws identity answers"
fi

echo ""
echo "🌳 cowabunga! $GROVE is ready"
echo "   ├─ rungs:  $FROM..$UPTO, every one held"
echo "   └─ next:   rhx git.grove.provision test $GROVE"

#!/usr/bin/env bash
######################################################################
# git.grove.provision boot — bare box to acceptance-grade, in ONE command
#
# ⚠️ reached through the dispatcher: `rhx git.grove.provision boot <name>`.
#    `git.grove.provision.sh` execs this file; it carries no slug of its own.
#
# .what = drives the WHOLE provision, in the one order that works:
#
#           0. grants  — ask the HUMAN-ONLY credentials FIRST, before any reach
#           1. reach   — wake the tunnel, trust the host key
#           2. ground  — push, then ONE apply. the seat WITH sudo goes first
#           3. camper  — push, then ONE apply. the seat that does the work
#           4. gate    — `git.grove.provision test`, with no command in between
#
# ⚠️ .why step 0 exists, and why it runs before the tunnel
#         a grant only a HUMAN can make is one no bundle can converge. a pat is
#         MINTED at github by a person; no box derives one. so its absence is
#         not a defect a run can repair — it is a question for the human, and
#         the cost of that question depends entirely on WHEN it is asked.
#
#         📜 measured 2026-09-21 on `grove-aether-v20260921`. the box provisioned
#            both seats, then reported 15 claims, 3 of which were one absent
#            `@all.camp.GITHUB_TOKEN`. the human was asked for it AFTER a full
#            unattended run — so the run had to be driven twice, and the first
#            pass answered a question nobody had been given the chance to settle.
#
#         ⇒ the rule this serves: **a human-only grant is asked UPFRONT, at the
#           cheapest moment, never discovered mid-run.** a machine-fixable gap
#           belongs in a bundle (`rule.forbid.deferred-provision-defects`); a
#           human-only grant belongs in this step.
#
# .why a SKILL and not the howto = `howto.provision-a-grove.md` carried these
#         as seven prose commands for a human to type in order. that is a skill
#         written as prose, and it fails the three ways prose fails:
#
#           - a step is SKIPPED, and the fault surfaces three layers down.
#             measured 2026-08-26: a push run with no prior `wake` reported
#             `connect to host localhost port 36902: Connection refused` —
#             a message that names the tunnel and never names the absent step
#           - the ORDER is load-bear and invisible. camper-first draws a ✋
#             from every box-wide bundle, since that seat holds no sudo by
#             design (`term=seat`), and each ✋ names a defect that is not one
#           - "type no command between step 4 and 5" is a rule only a human can
#             break, and the bar it guards is the whole point of the exercise
#
#         `rule.require.wrap-cli-in-skills` and `rule.require.install-via-procedures`
#         both name this: never hand a human an ordered list to type.
#
# ⚠️ .the bar this guards = ONE apply per seat, non-interactive, from scratch
#         (`rule.require.one-command-provision`). so this drives exactly one
#         apply per seat, and it asks the BOX whether an apply already ran there
#         rather than quietly drive a second — see `_prior_apply_at` for why the
#         box is asked and no local record is kept.
#
# ⚠️ .exit 97 is NO VERDICT, never a failure. an apply rides `--detach`, and its
#         verdict comes from a SECOND read of the log — never from the send
#         (`gotcha.the-duct-returns-the-send-not-the-answer`). so a slow box
#         extends the wait; it never yields a failure that did not happen.
#
# usage:
#   rhx git.grove.provision boot <name>                        # plan — name the steps, run none
#   rhx git.grove.provision boot <name> --mode apply
#   rhx git.grove.provision boot <name> --mode apply --from 3  # resume at the camper
#   rhx git.grove.provision boot <name> --from 0               # ask the grants alone
#   rhx git.grove.provision boot <name> --mode apply --trust replace   # a REBUILT box
#
# options:
#   --mode    plan | apply             default plan
#   --from    first step to run (0-4)  default 0
#   --trust   verified | replace | tofu | keep    default verified — the host key
#             is checked against the box's OWN report: on ec2 its boot record
#             (console / ssm), on the tailnet its keys over ssh pinned to a key
#             already trusted. a tailnet FIRST contact has no report: `tofu`.
#             `replace` for a REBUILT box whose key changed (still verified);
#             `tofu` accepts a scan with NO attestation, and is a human's call
#             to make explicitly — see the 🛑 at the trust step below
#   --within  seconds to allow one apply   default 2700 (45m)
#   --what    one bundle slug — the same steps 1-3, each apply narrowed to it
#
# 🛑 .--what is how ONE bundle reaches a grove — never a hand-typed push + send
#      📜 2026-11-20: asked to apply 5.26.backup alone, a clone handed the human six
#         commands (sync, trust, wake .ground, push, send plan, send apply) copied out
#         of this file's own internals. each was a step this skill already owns, in an
#         order it already enforces. a skill short one flag is a skill to extend, never
#         a procedure to re-type (`rule.forbid.adhoc-shell`)
#
# guarantee:
#   - exit 0 = the box provisioned AND passed the gate
#   - exit 3 = a step did not hold; it is named, with its fix
#              (a step-0 halt names a command for a HUMAN to run, never a repair
#               this skill could have made)
#   - exit 2 = bad input
#   - exit 1 = malfunction
######################################################################
set -uo pipefail

# ── help, found ANYWHERE in the args — never at $1 alone
#
# 🛑 rhachet INJECTS `--skill <slug>` ahead of the caller's own args, so `$1` is
#    an injected flag on every invocation and no `$1` test can ever fire. the
#    parse loop below takes the first bare word as the GROVE NAME, so a `$1`
#    check here does not merely fail to answer — it plans a provision against a
#    box named `help`. read `$*`, padded, so `helpdesk` is spared.
if [[ " $* " == *" help "* || " $* " == *" --help "* || " $* " == *" -h "* ]]; then
  echo "git.grove.provision boot — bare box to acceptance-grade, in ONE command"
  echo ""
  echo "usage:"
  echo "  rhx git.grove.provision boot <name> [--mode plan|apply] [--from N] [--trust verified|replace|tofu|keep] [--within S]"
  echo ""
  echo "inputs:"
  echo "  <name>    the grove, as rhx git.grove.list names it      (required)"
  echo "  --mode    plan names the steps and runs none; apply runs them  (default plan)"
  echo "  --from    the first step to run, 0-4                      (default 0)"
  echo "  --trust   how the host key is trusted at step 1           (default verified)"
  echo "            verified — checked against the box's own report; an unattested key halts"
  echo "            replace  — verified, and a CHANGED key is re-trusted (a rebuilt box)"
  echo "            tofu     — the check is skipped: a tailnet first contact, by your word"
  echo "            keep     — the trust step is not run"
  echo "  --within  seconds to allow one seat's apply               (default 2700)"
  echo "  --what    apply ONE bundle (a slug) on both seats, not the whole tree"
  echo "            the same reach, push, and ground-then-camper order; no grants,"
  echo "            no key placement, no gate — those are claims about a WHOLE box"
  echo ""
  echo "examples:"
  echo "  rhx git.grove.provision boot <name> --what 5.26.backup --mode apply    # one bundle"
  echo "  rhx git.grove.provision boot <name>                                    # plan"
  echo "  rhx git.grove.provision boot <name> --mode apply                       # the whole boot"
  echo "  rhx git.grove.provision boot <name> --mode apply --trust tofu          # a tailnet first contact"
  echo "  rhx git.grove.provision boot <name> --mode apply --from 3 --trust keep # resume at the camper"
  echo ""
  echo "the steps:"
  echo "  0. grants  — ask the HUMAN-ONLY credentials first, before any reach"
  echo "  1. reach   — wake the road (an ec2 tunnel, or the tailnet), trust the host key"
  echo "               (a tailnet first contact: --trust tofu, by your word)"
  echo "  2. ground  — push, then ONE apply (the seat WITH sudo goes first)"
  echo "  3. camper  — push, then ONE apply (the seat that does the work)"
  echo "  4. gate    — git.grove.provision test, with no command in between"
  echo ""
  echo "the ORDER is the point: ground converges every box-wide fact, so the"
  echo "camper's apply asks for no root at all — and step 0 runs first so a"
  echo "grant only a human can make is asked BEFORE a 45-minute unattended run,"
  echo "never discovered as a claim at the end of one."
  echo "exit 0 = provisioned + gated | 3 = a step failed | 2 = bad input"
  exit 0
fi

GROVE=""
MODE="plan"
# ⚠️ 0, never 1 — step 0 is the grants preflight, and it runs on EVERY default
#    invocation. to default to 1 would make the preflight opt-in, which is the
#    same as absent: a human who knew to ask for it did not need it.
FROM=0
WHAT=""
####################################################################
# 🛑 the default is VERIFIED, and never `tofu`
#
# .why = `git.grove.trust.gen` checks that EVERY offered host key appears in the
#      box's own report (`FINGERPRINTS_SCAN ⊆ FINGERPRINTS_BOOT`, via ec2
#      console output or ssm, or a tailnet box's own keys over a pinned ssh) —
#      and `--trust tofu` is the flag that skips that
#      check entirely. a tofu DEFAULT walks the PAVED ONE-COMMAND PATH, the one
#      a human is told to run, around the strongest control this repo has over a
#      trust anchor.
#
# 🛑 .and "trust on first use" is not what happens here
#      a grove is reached at `localhost:$PORT`, and the port defaults to the
#      same number for every grove. so "a port never seen before" — tofu's own
#      justification — is false: an orphaned tunnel from another
#      grove, a second grove on the default port, or any other local process
#      that binds it first becomes what gets pinned into `~/.ssh/known_hosts`
#      as this box's permanent identity. tofu's whole premise is that the first
#      answer is authentic, and a shared local port cannot support it.
#
# .what each value does
#      verified  (default) — the subset check runs; an unattested key HALTS
#      replace             — verified, and a CHANGED key is re-trusted (a rebuild)
#      tofu                — the check is SKIPPED. a human's explicit call, for a
#                            box whose boot record genuinely cannot be read
#      keep                — trust.gen is not run at all
####################################################################
TRUST="verified"
WITHIN=2700

# a bad input names itself, ONE next step, and the help — then exits 2 (the caller fixes it)
#   the hint, where the refusal has one, IS that step; else the call itself, with what the caller
#   already named (its grove, its --what), so a fix never widens a one-bundle boot to the whole tree
boot_input_refused() {
  local what="$1" hint="${2:-}" call="rhx git.grove.provision boot ${GROVE:-<name>}"
  [[ "${WHAT:-}" =~ ^[A-Za-z0-9._-]+$ ]] && call+=" --what $WHAT"
  echo "✋ ConstraintError: $what" >&2
  [[ -n "$hint" && "$hint" != fix:* ]] && echo "   ├─ $hint" >&2
  if [[ "$hint" == fix:* ]]; then echo "   ├─ $hint" >&2; else echo "   ├─ fix: $call --mode apply" >&2; fi
  echo "   └─ every input: rhx git.grove.provision boot --help" >&2
  exit 2
}

while [[ $# -gt 0 ]]; do
  # a value flag with no value names itself, never a bash `unbound variable`
  [[ "$1" =~ ^--(mode|from|trust|within|what)$ && $# -lt 2 ]] && boot_input_refused "$1 needs a value"
  case "$1" in
    --mode)   MODE="$2";   shift 2 ;;
    --what)   WHAT="$2";   shift 2 ;;
    --from)   FROM="$2";   shift 2 ;;
    --trust)  TRUST="$2";  shift 2 ;;
    --within) WITHIN="$2"; shift 2 ;;
    --skill|--repo|--role) shift 2 ;;
    --) shift; [[ -z "$GROVE" ]] && { GROVE="${1:-}"; shift 2>/dev/null || true; } ;;
    -*) boot_input_refused "unknown flag '$1'" \
          "valid: --mode plan|apply  --from 0-4  --trust verified|replace|tofu|keep  --within <secs>  --what <slug>  --help" ;;
    *) [[ -z "$GROVE" ]] && GROVE="$1"; shift ;;
  esac
done

[[ -n "$GROVE" ]] || boot_input_refused "no grove named" "list them: rhx git.grove.list"
[[ "$MODE" == "plan" || "$MODE" == "apply" ]] || boot_input_refused "--mode '$MODE' is not plan or apply"
[[ "$FROM" =~ ^[0-4]$ ]] || boot_input_refused "--from '$FROM' is not a step 0-4"
[[ "$TRUST" =~ ^(verified|tofu|replace|keep)$ ]] ||
  boot_input_refused "--trust '$TRUST' is not verified, replace, tofu, or keep"
[[ "$WITHIN" =~ ^[0-9]+$ ]] || boot_input_refused "--within '$WITHIN' is not a whole number of seconds"
# 🛑 a LIVE clamp — the slug reaches a command line on a remote box
[[ -z "$WHAT" || "$WHAT" =~ ^[A-Za-z0-9._-]+$ ]] ||
  boot_input_refused "--what '$WHAT' is not a bundle slug ([A-Za-z0-9._-])" "list them: rhx grove.provision --mode plan"
# `--what` runs the two seat steps (2, 3) and no gate: a --from past them would apply naught
[[ -z "$WHAT" || "$FROM" -le 3 ]] ||
  boot_input_refused "--from $FROM skips both seats, so --what would apply naught" "fix: rhx git.grove.provision boot ${GROVE:-<name>} --what $WHAT --from 2 --mode apply (both seats), or --from 3 (camper alone)"

# the transport, shared so it cannot drift from every other grove read
# (`rule.forbid.two-writers-on-one-artifact`)
source "$(dirname "${BASH_SOURCE[0]}")/git.grove.operations.sh"

# the RACK read, shared for the same reason — `_rack_profile` carries the org
# axis and RELAYS keyrack's stderr, and `_rack_profile_fix` names the one repair
# each state wants. seven other skills already read the rack through it
source "$(dirname "${BASH_SOURCE[0]}")/git.grove.rack.operations.sh"

# the platform findsert over a seat — an ssh communicator, kept with the other
# seat writes so `prove.platform-findsert-names-each-verdict` can drive it alone
source "$(dirname "${BASH_SOURCE[0]}")/git.grove.ssh.operations.sh"

# the step printers (`say`, `halt`) and the steps a play must render — the
# platform declaration and the key placement (`prove.boot-steps-name-each-verdict`)
source "$(dirname "${BASH_SOURCE[0]}")/git.grove.provision.boot.operations.sh"

RHX="${RHX:-rhx}"

# ⚠️ .a RELATIVE remote path, never `~/…` or `/…`
#
#    a `~` on an `--into` path expands LOCALLY, so `~/git/…` reaches the push
#    already resolved to `/home/<this-laptop-user>/git/…` — and the grove's user
#    is its own, and it CHANGES between images. ssh and rsync both read a
#    relative remote path as home-relative, so this is the one form that follows
#    the box. `git.grove.push` REFUSES a `~/` or `/` prefix rather than land the
#    content somewhere silent.
INTO='git/more/dev-env-setup'

# ⚠️ .NO `--for cloud`, and the absence is the point
#
#    the server is DETECTED (`src/grove.env.sh`), and both applies report
#    `server cloud@aws.ec2` with no flag — measured on a fresh grove 2026-08-13.
#    a hand-passed `--for` OVERRIDES that detection on exactly the box where a
#    detection defect would matter, so it hides the one fact worth a proof
#    (`rule.require.prove-the-path-the-human-runs`).
UPGRADE='bash $HOME/git/more/dev-env-setup/src/grove.provision._.sh --mode apply'

# 🛑 .the ORG is an INPUT, and a grove CANNOT derive its own
#
# .measured 2026-09-28 on `grove-aether-v20260921`, ground seat, first apply:
#
#     ✋ ahbode.test — the hop is declared, and this box is REFUSED it
#     ✋ ahbode.prep — the hop is declared, and this box is REFUSED it
#     ✋ ahbode.prod — the hop is declared, and this box is REFUSED it
#     ✋ ehmpathy.test — the hop is declared, and this box is REFUSED it
#     ✋ ehmpathy.prep — the hop is declared, and this box is REFUSED it
#
#    five `5.13.reach` claims, every one an ahbode/ehmpathy hop, on an AETHER box.
#    the tree was right: `5.13.reach/_.sh` gates each row on `$GROVE_ORG` and
#    carries only an `ahbode)` arm, so aether is owed ZERO rows.
#
# ⚠️ the defect is upstream of the tree — `grove_org_derive` falls back to the
#    PUSHED `.agent/keyrack.yml`, and this repo's manifest declares `org: ahbode`.
#    so every foreign-org grove inherits ahbode's whole reach table, and every
#    refusal it then prints is AWS-correct (`5.13.reach/configure.verify.sh`
#    records the same measurement from 2026-09-24).
#
# ⇒ the registry already holds the answer, beside `account` and `env`, so the
#   boot reads it and passes `--org`. a `boot` that omits the flag reproduces
#   this on every foreign-org grove, and the human would owe it by hand forever
#   (`rule.require.one-command-provision`).
BOOT_ORG=$(jq -r '.org // ""' \
  "${GIT_FOREST_DIR:-$HOME/.git.forest}/groves/$GROVE.json" 2>/dev/null) || BOOT_ORG=""
[[ "$BOOT_ORG" == "null" ]] && BOOT_ORG=""

# 🛑 a LIVE clamp — this reaches a command line on a remote box
if [[ -n "$BOOT_ORG" && "$BOOT_ORG" == *[!A-Za-z0-9._@-]* ]]; then
  echo "✋ the registry's org holds a character a send cannot carry: '$BOOT_ORG'" >&2
  echo "   want: [A-Za-z0-9._@-]" >&2
  echo "   fix it: rhx git.grove.set $GROVE --org <org>" >&2
  exit 2
fi

[[ -n "$BOOT_ORG" ]] && UPGRADE="$UPGRADE --org $BOOT_ORG"
[[ -n "$WHAT" ]] && UPGRADE="$UPGRADE --what $WHAT"

echo "🐢 heres the wave..."
echo ""
echo "🌱 git.grove.provision boot $GROVE --mode $MODE"
if [[ -n "$WHAT" ]]; then
  echo "   ├─ what: $WHAT — one bundle, on each seat; no grants, keys, or gate"
  echo "   ├─ steps: $(( FROM > 1 ? FROM : 1 ))..3"
else
  echo "   ├─ steps: $FROM..4"
fi
echo "   ├─ trust: $TRUST"
echo "   ├─ within: ${WITHIN}s per apply"
# ⚠️ an ABSENT org is reported out loud, because its consequence is silent: the
#    apply then derives ahbode off the pushed manifest, and a foreign-org box
#    inherits a reach table it is refused every row of
if [[ -n "$BOOT_ORG" ]]; then
  echo "   ├─ org: $BOOT_ORG (the registry's)"
else
  echo "   ├─ org: <none> — the apply will derive it off the pushed manifest"
  echo "   │  └─ set it if this box is not an ahbode one:"
  echo "   │     rhx git.grove.set $GROVE --org <org>"
fi
echo "   └─ run"

######################################################################
# _prior_apply_at — did an apply ALREADY run on THIS box, for this seat?
#
# 🛑 the subject is the BOX, never the grove NAME. a name survives a rebuild —
#    that is the whole point of a name — so a record keyed on one outlives its
#    subject and then speaks with authority about a box that no longer exists.
#
#    ⚠️ and it is NOT a `marker` — that word is taken, for a different concept:
#       a fixed line appended into a file this repo does not own, so an APPEND
#       is idempotent (`term=marker`). a local file that remembers a REMOTE
#       fact differs in kind. one word over two concepts is the ambiguity
#       `rule.forbid.domain-term-synonyms` forbids, so it is spelled `record`.
#
#    .measured 2026-08-30. this skill kept a local record at
#        $XDG_STATE_HOME/git.grove.provision/<name>/applied.<seat>
#    the instance was terminated and rebuilt under the same name, and the plan
#    then reported "this skill already drove an apply on ground — 07:05:47Z"
#    about an instance that had been dead for half an hour. so the ONE
#    from-scratch box the bar waits for read as a SECOND run
#    (`gotcha.a-check-that-cries-wolf-gets-silenced` — the false ✋ is the
#    corrosive half, because to act on it is to discard a true measurement).
#
# ⇒ so the question is put to the BOX, which holds the only copy that cannot
#   outlive it: the apply writes its own `--detach --log` onto that disk, and a
#   rebuild takes the disk with it. one fact, one reader
#   (`rule.forbid.two-writers-on-one-artifact`).
#
# ⚠️ THREE answers, never two. a duct that gives no verdict has said not one
#    word about the box — 97 is the transport, never the subject
#    (`gotcha.the-duct-returns-the-send-not-the-answer`). to fold that arm into
#    either of the others buys a false ✔ one way and a false ✋ the other.
#
# ⚠️ and the probe is BOUNDED. a plan is meant to be cheap, and a plan may run
#    against a box that was never woken — step 1 wakes none in plan mode. an
#    unbounded ask would hold the survey 900s per seat, over a question whose
#    honest answer at that point is "could not tell"
#    (`rule.require.bounded-probes-in-verifies`).
#
# ✔ .seen to DISCRIMINATE — all three arms, 2026-08-30, one seat, minutes apart
#    a check proven one way is half proven (`term=bite`), so each arm was
#    watched fire on a real case:
#
#      test -d /home                    → rc 0   → yes      (a real true)
#      test -f …/grove.provision.*.log   → rc 1   → no       (a real false)
#      the same probe, seat not yet woken → rc 97 → unknown  (a real refusal)
#
#    ⚠️ the `no` arm nearly read as a transport fault: rhachet prints
#       `💥 failed with an error` for ANY non-zero exit, so a truthful `false`
#       wears the same banner as a break. the control probe above separates
#       them, which is why one is written down here — a glyph from a wrapper is
#       no evidence about the command underneath it.
######################################################################
_prior_apply_at() {
  local seat="$1" log="$2" rc=0
  "$RHX" git.grove.send "$seat" --await 15 --reply --within 25 \
    --what "test -f $log" >/dev/null 2>&1 || rc=$?
  case "$rc" in
    0)  echo yes ;;      # the log is there — an apply ran on THIS disk
    97) echo unknown ;;  # the duct, not the box. claim neither arm
    *)  echo no ;;       # the command answered, and answered false
  esac
}

######################################################################
# drive_seat — push this seat's checkout, then drive its ONE apply
#
# ⚠️ the apply rides `--detach`, never `--reply --within`. a `--reply` that
#    outruns its window returns 97 while the apply CARRIES ON, so a caller that
#    resumed would drive a SECOND apply over a first that never stopped — the
#    exact event the bar counts (`rule.require.one-command-provision`).
#    a detached run owns its own session, so the wait is ours to extend.
######################################################################
drive_seat() {
  local seat="$1" label="$2" step="$3" upgrade="${4:-$UPGRADE}"
  local log='$HOME/grove.provision.'"$label"'.log'

  # a `--what` run follows a whole-tree one by design, so a prior log is no news there
  [[ -z "$WHAT" ]] && case "$(_prior_apply_at "$seat" "$log")" in
    yes)
      say "│  ⚠️ this BOX already holds an apply log for $label"
      say "│     a second apply proves the SECOND run, and says none of what the"
      say "│     first does. only a from-scratch box proves the bar."
      ;;
    unknown)
      say "│  · prior apply: no verdict — the duct did not answer inside its bound"
      say "│    (a fact about the DUCT. it says none about the box)"
      ;;
  esac

  if [[ "$MODE" == "plan" ]]; then
    say "│  · would push . → $seat:$INTO"
    say "│  · would apply, detached, up to ${WITHIN}s"
    return 0
  fi

  # ── carry the checkout
  #
  # ⚠️ `--from .`, never `--from src/`. a `src/`-only push leaves a grove with no
  #    `package.json`, no `.agent/`, and no `readme.md` — so `rhx` cannot run
  #    there and NO SKILL is reachable, which breaks step 4 outright. the push
  #    skips `.git`, `node_modules`, `.log`, `.temp`, and `.agent/.cache` on both
  #    carriers and prints that list, so a whole-repo push is cheap.
  #
  # ⚠️ stdout is quieted so the tree stays readable; stderr is NOT. a sequencer
  #    that swallows its steps' errors reports a step number and destroys the
  #    one sentence that says WHY (`term=swallow`) — and the `fix:` below is a
  #    guess by construction, since it cannot see what went wrong.
  if ! "$RHX" git.grove.push "$seat" --from . --into "$INTO" --mode apply >/dev/null; then
    halt "$step" "$label" \
      "the push to $seat did not land" \
      "$RHX git.grove.wake $seat --mode apply" \
      "$(boot_reach_road_line)" \
      "$RHX git.grove.push $seat --from . --into '$INTO' --mode apply"
  fi
  say "│  ├─ push ✔"

  ####################################################################
  # 🛑 a RUN MARKER, written before the apply — every read below slices from it
  #
  # `git.grove.send --detach` writes `>> "$LOG"`, so ONE path accumulates every
  # apply that box ever ran. that is correct for the send — a detached job must
  # not clobber a log another reader holds — and it makes every UNBOUNDED read
  # here a claim about the wrong run.
  #
  # 📜 measured 2026-09-14 on a grove whose ground seat had applied twice.
  #    `git.grove.auth.keys.set` placed 8 keys and the grove read each one back;
  #    this boot then reported all 8 as `the rack hands over an EMPTY value`.
  #    one claim, two readers, and the boot read an OLDER apply
  #    (`gotcha.a-check-that-cries-wolf-gets-silenced`, m.9).
  #
  #    ⚠️ two lines it printed could not have come from that run at all: `the
  #       rack names no profile for ehmpathy.demo.AWS_PROFILE` is unreachable
  #       under the current `5.13.reach` verify, and the tmux TERM claim had
  #       been proven green on that box hours earlier. that pair is what
  #       exposed it — a false ✋ is the half that gets a check SILENCED.
  #
  # 🛑 the FALSE ✔ is the worse half, and it had not fired yet. the poll below
  #    reads four lines twenty seconds after the send; before the new apply has
  #    written four, that tail carries the PRIOR run's terminal line — so a box
  #    whose last apply ended `🌲 grove.provision done` reports `✔ converged in
  #    ~0m` for a run that had just begun.
  #
  # ⇒ the repair is at cause and it KEEPS the history: mark the log, then read
  #   only what follows the mark. an unwritten mark makes every slice empty,
  #   which the empty-payload arm below already halts on — so this degrades to
  #   a loud halt and never to a verdict (`rule.forbid.failhide`).
  #
  # ⚠️ the marker carries NO glob metacharacter and NO dash at its head: the
  #    duct runs an interactive zsh (see the claim read below), and a `printf`
  #    whose first argument opens with `-` is parsed as an option. `%s` is why
  #    the format holds whatever the marker becomes
  #    (`rule.forbid.bare-globs-in-dual-shell-files`).
  ####################################################################
  local mark="~~~ boot run $(date +%s).$$ ~~~"

  # 🛑 the sed expression is wrapped in DOUBLE quotes, and that is load-bear
  #
  # 📜 measured 2026-09-14, on this file's own first run. a single-quoted
  #    expression reads fine programmatically — the transport escapes the whole
  #    `--what` verbatim — and it COLLIDES the moment a halt quotes it for a
  #    human, since every fix-text here wraps `--what` in single quotes:
  #
  #      --what 'sed -n '/~~~ boot run N ~~~/,$p' $HOME/…'
  #             └ opens ┘                        └ closes ┘
  #
  #    ⇒ the pasted command loses its quoting: `$p` expands to empty, `~~~`
  #      reaches zsh bare, and the one command whose job is to SHOW this run's
  #      log shows none of it (`rule.require.errors-name-the-fix`).
  #
  # ⇒ double inside, single outside. `\$p` survives the far shell's double
  #   quotes as a literal, and `$HOME` still expands THERE rather than on the
  #   human's box — which is the whole point, since the seats do not share one.
  local slice="sed -n \"/$mark/,\\\$p\" $log"

  if ! "$RHX" git.grove.send "$seat" --reply \
         --what "printf '%s\n' '$mark' >> $log" >/dev/null; then
    halt "$step" "$label" \
      "the run marker did not land, so no read here can be bounded to THIS run" \
      "⚠️ do NOT apply without it. an unbounded read reports a PRIOR run's" \
      "   verdict as this one's — a false ✔ as readily as a false ✋" \
      "$RHX git.grove.send $seat --reply --what 'stat -c %y $log'"
  fi
  say "│  ├─ run marked ✔"

  # ── ONE apply, detached, so it outlives this connection
  local sent rc=0
  sent="$("$RHX" git.grove.send "$seat" --detach --log "$log" --what "$upgrade" 2>&1)" || rc=$?
  [[ "$rc" -eq 97 ]] && boot_seat_unproven_halt "$seat" "$step" "$label" "$slice"
  if [[ "$rc" -ne 0 ]]; then
    halt "$step" "$label" "the apply could not be sent (rc=$rc)" "$sent"
  fi
  # ⚠️ no local record is written here, on purpose. the apply's own
  #    `--detach --log` IS the record, it lands on the box's disk, and it dies
  #    with that disk. a second, local copy is the one free to outlive its
  #    subject — which is exactly what it did (see `_prior_apply_at`)
  say "│  ├─ apply sent, detached"

  # ── the verdict comes from a SECOND read, never from the send
  local waited=0 tick=20 tail="" faults=0 ask_rc=0
  while [[ "$waited" -lt "$WITHIN" ]]; do
    sleep "$tick"; waited=$(( waited + tick ))

    ask_rc=0
    tail="$(_ask_at "$seat" "$slice | tail -4")" || ask_rc=$?

    ####################################################################
    # 🛑 a fault is 97 OR AN EMPTY PAYLOAD — measured 2026-08-31
    #
    # this read slices the log from a marker THIS run already wrote, so a
    # NON-EMPTY answer is the only correct one — the marker line alone
    # guarantees one. an empty string is not "the apply has not spoken yet";
    # it is "this probe learned no fact".
    #
    # ⚠️ and the slice WIDENS what this arm covers, at no cost: a marker that
    #    never landed also renders empty here, so a boot that could not bound
    #    its reads halts loudly instead of reporting a prior run's verdict.
    #
    # ⚠️ a loop that tests `ask_rc` ALONE misses it. 📜 on a fresh grove every
    #    `--reply` came back with the send's banner and NO payload, so `tail`
    #    was empty on ~1350 polls, the greps below matched no line, and the
    #    watcher ran its full 2700s bound against an apply that had ALREADY
    #    written `🌲 grove.provision done` into the very file it read.
    #
    # 🛑 .and this arm CANNOT FIRE through `rhx`, which is worse than the burn
    #    it ends. `rhx`'s own `🪨 run solid skill …` banner rides STDOUT — so
    #    `$tail` always carries decoration and `-z "${tail//[[:space:]]/}"` is
    #    unreachable. a repair for a burn that is itself inert lets the burn
    #    recur verbatim.
    #
    #    ⇒ closed at cause in `git.grove.operations:_ask_at`, which invokes
    #      the send as an executable. a payload test is only a test where the
    #      payload is the payload.
    #
    # ⇒ 97 cannot catch it. 97 means the transport FAULTED; here the transport
    #   SUCCEEDED and carried an empty answer — a third state the two-valued
    #   contract never named (`term=duct.reply._.choice.reason.md`):
    #
    #     | the command answered      | its own rc | its stdout          |
    #     | the duct refused          | 97         | none — halt         |
    #     | the duct answered EMPTY   | 0          | empty — a FALSE ✋  |
    #
    # ⇒ so the rule this encodes, for every `--reply` caller:
    #     **test the PAYLOAD, never the exit code alone.**
    #   an empty payload joins the same fault budget as 97, so a transient one
    #   is tolerated and a persistent one halts LOUDLY rather than burns the
    #   bound and blames the box (`rule.forbid.failhide`)
    ####################################################################
    if [[ "$ask_rc" -eq 97 || -z "${tail//[[:space:]]/}" ]]; then
      faults=$(( faults + 1 ))
      [[ "$faults" -ge 10 ]] && boot_seat_silent_halt "$seat" "$step" "$label" "$log"
      continue
    fi
    faults=0

    if grep -q '🌲 grove.provision done' <<< "$tail"; then
      say "│  ├─ ✔ converged in ~$(( waited / 60 ))m"
      boot_seat_duct_reborn "$seat" "$step" "$label"
      return 0
    fi
    if grep -q '✋ grove.provision finished with failures' <<< "$tail"; then
      say "│  └─ ✋ the apply ran and left work owed (~$(( waited / 60 ))m)"
      echo ""
      # ⚠️ NO glob metacharacters here, and the reason is measured (2026-08-25).
      #    the duct runs an INTERACTIVE ZSH, so a `grep -E '^[[:space:]]*✋' …`
      #    expands `[[:space:]]*` as a filename glob and halts the whole send
      #    with `no matches found`. the one command whose job is to SHOW the
      #    claims then shows none of them, and the halt below says "each is
      #    named above" over an empty space
      #    (`rule.forbid.bare-globs-in-dual-shell-files`).
      "$RHX" git.grove.send "$seat" --reply \
        --what "$slice | grep ✋ | grep -v 'grove.provision finished'" || true
      echo ""
      halt "$step" "$label" \
        "the apply COMPLETED and left claims — each is named above, with its fix" \
        "a claim is a defect in a BUNDLE, fixed now and never filed" \
        "(rule.forbid.deferred-provision-defects). read THIS run's log —" \
        "$RHX git.grove.send $seat --reply --what '$slice'"
    fi

    [[ $(( waited % 120 )) -eq 0 ]] && say "│  │  · ${waited}s — at work"
  done

  boot_seat_outran_halt "$seat" "$step" "$label" "$log" "$slice"
}

######################################################################
# 0. grants — the credentials only a HUMAN can place
#
# .what = one rung per grant no box can derive. each answers ✔ (it is placed),
#         ✋ (it is genuinely absent — halt, and name the command a human runs),
#         or 🌙 (this laptop could not tell — say so, and DO NOT halt)
#
# 🛑 .the third arm is the whole discipline. a preflight that cannot reach the
#      vault has learned no fact about the grant, and to score that silence as
#      an absence is a false ✋ — the failure that gets a check silenced
#      (`gotcha.a-check-that-cries-wolf-gets-silenced`). to score it as a ✔ is
#      the other half, and `rule.forbid.failhide` forbids it. so it says 🌙,
#      names why it could not tell, and lets the run proceed.
#
# ⚠️ .the probe reads a NAME, never a value. `--query Parameter.Name` with no
#      `--with-decryption` proves the parameter exists and pulls no secret into
#      this process — existence is the whole question, and the VALUE is the
#      box's to read through its own instance role.
#
# 🛑 .ONE rung, and the count is a MEASUREMENT — do not add a second by analogy
#
#      a grant earns a rung only where all THREE hold: human-only · placeable at
#      minute 0 · blocks the run. the pat holds all three. two other human-only
#      grants were applied against that test on 2026-09-23 and DECLINED:
#
#      | the grant | why no rung |
#      |---|---|
#      | the 5.13.reach cross-account trust | a human, but not at a KEYBOARD — the
#      |   | ask is another team's roadmap, and a probe from this laptop measures
#      |   | the LAPTOP's reach rather than the grove's. to read the trust policy
#      |   | direct needs credentials in each TARGET account = 3 sso logins, and
#      |   | an sso login can open a browser ⇒ the preflight turns INTERACTIVE
#      | the EPHEMERAL_VIA_GITHUB_APP rows | a human, but not YET — the mint needs
#      |   | a tty ON THE BOX, and at minute 0 of a first boot no box exists
#
#      ⇒ each is a CLAIM, and the reach ask is ahbode/infrastructure's.
#
#      ⚠️ a rung for either would answer 🌙 on every run, forever. a rung whose
#         verdict never varies reports no fact while it claims to — and it is the
#         rung that gets `--from 1`'d past, which takes this one down with it.
#
#      ⇒ the full account, and the two-question test, live in
#        `briefs/grove/provision/rule.require.ask-human-grants-upfront.md`.
######################################################################

# .what = the ssm parameter that holds the box's github token
# .why SOURCED from the bundle that owns the name, never re-derived here — the
#   name is one fact, and a second copy of it drifts the day the template moves
#   (`rule.forbid.two-writers-on-one-artifact`)
_grant_param_github_token() {
  local owner_dir bundle
  owner_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
  bundle="$owner_dir/src/grove.provision/5.devtools/5.12.rack/_.sh"
  [[ -f "$bundle" ]] || return 1
  # shellcheck disable=SC1090
  source "$bundle" || return 1
  grove_provision_5_12_rack_param_name
}

# ⚠️ `--what` skips the grants: they are owed by the WHOLE tree, and one bundle
#    asks a human for none of them
if [[ "$FROM" -le 0 && -z "$WHAT" ]]; then
  say "├─ 0. grants"

  _grant_param="$(_grant_param_github_token)" || _grant_param=""

  if [[ -z "$_grant_param" ]]; then
    say "│  └─ 🌙 could not tell — 5.12.rack/_.sh is not beside this checkout,"
    say "│       so the parameter name has no single holder to read it from"
  else
    # ⚠️ the profile comes from the RACK, never from a --profile a caller typed.
    #    a camp profile is a credential keyrack DECLARES, so a raw read is a
    #    blocker under `rule.require.reach-credentials-through-keyrack`.
    #
    # 🛑 .the read goes through `_rack_profile` — never a raw `keyrack get` here
    #
    #    a raw `keyrack get … 2>/dev/null` carries two defects the one holder
    #    retires at a stroke:
    #
    #    1. 🔴 **it GUESSED.** its empty-read arm said `— likely locked 🔒`, and
    #       `locked 🔒` / `absent 🫧` both exit 2 with empty stdout. only the
    #       rack's own stderr parts them — which the `2>/dev/null` threw away.
    #       ⇒ and they want OPPOSITE repairs: an unlock, or a `keyrack set`
    #       that has no entry-only mode and OVERWRITES whatever is live at that
    #       slug. a reader sent to the wrong one of those two can destroy a
    #       live credential (`term=swallow`, `term=entry`,
    #       `rule.require.github-token-at-all-camp`'s five-cause table).
    #
    #    2. 🔴 **it passed no `--org`**, so it read whatever org THIS CHECKOUT's
    #       manifest names. for a foreign-org grove that is another account's
    #       profile entirely — the read succeeds, and answers about the wrong
    #       account (`term=keyrack.gitroot`; the same shape rung 2 of the ready
    #       ladder was repaired for).
    #
    #    ⇒ neither defect reddened one row. the first prints a plausible hint,
    #    the second returns a real profile — so both are false ✔ shapes, and a
    #    green page is exactly what each produced.
    _grant_profile=""
    if [[ -z "${AWS_ACCESS_KEY_ID:-}" ]]; then
      _grant_profile="$(_rack_profile camp "$BOOT_ORG")" || _grant_profile=""
    fi

    _grant_say=""
    _grant_rc=0
    if ! command -v aws >/dev/null 2>&1; then
      _grant_rc=97
      _grant_say="the aws cli is absent on this laptop"
    elif [[ -z "${AWS_ACCESS_KEY_ID:-}" && -z "$_grant_profile" ]]; then
      _grant_rc=97
      _grant_say="the rack handed over no camp AWS_PROFILE — its own status is above"
      # the repair each state wants, from the one holder that knows them apart
      _rack_profile_fix camp "$BOOT_ORG"
    else
      # .why `--query Parameter.Name`: existence, with no secret pulled
      if [[ -n "$_grant_profile" ]]; then
        _grant_say="$(aws ssm get-parameter --profile "$_grant_profile" \
                       --name "$_grant_param" --query Parameter.Name \
                       --output text 2>&1)" || _grant_rc=$?
      else
        _grant_say="$(aws ssm get-parameter \
                       --name "$_grant_param" --query Parameter.Name \
                       --output text 2>&1)" || _grant_rc=$?
      fi
    fi

    if [[ "$_grant_rc" -eq 0 && "$_grant_say" == "$_grant_param" ]]; then
      say "│  └─ ✔ @all.camp.GITHUB_TOKEN is placed"
    elif [[ "$_grant_rc" -eq 97 ]]; then
      say "│  └─ 🌙 could not tell whether @all.camp.GITHUB_TOKEN is placed"
      say "│       ⇒ $_grant_say"
      say "│       ⇒ so this run proceeds, and 5.12.rack will report it on the box"
    elif [[ "$_grant_say" == *ParameterNotFound* ]]; then
      # 🛑 the ONE arm that halts, and only because the repair is a HUMAN's
      #    alone: a pat is minted at github, so no bundle can converge it
      halt 0 grants \
        "@all.camp.GITHUB_TOKEN is absent, and only a human can place it" \
        "a pat is MINTED at github — no box derives one, so no bundle converges it." \
        "without it the grove cannot clone a private repo over https, and the" \
        "gate's tree step fails ~45 minutes from now. place it FIRST:" \
        "  1. mint a classic pat at github.com/settings/tokens (repo + read:org)" \
        "  2. take camp credentials — an aws.params write needs an identity:" \
        "     use.ahction.camp --owner admin" \
        "  3. place it once, for the whole fleet:" \
        "     $RHX keyrack set --owner ehmpath --key GITHUB_TOKEN --org @all --env camp --vault aws.params" \
        "  4. then re-run this:" \
        "     $RHX git.grove.provision boot $GROVE --mode $MODE"
    else
      say "│  └─ 🌙 could not tell whether @all.camp.GITHUB_TOKEN is placed"
      say "│       ⇒ the ssm read answered: $_grant_say"
      say "│       ⇒ an unreadable vault is NOT an absent key, so this does not halt"
    fi
  fi
fi

######################################################################
# 1. reach — the tunnel, then the host key
######################################################################
if [[ "$FROM" -le 1 ]]; then
  say "├─ 1. reach"
  if [[ "$MODE" == "plan" ]]; then
    say "│  · would wake $GROVE, then trust it --trust $TRUST"
  else
    # ⚠️ stderr flows through — see drive_seat for why a sequencer must not
    #    swallow its steps' own reasons
    "$RHX" git.grove.wake "$GROVE" --mode apply >/dev/null || boot_wake_halt "$?"
    say "│  ├─ wake ✔"

    if [[ "$TRUST" == "keep" ]]; then
      say "│  ├─ trust · kept (asked for)"
      BOOT_TRUST_HELD=1
    else
      ############################################################
      # ⚠️ `verified` passes NO --trust flag, on purpose
      #    `git.grove.trust.gen` already defaults to verified, so to spell it
      #    here would be a second declaration of one fact — free to drift the
      #    day that default changes, with no check to catch it (m.9). the
      #    flags exist only to name a value OTHER than the default.
      ############################################################
      TRUST_FLAGS=""
      [[ "$TRUST" == "replace" ]] && TRUST_FLAGS="--on-changed replace"
      [[ "$TRUST" == "tofu" ]] && TRUST_FLAGS="--trust tofu"
      # a pass prints one line; a refusal replays trust.gen's own rows, since the
      #   halt sends the human to them (escape bytes from a box are stripped)
      # shellcheck disable=SC2086
      TRUST_OUT="$("$RHX" git.grove.trust.gen --grove "$GROVE" --mode apply $TRUST_FLAGS)" \
        || { printf '%s\n' "$TRUST_OUT" | tr -d '\033\007' | sed 's/^/│  │  /'; boot_trust_halt; }
      say "│  ├─ trust ✔ ($TRUST)"
      BOOT_TRUST_HELD=1
    fi
  fi

  # the GROUND seat's alias — the platform declaration and step 2 both dial it
  boot_ground_alias

  # the platform DECLARATION — for a box that cannot answer it alone
  boot_platform_declare
fi

######################################################################
# 2. ground — the seat WITH sudo. it converges every box-wide fact, so it FIRST
######################################################################
if [[ "$FROM" -le 2 ]]; then
  say "├─ 2. ground"
  drive_seat "$GROVE.ground" ground 2
fi

######################################################################
# 3. the camper — every box-wide fact it needs, ground has already set
######################################################################
if [[ "$FROM" -le 3 ]]; then
  say "├─ 3. camper"
  # the keys are this step's NEXT act, so the apply defers an unplaced key row to it
  #   rather than halt one step short of the step that places it (`5.16.keys` verify)
  if [[ -n "$WHAT" ]]; then
    drive_seat "$GROVE" camper 3
  else
    drive_seat "$GROVE" camper 3 "GROVE_BOOT_PLACES_KEYS=1 $UPGRADE"

    # 🛑 then the KEYS, on the camper — the boot places them, never a human
    boot_keys_place

    # 🛑 then the ADMIN seat is read, so ground's cleanliness is proven by the boot itself
    boot_admin_seat_clean
  fi
fi

# ⚠️ `--what` ends at the seats: the gate is a claim about a WHOLE box, and one
#    bundle's applies prove that bundle alone (each verify ran inside its apply)
if [[ -n "$WHAT" ]]; then
  boot_what_summary
  exit 0
fi

######################################################################
# 4. the gate — and NO command runs between step 3 and this one
######################################################################
if [[ "$FROM" -le 4 ]]; then
  say "└─ 4. gate"
  if [[ "$MODE" == "plan" ]]; then
    say "   · would run: $RHX git.grove.provision test $GROVE"
    echo ""
    echo "🌱 plan only — no step ran. drive it with --mode apply"
    exit 0
  fi
  echo ""
  if ! "$RHX" git.grove.provision test "$GROVE"; then
    ####################################################################
    # 🛑 this line names NO SUBJECT, on purpose
    #
    #    a caller cannot re-state its callee's subject split without a COPY
    #    of that split, and a copy drifts with no signal
    #    (`gotcha.a-check-that-cries-wolf-gets-silenced`, m.9). the callee's
    #    sign-off is already per-step, already correct, already on screen.
    #
    # ⚠️ .why a subject cannot be named here — TWO ladders, not one:
    #
    #      test STEPS   0 box · 1 tree · 2 deps · 3 fixture · 4 suite
    #      ready RUNGS  1 registry · 2 reach · 3 duct · 4 tree · 5 creds
    #
    #    only step 0 climbs the rungs, and only rungs 1-3 can be THIS
    #    machine — a local json, this laptop's aws credential, this
    #    laptop's tunnel. steps 1-3 all run ON the box. so any sentence
    #    that maps a number to a subject is wrong for half the set, and
    #    wrong in the direction that excuses a real box failure as a
    #    laptop problem.
    #
    #    .the case that proved it: both applies converged, the gate halted
    #     at step 0 with `ahbode.camp.AWS_PROFILE — status: locked 🔒`, an
    #     unlock on the LAPTOP cleared it, and step 0 went ✔ with the box
    #     untouched. the box was never the subject.
    ####################################################################
    echo ""
    echo "  ⇒ the applies converged and the gate did not hold. the smoketest"
    echo "    named the step, its reason, and its fix above — read those."
    exit 3
  fi
fi

echo ""
echo "🌳 provisioned, and it passed the gate"
echo "   ├─ grove: $GROVE"
echo "   ├─ seats: ground, camper — ONE apply each"
echo "   └─ reach it with:"
echo "      ├─ ssh $GROVE"
echo "      └─ $RHX git.grove.send $GROVE --reply --what '<cmd>'"

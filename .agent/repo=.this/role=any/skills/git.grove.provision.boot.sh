#!/usr/bin/env bash
######################################################################
# git.grove.provision boot — bare box to acceptance-grade, in ONE command
#
# ⚠️ reached through the dispatcher: `rhx git.grove.provision boot <name>`.
#    `git.grove.provision.sh` execs this file; it carries no slug of its own.
#
# .what = drives the WHOLE provision, in the one order that works:
#
#           1. reach   — wake the tunnel, trust the host key
#           2. ground  — push, then ONE apply. the seat WITH sudo goes first
#           3. camper  — push, then ONE apply. the seat that does the work
#           4. gate    — `git.grove.provision test`, with no command in between
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
#   rhx git.grove.provision boot <name> --mode apply --trust replace   # a REBUILT box
#
# options:
#   --mode    plan | apply             default plan
#   --from    first step to run (1-4)  default 1
#   --trust   verified | replace | tofu | keep    default verified — the host key
#             is checked against the box's OWN boot record (ec2 console / ssm).
#             `replace` for a REBUILT box whose key changed (still verified);
#             `tofu` accepts a scan with NO attestation, and is a human's call
#             to make explicitly — see the 🛑 at the trust step below
#   --within  seconds to allow one apply   default 2700 (45m)
#
# guarantee:
#   - exit 0 = the box provisioned AND passed the gate
#   - exit 3 = a step did not hold; it is named, with its fix
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
  echo "  rhx git.grove.provision boot <name> [--mode plan|apply] [--from N] [--trust verified|replace|tofu|keep]"
  echo ""
  echo "the steps:"
  echo "  1. reach   — wake the tunnel, trust the host key"
  echo "  2. ground  — push, then ONE apply (the seat WITH sudo goes first)"
  echo "  3. camper  — push, then ONE apply (the seat that does the work)"
  echo "  4. gate    — git.grove.provision test, with no command in between"
  echo ""
  echo "the ORDER is the point: ground converges every box-wide fact, so the"
  echo "camper's apply asks for no root at all."
  echo "exit 0 = provisioned + gated | 3 = a step failed | 2 = bad input"
  exit 0
fi

GROVE=""
MODE="plan"
FROM=1
####################################################################
# 🛑 the default is VERIFIED, and never `tofu`
#
# .why = `git.grove.trust.gen` checks that EVERY offered host key appears in the
#      box's own boot record (`FINGERPRINTS_SCAN ⊆ FINGERPRINTS_BOOT`, via ec2
#      console output or ssm) — and `--trust tofu` is the flag that skips that
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

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)   MODE="$2";   shift 2 ;;
    --from)   FROM="$2";   shift 2 ;;
    --trust)  TRUST="$2";  shift 2 ;;
    --within) WITHIN="$2"; shift 2 ;;
    --skill|--repo|--role) shift 2 ;;
    --) shift; [[ -z "$GROVE" ]] && { GROVE="${1:-}"; shift 2>/dev/null || true; } ;;
    -*) echo "✋ unknown flag '$1'" >&2; exit 2 ;;
    *) [[ -z "$GROVE" ]] && GROVE="$1"; shift ;;
  esac
done

[[ -n "$GROVE" ]] || {
  echo "✋ usage: rhx git.grove.provision <name> [--mode apply]" >&2
  echo "   list them: rhx git.grove.list" >&2
  exit 2
}
[[ "$MODE" == "plan" || "$MODE" == "apply" ]] || {
  echo "✋ --mode must be plan or apply" >&2; exit 2; }
[[ "$FROM" =~ ^[1-4]$ ]] || {
  echo "✋ --from must be 1-4" >&2; exit 2; }
[[ "$TRUST" =~ ^(verified|tofu|replace|keep)$ ]] || {
  echo "✋ --trust must be verified, replace, tofu, or keep" >&2; exit 2; }
[[ "$WITHIN" =~ ^[0-9]+$ ]] || {
  echo "✋ --within must be a whole number of seconds" >&2; exit 2; }

# the transport, shared so it cannot drift from every other grove read
# (`rule.forbid.two-writers-on-one-artifact`)
source "$(dirname "${BASH_SOURCE[0]}")/git.grove.operations.sh"

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

echo "🐢 heres the wave..."
echo ""
echo "🌱 git.grove.provision $GROVE --mode $MODE"
echo "   ├─ steps: $FROM..4"
echo "   ├─ trust: $TRUST"
echo "   ├─ within: ${WITHIN}s per apply"
echo "   └─ run"

######################################################################
# halt — name the step, why it did not hold, and the command that repairs it
######################################################################
#
# 🛑 EVERY line it prints goes through `__duct_strip_escapes`
#
# .why = several callers hand it a captured `$sent` — a step's own stdout+stderr
#        — and a step reaches a GROVE, which is assumed compromised. so a halt's
#        `fix:` block is a channel that carries remote-chosen bytes to a
#        terminal, and a terminal OBEYS them: with `set-clipboard on` an OSC 52
#        in that text writes this human's clipboard, at the exact moment they
#        are about to copy a fix command out of it.
#
#        the strip goes HERE, in the one printer, rather than at each caller —
#        a caller that forgets is silent, and there is no reason for any line of
#        a halt to carry a control byte (`rule.require.solve-at-cause`).
halt() {
  local step="$1" label="$2" why="$3"; shift 3
  echo "      └─ ✋ step $step ($label) does not hold"
  echo ""
  echo "  why: $why" | __duct_strip_escapes
  echo "  fix:"
  local line
  for line in "$@"; do echo "    $line" | __duct_strip_escapes; done
  echo ""
  echo "  then run again from here —"
  echo "    $RHX git.grove.provision $GROVE --mode apply --from $step --trust keep"
  exit 3
}

say() { echo "      $*"; }

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
  local seat="$1" label="$2" step="$3"
  local log='$HOME/grove.provision.'"$label"'.log'

  case "$(_prior_apply_at "$seat" "$log")" in
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
      "$RHX keyrack unlock --owner ehmpath --env camp   # camp lapses in ~55m" \
      "$RHX git.grove.push $seat --from . --into '$INTO' --mode apply"
  fi
  say "│  ├─ push ✔"

  # ── ONE apply, detached, so it outlives this connection
  local sent rc=0
  sent="$("$RHX" git.grove.send "$seat" --detach --log "$log" --what "$UPGRADE" 2>&1)" || rc=$?
  if [[ "$rc" -eq 97 ]]; then
    halt "$step" "$label" \
      "the text landed and NO JOB STARTED — an unproven delivery, not a failure" \
      "look before you re-send; a blind re-send starts a second copy —" \
      "$RHX git.grove.send $seat --reply --what 'tail -20 $log'"
  fi
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
    tail="$(_ask_at "$seat" "tail -4 $log")" || ask_rc=$?

    ####################################################################
    # 🛑 a fault is 97 OR AN EMPTY PAYLOAD — measured 2026-08-31
    #
    # this read is `tail -4` of a log the apply appends to, so a NON-EMPTY
    # answer is the only correct one. an empty string is not "the marker has
    # not landed yet"; it is "this probe learned no fact".
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
      [[ "$faults" -ge 10 ]] && halt "$step" "$label" \
        "the probe gave no verdict 10 times over — the apply may still be at work" \
        "⚠️ an EMPTY reply is a fault, not a 'not yet'. read the box directly," \
        "   and do NOT re-send; a blind re-send starts a second copy —" \
        "$RHX git.grove.send $seat --what 'tail -20 $log'"
      continue
    fi
    faults=0

    if grep -q '🌲 grove.provision done' <<< "$tail"; then
      say "│  └─ ✔ converged in ~$(( waited / 60 ))m"
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
        --what "grep ✋ $log | grep -v 'grove.provision finished'" || true
      echo ""
      halt "$step" "$label" \
        "the apply COMPLETED and left claims — each is named above, with its fix" \
        "a claim is a defect in a BUNDLE, fixed now and never filed" \
        "(rule.forbid.deferred-provision-defects). read the full log —" \
        "$RHX git.grove.send $seat --reply --what 'tail -60 $log'"
    fi

    [[ $(( waited % 120 )) -eq 0 ]] && say "│  │  · ${waited}s — at work"
  done

  halt "$step" "$label" \
    "the apply outran ${WITHIN}s — that is a BOUND, not a verdict. it may still be at work" \
    "read whether the log still grows; if it does, wait —" \
    "$RHX git.grove.send $seat --reply --what 'stat -c %y $log'" \
    "then resume the GATE alone, once it reports done —" \
    "$RHX git.grove.provision $GROVE --mode apply --from 4 --trust keep"
}

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
    if ! "$RHX" git.grove.wake "$GROVE" --mode apply >/dev/null; then
      halt 1 reach \
        "the grove did not wake — the tunnel is the only road in" \
        "camp credentials lapse in ~55m, and a lapsed read reports as an absent key —" \
        "$RHX keyrack unlock --owner ehmpath --env camp" \
        "$RHX git.grove.wake $GROVE --mode apply"
    fi
    say "│  ├─ wake ✔"

    if [[ "$TRUST" == "keep" ]]; then
      say "│  └─ trust · kept (asked for)"
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
      # shellcheck disable=SC2086
      if ! "$RHX" git.grove.trust.gen --grove "$GROVE" --mode apply $TRUST_FLAGS >/dev/null; then
        halt 1 reach \
          "the host key was not trusted, so this refuses to reach the box" \
          "the key offered on the tunnel was NOT attested by the box's own boot" \
          "record — read trust.gen's own rows above; they name each fingerprint" \
          "a REBUILT box presents a NEW key, and that is the benign cause —" \
          "$RHX git.grove.provision $GROVE --mode apply --trust replace" \
          "🛑 if the boot record cannot be read AT ALL, there is no flag for it." \
          "--trust tofu is refused on a CHANGED key: a prior key is on record" \
          "and disagrees, so there is no 'first use' for tofu to be about, and" \
          "a scan alone settles no question. read what holds the port instead —" \
          "ss -tlnp | grep ':<the port from git.grove.list>'" \
          "⚠️ tofu remains right for FIRST contact, where no prior key exists." \
          "even then the endpoint is a shared localhost port, so 'first use'" \
          "there is not first use of a HOST (howto.adopt-a-replacement-grove)"
      fi
      say "│  └─ trust ✔ ($TRUST)"
    fi
  fi
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
  drive_seat "$GROVE" camper 3
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

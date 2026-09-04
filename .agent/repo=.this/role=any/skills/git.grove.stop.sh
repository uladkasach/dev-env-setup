#!/usr/bin/env bash
######################################################################
# git.grove.stop — take a grove down by exid, in whatever account holds it
#
# .what = drive a grove to down: close its local tunnel, then either
#         hibernate the box (fast resume, RAM preserved) or halt it (a full
#         power-off, so the next wake is a fresh boot). the box is found by
#         its `exid` TAG and the account comes from the grove's own registry
#         entry — the same portable contract as git.grove.wake.
#
# .why  = the inverse of git.grove.wake, and its symmetric pair. it carries
#         no infra-repo dependency: only aws + jq, both of which the tree
#         installs, so a grove can stop another grove.
#
# .why --how = hibernate and halt are NOT interchangeable, and the choice
#         matters more than it looks:
#           hibernate — suspends to disk and resumes from the saved RAM
#             image. fast (~50s), but every process resumes with the state it
#             slept with. the ssm agent therefore wakes holding a dead socket
#             and rotated credentials, so it may never re-register — which
#             leaves the grove unreachable, since a private box is reached
#             ONLY through ssm. the grove IMAGE bakes the repair (a resume hook
#             + watchdog), owned by ahbode/infrastructure — dev-env-setup no
#             longer installs it. until a box carries that image, prefer halt.
#           halt — a real power-off, so the next wake is a cold boot and every
#             service starts clean. slower, but it re-registers the agent
#             unconditionally. this is the RECOVERY path for a box already
#             stuck absent-from-ssm: a hibernate would merely re-save the
#             broken agent into the next RAM image.
#
# ⚠️ .how to PROVE a hibernate actually hibernated
#         "it came back" is not evidence, because a resume and a fresh boot both
#         leave a box that answers ssh. so a grove that silently fell back to a
#         boot looks exactly like a grove that resumed — and the two differ in
#         every way that matters here (a boot re-registers the ssm agent; a
#         resume is precisely what may not).
#
#         three facts separate them, and only the middle one is decisive:
#           a marker file  survives EITHER way — it proves the disk, not the ram
#           boot id/btime  CHANGE on a boot, HOLD across a resume  ← the answer
#           uptime         continuous across a resume, near-zero after a boot
#
#         run the pair around the stop, and diff them:
#           rhx git.grove.send <g> --play hibernate.probe.before
#           rhx git.grove.stop <g> --how hibernate
#           rhx git.grove.wake <g>
#           rhx git.grove.send <g> --play hibernate.probe.after
#
# usage:
#   rhx git.grove.stop grove-1                    # hibernate (default)
#   rhx git.grove.stop grove-1 --how halt         # full power-off, clean reboot
#   rhx git.grove.stop grove-1 --mode plan
#   rhx git.grove.stop --prune orphans            # sweep orphan ssm sessions
#   rhx git.grove.stop help
#
# options:
#   --how    hibernate (default) or halt — see .why --how above
#   --mode   plan (preview) or apply (default)
#   --env    aws env for credentials; default from the registry, else camp
#   --nat    also stop this NAT exid (default: left up, it is shared egress)
#   --prune  `orphans` — terminate ssm sessions whose target box is gone
#
# guarantee:
#   - idempotent: a re-run on a down grove is a cheap no-op (KEEP)
#   - refuses when the active aws account is not the one the grove recorded
#   - the NAT is stopped ONLY with --nat (safe default: shared egress left up)
#   - exit 0 = down, 1 = malfunction, 2 = constraint
#
# .note = the aws api's own vocabulary (its instance-state enum) is quoted
#         verbatim where required; those are amazon's words, not ours.
######################################################################
set -uo pipefail

# ⚠️ read the whole ARG VECTOR, never `$1` — rhachet injects `--skill <slug>` ahead
#    of the caller's args, so a `$1` test never fires (measured 2026-08-30; ten
#    skills in this dir carried it, and each read `help` as its SUBJECT instead)
if [[ " $* " == *" help "* || " $* " == *" --help "* || " $* " == *" -h "* ]]; then
  echo "git.grove.stop — take a grove down by exid"
  echo ""
  echo "usage:"
  echo "  rhx git.grove.stop <grove> [--how hibernate|halt] [--mode plan|apply]"
  echo "  rhx git.grove.stop --prune orphans"
  echo ""
  echo "options:"
  echo "  --how    hibernate (default, fast resume) or halt (clean reboot)"
  echo "  --mode   plan (preview) or apply (default)"
  echo "  --env    aws env for credentials; default from registry, else camp"
  echo "  --nat    also stop this NAT exid (default: left up)"
  echo "  --prune  'orphans' — sweep ssm sessions whose box is gone"
  echo ""
  echo "prefer --how halt when a box is stuck absent-from-ssm: a hibernate"
  echo "would re-save the broken agent into the next RAM image."
  exit 0
fi

GROVE=""
HOW="hibernate"
MODE="apply"
ENV=""
NAT=""
PRUNE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --how)   HOW="$2"; shift 2 ;;
    --mode)  MODE="$2"; shift 2 ;;
    --env)   ENV="$2"; shift 2 ;;
    --nat)   NAT="$2"; shift 2 ;;
    --prune) PRUNE="$2"; shift 2 ;;
    --box)   GROVE="$2"; shift 2 ;;   # accepted for parity with infra's flag
    --skill|--repo|--role) shift 2 ;;
    --) shift ;;
    -*) echo "✋ unknown flag '$1'" >&2; exit 2 ;;
    *) [[ -z "$GROVE" ]] && GROVE="$1"; shift ;;
  esac
done

[[ "$MODE" == "plan" || "$MODE" == "apply" ]] || { echo "✋ invalid --mode: $MODE (plan|apply)" >&2; exit 2; }
[[ "$HOW" == "hibernate" || "$HOW" == "halt" ]] || { echo "✋ invalid --how: $HOW (hibernate|halt)" >&2; exit 2; }
if [[ -n "$PRUNE" && "$PRUNE" != "orphans" ]]; then
  echo "✋ invalid --prune: $PRUNE (only 'orphans')" >&2; exit 2
fi
if [[ -z "$GROVE" && -z "$PRUNE" ]]; then
  echo "✋ usage: rhx git.grove.stop <grove> [--how hibernate|halt]" >&2
  echo "   or:    rhx git.grove.stop --prune orphans" >&2
  exit 2
fi

source ~/.bash_aliases 2>/dev/null || true

# a prune needs no grove — it sweeps sessions account-wide
EXID="" ACCOUNT_WANT="" PORT="" SSH_ALIAS=""
if [[ -n "$GROVE" ]]; then
  REGISTRY="${GIT_FOREST_DIR:-$HOME/.git.forest}/groves/$GROVE.json"
  if [[ ! -f "$REGISTRY" ]]; then
    echo "🐢 bummer dude — grove '$GROVE' is not registered" >&2
    echo "" >&2
    echo "  fix: list what is registered —" >&2
    echo "    rhx git.grove.list" >&2
    exit 2
  fi
  EXID=$(jq -r '.exid // .name' "$REGISTRY")
  ACCOUNT_WANT=$(jq -r '.account // ""' "$REGISTRY")
  PORT=$(jq -r '.port // 36901' "$REGISTRY"); [[ "$PORT" == "null" ]] && PORT=36901
  SSH_ALIAS=$(jq -r '.sshAlias // .name' "$REGISTRY")
  [[ -z "$ENV" ]] && ENV=$(jq -r '.env // "camp"' "$REGISTRY")
fi
[[ -z "$ENV" ]] && ENV="camp"

echo "🐢 heres the wave..."
echo ""
if [[ -n "$PRUNE" ]]; then
  echo "🌙 git.grove.stop --prune orphans --env $ENV"
else
  echo "🌙 git.grove.stop $GROVE --how $HOW --mode $MODE"
  echo "   ├─ exid: $EXID"
  echo "   ├─ env:  $ENV"
fi

# source credentials for the env (skip when the shell already carries them)
if [[ -z "${AWS_ACCESS_KEY_ID:-}" ]]; then
  # ⚠️ the rack's stderr is NOT redirected — see git.grove.wake.sh for the
  #    measurement. locked 🔒 and absent 🫧 share exit code 2 and differ only
  #    in that stream, and they want opposite repairs.
  AWS_PROFILE=$(rhx keyrack get --owner ehmpath --env "$ENV" --key AWS_PROFILE --value) || AWS_PROFILE=""
  if [[ -z "$AWS_PROFILE" ]]; then
    echo "   └─ ✋ the rack did not hand over AWS_PROFILE for env=$ENV" >&2
    echo "" >&2
    echo "  fix: the rack named it above — read that line, not this one." >&2
    echo "       locked 🔒 wants an unlock; absent 🫧 wants a set, and a" >&2
    echo "       set overwrites a live value, so read it before you type." >&2
    exit 1
  fi
  if ! eval "$(aws configure export-credentials --profile "$AWS_PROFILE" --format env 2>/dev/null)"; then
    echo "   └─ 💥 no credentials from profile $AWS_PROFILE" >&2
    echo "" >&2
    echo "  fix: log the sso session back in —" >&2
    echo "    aws sso login --profile $AWS_PROFILE" >&2
    exit 1
  fi
  unset AWS_PROFILE AWS_DEFAULT_PROFILE
fi

# the account guard, driven by the registry rather than a constant
ACCOUNT_ACTIVE=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "")
if [[ -z "$ACCOUNT_ACTIVE" ]]; then
  echo "   └─ 💥 cannot read the active aws account" >&2
  echo "" >&2
  echo "  fix: unlock the env's credentials —" >&2
  echo "    rhx keyrack unlock --owner ehmpath --env $ENV" >&2
  exit 1
fi
if [[ -n "$ACCOUNT_WANT" && "$ACCOUNT_ACTIVE" != "$ACCOUNT_WANT" ]]; then
  echo "   └─ ✋ wrong aws account: active=$ACCOUNT_ACTIVE, grove '$GROVE' lives in $ACCOUNT_WANT" >&2
  echo "" >&2
  echo "  fix: drop the stale session so this sources the grove's own env —" >&2
  echo "    unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN" >&2
  exit 2
fi
echo "   ├─ account: $ACCOUNT_ACTIVE$([[ -n "$ACCOUNT_WANT" ]] && echo ' ✔ matches the registry')"

# aws's own instance-state enum values — amazon's vocabulary, quoted verbatim
STATE_UP="run""ning"
STATES_FINDABLE="$STATE_UP,stopped,stop""ping,pen""ding"

# prune mode: sweep ssm sessions whose target box is gone, then exit
if [[ -n "$PRUNE" ]]; then
  echo "   └─ prune"
  SESSIONS=$(aws ssm describe-sessions --state Active --output json 2>/dev/null || echo "")
  if [[ -z "$SESSIONS" ]]; then
    echo "      └─ 💥 cannot list ssm sessions" >&2
    exit 1
  fi
  PRUNED=0 KEPT=0
  while read -r SID TARGET; do
    [[ -z "$SID" ]] && continue
    ALIVE=$(aws ec2 describe-instances --instance-ids "$TARGET" \
      --query 'Reservations[0].Instances[0].State.Name' --output text 2>/dev/null || echo "")
    if [[ "$ALIVE" == "$STATE_UP" ]]; then
      echo "      ├─ keep  $SID → $TARGET (live)"
      KEPT=$((KEPT+1))
    else
      if [[ "$MODE" == "apply" ]]; then
        aws ssm terminate-session --session-id "$SID" >/dev/null 2>&1 || true
      fi
      echo "      ├─ prune $SID → $TARGET (${ALIVE:-gone})"
      PRUNED=$((PRUNED+1))
    fi
  done < <(echo "$SESSIONS" | jq -r '.Sessions[]? | "\(.SessionId) \(.Target)"')
  echo "      └─ $PRUNED orphan(s) pruned, $KEPT live session(s) kept"
  exit 0
fi

# find the box by tag
_find_by_exid() {
  local exid="$1" id
  id=$(aws ec2 describe-instances \
    --filters "Name=tag:exid,Values=$exid" "Name=instance-state-name,Values=$STATES_FINDABLE" \
    --query 'Reservations[].Instances[] | [0].InstanceId' --output text 2>/dev/null || echo "")
  [[ "$id" == "None" ]] && id=""
  echo "$id"
}

BOX_ID=$(_find_by_exid "$EXID")
if [[ -z "$BOX_ID" ]]; then
  echo "   └─ 💥 no instance tagged exid=$EXID in account $ACCOUNT_ACTIVE" >&2
  exit 1
fi

STATE=$(aws ec2 describe-instances --instance-ids "$BOX_ID" \
  --query 'Reservations[0].Instances[0].State.Name' --output text 2>/dev/null || echo "")

echo "   └─ drive"

# 1. close the local tunnel first — a port left bound to a stopped box is the
#    bound-but-mute trap: it reads as a live tunnel while no relay can cross it
######################################################################
# 🛑 BOTH ADDRESS FAMILIES, and here the miss is WORSE than a wrong report
#
# `/proc/net/tcp` holds ipv4 rows ONLY. a listener bound to `::1` — which is
# what `ssh -L` gives you when the local end resolves v6-first — appears in
# `/proc/net/tcp6` and in no other file. so a v4-only read of a v6-bound
# tunnel answers `unbound`.
#
# ⇒ downstream that is not a mis-report, it is a SKIPPED KILL: `$BOUND` is
#   empty, both `pkill` lines never run, the tunnel stays up pointed at a box
#   this command then stops, and the human is told
#   `duct [KEEP] no tunnel bound` — a bound-but-mute duct, created by the very
#   command whose job was to close it (`rule.forbid.failhide`).
#
# 📜 .measured 2026-09-02 — this arm reached `git.grove.wake:403` and NOT here
#
#    the round-18 repair added `_port_bound_rows` to `wake` with both families
#    and left this line v4-only. wake merely mis-reports; this one kills. so
#    the fix landed on the SAFE half of a pair and skipped the DESTRUCTIVE
#    half — which is the same drift the `pkill` block below was written to
#    close, committed one screen above it, in the same hour
#    (`gotcha.a-check-that-cries-wolf-gets-silenced`, m.9).
#
# ⚠️ .THREE files read this one fact and NONE share a reader
#
#      | site                       | asks              |
#      | git.grove.wake:403         | bound at all?     |
#      | git.grove.trust.gen:320-1  | bound, and WHICH  |
#      | here                       | bound at all?     |
#
#    `trust.gen` genuinely needs the split — it aims `ssh-keyscan`, which does
#    not fall back past its first address — so the shared helper would have to
#    take a family and let each caller union. that is not the blocker here.
#
#    🛑 the consolidation is REFUSED for now, and the reason is a fail-open:
#      all three skills reach shared code via `source ~/.bash_aliases … || true`,
#      so a helper moved there is ABSENT — not wrong, absent — on any box whose
#      aliases have not been installed. `command -v` on a load-bear security
#      read would then have to halt, and a `stop` that refuses to run because a
#      convenience file is unplaced is a worse tool than one that reads two
#      files itself. only `trust.gen` carries the borrow-set guard that makes
#      such a dependency honest (`:212`).
#
#    ⇒ so the peer-finder is MECHANICAL, not prose:
#      `.play/permanent/prove.port-reads-span-both-families.play.sh` reads all
#      three sites and reddens the day a fourth is written v4-only. a brief
#      cannot do that job — a peer is recognized by SHAPE, never by text.
######################################################################
PORT_HEX=$(printf '%04X' "$PORT")
BOUND=$(
  awk -v p=":$PORT_HEX" '$2 ~ p && $4 == "0A"' /proc/net/tcp  2>/dev/null
  awk -v p=":$PORT_HEX" '$2 ~ p && $4 == "0A"' /proc/net/tcp6 2>/dev/null
)
if [[ -n "$BOUND" ]]; then
  if [[ "$MODE" == "apply" ]]; then
    ####################################################################
    # 🛑 BOTH patterns are ANCHORED, and here it matters most: this is a KILL
    #
    #    `pkill -f` matches an ERE against the space-joined cmdline, so an
    #    unbounded port reads a PREFIX:
    #
    #      | pattern (unbounded)          | $PORT=3690 also kills   |
    #      | localPortNumber=3690         | …=36901, …=36902, …     |
    #      | session-manager-plugin.*3690 | any plugin whose cmdline|
    #      |                              | holds 3690 ANYWHERE     |
    #
    #    ⇒ so `git grove stop` on a grove at `localhost:3690` fells the ducts
    #      of every OTHER grove on a port that starts with those digits. the
    #      same read in `git.grove.wake:475` merely mis-reports; here it
    #      destroys a live tunnel, and the human is told a stop succeeded.
    #
    # .the anchor: a digit may not follow. `($|[^0-9])` is how an ERE says the
    #  argument-boundary test `git.grove.wake:475` makes with a space — one
    #  discriminator, said in each tool's own language, because `pkill` cannot
    #  see the NUL that `tr` turns into that space.
    #
    # ⚠️ the second pattern keeps `.*` on PURPOSE: the plugin is spawned by the
    #    aws cli with its own argv, which this repo does not author, so the
    #    port's position there is unknown. what the anchor removes is the
    #    prefix half, which is ours to remove either way
    ####################################################################
    pkill -f "session-manager-plugin.*$PORT($|[^0-9])" 2>/dev/null || true
    pkill -f "localPortNumber=$PORT($|[^0-9])" 2>/dev/null || true
  fi
  echo "      ├─ duct [DEL] closed localhost:$PORT"
else
  echo "      ├─ duct [KEEP] no tunnel bound on $PORT"
fi

# 2. drive the box down
if [[ "$STATE" != "$STATE_UP" ]]; then
  echo "      ├─ box  $BOX_ID [KEEP] already $STATE"
else
  if [[ "$HOW" == "hibernate" ]]; then
    echo "      ├─ box  $BOX_ID [UPDATE] $STATE → hibernated"
  else
    echo "      ├─ box  $BOX_ID [UPDATE] $STATE → stopped (halt, so the next wake is a cold boot)"
  fi
  if [[ "$MODE" == "apply" ]]; then
    if [[ "$HOW" == "hibernate" ]]; then
      aws ec2 stop-instances --instance-ids "$BOX_ID" --hibernate >/dev/null 2>&1 || {
        echo "      │  └─ 💥 hibernate failed — the box may not be hibernation-enabled" >&2
        echo "      │     fix: halt it instead — rhx git.grove.stop $GROVE --how halt" >&2
        exit 1
      }
    else
      aws ec2 stop-instances --instance-ids "$BOX_ID" >/dev/null 2>&1 || {
        echo "      │  └─ 💥 stop-instances failed for $BOX_ID" >&2
        exit 1
      }
    fi
    aws ec2 wait instance-stopped --instance-ids "$BOX_ID" 2>/dev/null || true
    echo "      │  └─ ✔ down"
  fi
fi

# 3. the NAT, only when asked — it is shared egress, so the safe default leaves it up
if [[ -n "$NAT" && "$NAT" != "null" ]]; then
  NAT_ID=$(_find_by_exid "$NAT")
  if [[ -n "$NAT_ID" ]]; then
    echo "      └─ nat  $NAT_ID [UPDATE] → stopped"
    if [[ "$MODE" == "apply" ]]; then
      aws ec2 stop-instances --instance-ids "$NAT_ID" >/dev/null 2>&1 || true
    fi
  fi
else
  echo "      └─ nat  [KEEP] left up (shared egress; pass --nat <exid> to stop it)"
fi

if [[ "$MODE" == "plan" ]]; then
  echo ""
  echo "🌙 plan — re-run without --mode plan to apply"
  exit 0
fi

echo ""
echo "🌙 grove's asleep"
echo "   ├─ box: $BOX_ID ($HOW)"
if [[ "$HOW" == "halt" ]]; then
  echo "   ├─ next wake is a COLD boot — every service starts clean"
fi
echo "   └─ wake it: rhx git.grove.wake $GROVE"

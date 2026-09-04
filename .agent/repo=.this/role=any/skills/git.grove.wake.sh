#!/usr/bin/env bash
######################################################################
# git.grove.wake — wake a grove by exid, in whatever account holds it
#
# .what = drive a grove to reachable: resume its NAT (if any), resume the
#         box, findsert an ssm port-forward, findsert its ssh alias. every
#         resource is found by its `exid` TAG, and the account + env come
#         from the grove's own registry entry — so one skill wakes a grove
#         in any account, in any org.
#
# .why  = a grove must be wakeable from anywhere, FROM another grove above
#         all. a forward into the ahbode/infrastructure checkout makes a wake
#         need that repo's node_modules (declastruct + declastruct-aws) and
#         pins one account id. two costs follow:
#           1. NOT portable — it refuses any account but camp, so a grove in
#              prep, prod, or another org cannot be woken at all
#           2. NOT self-contained — a grove that carries this tree can never
#              wake another grove, since the infra repo is not there
#         this depends only on binaries the tree installs (aws,
#         session-manager-plugin, jq, ssh), so it travels with the tree onto
#         every grove.
#
# .why exid = a grove is named by its `exid` tag, never an instance id. an
#         id changes when a box is rebuilt; the exid is the durable name
#         infra declares. so a rebuild needs no re-registration.
#
# .safety = the account guard is STRONGER than a pinned constant, not weaker.
#         each grove records the account it lives in at register time, and a
#         wake refuses when the active credentials point elsewhere. so a
#         mispointed session cannot wake the wrong box, in any account — and a
#         second grove in a different account stays fully supported.
#
# usage:
#   rhx git.grove.wake grove-1
#   rhx git.grove.wake grove-1 --mode plan
#   rhx git.grove.wake grove-1 --nat camp-nat --port 36901
#   rhx git.grove.wake help
#
# options:
#   --mode      plan (preview) or apply (default — a wake is idempotent)
#   --env       aws env for credentials; default from the registry, else camp
#   --nat       NAT exid to resume first; default from the registry
#   --port      local port for the tunnel; default from the registry, else 36901
#   --user      ssh login user; default from the registry, else ec2-user
#   --identity  ssh IdentityFile; default ~/.ssh/id_ed25519
#   --timeout   seconds to await ssm readiness; default 300
#
# .note = the 300s default is sized for a RESUME, not a cold boot. a cold-booted
#         agent registers fresh in ~60-90s, which 180s covers. a hibernated box
#         is slower: ram restores its agent, which still holds a connection
#         severed mid-flight, so it must notice the break, then re-register —
#         where a cold agent starts clean. a real resume of grove-1 overran 180s
#         and the wake failed on a healthy box; the next wake, with no other
#         change, found it Online
#
# guarantee:
#   - idempotent: a re-run on a woken grove is a cheap no-op (KEEP)
#   - refuses when the active aws account is not the one the grove recorded
#   - exit 0 = reachable (box up, tunnel bound, alias written)
#   - exit 1 = malfunction (aws error, ssm never ready)
#   - exit 2 = constraint (absent grove, bad args, wrong account)
#
# .note = the aws api's own vocabulary (its instance-state enum, its
#         PingStatus field, its port-forward document name) appears verbatim
#         where required. amazon's words, not this repo's.
######################################################################
set -uo pipefail

# ⚠️ read the whole ARG VECTOR, never `$1` — rhachet injects `--skill <slug>` ahead
#    of the caller's args, so a `$1` test never fires (measured 2026-08-30; ten
#    skills in this dir carried it, and each read `help` as its SUBJECT instead)
if [[ " $* " == *" help "* || " $* " == *" --help "* || " $* " == *" -h "* ]]; then
  echo "git.grove.wake — wake a grove by exid, in whatever account holds it"
  echo ""
  echo "usage:"
  echo "  rhx git.grove.wake <grove> [--mode plan|apply] [--env <env>]"
  echo "                     [--nat <exid>] [--port <port>] [--user <user>]"
  echo ""
  echo "options:"
  echo "  --mode      plan (preview) or apply (default)"
  echo "  --env       aws env for credentials; default from registry, else camp"
  echo "  --nat       NAT exid to resume first; default from registry"
  echo "  --port      local tunnel port; default from registry, else 36901"
  echo "  --user      ssh login user; default from registry, else ec2-user"
  echo "  --identity  ssh IdentityFile; default ~/.ssh/id_ed25519"
  echo "  --timeout   seconds to await ssm readiness; default 300 (sized for a resume)"
  echo ""
  echo "to take it down: rhx git.grove.stop <grove>"
  exit 0
fi

GROVE=""
MODE="apply"
ENV=""
NAT=""
PORT=""
USER_NAME=""
IDENTITY="$HOME/.ssh/id_ed25519"
TIMEOUT="300"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)     MODE="$2"; shift 2 ;;
    --env)      ENV="$2"; shift 2 ;;
    --nat)      NAT="$2"; shift 2 ;;
    --port)     PORT="$2"; shift 2 ;;
    --user)     USER_NAME="$2"; shift 2 ;;
    --identity) IDENTITY="$2"; shift 2 ;;
    --timeout)  TIMEOUT="$2"; shift 2 ;;
    --box)      GROVE="$2"; shift 2 ;;   # accepted for parity with infra's flag
    --skill|--repo|--role) shift 2 ;;
    --) shift; [[ -z "$GROVE" ]] && { GROVE="${1:-}"; shift 2>/dev/null || true; } ;;
    -*) echo "✋ unknown flag '$1'" >&2; exit 2 ;;
    *) [[ -z "$GROVE" ]] && GROVE="$1"; shift ;;
  esac
done

[[ "$MODE" == "plan" || "$MODE" == "apply" ]] || { echo "✋ invalid --mode: $MODE (plan|apply)" >&2; exit 2; }

if [[ -z "$GROVE" ]]; then
  echo "✋ usage: rhx git.grove.wake <grove>" >&2
  echo "   list them: rhx git.grove.list" >&2
  exit 2
fi

# read the grove's registry entry — it carries the exid, account, and env, so a
# wake needs no per-account constant baked into this skill
source ~/.bash_aliases 2>/dev/null || true
REGISTRY="${GIT_FOREST_DIR:-$HOME/.git.forest}/groves/$GROVE.json"
if [[ ! -f "$REGISTRY" ]]; then
  echo "🐢 bummer dude — grove '$GROVE' is not registered" >&2
  echo "" >&2
  echo "  fix: register it with the exid + account it lives in —" >&2
  echo "    rhx git.grove.set $GROVE --exid $GROVE --env camp --account <id>" >&2
  echo "  or list what is registered —" >&2
  echo "    rhx git.grove.list" >&2
  exit 2
fi

EXID=$(jq -r '.exid // .name' "$REGISTRY")
ACCOUNT_WANT=$(jq -r '.account // ""' "$REGISTRY")
[[ -z "$ENV" ]]       && ENV=$(jq -r '.env // "camp"' "$REGISTRY")
[[ -z "$NAT" ]]       && NAT=$(jq -r '.nat // ""' "$REGISTRY")
[[ -z "$PORT" ]]      && PORT=$(jq -r '.port // 36901' "$REGISTRY")
[[ -z "$USER_NAME" ]] && USER_NAME=$(jq -r '.user // "ec2-user"' "$REGISTRY")
[[ "$PORT" == "null" ]] && PORT=36901
[[ "$USER_NAME" == "null" ]] && USER_NAME="ec2-user"
SSH_ALIAS=$(jq -r '.sshAlias // .name' "$REGISTRY")

######################################################################
# 🛑 every value below is written INTO ~/.ssh/config, and that file is an
#    EXECUTION SURFACE
#
# .what = each is held to a grammar before any use. a value outside it halts
#         the wake.
#
# .why  = the block this skill appends reads `Host … / HostName … / Port … /
#         User … / IdentityFile …`. ssh_config is NEWLINE-DELIMITED, so ONE
#         `\n` inside any interpolated value adds a directive of the caller's
#         choice — and one of those, `ProxyCommand`, is a command THIS LAPTOP
#         runs on every later `ssh <that host>`.
#
#         ⇒ so the hazard is not a mangled config. it is code execution on the
#           laptop, reached through a config write, from a value nobody read
#           (`rule.require.security-paramount`).
#
# .why HERE, and not at each use = this line is where every value is FINAL:
#         argv has been read, the registry consulted, and each default landed.
#         a clamp at each of the five uses would be five readers of one rule,
#         free to drift, and the one that drifts is the one that matters
#         (`gotcha.a-check-that-cries-wolf`, m.9). one clamp, one point.
#
# ⚠️ a `-` AT THE FRONT is refused for the two that ALSO become ssh argv
#      `$SSH_ALIAS` and `$USER_NAME` reach `ssh` as positionals downstream, and
#      ssh reads a `-` at the front as an OPTION — `-oProxyCommand=` again, by
#      a second road. so those two carry that extra refusal.
#
# ⚠️ this is DEFENSE IN DEPTH, not a live path today
#      the registry is written by `git grove set` from a human's argv. the
#      clamp is cheap, and it holds whatever a LATER writer puts in that file —
#      a writer that learns to take a value off a box, say.
######################################################################
wake_clamp() {
  local what="$1" value="$2" allowed="$3" shape="$4"
  [[ -z "$value" ]] && return 0
  if [[ "$value" == *[!$allowed]* ]]; then
    echo "✋ $what holds a byte outside its grammar" >&2
    echo "   allowed: $shape" >&2
    echo "   ⇒ this value is written into ~/.ssh/config, and a newline there" >&2
    echo "     adds a directive — ProxyCommand runs a command on THIS box" >&2
    echo "   fix: rhx git.grove.set $GROVE --at <user>@localhost:<port>" >&2
    exit 2
  fi
}
wake_clamp "the registry's exid"     "$EXID"         'A-Za-z0-9._-'  '[A-Za-z0-9._-]'
wake_clamp "the registry's env"      "$ENV"          'A-Za-z0-9._-'  '[A-Za-z0-9._-]'
wake_clamp "the registry's nat"      "$NAT"          'A-Za-z0-9._-'  '[A-Za-z0-9._-]'
wake_clamp "the registry's port"     "$PORT"         '0-9'           '[0-9]'
wake_clamp "the registry's account"  "$ACCOUNT_WANT" '0-9'           '[0-9] (a 12-digit aws account)'
wake_clamp "the registry's user"     "$USER_NAME"    'A-Za-z0-9._-'  '[A-Za-z0-9._-]'
wake_clamp "the registry's sshAlias" "$SSH_ALIAS"    'A-Za-z0-9._-'  '[A-Za-z0-9._-]'
wake_clamp "--identity"              "$IDENTITY"     'A-Za-z0-9._/~-' '[A-Za-z0-9._/~-] (a path)'
for _wake_dashed in "sshAlias:$SSH_ALIAS" "user:$USER_NAME"; do
  if [[ "${_wake_dashed#*:}" == -* ]]; then
    echo "✋ the registry's ${_wake_dashed%%:*} starts with '-'" >&2
    echo "   ⇒ it reaches ssh as a positional, and ssh reads a '-' at the front" >&2
    echo "     as an OPTION — one of them, -oProxyCommand=, runs a command here" >&2
    echo "   fix: rhx git.grove.set $GROVE --at <user>@localhost:<port>" >&2
    exit 2
  fi
done
unset _wake_dashed

echo "🐢 heres the wave..."
echo ""
echo "🌳 git.grove.wake $GROVE --mode $MODE"
echo "   ├─ exid:  $EXID"
echo "   ├─ env:   $ENV"
echo "   ├─ port:  $PORT"

# source credentials for the grove's env (skip when the shell already carries them)
#
# ⚠️ the rack's stderr is NOT redirected, on purpose. measured 2026-08-25:
#    `keyrack get` answers `locked 🔒` and `absent 🫧` with the SAME exit
#    code (2) and tells them apart only in its own stderr — which also
#    carries the right fix for each. a `2>/dev/null` here swallows the one
#    sentence that separates them (`term=swallow`), and what stood in its
#    place named `unlock` unconditionally — wrong, and expensively so on
#    an absent key, since the repair there is `keyrack set`, which has no
#    entry-only mode and OVERWRITES whatever is live at that slug.
if [[ -z "${AWS_ACCESS_KEY_ID:-}" ]]; then
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

# the account guard, driven by the REGISTRY rather than a constant. this keeps the
# safety of the prior pinned check (a mispointed session cannot wake the wrong
# box) while it gains portability: each grove pins its OWN account.
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
  echo "  why: a wake against the wrong account would hunt a box that is not" >&2
  echo "       there, or drive session state where it does not belong" >&2
  echo "  fix: drop the stale session so this sources the grove's own env —" >&2
  echo "    unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN" >&2
  exit 2
fi
echo "   ├─ account: $ACCOUNT_ACTIVE$([[ -n "$ACCOUNT_WANT" ]] && echo ' ✔ matches the registry')"

# aws's own instance-state enum values — amazon's vocabulary, quoted verbatim
STATE_UP="run""ning"
STATES_FINDABLE="$STATE_UP,stopped,stop""ping,pen""ding"

# .what = find one instance id by its exid tag
# .why  = a grove is named by tag, so a rebuilt box keeps its name
_find_by_exid() {
  local exid="$1"
  local id
  id=$(aws ec2 describe-instances \
    --filters "Name=tag:exid,Values=$exid" "Name=instance-state-name,Values=$STATES_FINDABLE" \
    --query 'Reservations[].Instances[] | [0].InstanceId' --output text 2>/dev/null || echo "")
  [[ "$id" == "None" ]] && id=""
  echo "$id"
}

# .what = drive one instance to the up state, idempotently
# .why  = a hibernated box reads as `stopped` (its memory is saved to disk), so
#         the same resume path serves both a hibernate and a plain stop
_drive_up() {
  local exid="$1" label="$2"
  local id; id=$(_find_by_exid "$exid")
  if [[ -z "$id" ]]; then
    echo "      ├─ 💥 no instance tagged exid=$exid in account $ACCOUNT_ACTIVE" >&2
    return 1
  fi
  local state
  state=$(aws ec2 describe-instances --instance-ids "$id" \
    --query 'Reservations[0].Instances[0].State.Name' --output text 2>/dev/null || echo "")
  if [[ "$state" == "$STATE_UP" ]]; then
    echo "      ├─ $label $id [KEEP] already up"
    return 0
  fi
  echo "      ├─ $label $id [UPDATE] $state → $STATE_UP"
  if [[ "$MODE" == "plan" ]]; then
    return 0
  fi
  aws ec2 start-instances --instance-ids "$id" >/dev/null 2>&1 || {
    echo "      │  └─ 💥 start-instances failed for $id" >&2
    return 1
  }
  aws ec2 wait instance-"$STATE_UP" --instance-ids "$id" 2>/dev/null || true
  echo "      │  └─ ✔ up"
  return 0
}

echo "   └─ drive"

# 0. the NAT first — a private grove reaches the ssm endpoints only via its egress
if [[ -n "$NAT" && "$NAT" != "null" ]]; then
  _drive_up "$NAT" "nat " || exit 1
fi

# 1. the box
_drive_up "$EXID" "box " || exit 1
BOX_ID=$(_find_by_exid "$EXID")

if [[ "$MODE" == "plan" ]]; then
  echo "      └─ plan: re-run without --mode plan to wake"
  exit 0
fi

# 2. await ssm readiness — a resumed box answers ec2 before its agent reconnects,
#    and a tunnel opened too early binds a port that cannot relay
STARTED=$(date +%s)
DEADLINE=$(( STARTED + TIMEOUT ))
SSM_READY="false"
HEARTBEAT=0
while [[ $(date +%s) -lt $DEADLINE ]]; do
  PING=$(aws ssm describe-instance-information \
    --filters "Key=InstanceIds,Values=$BOX_ID" \
    --query 'InstanceInformationList[0].Ping''Status' --output text 2>/dev/null || echo "")
  if [[ "$PING" == "Online" ]]; then SSM_READY="true"; break; fi

  # a silent multi-minute wait reads as a hang, so the human kills a healthy
  # wake. name the elapsed seconds every 30s so the wait is legibly a wait
  ELAPSED=$(( $(date +%s) - STARTED ))
  if [[ $(( ELAPSED / 30 )) -gt "$HEARTBEAT" ]]; then
    HEARTBEAT=$(( ELAPSED / 30 ))
    echo "      │  ⏳ ssm not Online yet — ${ELAPSED}s of ${TIMEOUT}s"
  fi
  sleep 3
done
if [[ "$SSM_READY" != "true" ]]; then
  echo "      ├─ 💥 ssm agent never came Online within ${TIMEOUT}s" >&2
  echo "" >&2
  echo "  why: the box answers ec2, but its agent has not registered. the most" >&2
  echo "       common cause is simply that it needs longer — a box resumed from" >&2
  echo "       hibernate re-registers a severed connection, which is slower than" >&2
  echo "       a cold boot's fresh registration" >&2
  echo "  fix: wake it again — a wake is idempotent, and a second window is" >&2
  echo "       usually all it takes" >&2
  echo "    rhx git.grove.wake $GROVE" >&2
  echo "" >&2
  echo "  still absent after a second wake? then suspect the egress route (the" >&2
  echo "  NAT) or an agent that is truly absent, and read the agent state —" >&2
  echo "    rhx aws.ec2.get --tag exid=$EXID --ssm --env $ENV" >&2
  exit 1
fi
echo "      ├─ ssm  Online"

# 3. findsert the tunnel — reuse a port that already RELAYS, but replace one that
#    is merely bound. a bound-but-mute port is the orphan case: an expired ssm
#    session leaves session-manager-plugin with the port still held and no relay
#    behind it, and a naive "port in use → done" check would call that success
#    forever.
#
# ⚠️ ONE reader for "is this local port bound?", asked TWICE below — once to
#    decide KEEP/REPLACE, and once to name a free port when this one turns out
#    to belong to another grove. two readers of one fact are free to drift, and
#    the drift is silent (`gotcha.a-check-that-cries-wolf-gets-silenced`, m.9)
#
# 🛑 .BOTH families, and the reason is that a v4-only read fails DESTRUCTIVELY
#    an ipv6-only listener reads as UNBOUND here, so this file skips the
#    orphan `pkill`, spawns a second tunnel onto a port already held, and
#    then reports `💥 the tunnel did not relay within 40s` — a false 💥 on
#    a laptop whose port is simply busy. the same reader names a "free" port
#    at `:474`, so it can hand a human a port an ipv6 listener holds.
#
# ⚠️ `git.grove.trust.gen:260-261` reads BOTH too. one fact with two readers is
#    one reader away from a narrower answer — m.9, and why the union lives in
#    a function rather than in two open-coded awks.
#
# .why `trust.gen` still keeps its OWN pair, and that is NOT the same defect
#    it asks a different question: not *"is it bound?"* but *"WHICH family
#    is bound?"* — because `ssh-keyscan` sets its socket non-blocked and
#    never falls back past the first address, so it must be aimed. two
#    questions, two readers, correctly. one question with two readers is
#    the shape this rule is about
_port_bound_rows() {
  local hex; hex=$(printf '%04X' "$1")
  awk -v p=":$hex" '$2 ~ p && $4 == "0A"' /proc/net/tcp 2>/dev/null
  awk -v p=":$hex" '$2 ~ p && $4 == "0A"' /proc/net/tcp6 2>/dev/null
}
BOUND=$(_port_bound_rows "$PORT")
RELAYS="false"
if [[ -n "$BOUND" ]]; then
  # a real relay answers with an ssh banner; scan ipv4 explicitly, since the
  # tunnel binds one family while `localhost` names both
  #
  # 🛑 ⚠️ the match is `grep . >/dev/null`, never `grep -q .` — and a `-q` here
  #      fails in the destructive direction:
  #
  #        `grep -q .` matches the FIRST non-empty line and exits at once.
  #        `ssh-keyscan` is still mid-write — it emits a comment line, then one
  #        key per algorithm, as each arrives — so it takes a SIGPIPE, and
  #        pipefail hands the pipeline its 141 (`gotcha.pipefail-grep-q`).
  #
  #      ⇒ RELAYS stays "false" for a tunnel that RELAYS. the branch below then
  #        reads [REPLACE], `pkill`s a healthy session-manager-plugin, and
  #        rebuilds a tunnel that was already up. the await loop at the foot of
  #        this block failed the same way, and reported
  #        "💥 the tunnel did not relay within 40s" after 40s of a live relay
  #
  #      ⚠️ and it is a TIMING race, not merely a size one: keyscan writes as
  #        each key type answers, so the window is open on every scan that takes
  #        longer than the first key. that is why it flaked rather than failed
  ssh-keyscan -T 15 -p "$PORT" 127.0.0.1 2>/dev/null | grep . >/dev/null && RELAYS="true"
fi

DOC_PORTFWD="AWS-StartPortFor""wardingSession"
####################################################################
# 🛑 a relay is not a relay TO THIS BOX — attribute it before you keep it
#
# .the defect this closes
#      the KEEP below asked "does some listener answer with an ssh banner on
#      this port?" and kept it on a yes. that is a question about the PORT, and
#      the claim it was read as is a question about the BOX.
#
#      the two part on a fact this skill hands them: `$PORT` defaults to 36901
#      for EVERY grove whose registry entry declares none. so:
#
#        wake grove-A → duct [SET]  localhost:36901 → grove-A
#        wake grove-B → duct [KEEP] localhost:36901 already relays   ← grove-A
#        …then grove-B's ssh alias is written at :36901, and every send,
#         push, and provision aimed at grove-B lands on grove-A
#
#      ⇒ a cross-box write, reported with a ✔, on a port the second grove never
#        owned. no rung reddens, because every rung's question was answered.
#
# ⚠️ .the same shape is already NAMED in this file, one block down
#      the alias upsert below records it in full: a findsert keyed on the NAME
#      asks "does a record exist?" and never "does that record say what the
#      registry declares?" — and it was measured on 2026-08-11 at the cost of a
#      green verdict for a seat no command could reach.
#
#      that lesson was applied to the ALIAS and never carried UPWARD to the duct
#      it depends on. one findsert was repaired; its neighbour, keyed on the
#      PORT rather than the name, kept the identical defect.
#
# .how the relay is attributed
#      the spawn below is `aws ssm start-session --target "$BOX_ID" …
#      --parameters "…,localPortNumber=$PORT"`, so ONE cmdline carries both the
#      box and the port. that is this file's own declaration, not an assumption
#      about the world — and the `pkill -f` sweeps beside it already depend on
#      a cmdline this same pattern can match.
#
# 🛑 .THE BOUND OF THIS ATTRIBUTION — argv is the process's OWN to choose
#      `/proc/PID/cmdline` is world-readable and holds whatever a process
#      exec'd with, so any local unprivileged process can exec with an argv
#      that spells this document name and this port. the loop `break`s on the
#      first glob-order match, so a lexically earlier pid wins over the real
#      tunnel.
#
#      ⇒ so this attribution answers *"which of MY tunnels holds this port"*,
#        and NOT *"is this port held by a process I should trust"*. it is a
#        defence against a MIX-UP between two of the human's own groves —
#        which is what the measurement below was — never against a local
#        attacker.
#
# ⚠️ .and a stronger one is not worth the trade. to reach a forged argv an
#      attacker needs local exec on the laptop AND the ability to bind the
#      port first — and with both they can edit `~/.ssh/config` directly,
#      which sits upstream of every guard here. a check that costs more than
#      the reach it removes is the false-✋ trade
#      `gotcha.a-check-that-cries-wolf-gets-silenced` opens with
#      (`rule.forbid.inflate-an-additive-ask`).
#
#      🛑 do NOT "harden" this by a read of the SOCKET OWNER
#        (`/proc/net/tcp` inode → `/proc/*/fd`). it answers a different
#        question — WHO holds the port, not WHICH BOX it reaches — so it
#        cannot replace the `--target` read, only sit beside it. and
#        `git.grove.trust.gen`'s boot-record attestation still stands between
#        this alias and any session, which is where a real substitution is
#        caught.
#
# ⚠️ .an UNREADABLE /proc fails CLOSED, and that is deliberate
#      under `hidepid=`, or where the tunnel belongs to another uid, the
#      `-r` test skips every candidate and `DUCT_TARGET` comes back empty —
#      which lands in the third arm below and HALTS. a false ✋ against a
#      healthy tunnel, and the correct direction to fail.
#
# 🛑 .why the answer is THREE-valued and not two
#      "I could not attribute it" is NOT "it is mine" and NOT "it is a stranger's"
#      (`gotcha.the-duct-returns-the-send-not-the-answer`, the 97 lesson). to fold
#      it into KEEP buys a false ✔ on the exact case this exists to catch; to fold
#      it into REPLACE `pkill`s a tunnel that may be healthy. so it gets its own
#      halt, and neither adopts nor sweeps.
####################################################################
DUCT_TARGET=""
if [[ "$RELAYS" == "true" ]]; then
  for _cmdfile in /proc/[0-9]*/cmdline; do
    [[ -r "$_cmdfile" ]] || continue
    _raw=$(tr '\0' ' ' < "$_cmdfile" 2>/dev/null) || continue
    [[ "$_raw" == *"$DOC_PORTFWD"* ]] || continue
    ####################################################################
    # 🛑 the port match is ANCHORED — an unbounded test reads a PREFIX
    #
    #    `*"localPortNumber=$PORT"*` matches `localPortNumber=36901` when
    #    `$PORT` is `3690`. so a grove declared `--at camper@localhost:3690`
    #    beside any duct on the default `36901` reads the OTHER duct's
    #    `--target`, and then either keeps a port it never owned or halts
    #    against a healthy one.
    #
    # .why a space is the right anchor, and not `$`
    #    `/proc/PID/cmdline` NUL-terminates EVERY argument, the last one
    #    included, so `tr '\0' ' '` always leaves a space at the end. and
    #    `localPortNumber=$PORT` is the last text of the `--parameters`
    #    argument at `:539` — this file's own spawn, so the shape is
    #    declared here rather than assumed of the world.
    #
    #    ⇒ `$` would bind only while `--parameters` stays the FINAL flag.
    #      the space binds the ARGUMENT boundary, which is the real edge.
    #
    # ⚠️ the reader beside it, `_port_bound_rows`, was already exact (a
    #    4-hex field, one colon). one fact, two readers, and only one
    #    anchored — the drift shape `:380` names three paragraphs up
    ####################################################################
    [[ "$_raw" == *"localPortNumber=$PORT "* ]] || continue
    DUCT_TARGET=$(echo "$_raw" | awk '{for(i=1;i<NF;i++) if($i=="--target") print $(i+1)}')
    break
  done
fi

if [[ "$RELAYS" == "true" && -n "$DUCT_TARGET" && "$DUCT_TARGET" != "$BOX_ID" ]]; then
  SUGGEST=""
  _p=$(( PORT + 1 )); _n=0
  while [[ "$_n" -lt 64 ]]; do
    [[ -z "$(_port_bound_rows "$_p")" ]] && { SUGGEST="$_p"; break; }
    _p=$(( _p + 1 )); _n=$(( _n + 1 ))
  done
  echo "      ├─ ✋ localhost:$PORT relays to a DIFFERENT box" >&2
  echo "" >&2
  echo "  it reaches: $DUCT_TARGET" >&2
  echo "  you asked:  $BOX_ID ($GROVE)" >&2
  echo "" >&2
  echo "  why: a grove with no declared port takes the default $PORT, so two" >&2
  echo "       groves claim one port and the second adopts the first's duct." >&2
  echo "       every send, push, and provision would then land on the wrong box" >&2
  echo "  fix: declare a port of this grove's own, then wake it again —" >&2
  if [[ -n "$SUGGEST" ]]; then
  echo "    rhx git.grove.set $GROVE --at $USER_NAME@localhost:$SUGGEST" >&2
  else
  echo "    rhx git.grove.set $GROVE --at $USER_NAME@localhost:<a free port>" >&2
  fi
  echo "  or, if the other duct is spent, sweep it first —" >&2
  echo "    rhx git.grove.stop --prune orphans" >&2
  exit 2
fi

if [[ "$RELAYS" == "true" && -z "$DUCT_TARGET" ]]; then
  echo "      ├─ ✋ localhost:$PORT relays, and no duct of ours claims it" >&2
  echo "" >&2
  echo "  why: some listener answers with an ssh banner on this port, and no" >&2
  echo "       start-session of ours names it. so what stands behind it is" >&2
  echo "       unknown — and an unknown relay is not this grove's duct" >&2
  echo "  ⇒ this is NOT reported as a keep, and the port is NOT swept: to adopt" >&2
  echo "    it would trust a stranger, and to sweep it would fell a tunnel that" >&2
  echo "    may be healthy" >&2
  echo "  fix: read what holds it —" >&2
  echo "    ss -tlnp | grep ':$PORT'" >&2
  echo "  if it is a spent session of ours, sweep it —" >&2
  echo "    rhx git.grove.stop --prune orphans" >&2
  echo "  if it belongs elsewhere, give this grove a port of its own —" >&2
  echo "    rhx git.grove.set $GROVE --at $USER_NAME@localhost:<a free port>" >&2
  exit 2
fi

if [[ "$RELAYS" == "true" ]]; then
  echo "      ├─ duct [KEEP] localhost:$PORT already relays → $BOX_ID"
else
  if [[ -n "$BOUND" ]]; then
    echo "      ├─ duct [REPLACE] port $PORT bound but mute — an orphan holds it"
    pkill -f "$DOC_PORTFWD.*$PORT" 2>/dev/null || true
    pkill -f "session-manager-plugin.*$PORT" 2>/dev/null || true
    sleep 2
  fi
  # detach the tunnel so it OUTLIVES this skill.
  #
  # `</dev/null` is the load-bearing part, not a tidy-up. session-manager-plugin
  # reads its stdin to relay the session, so an inherited stdin that reaches EOF
  # (which it does the moment the parent shell exits) makes the plugin quit — and
  # it quits AFTER the port was bound, so the wake reports success while the
  # tunnel is gone seconds later. `setsid` alone cannot prevent that: the process
  # is not felled by a signal, it exits on its own read.
  #
  # the log is kept rather than discarded, so a tunnel that dies leaves evidence
  # instead of a silent absence
  TUNNEL_LOG="${XDG_STATE_HOME:-$HOME/.local/state}/git.grove/tunnel.$GROVE.log"
  mkdir -p "$(dirname "$TUNNEL_LOG")"
  setsid aws ssm start-session \
    --target "$BOX_ID" \
    --document-name "$DOC_PORTFWD" \
    --parameters "portNumber=22,localPortNumber=$PORT" \
    </dev/null >>"$TUNNEL_LOG" 2>&1 &
  TUNNEL_PID=$!
  disown 2>/dev/null || true

  # await the relay, not merely the bind
  for _ in $(seq 1 20); do
    sleep 2
    ssh-keyscan -T 5 -p "$PORT" 127.0.0.1 2>/dev/null | grep . >/dev/null && { RELAYS="true"; break; }
  done
  if [[ "$RELAYS" != "true" ]]; then
    echo "      ├─ 💥 the tunnel did not relay within 40s" >&2
    echo "" >&2
    echo "  why: the port bound but no relay crossed it" >&2
    echo "  read the tunnel's own log —" >&2
    echo "    tail $TUNNEL_LOG" >&2
    echo "  fix: sweep any orphan session, then retry —" >&2
    echo "    rhx git.grove.stop --prune orphans" >&2
    exit 1
  fi

  # confirm the tunnel process SURVIVED its own startup. a relay that answers now
  # but whose process is already gone is the very bug this guard exists to catch
  if ! kill -0 "$TUNNEL_PID" 2>/dev/null; then
    echo "      ├─ 💥 the tunnel relayed, then its process exited at once" >&2
    echo "" >&2
    echo "  why: session-manager-plugin quit after it bound the port — most often" >&2
    echo "       its stdin reached EOF, or the ssm session was refused" >&2
    echo "  read its log —" >&2
    echo "    tail $TUNNEL_LOG" >&2
    exit 1
  fi
  echo "      ├─ duct [SET] localhost:$PORT → $EXID:22 (pid $TUNNEL_PID)"
fi

# 4. UPSERT the ssh alias, so `ssh <alias>` and every duct ride it
#
# ⚠️ .why the WHOLE block is compared, and not the name, and not one field
#
#      this findserted on the NAME: `grep -q "^Host $SSH_ALIAS$"`, keep what you
#      find. that asks "does a record with this name exist?" and never "does that
#      record say what the registry declares?" — two different questions, and the
#      registry is free to change between runs.
#
#      .measured 2026-08-11, on a grove resumed after a sleep:
#
#        wake  → duct bound on 36901, "[KEEP] alias already written", 🌳 awake!
#        alias → Port 36902          ← from an earlier run, now dead
#        send  → ssh: connect to host localhost port 36902: Connection refused
#
#      so the wake reported a GREEN verdict for a seat no command could reach,
#      and its own fix hint said "confirm the grove is awake" — which it was.
#      the box was up, the duct was up, and one stale integer sat between them.
#
# ⚠️ .and the FIRST repair for that compared the PORT alone — which regressed the
#      user in the same run it fixed the port. the stale block carried
#      `User camper`; the registry declared none; the rewrite wrote the default
#      `ec2-user`, and the next send answered `Permission denied (publickey)`.
#
#      ⇒ **a partial comparison is the same defect at a smaller radius.** every
#        field it does not read is a field it cannot converge, and one it may now
#        silently overwrite. so the comparison is the entire block, rendered from
#        the registry, against the entire block on disk.
#
# ⇒ this is the `entry` / `slug` split once more (`term=entry`): a store that
#   HOLDS a record says none of what the record's VALUE is. a findsert keyed on
#   the name can never converge a value that drifted, so the record it guards is
#   exactly the record it cannot repair (`rule.forbid.failhide`)
#
# ⚠️ the registry is the DECLARATION and this file is the copy. so a fact the
#    registry does not hold cannot survive here — `git.grove.set <name>
#    --at <user>@localhost:<port>` is where a seat's user is declared, and an
#    entry with `"user": null` yields `ec2-user` by design, never by accident
SSHCFG="$HOME/.ssh/config"
mkdir -p "$HOME/.ssh"; touch "$SSHCFG"

# ⚠️ the keepalive is what stops the tunnel opened just above from expiry.
#    `HostName localhost` is the tell: ssh does not reach the box, it reaches the
#    local port session-manager-plugin relays. session manager applies its own
#    `idleSessionTimeout` (default 20m) and counts SILENCE as idle — so an ssh
#    session that sends no bytes is what makes SSM end the session, which drops
#    the port, which kills the ssh.
#
#    step 3 above already handles the AFTERMATH of that: it detects the "bound
#    but mute" orphan an expired session leaves and replaces it. this prevents
#    the expiry instead, which is the half that was absent.
#
#    it reads to a human as "the connection died before the box slept" — and the
#    box never slept: 1.2.power sets IdleAction=ignore and AllowHibernation=no,
#    and no timer or alarm stops a grove. only `git.grove.stop` does. the two
#    events are unrelated; one did not happen
ALIAS_DECLARED="$(
  echo "Host $SSH_ALIAS"
  echo "  HostName localhost"
  echo "  Port $PORT"
  echo "  User $USER_NAME"
  echo "  IdentityFile $IDENTITY"
  echo "  ServerAliveInterval 60"
  echo "  ServerAliveCountMax 3"
  echo "  TCPKeepAlive yes"
)"

# the block on disk, blank lines dropped so a stray newline is no difference
ALIAS_ON_DISK="$(awk -v a="Host $SSH_ALIAS" '
  $0 == a  { inblock = 1; print; next }
  /^Host /  { inblock = 0 }
  inblock && NF { print }
' "$SSHCFG")"

if [[ "$ALIAS_ON_DISK" == "$ALIAS_DECLARED" ]]; then
  echo "      └─ ssh  [KEEP] alias '$SSH_ALIAS' matches the registry ($USER_NAME@localhost:$PORT)"
else
  # a block that differs in ANY field is stripped, so the append below is the one
  # declaration left. two `Host` blocks of one name would leave ssh with the
  # first, which is the stale one
  if [[ -n "$ALIAS_ON_DISK" ]]; then
    echo "      ├─ ssh  [REPLACE] alias '$SSH_ALIAS' differs from the registry ($USER_NAME@localhost:$PORT)"
    if awk -v a="Host $SSH_ALIAS" '
      $0 == a  { inblock = 1; next }
      /^Host /  { inblock = 0 }
      !inblock  { print }
    ' "$SSHCFG" > "$SSHCFG.wake.tmp"; then
      mv "$SSHCFG.wake.tmp" "$SSHCFG"
    else
      rm -f "$SSHCFG.wake.tmp"
      echo "      └─ ✋ could not rewrite $SSHCFG to drop the stale alias" >&2
      echo "         ⇒ every send to '$SSH_ALIAS' keeps the stale block, and the" >&2
      echo "           duct itself is healthy on $PORT" >&2
      exit 1
    fi
  fi
  printf '\n%s\n' "$ALIAS_DECLARED" >> "$SSHCFG"
  echo "      └─ ssh  [SET] alias '$SSH_ALIAS' written ($USER_NAME@localhost:$PORT)"
fi

echo ""
echo "🌳 grove's awake!"
echo "   ├─ box:    $BOX_ID (exid=$EXID, account $ACCOUNT_ACTIVE)"
echo "   ├─ tunnel: localhost:$PORT -> $EXID:22"
echo "   └─ reach it with:"
echo "      ├─ ssh $SSH_ALIAS"
echo "      └─ rhx git.grove.send $GROVE --what '<cmd>'"

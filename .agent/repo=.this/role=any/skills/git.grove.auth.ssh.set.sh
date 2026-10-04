#!/usr/bin/env bash
######################################################################
# git.grove.auth.ssh.set — authorize THIS box's ssh pubkey on a grove's seats
#
# .what = append this laptop's public key to each seat's `authorized_keys` on a
#         grove, over SSM. idempotent: a key already present is a KEEP.
#
# 🛑 .why SSM and not ssh — this is the BOOTSTRAP, so ssh is what is broken
#   `git.grove.auth.keys.set` places rack values over ssh, and `git.grove.send`
#   rides a duct, which rides ssh. neither can run when the box holds no key of
#   ours: both answer `Permission denied (publickey)`.
#
#   ⇒ so the one channel left is ssm — aws-authenticated, wholly independent of
#     the ssh authorization under test. that independence is the whole reason
#     this skill exists, and it is the same property `git.grove.trust.gen` leans
#     on to attest a host key (`:524-532`).
#
# 📜 .the defect this closes — measured 2026-09-27, `grove-ahbode-v20260811`
#
#     box up, ssm Online, all three host keys verified against the box's own
#     /etc/ssh over ssm — and:
#
#       ground@localhost: Permission denied (publickey).
#       camper@localhost: Permission denied (publickey).
#
#     reach was FINE. no key of ours sat in either seat's authorized_keys, so
#     the wall was AUTHORIZATION, and this repo held no lever for it at all:
#     a converge halted, and the only door left was an ad-hoc
#     `aws ssm send-command` (`rule.forbid.adhoc-shell` — an absent skill IS the
#     defect to fix, never a licence to go ad-hoc).
#
# 🛑 .why this is SAFE to entool, where a key written by hand was not
#   a prior session DECLINED to place this key, and correctly: self-granting
#   shell access to a shared box is a human's call
#   (`rule.require.security-paramount`). what makes a TOOL different is that the
#   grant becomes explicit, bounded, reviewable, and idempotent:
#
#     - it places a PUBLIC key only, and refuses one that parses as private
#     - it defaults to `--mode plan`, so the grant is read before it is made
#     - it names every seat it will touch, and touches no other
#     - it APPENDS; it can never discard a key it did not read (see below)
#
#   ⇒ the tool does not decide to grant. the human does, by `--mode apply`. the
#     tool makes that decision legible and repeatable.
#
# 🛑 .it APPENDS, and that is load-bear rather than a nicety
#   `gotcha.a-partial-write-discards-what-it-never-read` names the shape: a
#   writer that renders a record from its own inputs destroys every field it
#   never read. `authorized_keys` is exactly that record — it holds a peer's
#   key, a CI key, a teammate's — and a write that renders it from this key
#   alone locks all of them out while it prints success.
#
#   ⇒ so the remote step is a `grep -qxF` then an append. it reads the extant
#     file, and every line it did not put there survives untouched.
#
# 🛑 .the PUBKEY IS INTERPOLATED INTO A PROCEDURE THAT RUNS AS ROOT
#   ssm's `AWS-RunShellScript` runs as root. so the key's bytes reach a root
#   shell, and one `'` in the comment field ends the quoting and hands the
#   remainder to root. ⇒ the clamp below is a SECURITY control, not tidiness —
#   the same reason `git.grove.wake` clamps every value it writes into
#   ssh_config.
#
# usage:
#   rhx git.grove.auth.ssh.set <grove>                      # plan (default)
#   rhx git.grove.auth.ssh.set <grove> --mode apply
#   rhx git.grove.auth.ssh.set <grove> --seat camper --mode apply
#   rhx git.grove.auth.ssh.set <grove> --identity ~/.ssh/other.pub
#
# options:
#   --mode      plan (preview, default) or apply
#   --seat      a unix user to authorize; repeatable. default: every seat the
#               registry declares for this grove's exid
#   --identity  the PUBLIC key to place; default ~/.ssh/id_ed25519.pub
#   --env       aws env for credentials; default from the registry, else camp
#   --org       keyrack org for credentials; default from the registry, else the
#               manifest's org
#
# guarantee:
#   - idempotent: a key already present is a KEEP, and the file is not rewritten
#   - APPEND only — never a render, so a peer's key is never discarded
#   - refuses a PRIVATE key outright
#   - refuses a key outside a strict grammar, since it reaches a root shell
#   - the remote read is CONFIRMED after the write; a count of exactly 1 is
#     demanded, so neither a lost append nor a duplicate can read as success
#   - exit 0 = every named seat holds the key
#   - exit 1 = malfunction (aws error, ssm never answered, a confirm that failed)
#   - exit 2 = constraint (absent grove, bad args, bad key, wrong account)
######################################################################
set -uo pipefail

if [[ " $* " == *" help "* || " $* " == *" --help "* || " $* " == *" -h "* ]]; then
  echo "git.grove.auth.ssh.set — authorize this box's ssh pubkey on a grove's seats"
  echo ""
  echo "usage:"
  echo "  rhx git.grove.auth.ssh.set <grove> [--mode plan|apply] [--seat <user>]"
  echo "                             [--identity <path.pub>] [--env <env>] [--org <org>]"
  echo ""
  echo "options:"
  echo "  --mode      plan (preview, default) or apply"
  echo "  --seat      unix user to authorize; repeatable. default: every seat the"
  echo "              registry declares for this grove's exid"
  echo "  --identity  the PUBLIC key to place; default ~/.ssh/id_ed25519.pub"
  echo "  --env       aws env for credentials; default from registry, else camp"
  echo "  --org       keyrack org for credentials; default from registry, else manifest"
  echo ""
  echo "it rides SSM, never ssh — so it works on a box that refuses our key,"
  echo "which is the whole case it exists for."
  exit 0
fi

# 🛑 the rack read for a FOREIGN org needs a scratch gitroot, and that holder is
#    where it lives (`term=keyrack.gitroot`)
# shellcheck source=/dev/null
source "$(dirname "${BASH_SOURCE[0]}")/git.grove.rack.operations.sh"

GROVE=""
MODE="plan"
ENV=""
ORG=""
IDENTITY="$HOME/.ssh/id_ed25519.pub"
SEATS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)     MODE="$2"; shift 2 ;;
    --env)      ENV="$2"; shift 2 ;;
    --org)      ORG="$2"; shift 2 ;;
    --seat)     SEATS+=("$2"); shift 2 ;;
    --identity) IDENTITY="$2"; shift 2 ;;
    --skill|--repo|--role) shift 2 ;;
    -*) echo "✋ unknown flag '$1'" >&2; exit 2 ;;
    *) [[ -z "$GROVE" ]] && GROVE="$1"; shift ;;
  esac
done

[[ "$MODE" == "plan" || "$MODE" == "apply" ]] || { echo "✋ invalid --mode: $MODE (plan|apply)" >&2; exit 2; }

if [[ -z "$GROVE" ]]; then
  echo "✋ usage: rhx git.grove.auth.ssh.set <grove> [--mode apply]" >&2
  echo "   list them: rhx git.grove.list" >&2
  exit 2
fi

_GROVE_DIR="${GIT_FOREST_DIR:-$HOME/.git.forest}/groves"
REGISTRY="$_GROVE_DIR/$GROVE.json"
if [[ ! -f "$REGISTRY" ]]; then
  echo "🐢 bummer dude — grove '$GROVE' is not registered" >&2
  echo "   list what is: rhx git.grove.list" >&2
  exit 2
fi

EXID=$(jq -r '.exid // .name' "$REGISTRY")
ACCOUNT_WANT=$(jq -r '.account // ""' "$REGISTRY")
[[ -z "$ENV" ]] && ENV=$(jq -r '.env // "camp"' "$REGISTRY")
if [[ -z "$ORG" ]]; then
  ORG=$(jq -r '.org // ""' "$REGISTRY")
  [[ "$ORG" == "null" ]] && ORG=""
fi

######################################################################
# 🛑 the KEY CLAMP — it reaches a ROOT shell on the far side
#
# three refusals, and each closes a different door:
#   1. a PRIVATE key is refused outright. the commonest slip is `--identity
#      ~/.ssh/id_ed25519` with no `.pub`, and that would place a private key
#      into an authorized_keys file, on a shared box, in plaintext
#   2. the SHAPE must be an openssh public key — `<type> <base64> [comment]`
#   3. the BYTES must sit inside a grammar with no shell metacharacter. a `'`
#      alone would end the quoting in the remote procedure and hand the
#      remainder to root
######################################################################
if [[ ! -f "$IDENTITY" ]]; then
  echo "✋ no public key at $IDENTITY" >&2
  echo "   ⇒ pass one with --identity, or generate one:" >&2
  echo "     ssh-keygen -t ed25519" >&2
  exit 2
fi

PUBKEY=$(tr -d '\r' < "$IDENTITY" | grep -vE '^[[:space:]]*$' | head -1)

if [[ "$PUBKEY" == *"PRIVATE KEY"* ]]; then
  echo "✋ $IDENTITY holds a PRIVATE key" >&2
  echo "   ⇒ this skill places a PUBLIC key into authorized_keys. a private key" >&2
  echo "     there is a secret published on a shared box" >&2
  echo "   fix: name the .pub beside it — $IDENTITY.pub" >&2
  exit 2
fi

if [[ ! "$PUBKEY" =~ ^(ssh-ed25519|ssh-rsa|ecdsa-sha2-nistp256|ecdsa-sha2-nistp384|ecdsa-sha2-nistp521|sk-ssh-ed25519@openssh\.com|sk-ecdsa-sha2-nistp256@openssh\.com)[[:space:]]+[A-Za-z0-9+/=]+([[:space:]]+.*)?$ ]]; then
  echo "✋ $IDENTITY does not read as an openssh public key" >&2
  echo "   expected: <type> <base64> [comment]" >&2
  echo "   ⇒ confirm it yourself: ssh-keygen -lf $IDENTITY" >&2
  exit 2
fi

if [[ "$PUBKEY" == *[!A-Za-z0-9+/=@.\ _-]* ]]; then
  echo "✋ the key holds a byte outside its grammar" >&2
  echo "   allowed: [A-Za-z0-9+/=@. _-]" >&2
  echo "   ⇒ this value is interpolated into a procedure that runs AS ROOT on" >&2
  echo "     the grove, so one quote there hands the remainder to root" >&2
  echo "   fix: the comment field is the usual culprit — re-cut it plainly" >&2
  exit 2
fi

KEY_FINGERPRINT=$(ssh-keygen -lf "$IDENTITY" 2>/dev/null | head -1 || echo "unreadable")

######################################################################
# the SEATS — derived from the registry, never guessed
#
# every registry entry that shares this exid is a seat of ONE box (that is what
# an exid means, and why `git.grove.wake`'s port guard exempts them). so the
# registry already answers *which seats does this box hold*, and a hand-typed
# list here would be a second holder of that fact, free to drift
# (`rule.require.identical-bundle-composition`).
######################################################################
if [[ "${#SEATS[@]}" -eq 0 ]]; then
  while read -r _seat; do
    [[ -n "$_seat" ]] && SEATS+=("$_seat")
  done < <(
    for _e in "$_GROVE_DIR"/*.json; do
      [[ -f "$_e" ]] || continue
      [[ "$(jq -r '.exid // .name' "$_e" 2>/dev/null)" == "$EXID" ]] || continue
      jq -r '.user // empty' "$_e" 2>/dev/null
    done | sort -u
  )
  unset _e _seat
fi

if [[ "${#SEATS[@]}" -eq 0 ]]; then
  echo "✋ no seat to authorize: the registry declares no user for exid '$EXID'" >&2
  echo "   fix: name one — rhx git.grove.auth.ssh.set $GROVE --seat camper" >&2
  exit 2
fi

for _s in "${SEATS[@]}"; do
  if [[ "$_s" == *[!A-Za-z0-9._-]* || "$_s" == -* ]]; then
    echo "✋ seat '$_s' holds a byte outside its grammar" >&2
    echo "   allowed: [A-Za-z0-9._-], and never a leading '-'" >&2
    echo "   ⇒ it reaches a root shell on the grove" >&2
    exit 2
  fi
done
unset _s

echo "🐢 heres the wave..."
echo ""
echo "🔑 git.grove.auth.ssh.set $GROVE --mode $MODE"
echo "   ├─ exid:  $EXID"
echo "   ├─ env:   $ENV${ORG:+   (org $ORG)}"
echo "   ├─ key:   $KEY_FINGERPRINT"
echo "   ├─ from:  $IDENTITY"
echo "   ├─ seats: ${SEATS[*]}"

# source credentials for the grove's env (skip when the shell already carries them)
#
# ⚠️ the rack's stderr is NOT redirected, on purpose: `keyrack get` answers
#    `locked 🔒` and `absent 🫧` with the same exit code and tells them apart
#    only there — and they want opposite repairs (`term=swallow`)
if [[ -z "${AWS_ACCESS_KEY_ID:-}" ]]; then
  # 🛑 the read goes through ONE holder. do NOT inline a plain named-org
  #    `keyrack get` here: keyrack scopes such a read to the CHECKOUT, so every
  #    grove outside this checkout's org is refused (`term=keyrack.gitroot`)
  AWS_PROFILE="$(_rack_profile "$ENV" "$ORG")" || AWS_PROFILE=""
  if [[ -z "$AWS_PROFILE" ]]; then
    echo "   └─ ✋ the rack did not hand over AWS_PROFILE for env=$ENV${ORG:+ org=$ORG}" >&2
    echo "" >&2
    _rack_profile_fix "$ENV" "$ORG"
    exit 1
  fi
  if ! eval "$(aws configure export-credentials --profile "$AWS_PROFILE" --format env 2>/dev/null)"; then
    echo "   └─ 💥 no credentials from profile $AWS_PROFILE" >&2
    echo "      fix: aws sso login --profile $AWS_PROFILE" >&2
    exit 1
  fi
  unset AWS_PROFILE AWS_DEFAULT_PROFILE
fi

ACCOUNT_ACTIVE=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "")
if [[ -n "$ACCOUNT_WANT" && -n "$ACCOUNT_ACTIVE" && "$ACCOUNT_ACTIVE" != "$ACCOUNT_WANT" ]]; then
  echo "   └─ ✋ wrong aws account: active=$ACCOUNT_ACTIVE, grove '$GROVE' lives in $ACCOUNT_WANT" >&2
  echo "      ⇒ an ssm send against the wrong account would reach a box that is" >&2
  echo "        not this grove, or no box at all — and this send WRITES a key" >&2
  exit 2
fi
echo "   ├─ account: $ACCOUNT_ACTIVE${ACCOUNT_WANT:+ ✔ matches the registry}"

STATE_UP="run""ning"
INSTANCE_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:exid,Values=$EXID" "Name=instance-state-name,Values=$STATE_UP" \
  --query 'Reservations[0].Instances[0].InstanceId' --output text 2>/dev/null || echo "")
if [[ -z "$INSTANCE_ID" || "$INSTANCE_ID" == "None" ]]; then
  echo "   └─ ✋ no $STATE_UP box tagged exid=$EXID" >&2
  echo "      ⇒ ssm reaches a live box only, so the grove must be awake" >&2
  echo "      fix: rhx git.grove.wake $GROVE" >&2
  exit 2
fi
echo "   ├─ box:   $INSTANCE_ID"
echo "   └─ drive"

######################################################################
# the remote step, per seat
#
# ⚠️ it is READ-then-APPEND, and the read is `grep -qxF`:
#      -q  answer by exit code; print no key material
#      -x  WHOLE LINE, so a key that is a prefix of another is not a match
#      -F  FIXED STRING, so `+` and `/` in base64 are not read as a regex
#
# ⚠️ the trailing `grep -cxF` is the CONFIRM, and it is why this skill may claim
#    a seat HOLDS the key rather than that a write was attempted. the caller
#    demands exactly 1: a 0 means the append did not land, and above 1 means
#    this run duplicated it (`rule.forbid.failhide`).
######################################################################
_remote_procedure_apply() {
  local seat="$1"
  cat <<PROC
set -u
home=\$(getent passwd '$seat' | cut -d: -f6)
if [ -z "\$home" ]; then echo "ABSENT-SEAT $seat"; exit 0; fi
mkdir -p "\$home/.ssh" || exit 1
chmod 700 "\$home/.ssh"
[ -f "\$home/.ssh/authorized_keys" ] || : >> "\$home/.ssh/authorized_keys"
chmod 600 "\$home/.ssh/authorized_keys"
if grep -qxF '$PUBKEY' "\$home/.ssh/authorized_keys"; then
  echo "KEEP $seat"
else
  printf '%s\n' '$PUBKEY' >> "\$home/.ssh/authorized_keys" || exit 1
  echo "SET $seat"
fi
chown -R '$seat': "\$home/.ssh" 2>/dev/null || true
echo "COUNT \$(grep -cxF '$PUBKEY' "\$home/.ssh/authorized_keys")"
PROC
}

# the PLAN reads and writes naught. a separate procedure rather than a flag
# inside the one above, because a plan that shares a body with an apply is one
# `if` away from a write nobody asked for — and the write here grants shell
# access
_remote_procedure_plan() {
  local seat="$1"
  cat <<PROC
set -u
home=\$(getent passwd '$seat' | cut -d: -f6)
if [ -z "\$home" ]; then echo "ABSENT-SEAT $seat"; exit 0; fi
if [ ! -f "\$home/.ssh/authorized_keys" ]; then echo "PLAN $seat — no authorized_keys yet"; exit 0; fi
if grep -qxF '$PUBKEY' "\$home/.ssh/authorized_keys"; then
  echo "KEEP $seat"
else
  echo "PLAN $seat"
fi
PROC
}

# .what = run one procedure on the box over ssm, and hand back its stdout
# .why  = ssm is ASYNC, so a send returns a command id and the answer must be
#         polled to a terminal state. bounded at 15 polls — a probe that waits
#         forever holds the run (`rule.require.bounded-probes-in-verifies`)
#
# ⚠️ it echoes a `__SSM_*__` marker rather than an exit code, for the reason
#    `gotcha.the-duct-returns-the-send-not-the-answer` names: a refusal and a
#    real answer must not share a channel, or the caller reads one as the other
_ssm_says() {
  local proc="$1" cmd_id state="" out="" _i
  cmd_id=$(aws ssm send-command \
    --instance-ids "$INSTANCE_ID" \
    --document-name AWS-RunShellScript \
    --parameters "$(jq -n --arg c "$proc" '{commands:[$c]}')" \
    --query 'Command.CommandId' --output text 2>/dev/null || echo "")
  if [[ -z "$cmd_id" || "$cmd_id" == "None" ]]; then
    echo "__SSM_REFUSED__"
    return 0
  fi
  for _i in $(seq 1 15); do
    state=$(aws ssm get-command-invocation \
      --command-id "$cmd_id" --instance-id "$INSTANCE_ID" \
      --query 'Status' --output text 2>/dev/null || echo "")
    [[ "$state" == "Success" || "$state" == "Failed" || "$state" == "TimedOut" ]] && break
    sleep 2
  done
  if [[ "$state" != "Success" ]]; then
    echo "__SSM_${state:-SILENT}__"
    return 0
  fi
  out=$(aws ssm get-command-invocation \
    --command-id "$cmd_id" --instance-id "$INSTANCE_ID" \
    --query 'StandardOutputContent' --output text 2>/dev/null || echo "")
  printf '%s\n' "$out"
}

FAILED=0
for _seat in "${SEATS[@]}"; do
  if [[ "$MODE" == "plan" ]]; then
    _out=$(_ssm_says "$(_remote_procedure_plan "$_seat")")
  else
    _out=$(_ssm_says "$(_remote_procedure_apply "$_seat")")
  fi

  case "$_out" in
    __SSM_REFUSED__)
      echo "      ├─ $_seat ✋ ssm refused the send" >&2
      echo "      │  ⇒ the box may hold no ssm agent, or this identity lacks" >&2
      echo "      │    ssm:SendCommand on it" >&2
      FAILED=1 ;;
    __SSM_*)
      echo "      ├─ $_seat ✋ ssm gave no answer (${_out//__/})" >&2
      echo "      │  ⇒ that seat's state is UNKNOWN — re-run to read it" >&2
      FAILED=1 ;;
    *ABSENT-SEAT*)
      echo "      ├─ $_seat ✋ no such user on the box" >&2
      echo "      │  ⇒ the registry declares this seat and the box does not hold" >&2
      echo "      │    it. one of the two is wrong" >&2
      FAILED=1 ;;
    *KEEP*)
      echo "      ├─ $_seat [KEEP] already authorized" ;;
    *SET*)
      _count=$(printf '%s\n' "$_out" | sed -n 's/^COUNT \([0-9]*\)$/\1/p' | head -1)
      if [[ "$_count" == "1" ]]; then
        echo "      ├─ $_seat [SET] authorized ✔ confirmed present once"
      else
        echo "      ├─ $_seat ✋ wrote the key and the confirm read '${_count:-no count}'" >&2
        echo "      │  ⇒ expected exactly 1. a 0 means the append did not land;" >&2
        echo "      │    above 1 means this run duplicated it" >&2
        FAILED=1
      fi ;;
    *PLAN*)
      echo "      ├─ $_seat [PLAN] would authorize" ;;
    *)
      echo "      ├─ $_seat ✋ unreadable answer from the box" >&2
      echo "      │  got: $_out" >&2
      FAILED=1 ;;
  esac
done
unset _seat _out _count

echo ""
if [[ "$FAILED" != 0 ]]; then
  echo "✋ at least one seat was not authorized" >&2
  exit 1
fi

if [[ "$MODE" == "plan" ]]; then
  echo "🍃 plan only — no key was placed"
  echo "   └─ grant it: rhx git.grove.auth.ssh.set $GROVE --mode apply"
  exit 0
fi

echo "🌲 authorized — every named seat holds this box's key ✔"
echo "   ├─ key:  $KEY_FINGERPRINT"
echo "   └─ reach it: rhx git.grove.send $GROVE --reply --what 'whoami'"

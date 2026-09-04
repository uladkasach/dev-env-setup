#!/usr/bin/env bash
######################################################################
# git.grove.trust.gen — findsert our trust of a grove into known_hosts
#
# .what = scan the grove's tunnel endpoint for the ssh host keys it offers,
#         verify each fingerprint against what the box reported at boot (its
#         ec2 console output), and record our TRUST of them into
#         ~/.ssh/known_hosts. a re-run on an already-trusted key is a no-op;
#         a CHANGED key fails loud.
#
# .note = the object created here is the TRUST, never the key. the grove
#         authors its own host key at boot; this reads that key and writes
#         only our local record that we accept it. `gen` is findsert, so a
#         name like `hostkey.gen` would read as "find-or-create a host key
#         for the grove" — an act that would forge the very identity this
#         exists to verify. see domain.terms/term=trust._.choice.reason.md
#
# .why  = ductwork runs ssh detached, with no tty — so ssh cannot ask
#         "continue (yes/no)?". it falls back to the $SSH_ASKPASS gui
#         helper, finds none, and dies with "Host key verification failed".
#         the cure is the trust, not the prompt: install askpass and you
#         merely move the same unanswered question into a dialog box.
#
#         the verify matters more here than usual. a grove is reached at
#         localhost:<port> over an ssm tunnel, so the known_hosts entry is
#         keyed on a LOCAL port — an address that names your own machine,
#         not the box. blind trust-on-first-use would bind that entry to
#         whatever answers that port. so the fingerprint is checked against
#         the box's own boot record before it is written.
#
# usage:
#   rhx git.grove.trust.gen --grove grove-1
#   rhx git.grove.trust.gen --grove grove-1 --mode apply
#   rhx git.grove.trust.gen --grove grove-1 --mode apply --trust tofu
#   rhx git.grove.trust.gen --grove grove-1 --mode apply --on-changed replace
#   rhx git.grove.trust.gen help
#
# options:
#   --grove  the grove name from the registry; default grove-1
#   --env    aws env whose credentials read the console output; default camp
#   --mode   plan (default, preview) or apply (write known_hosts)
#   --trust  verified (default) — write only when the boot record confirms it
#            tofu     — write on scan alone, for an ABSENT key only. 🛑 it is
#                       REFUSED beside --on-changed replace: tofu is trust on
#                       FIRST use, and a changed key means a prior one already
#                       disagrees, so there is no first use to trust on
#   --timeout  seconds to await the host-key scan; default 30 (an ssm tunnel
#              relays lazily, so ssh-keyscan's own 5s default is far too short)
#   --on-changed  refuse (default) — halt, and name the two commands that settle it
#                 replace — drop the stale entry for this endpoint, then trust anew
#
# ⚠️ .when to reach for --on-changed replace
#     a grove is reached at localhost:<port>, so a CHANGED key is ambiguous by
#     construction: the port was re-used by a NEW box (benign — the old box is
#     gone and its key with it), or another process took the port (a security
#     event). `refuse` is the default because the skill cannot tell those apart
#     on its own. it does not have to guess: --trust verified checks the scanned
#     key against THIS box's boot record first, so a `replace` that reaches the
#     write has already proven the key belongs to the box you asked for.
#
# guarantee:
#   - a key already trusted and unchanged = no-op (findsert)
#   - a key already trusted but CHANGED:
#     - --on-changed refuse (default) = exit 2, never overwritten
#     - --on-changed replace = the endpoint's entry is dropped and re-trusted,
#       and ONLY after the fingerprint check the --trust mode demands has passed
#   - plan mode by default; no write without --mode apply
#   - exit 0 = trusted, exit 1 = malfunction, exit 2 = constraint
######################################################################
set -uo pipefail

# ⚠️ read the whole ARG VECTOR, never `$1` — rhachet injects `--skill <slug>` ahead
#    of the caller's args, so a `$1` test never fires (measured 2026-08-30; ten
#    skills in this dir carried it, and each read `help` as its SUBJECT instead)
if [[ " $* " == *" help "* || " $* " == *" --help "* || " $* " == *" -h "* ]]; then
  echo "git.grove.trust.gen"
  echo ""
  echo "usage:"
  echo "  rhx git.grove.trust.gen --grove <name> [--env <env>] [--mode plan|apply] [--trust verified|tofu] [--on-changed refuse|replace]"
  echo ""
  echo "options:"
  echo "  --grove  grove name from the registry; default grove-1"
  echo "  --env    aws env for the console-output read; default camp"
  echo "  --mode   plan (default) or apply"
  echo "  --trust  verified (default) or tofu (scan alone, ABSENT key only)"
  echo "  --timeout      seconds to await the key scan; default 30"
  echo "  --on-changed   refuse (default) — halt on a changed key"
  echo "                 replace — drop the stale entry, then trust anew"
  echo ""
  echo "🛑 --on-changed replace --trust tofu is refused. tofu is trust on FIRST"
  echo "   use; a changed key means a prior one disagrees, so there is no first"
  echo "   use — and the boot record is the only reader that tells a rebuilt box"
  echo "   from a hijacked port"
  echo ""
  echo "a changed key is ambiguous at localhost:<port> — a new box on a re-used"
  echo "port, or another process on it. --trust verified checks the scanned key"
  echo "against this box's boot record, so a replace that writes is a proven one."
  exit 0
fi

GROVE="grove-1"
ENV="camp"
MODE="plan"
TRUST="verified"
TIMEOUT="30"
ON_CHANGED="refuse"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --grove)      GROVE="$2"; shift 2 ;;
    --env)        ENV="$2"; shift 2 ;;
    --mode)       MODE="$2"; shift 2 ;;
    --trust)      TRUST="$2"; shift 2 ;;
    --timeout)    TIMEOUT="$2"; shift 2 ;;
    --on-changed) ON_CHANGED="$2"; shift 2 ;;
    --skill|--repo|--role) shift 2 ;;
    --) shift ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

[[ "$MODE" == "plan" || "$MODE" == "apply" ]] || { echo "invalid --mode: $MODE (plan|apply)" >&2; exit 2; }
[[ "$TRUST" == "verified" || "$TRUST" == "tofu" ]] || { echo "invalid --trust: $TRUST (verified|tofu)" >&2; exit 2; }
[[ "$ON_CHANGED" == "refuse" || "$ON_CHANGED" == "replace" ]] || { echo "invalid --on-changed: $ON_CHANGED (refuse|replace)" >&2; exit 2; }

####################################################################
# 🛑 `--on-changed replace --trust tofu` is REFUSED — the two contradict
#
# .why it is a contradiction and not merely a risk
#      TOFU is trust on FIRST use. a CHANGED key means a prior key is on
#      record and disagrees with the one now offered — so there is no first
#      use to trust on. the pair asks to trust-on-first-use a thing that is
#      demonstrably not first.
#
# 🛑 .why it is the ONE state with no evidence either way
#      a changed key at a LOCAL port has exactly two causes, and the boot
#      record is what tells them apart:
#
#        | the cause | the boot record |
#        |---|---|
#        | the port was reused by a NEW box | attests the scanned key |
#        | another process now holds the port | does NOT attest it |
#
#      so `--trust tofu` here does not lower the bar — it removes the only
#      reader that can answer the question, at the one moment the question
#      is live. a replace then drops the prior key and writes the new one,
#      on no evidence at all.
#
# ⚠️ .why the two usual excuses do NOT apply
#      a fix-text may offer this pair for "a resumed box, or one booted long
#      ago" — the two states whose console output holds no boot record. but a
#      resumed box KEEPS its host keys, and so does a long-booted one. so
#      neither produces a changed key by itself, and the pair's stated
#      trigger describes a state it cannot arise from
#      (`rule.require.exemptions-name-their-trigger`).
#
# .what is NOT refused, and why each stays
#      - `--on-changed replace` with the default `--trust verified` — the
#        paved path, and the common case. the boot record decides. an
#        over-strict halt here already cost a provision on 2026-08-12 (see
#        the block above `if [[ -n "$CHANGED" ...`), so this narrows to the
#        tofu pair alone and leaves that path untouched
#      - `--trust tofu` on an ABSENT key — literally correct: no prior key
#        is on record, so it IS the first use
####################################################################
if [[ "$ON_CHANGED" == "replace" && "$TRUST" == "tofu" ]]; then
  echo "   ✋ --on-changed replace --trust tofu is refused" >&2
  echo "" >&2
  echo "  why: tofu means trust on FIRST use. a CHANGED key means a prior key" >&2
  echo "       is on record and disagrees — so there is no first use. together" >&2
  echo "       they ask to drop a known key and write an unattested one on the" >&2
  echo "       scan alone, at the one moment a scan settles no question" >&2
  echo "  fix: let the box's own boot record decide, which is the default —" >&2
  echo "    rhx git.grove.trust.gen --grove $GROVE --mode apply --on-changed replace" >&2
  exit 2
fi

# look up the grove's ssh alias from the registry (infra may own the alias)
source ~/.bash_aliases 2>/dev/null || true
####################################################################
# 🛑 the gate reads EVERY function this skill borrows, never one of them
#
# ⚠️ `git.grove.send:83-116` holds the identical gate, for the identical reason.
#
# .what an installed copy that holds ONE of them reaches
#
#   | absent                | what a human sees                           |
#   | _git_grove_ssh_alias  | `✋ grove '<g>' not in the registry`         |
#   | _git_grove_get        | ✋ no line at all — see below                |
#
# 🛑 the second row is the one that matters. `:238` reads
#   `if REG_JSON="$(_git_grove_get …)"`, so an absent function makes that
#   test FALSE, leaves `REG_HOST`/`REG_PORT` empty, and the alias-vs-registry
#   DRIFT guard at `:242` silently does not run. its own comment names ONE
#   reason for the skip — a grove whose Host block infra owns — while the
#   code reaches three. a guard whose absence cannot be told from its
#   exemption is `rule.forbid.failhide`.
#
# ⚠️ the defect is the SUBSET, not the name. a gate that proves one member of
#   a set and lets the rest through is `gotcha.a-check-that-cries-wolf-gets-silenced`
#   q11 — a count is only as big as its reader's reach.
#
# 🛑 .AND ITS MIRROR: a SUPERSET is a false ✋, which is the worse half
#
# 📜 .measured 2026-09-02
#
#   a set that includes `git_alias_grove` — which this file NEVER CALLS — halts
#   on a box where the two real borrows are present and that one is not: a loud
#   refusal, with a named fix, aimed at an installation that works.
#
#   ⚠️ a false ✋ decays into a false ✔: the next human learns this gate lies
#     and stops reading it (`gotcha.a-check-that-cries-wolf-gets-silenced`).
#
# 🛑 .and a WHOLE-FILE derivation produces exactly that wrong set
#
#     `rg -o 'git_alias_[a-z_]+|_git_grove_[a-z_.]+' <this file> | sort -u`
#   scans the WHOLE file — so it is answered by this comment block, and
#   by the declaration on the next line. it cannot help but confirm whatever
#   the list already says. that is m.10: a correction that quotes the dead
#   pointer it corrects, and so re-creates it.
#
# ⇒ the re-derivation must reach CALL SITES only — code, with the declaration
#   and every comment removed:
#     sed 's/#.*$//' <this file> | grep -v GROVE_TRUST_BORROWS \
#       | grep -oE 'git_alias_[a-z_]+|_git_grove_[a-z_.]+' | sort -u
####################################################################
GROVE_TRUST_BORROWS=(_git_grove_ssh_alias _git_grove_get)
for _fn in "${GROVE_TRUST_BORROWS[@]}"; do
  command -v "$_fn" &>/dev/null && continue
  echo "✋ $_fn absent — the installed aliases are stale" >&2
  echo "   ├─ this skill borrows ${GROVE_TRUST_BORROWS[*]} from ~/.bash_aliases" >&2
  echo "   └─ fix: install from a copy that HOLDS it —" >&2
  echo "        rhx grove.provision --what 2.7.aliases --from tree --mode apply" >&2
  #
  # ⚠️ `--from tree`, NOT `--from main`. this gate fires when the installed
  #    copy is BEHIND, so the fix must name a copy that is AHEAD — the same
  #    reason `git.grove.send:124-129` gives, measured on the same day
  exit 2
done
ALIAS="$(_git_grove_ssh_alias "$GROVE")" || {
  echo "✋ grove '$GROVE' not in the registry — run: rhx git.grove.list" >&2
  exit 2
}

# read the endpoint the alias actually dials, so the known_hosts entry matches
# what ssh will look up (ssh keys known_hosts on HostName + Port, not the alias)
SSH_CONFIG_EFFECTIVE=$(ssh -G "$ALIAS" 2>/dev/null)
HOSTNAME_SSH=$(echo "$SSH_CONFIG_EFFECTIVE" | awk '/^hostname /{print $2}')
PORT_SSH=$(echo "$SSH_CONFIG_EFFECTIVE" | awk '/^port /{print $2}')
if [[ -z "$HOSTNAME_SSH" || -z "$PORT_SSH" ]]; then
  echo "✋ cannot read the ssh endpoint for alias '$ALIAS'" >&2
  echo "   fix: wake the grove so its alias is written —" >&2
  echo "     rhx git.grove.wake --box $GROVE   (from the infrastructure repo)" >&2
  exit 2
fi

echo "🐢 heres the wave..."
echo ""
echo "🔑 git.grove.trust.gen --grove $GROVE --mode $MODE --trust $TRUST"
echo "   ├─ alias:    $ALIAS"
echo "   ├─ endpoint: $HOSTNAME_SSH:$PORT_SSH"

####################################################################
# ⚠️ has the ssh alias DRIFTED from the registry?
#
# .why this check is here at all
#      the registry is the DECLARATION; the ssh Host block is a COPY of it.
#      two homes for one fact, so the copy is free to go stale (`term=drift`).
#      `ssh -G` is read above rather than the registry ON PURPOSE — a
#      known_hosts entry must be keyed on the endpoint ssh will actually dial,
#      and that is the alias's answer, not the registry's. so this cannot be
#      cured by a read of the registry instead; it is cured by a read of BOTH,
#      and a halt when they disagree.
#
# .measured 2026-08-12, on a two-seat box whose second seat was never woken:
#
#      registry  camper@localhost:36902     ← the live tunnel
#      alias     Port 36901                 ← written when 36901 was the port
#      trust.gen 💥 no process listens on localhost:36901
#                "why: the ssm tunnel is closed"
#
#      the tunnel was NOT closed. it was up, relaying, and serving the other
#      seat on 36902 in the same minute. so the verdict was true (no process
#      listens on 36901) and the CAUSE it named was wrong, which sends a
#      reader to re-open a tunnel that never shut
#      (`gotcha.a-check-that-cries-wolf-gets-silenced`).
#
# ⚠️ .why it is skipped when the registry declares no endpoint
#      a grove registered with `--alias` has its Host block owned by infra, so
#      the registry holds no host/port to compare and there is no drift to find
#
# 🛑 .THAT IS ONE CAUSE OF THREE, so the skip must NAME which
#      as one `if` with a `2>/dev/null`, the read below drops an absent
#      `_git_grove_get`, an absent `jq`, and a malformed entry ALL into the
#      same silent skip as the documented exemption. a guard whose ABSENCE
#      cannot be told from its EXEMPTION is not a guard
#      (`rule.forbid.failhide`) — and this one exists because a wrong CAUSE
#      once sent a human to re-open a tunnel that was up the whole time.
#
#      ⇒ so the skip names which of the three it is, and only the
#        `--alias` case is quiet.
####################################################################
REG_HOST=""; REG_PORT=""; REG_UNREAD=""
if ! command -v jq &>/dev/null; then
  REG_UNREAD="jq is absent, so the registry entry cannot be parsed"
elif ! REG_JSON="$(_git_grove_get "$GROVE" 2>/dev/null)"; then
  # ⚠️ anomalous by construction: `_git_grove_ssh_alias` above already found
  #    this grove in the registry, so a get that fails here disagrees with a
  #    read that just succeeded
  REG_UNREAD="the registry entry for '$GROVE' could not be read"
else
  REG_HOST="$(echo "$REG_JSON" | jq -r '.host // empty' 2>/dev/null)"
  REG_PORT="$(echo "$REG_JSON" | jq -r '.port // empty' 2>/dev/null)"
fi
if [[ -n "$REG_UNREAD" ]]; then
  echo "   ├─ 🌙 drift unchecked — $REG_UNREAD" >&2
  echo "   │     ⇒ this is NOT the '--alias' exemption. the alias and the" >&2
  echo "   │       registry may disagree and this run cannot tell you" >&2
  echo "   │  fix: rhx git.grove.list   # then compare against 'ssh -G $ALIAS'" >&2
fi
if [[ -n "$REG_HOST" && -n "$REG_PORT" ]] \
   && [[ "$REG_HOST" != "$HOSTNAME_SSH" || "$REG_PORT" != "$PORT_SSH" ]]; then
  echo "   └─ ✋ the ssh alias has DRIFTED from the registry" >&2
  echo "" >&2
  echo "  registry declares: $REG_HOST:$REG_PORT" >&2
  echo "  alias '$ALIAS' dials: $HOSTNAME_SSH:$PORT_SSH" >&2
  echo "" >&2
  echo "  why: the Host block is a COPY of the registry, and this one is stale." >&2
  echo "       so a trust written now would be keyed on an endpoint no command" >&2
  echo "       uses — and every ssh through the alias reaches the wrong port" >&2
  echo "  fix: wake the seat; wake rewrites the WHOLE block from the registry —" >&2
  echo "    rhx git.grove.wake $GROVE" >&2
  exit 2
fi

# is the local tunnel port even bound? read /proc/net/tcp rather than guess, so a
# closed tunnel is told apart from a bound-but-mute one — two causes, two fixes
PORT_HEX=$(printf '%04X' "$PORT_SSH")
LISTENS_V4=$(awk -v p=":$PORT_HEX" '$2 ~ p && $4 == "0A"' /proc/net/tcp 2>/dev/null)
LISTENS_V6=$(awk -v p=":$PORT_HEX" '$2 ~ p && $4 == "0A"' /proc/net/tcp6 2>/dev/null)
LISTENS="$LISTENS_V4$LISTENS_V6"
if [[ -z "$LISTENS" ]]; then
  echo "   └─ 💥 no process listens on $HOSTNAME_SSH:$PORT_SSH" >&2
  echo "" >&2
  echo "  why: the ssm tunnel is closed — it does not survive a reboot, and it" >&2
  echo "       exits when its parent shell is killed" >&2
  echo "  fix: wake the grove to reopen it (from the infrastructure repo) —" >&2
  echo "    rhx git.grove.wake --box $GROVE" >&2
  exit 1
fi
# scan the address family that is ACTUALLY bound, not the name ssh was given.
#
# `localhost` resolves to BOTH ::1 and 127.0.0.1, while an ssm tunnel binds only
# one of them (IPv4, in practice). that split is a trap unique to ssh-keyscan:
# it sets its socket non-blocked, so connect() returns EINPROGRESS on the FIRST
# address and it never tries the rest — it just polls a dead ::1 until timeout.
# plain `ssh` connects synchronously, so it DOES fall back to IPv4 and works
# fine, which is why a human's `ssh grove-1` succeeds where a naive scan hangs.
#
# so: scan the bound family explicitly. the entry is still WRITTEN under the name
# ssh will look up (see the rewrite below), because ssh keys known_hosts on the
# HostName string, never on whatever address answered.
HOST_SCAN="$HOSTNAME_SSH"
if [[ -n "$LISTENS_V4" && -z "$LISTENS_V6" ]]; then
  HOST_SCAN="127.0.0.1"
  echo "   ├─ tunnel:   bound on ipv4 only (scan via $HOST_SCAN)"
elif [[ -z "$LISTENS_V4" && -n "$LISTENS_V6" ]]; then
  HOST_SCAN="::1"
  echo "   ├─ tunnel:   bound on ipv6 only (scan via $HOST_SCAN)"
else
  echo "   ├─ tunnel:   bound (listens on port $PORT_SSH)"
fi

# scan the live endpoint for its offered host keys.
# an ssm tunnel relays lazily — the local port binds at once, but the first
# connection must still reach ssm, so a scan needs far longer than ssh-keyscan's
# 5s default. hence --timeout, defaulted generously.
SCANNED=$(ssh-keyscan -T "$TIMEOUT" -p "$PORT_SSH" "$HOST_SCAN" 2>/dev/null | grep -v '^#')
if [[ -z "$SCANNED" ]]; then
  echo "   └─ 💥 the tunnel is bound, but offered no host keys in ${TIMEOUT}s" >&2
  echo "" >&2
  echo "  why: the local port answers, so the tunnel process is alive — but the" >&2
  echo "       relay past it did not complete. either the box is asleep behind a" >&2
  echo "       stale tunnel, or the ssm session it rides has expired" >&2
  echo "  fix: allow the relay more time —" >&2
  echo "    rhx git.grove.trust.gen --grove $GROVE --timeout 60" >&2
  echo "  or re-wake the grove, which rebuilds the tunnel (from infrastructure) —" >&2
  echo "    rhx git.grove.wake --box $GROVE" >&2
  exit 1
fi
echo "   ├─ scanned:  $(echo "$SCANNED" | wc -l) key(s) offered"

# ssh-keyscan labels each line with the host IT dialed, but ssh looks known_hosts
# up by the HostName in its config. when those differ (we scanned 127.0.0.1 while
# ssh says `localhost`), an unrewritten entry would be trusted for an address ssh
# never asks about — silently useless. so relabel to the name ssh will use.
if [[ "$HOST_SCAN" != "$HOSTNAME_SSH" ]]; then
  SCANNED=$(echo "$SCANNED" | awk -v want="[$HOSTNAME_SSH]:$PORT_SSH" '{$1=want; print}')
  echo "   ├─ labeled:  [$HOSTNAME_SSH]:$PORT_SSH (the name ssh looks up)"
fi

# compare against what is already trusted — a CHANGED key is a security event,
# never a silent overwrite (findsert: find extant, or insert; never clobber)
KNOWN_HOSTS="$HOME/.ssh/known_hosts"
touch "$KNOWN_HOSTS"
TRUSTED_ALREADY=""
ABSENT=""
CHANGED=""
while read -r LINE; do
  [[ -z "$LINE" ]] && continue
  KEYTYPE=$(echo "$LINE" | awk '{print $2}')
  KEYDATA=$(echo "$LINE" | awk '{print $3}')
  EXTANT=$(ssh-keygen -F "[$HOSTNAME_SSH]:$PORT_SSH" -f "$KNOWN_HOSTS" 2>/dev/null | grep " $KEYTYPE " || true)
  if [[ -z "$EXTANT" ]]; then
    ABSENT+="$KEYTYPE "
  # ⚠️ `grep -F … >/dev/null`, never `grep -qF`. a MATCH here means the key is
  #    already trusted — and a match is exactly what makes `-q` exit early, take
  #    the producer down with a SIGPIPE, and hand pipefail its 141
  #    (`gotcha.pipefail-grep-q`). the false answer would land in the `else`,
  #    which reports the host key CHANGED: a security alarm raised BECAUSE the
  #    key matched, which is the loudest possible way to cry wolf
  elif echo "$EXTANT" | grep -F "$KEYDATA" >/dev/null; then
    TRUSTED_ALREADY+="$KEYTYPE "
  else
    CHANGED+="$KEYTYPE "
  fi
done <<< "$SCANNED"

####################################################################
# ⚠️ a CHANGED key is NOT decided here — it is decided by the boot record
#
# .why this refusal moved
#      a grove is reached at localhost:<port>, so a known_hosts entry is keyed
#      on a LOCAL address. that makes a changed key ambiguous in a way it never
#      is for a real host:
#
#        | the cause | what it means |
#        |---|---|
#        | the tunnel PORT was reused by a NEW box | benign, and the common case |
#        | another process now holds the port | a security event |
#
#      an `exit 2` on any change, with a raw `ssh-keygen -R` for a human, is
#      wrong twice over:
#
#      1. it bails BEFORE the boot-record read — before it holds the one piece
#         of evidence that separates the two rows above. the skill refuses a
#         question it is about to be able to answer.
#      2. the fix it names is a raw CLI command, so a robot caller has no paved
#         path and improvises one (`rule.require.wrap-cli-in-skills`). measured
#         2026-08-12: a fresh grove on a reused port halted the whole provision
#         here, and the caller reached straight for `ssh-keygen -R` — the exact
#         improvisation this repo forbids, at the seam that offered no
#         alternative.
#
#      ⇒ so the change carries FORWARD to the verification below. where the
#      CURRENT box's boot record confirms the scanned key, the stale entry is
#      provably from a dead box and `--on-changed replace` may drop it. a
#      VERIFIED replace, not trust-on-faith — the boot record is the whole
#      reason this skill reads console output at all.
####################################################################
if [[ -n "$CHANGED" && "$ON_CHANGED" == "refuse" ]]; then
  echo "   └─ ✋ host key CHANGED for [$HOSTNAME_SSH]:$PORT_SSH ($CHANGED)" >&2
  echo "" >&2
  echo "  why: this port previously answered with a different key. either the" >&2
  echo "       grove was rebuilt (or the port was reused by a NEW box), or" >&2
  echo "       another process now holds the local port" >&2
  echo "  fix: if the box is new, let this skill verify and replace the stale" >&2
  echo "       entry — it writes only when the box's OWN boot record confirms" >&2
  echo "       the key it just scanned —" >&2
  echo "    rhx git.grove.trust.gen --grove $GROVE --mode apply --on-changed replace" >&2
  echo "  and if THAT refuses, the boot record did not attest the scanned key —" >&2
  echo "  which is the second row above, so read what holds the port before you" >&2
  echo "  trust any key here —" >&2
  echo "    ss -tlnp | grep ':$PORT_SSH'" >&2
  exit 2
fi

[[ -n "$CHANGED" ]] && echo "   ├─ changed:  $CHANGED (a replace is asked for; the boot record decides)"

# every scanned key is already trusted, and none changed → findsert is a no-op
if [[ -z "$ABSENT" && -z "$CHANGED" ]]; then
  echo "   └─ 🌊 already trusted ($TRUSTED_ALREADY) — no change"
  exit 0
fi

# read the box's boot record for the fingerprints it printed at first boot;
# this is what binds the local-port entry back to the real machine
FINGERPRINTS_BOOT=""
ATTEST=""
if [[ "$TRUST" == "verified" ]]; then
  if [[ -z "${AWS_ACCESS_KEY_ID:-}" ]]; then
    # ⚠️ the rack's stderr is NOT redirected — see git.grove.wake.sh for the
    #    measurement. this branch is TOLERANT by design (an absent profile
    #    just means we fall back to whatever creds the shell carries), so
    #    it does not halt — but it must not go QUIET either. with the old
    #    `2>/dev/null` a locked rack produced no word at all here, and the
    #    failure surfaced later as an opaque ec2 api error whose text names
    #    no credential (`term=swallow`, `rule.forbid.failhide`).
    AWS_PROFILE=$(rhx keyrack get --owner ehmpath --env "$ENV" --key AWS_PROFILE --value) || AWS_PROFILE=""
    if [[ -n "$AWS_PROFILE" ]]; then
      eval "$(aws configure export-credentials --profile "$AWS_PROFILE" --format env 2>/dev/null)" || true
      unset AWS_PROFILE AWS_DEFAULT_PROFILE
    else
      echo "   ├─ 🌙 no AWS_PROFILE from the rack — the reason is above." >&2
      echo "   │     the boot-record read below falls back to ambient creds," >&2
      echo "   │     so an ec2 error there is likely THIS, one step later." >&2
    fi
  fi
  # the aws api's own state enum is its word, not ours
  STATE_UP="run""ning"
  INSTANCE_ID=$(aws ec2 describe-instances \
    --filters "Name=tag:exid,Values=$GROVE" "Name=instance-state-name,Values=$STATE_UP" \
    --query 'Reservations[0].Instances[0].InstanceId' --output text 2>/dev/null || echo "")
  if [[ -z "$INSTANCE_ID" || "$INSTANCE_ID" == "None" ]]; then
    INSTANCE_ID=$(aws ec2 describe-instances \
      --filters "Name=tag:Name,Values=$GROVE" "Name=instance-state-name,Values=$STATE_UP" \
      --query 'Reservations[0].Instances[0].InstanceId' --output text 2>/dev/null || echo "")
  fi
  if [[ -n "$INSTANCE_ID" && "$INSTANCE_ID" != "None" ]]; then
    echo "   ├─ box:      $INSTANCE_ID"
    FINGERPRINTS_BOOT=$(aws ec2 get-console-output --instance-id "$INSTANCE_ID" --output text 2>/dev/null \
      | grep -oE 'SHA256:[A-Za-z0-9+/=]+' | sort -u || true)

    # ASK THE BOX ITSELF, over ssm. this is the stronger attestation, and the one
    # that works for the normal case: the console record holds only what a box
    # printed at FIRST boot, so a hibernate-resumed or long-lived box reports
    # none — which would strand every verify on the tofu escape hatch.
    #
    # ssm is a separate, aws-authenticated channel to the box, wholly independent
    # of the ssh tunnel under test. so if the key ssm reports matches the key the
    # tunnel offered, the tunnel demonstrably reaches THAT box — which is exactly
    # the claim a known_hosts entry on a local port cannot otherwise support.
    if [[ -z "$FINGERPRINTS_BOOT" ]]; then
      CMD_ID=$(aws ssm send-command \
        --instance-ids "$INSTANCE_ID" \
        --document-name AWS-RunShellScript \
        --parameters 'commands=["for k in /etc/ssh/ssh_host_*_key.pub; do ssh-keygen -lf \"$k\"; done"]' \
        --query 'Command.CommandId' --output text 2>/dev/null || echo "")
      if [[ -n "$CMD_ID" && "$CMD_ID" != "None" ]]; then
        # await the invocation; ssm is async, so poll its terminal state
        for _ in $(seq 1 15); do
          CMD_STATE=$(aws ssm get-command-invocation \
            --command-id "$CMD_ID" --instance-id "$INSTANCE_ID" \
            --query 'Status' --output text 2>/dev/null || echo "")
          [[ "$CMD_STATE" == "Success" || "$CMD_STATE" == "Failed" || "$CMD_STATE" == "TimedOut" ]] && break
          sleep 2
        done
        if [[ "$CMD_STATE" == "Success" ]]; then
          FINGERPRINTS_BOOT=$(aws ssm get-command-invocation \
            --command-id "$CMD_ID" --instance-id "$INSTANCE_ID" \
            --query 'StandardOutputContent' --output text 2>/dev/null \
            | grep -oE 'SHA256:[A-Za-z0-9+/=]+' | sort -u || true)
          [[ -n "$FINGERPRINTS_BOOT" ]] && ATTEST="ssm (the box's own /etc/ssh keys)"
        fi
      fi
    else
      ATTEST="ec2 console output (first boot)"
    fi
  fi
fi

# 🛑 the scan is fingerprinted, and the READ ITSELF is then proven complete
#
# .why  `ssh-keygen -lf -` is a SEPARATE PROGRAM at the end of a pipeline, with
#       its own ways to decline: one unparseable line among several, a key type
#       this build will not fingerprint, an openssh that will not take `-`. it
#       read `2>/dev/null` and the caller kept only the pipeline's stdout, so
#       every one of those failures produced the SAME value as a healthy read of
#       zero keys: the empty string.
#
#       ⇒ and an empty left set is exactly what the `⊆` test below cannot see.
#         so this counts what went IN and what came OUT, and treats a mismatch
#         as a check that did not read what it is about to write.
SCAN_LINES=$(printf '%s\n' "$SCANNED" | grep -cE '^[^#[:space:]]' || true)
FP_RAW="$(printf '%s\n' "$SCANNED" | ssh-keygen -lf - 2>&1)" || FP_RAW=""
FP_LINES=$(printf '%s\n' "$FP_RAW" | grep -cE '^[0-9]+ ' || true)
FINGERPRINTS_SCAN=$(printf '%s\n' "$FP_RAW" | awk '/^[0-9]+ /{print $2}' | sort -u)
FP_UNIQ=$(printf '%s\n' "$FINGERPRINTS_SCAN" | grep -c . || true)

####################################################################
# 🛑 EVERY scanned key must be attested — never merely one of them
#
# .the defect this replaces, measured 2026-08-31 by a redteam of this file
#      the verdict was an OR across the scanned set: one match set
#      `VERIFIED=true`, and the write below appends `$SCANNED` — ALL of it.
#      so a caller who offered two keys needed only ONE to be real.
#
#      that is reachable, and cheaply: a host's public keys ARE public. anyone
#      who takes the local port can offer the box's genuine ed25519 key beside
#      an rsa key of their own. the ed25519 satisfies the OR, both lines land in
#      known_hosts, and ssh may then negotiate rsa and match the attacker's —
#      a trust anchor installed BY the check that exists to guard it.
#
# .the property the anchor actually needs
#      not "some key here is real" but **no key here is unattested**:
#
#        FINGERPRINTS_SCAN ⊆ FINGERPRINTS_BOOT
#
#      inclusion, not equality in both directions — the boot record may hold
#      MORE keys than the scan offered, since `ssh-keyscan`'s default type list
#      is narrower than `/etc/ssh`. an extra ATTESTED key is no hazard; an extra
#      SCANNED key is the whole hazard.
#
# ⚠️ this is the same shape as `web_verify_gpg_fingerprints`
#      (`src/grove.web.sh:588`), which refuses a keyfile that HOLDS the
#      expected fingerprint beside another. one lesson, two anchors — and this
#      one had it backwards for as long as it existed.
#
# ⚠️ `grep -F … >/dev/null`. `-q` would exit on the match that PROVES the key,
#    SIGPIPE the echo, and hand pipefail its 141 — so a fingerprint the boot
#    record attests would read as unattested (`gotcha.pipefail-grep-q`)
####################################################################
# 🛑 .INCLUSION IS FAIL-OPEN ON AN EMPTY LEFT SET — and this is what that costs
#
#    ∅ ⊆ every set. so a `⊆` test whose left side came back empty reports TRUE,
#    and reports it about zero keys while the write below appends ALL of them.
#
#    📜 measured 2026-08-31, one round after `⊆` replaced an OR here. the
#       direction was right and the DEGENERATE CASE was new: the code seeded
#       `VERIFIED="true"` and narrowed it inside a loop, so a
#       `FINGERPRINTS_SCAN` of "" ran zero iterations and the optimistic seed
#       survived. every scanned key — none of them checked — then landed in
#       `~/.ssh/known_hosts`, which is what decides whether the ssh under every
#       duct, push, pull, and `_ask_at` reaches the grove at all.
#
#    ⚠️ the OTHER anchor in this repo gets it right and says why, at
#       `src/grove.web.sh:603` — *"with no gpg the read yields an empty set, an
#       empty set never equals a non-empty pin, and the function fails."* set
#       EQUALITY is fail-closed on an empty read; set INCLUSION is fail-open.
#       the ⚠️ above claims the two anchors share one lesson. they did not, and
#       the gap was invisible because each spells a relation that is correct.
#
#    ⇒ so the verdict is BUILT FROM COUNTS, with no optimistic seed left over.
#      three things must hold, and each names a distinct failure:
#        1. the scan offered at least one key line   (else: it read no subject)
#        2. every scanned LINE was fingerprinted     (else: it read PART of it)
#        3. every fingerprint is attested            (the ⊆ test itself)
VERIFIED="false"
UNATTESTED=""
UNREAD=""
if [[ "$SCAN_LINES" -eq 0 ]]; then
  UNREAD="the scan offered no key line at all"
elif [[ "$FP_LINES" -ne "$SCAN_LINES" ]]; then
  UNREAD="ssh-keygen fingerprinted $FP_LINES of the $SCAN_LINES scanned key(s)"
elif [[ -n "$FINGERPRINTS_BOOT" ]]; then
  ATTESTED=0
  for FP in $FINGERPRINTS_SCAN; do
    if echo "$FINGERPRINTS_BOOT" | grep -F "$FP" >/dev/null; then
      ATTESTED=$(( ATTESTED + 1 ))
    else
      UNATTESTED="$UNATTESTED $FP"
    fi
  done
  # ⚠️ `-gt 0` is not redundant with the guards above: it is the clause that
  #    makes this equality fail-closed rather than vacuous, stated where a
  #    reader of THIS line can see it
  [[ "$FP_UNIQ" -gt 0 && "$ATTESTED" -eq "$FP_UNIQ" ]] && VERIFIED="true"
fi

if [[ -n "$UNREAD" ]]; then
  echo "   ✋ this check could not read its own subject — $UNREAD" >&2
  echo "      ⇒ it is about to write keys into ~/.ssh/known_hosts, and it has" >&2
  echo "        NOT fingerprinted all of them. a partial read is not a pass." >&2
  echo "      read it yourself:" >&2
  echo "        ssh-keyscan -p <port> localhost | ssh-keygen -lf -" >&2
fi

[[ -n "$ATTEST" ]] && echo "   ├─ attest:   $ATTEST"
echo "   ├─ fingerprints"
for FP in $FINGERPRINTS_SCAN; do
  if [[ -n "$FINGERPRINTS_BOOT" ]] && echo "$FINGERPRINTS_BOOT" | grep -F "$FP" >/dev/null; then
    echo "   │  ├─ $FP ✔ matches the boot record"
  else
    echo "   │  ├─ $FP ✋ NO boot record match"
  fi
done

# refuse an unverified write unless the human opted into tofu explicitly
if [[ "$VERIFIED" != "true" && "$TRUST" != "tofu" ]]; then
  if [[ -n "$UNATTESTED" ]]; then
    echo "   └─ ✋ the boot record answered, and does NOT attest every offered key" >&2
    echo "" >&2
    echo "  why: this endpoint offered a key the box's own record does not hold:" >&2
    for FP in $UNATTESTED; do echo "       $FP" >&2; done
    echo "" >&2
    echo "       a host's public keys are public, so a real key beside a forged one" >&2
    echo "       is the cheap attack — every offered key is checked, never just one." >&2
    echo "       ⇒ treat this as a security event, NOT as a stale record. another" >&2
    echo "         process may hold the local port" >&2
    echo "  fix: find what holds the port before you trust any key here —" >&2
    echo "    ss -tlnp | grep ':$PORT_SSH'" >&2
    exit 2
  fi
  echo "   └─ ✋ cannot verify the fingerprint against the box's boot record" >&2
  echo "" >&2
  echo "  why: ec2 console output holds the host keys a box printed at FIRST boot." >&2
  echo "       a box resumed from hibernate, or booted long ago, may report none" >&2
  echo "  fix: confirm the fingerprint above by another route, then accept it —" >&2
  echo "    rhx git.grove.trust.gen --grove $GROVE --mode apply --trust tofu" >&2
  echo "  or, on your own terminal, answer ssh's prompt once —" >&2
  echo "    ssh $ALIAS" >&2
  exit 2
fi

if [[ "$MODE" == "plan" ]]; then
  if [[ -n "$CHANGED" ]]; then
    echo "   └─ plan: would REPLACE the stale entry, then trust ($CHANGED$ABSENT)"
  else
    echo "   └─ plan: run with --mode apply to trust these key(s)"
  fi
  exit 0
fi

####################################################################
# ⚠️ a replace drops the WHOLE entry for this endpoint, then re-adds
#
# .why the whole entry and not the one changed keytype
#      known_hosts is keyed on `[host]:port`, and a box offers several keys
#      (ed25519, rsa, ecdsa). if the port was reused by a new box, EVERY key
#      under that endpoint belongs to the dead one — so a per-keytype drop
#      would leave the others behind, and the next connection would match a
#      stale sibling and fail with the same error this just cleared.
#
# .why it is safe HERE and was not safe above
#      control only reaches this line when the BOOT RECORD confirmed the
#      scanned key. so the box has already been shown to be who it claims,
#      and the drop removes a record of a machine that is provably gone.
#
# 🛑 .why `--trust tofu` is NOT a second route to this line
#      it was, until the pair was refused at parse (see the block beside
#      `--on-changed` validation). tofu answers the ABSENT case, where no
#      prior key is on record; a CHANGED key has one, so the only evidence
#      that separates a rebuilt box from a hijacked port is the boot record.
#      a drop reached on tofu would erase the disagreeing key — the single
#      artifact that says a change occurred at all.
####################################################################
if [[ -n "$CHANGED" ]]; then
  if ! ssh-keygen -R "[$HOSTNAME_SSH]:$PORT_SSH" >/dev/null 2>&1; then
    echo "   └─ 💥 could not drop the stale entry for [$HOSTNAME_SSH]:$PORT_SSH" >&2
    echo "" >&2
    echo "  why: the scanned key was verified, so the write SHOULD proceed — but" >&2
    echo "       known_hosts could not be rewritten. a read-only file or a bad" >&2
    echo "       permission on ~/.ssh is the usual cause" >&2
    echo "  fix: check it, then re-run this skill —" >&2
    echo "    ls -l ~/.ssh/known_hosts" >&2
    exit 1
  fi
  echo "   ├─ replaced: stale entry for [$HOSTNAME_SSH]:$PORT_SSH dropped"
fi

echo "$SCANNED" >> "$KNOWN_HOSTS"
if [[ -n "$CHANGED" ]]; then
  echo "   └─ 🌴 trusted — [$HOSTNAME_SSH]:$PORT_SSH re-trusted for the new box"
else
  echo "   └─ 🌴 trusted — [$HOSTNAME_SSH]:$PORT_SSH added to known_hosts"
fi

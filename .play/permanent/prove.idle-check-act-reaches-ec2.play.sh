#!/usr/bin/env bash
######################################################################
# prove.idle-check-act-reaches-ec2 — the checkout's idle check, run on a real
# cloud grove, reaches the REAL imds and the REAL ec2 api with its stop act —
# as a dry run, so the box never stops — and the bundle's readers reach the
# REAL systemd. no stub stands between the check and any of the three
#
# .what = runs a copy of `idle-hibernate.sh` on THIS box, with its limit at 0 so
#         it judges the box idle, its records moved into a temp dir, and `aws`
#         wrapped so `ec2 stop-instances` gains `--dry-run`. then it reads the
#         installed units through the bundle's own bounded systemctl reader
#
# .why a dry run is the real contract, not a mock
#   - ec2 evaluates a `--dry-run` request in full — the caller's credentials, the
#     instance role's `ec2:StopInstances`, the instance id, the region — and then
#     answers `DryRunOperation` (permitted) or `UnauthorizedOperation` (refused)
#     in place of the act. so the request this check builds is sent, judged, and
#     answered by the real service; only the stop itself is withheld
#   - ⇒ a real stop on this box would hibernate it under the crew that runs this
#     play. the one fact a real stop adds — that ec2 hibernates rather than
#     stops — is the ground-seat walk the handoff names
#
# .the claims
#   guard      the wrapper refuses every aws call but a stop, and every stop it passes carries --dry-run
#   imds       the real imds answers a token, an instance id, and a region, each in its shape
#   dryrun     the check's own act reaches real ec2, which answers DryRunOperation — the role may stop this box
#   nocreds    with no credential reachable, the real aws refuses, and the check holds loud with its fix
#   systemd    the bundle's bounded reader gets real answers from this box's systemd
#
# 🛑 .no identifier reaches the output
#   this repo is PUBLIC (`rule.forbid.dox-in-public-repo`). an instance id, a
#   region, an account, and an arn are matched by SHAPE and masked before any
#   line is printed, and the snap holds only the claim set
#
# .the write — `rule.forbid.repair-plays` exception 2: a temp dir for the copy and
#   its records, removed by a trap. the box is only read, and asked a dry run
#
# usage:
#   rhx play.run --play prove.idle-check-act-reaches-ec2      # on a cloud grove
######################################################################
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REPO="${GROVE_SRC:-$ROOT/src}"
BUNDLE="$REPO/grove.provision/1.system/1.15.hibernate"
CHECK="$BUNDLE/idle-hibernate.sh"
IMDS=http://169.254.169.254/latest
T=""
# the restore reports whether it took: a temp dir that survives fails the play (`rule.forbid.repair-plays`, condition 4)
trap '[[ -n "$T" ]] && rm -rf "$T"; [[ -n "$T" && -e "$T" ]] && { echo "   ✋ residue SURVIVED — $T"; exit 1; }' EXIT

[[ -f "$CHECK" ]] || { echo "✋ ConstraintError: no check at $CHECK — this play measures the real file"; exit 2; }
REAL_AWS="$(command -v aws)" || { echo "✋ ConstraintError: no aws cli on PATH — fix: rhx grove.provision --what 5.6.aws --mode apply"; exit 2; }
TOKEN="$(timeout -k 2 5 curl -sf --max-time 3 -X PUT "$IMDS/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 60" </dev/null)" \
  || { echo "✋ ConstraintError: no imds answered — run this on a cloud grove, where the stop act has a box to reach"; exit 2; }

T="$(mktemp -d)"
FAILED=0
# .what = strip every identifier this box could print: an instance id, a region, an account, an arn
# .why each is matched by SHAPE, so a value this play never saw is masked all the same
mask() {
  sed -E -e "s#$T#<tmp>#g" -e 's/i-[0-9a-f]{8,17}/<instance-id>/g' -e 's/\b[a-z]{2}(-gov)?-[a-z]+-[0-9]\b/<region>/g' \
    -e 's/[0-9]{12}/<acct>/g' -e 's/arn:aws[^ ]*/<arn>/g' -e 's/(Encoded authorization failure message:) [^ ]*/\1 <encoded>/g'
}
# .what = the act's own lines, as a caller reads them: the verdict's grammar, the stop asked, the
#   aws answer, and the check's 💥 with its fix — every value this box sets masked by shape
# .why filtered: the check also reports each source it walks, and those differ per box and seat,
#   so only the act's lines join the snap; the claim above them is asserted in full
actlines() {
  local out="$1" err="$2" asked="$3"
  printf '%s\n' "$out" | head -n 1 | mask | sed -E -e 's/idle=[0-9]+s/idle=<n>s/' -e 's/newest=[a-z]+ [^;]*;/newest=<kind> <source>;/' \
    -e 's/=[0-9]+/=<n>/g'
  [[ -z "$asked" ]] || echo "aws $(printf '%s' "$asked" | mask) --dry-run"
  printf '%s\n' "$err" | grep -E 'DryRunOperation|Unable to locate credentials|aws refused stop-instances|└─ fix:' | mask
}
SNAP=""
judge() {
  echo "   ├─ arm '$1'"
  if [[ "$2" -eq 0 ]]; then echo "   │  ✔ $3"
  else echo "   │  ✋ $3 did NOT hold"; printf '%s\n' "${4:-}" | mask | sed 's/^/   │     │ /'; FAILED=1; fi
  SNAP+="$1: $([[ "$2" -eq 0 ]] && echo ✔ || echo ✋) $3"$'\n'
  [[ -z "${5:-}" ]] || SNAP+="$(printf '%s\n' "$5" | sed 's/^/   │ /')"$'\n'
}

echo "🔭 does the idle check's act reach the real imds and ec2, as a dry run?"

# the wrapper: a stop gains --dry-run; any other aws call is refused, so no act can slip past it
mkdir -p "$T/bin"
cat > "$T/bin/aws" <<STUB
#!/usr/bin/env bash
echo "\$*" >> "$T/aws.log"
[[ "\$1 \$2" == "ec2 stop-instances" ]] || { echo "dry-run wrapper: refused a call it does not know: \$1 \$2" >&2; exit 97; }
exec "$REAL_AWS" "\$@" --dry-run
STUB
chmod +x "$T/bin/aws"

# claim 1 — the guard: any call but a stop is refused, and the stop line it execs carries --dry-run
GUARD_OUT="$(PATH="$T/bin:$PATH" aws sts get-caller-identity 2>&1)"; GUARD_RC=$?
[[ "$GUARD_RC" -eq 97 && "$GUARD_OUT" == *"refused a call it does not know"* ]] && grep -qx "exec \"$REAL_AWS\" \"\\\$@\" --dry-run" "$T/bin/aws"
judge guard $? "the wrapper refuses every aws call but a stop, and every stop it passes carries --dry-run" "$GUARD_OUT"
[[ "$FAILED" -eq 0 ]] || { echo "   └─ 💥 MalfunctionError: the dry-run guard did not hold — no act runs past it"; exit 1; }

# claim 2 — the real imds, in the shapes the act needs
IID="$(timeout -k 2 5 curl -sf --max-time 3 -H "X-aws-ec2-metadata-token: $TOKEN" "$IMDS/meta-data/instance-id" </dev/null)"
REGION="$(timeout -k 2 5 curl -sf --max-time 3 -H "X-aws-ec2-metadata-token: $TOKEN" "$IMDS/meta-data/placement/region" </dev/null)"
[[ -n "$TOKEN" && "$IID" =~ ^i-[0-9a-f]{8,17}$ && "$REGION" =~ ^[a-z]{2}(-gov)?-[a-z]+-[0-9]$ ]]
judge imds $? "imds answers a token, an instance id (i-…), and a region (<area>-<zone>-<n>)" "iid=$IID region=$REGION"

# the copy: its limit at 0, so the box reads idle; its records in the temp dir, never the box's live ones
RUN="$T/idle-hibernate.sh"
sed -e 's/^IDLE_LIMIT=.*/IDLE_LIMIT=0/' -e "s#^LAST_RECORD=.*#LAST_RECORD=$T/idle-hibernate.last#" \
    -e "s#^LAST_SLEEP=.*#LAST_SLEEP=$T/idle-hibernate.last-sleep#" "$CHECK" > "$RUN"
grep -qx 'IDLE_LIMIT=0' "$RUN" && grep -qx "LAST_RECORD=$T/idle-hibernate.last" "$RUN" && grep -qx "LAST_SLEEP=$T/idle-hibernate.last-sleep" "$RUN" \
  || { echo "   └─ ✋ ConstraintError: the copy's limit or record paths were not rewritten — this play would act on, or write, the live box"; exit 2; }
# the act must call aws by name, so the wrapper on PATH is the binary it meets
grep -qE '^[[:space:]]*timeout .* aws ec2 stop-instances --hibernate ' "$RUN" \
  || { echo "   └─ ✋ ConstraintError: the check no longer calls \`aws ec2 stop-instances\` by name — the dry-run wrapper would not stand in front of it"; exit 2; }

# claim 3 — the act, against the real ec2 api
OUT="$(PATH="$T/bin:$PATH" bash "$RUN" 2>"$T/err")"; RC=$?; ERR="$(cat "$T/err")"
ASKED="$(tail -1 "$T/aws.log" 2>/dev/null)"
if [[ "$OUT" != *"hibernate now"* ]]; then
  judge dryrun 1 "the check judged the box idle at limit 0 and called its act" "exit=$RC"$'\n'"$OUT"$'\n'"$ERR"
else
  [[ "$ASKED" == "ec2 stop-instances --hibernate --instance-ids $IID --region $REGION" && "$RC" -eq 1 \
    && "$ERR" == *"💥 MalfunctionError: aws refused stop-instances --hibernate for $IID, so the box did not sleep: "*"DryRunOperation"* \
    && "$ERR" == *"└─ fix: none owed: aws answered a dry run"* && "$ERR" != *"ec2:StopInstances"* ]]
  judge dryrun $? "the act sent stop-instances --hibernate for this box to real ec2, which answered DryRunOperation" "exit=$RC asked: $ASKED"$'\n'"$ERR" \
    "exit=$RC"$'\n'"$(actlines "$OUT" "$ERR" "$ASKED")"
fi

# claim 4 — no credential reachable: the real aws refuses, and the check holds loud with its fix
cat > "$T/bin/aws" <<STUB
#!/usr/bin/env bash
[[ "\$1 \$2" == "ec2 stop-instances" ]] || exit 97
exec env -u AWS_PROFILE -u AWS_ACCESS_KEY_ID -u AWS_SECRET_ACCESS_KEY -u AWS_SESSION_TOKEN \\
  AWS_EC2_METADATA_DISABLED=true AWS_CONFIG_FILE=/dev/null AWS_SHARED_CREDENTIALS_FILE=/dev/null \\
  "$REAL_AWS" "\$@" --dry-run
STUB
OUT="$(PATH="$T/bin:$PATH" bash "$RUN" 2>"$T/err")"; RC=$?; ERR="$(cat "$T/err")"
# the fix names the cause aws gave: absent credentials, never the role or hibernate
[[ "$RC" -eq 1 && "$ERR" == *"💥 MalfunctionError: aws refused stop-instances --hibernate"*", so the box did not sleep: "*"Unable to locate credentials"* \
  && "$ERR" == *"└─ fix: the box holds no live aws credentials"* && "$ERR" != *"ec2:StopInstances"* ]]
judge nocreds $? "with no credential the real aws refuses, and the check names it with its fix" "exit=$RC"$'\n'"$ERR" \
  "exit=$RC"$'\n'"$(actlines "$OUT" "$ERR" "")"

# claim 5 — the bundle's own bounded reader, against this box's systemd
# shellcheck source=/dev/null
source "$BUNDLE/_.sh" || { echo "   └─ 💥 MalfunctionError: the bundle's _.sh would not load"; exit 1; }
LOAD="$(grove_provision_1_15_hibernate_systemctl show -p LoadState --value idle-hibernate.timer 2>&1)"; LRC=$?
ENABLED="$(grove_provision_1_15_hibernate_systemctl is-enabled idle-hibernate.timer 2>&1)"
DROPINS="$(grove_provision_1_15_hibernate_systemctl show -p DropInPaths --value idle-hibernate.service 2>&1)"; DRC=$?
[[ "$LRC" -eq 0 && "$LOAD" =~ ^(loaded|not-found|masked)$ && "$ENABLED" =~ ^(enabled|disabled|masked|static|not-found)$ && "$DRC" -eq 0 ]]
judge systemd $? "the bounded reader gets this box's systemd answers: LoadState, is-enabled, DropInPaths" "load=$LOAD enabled=$ENABLED dropins=$DROPINS rc=$DRC"

echo "   └─ asked of ec2: $(printf '%s' "${ASKED:-naught}" | mask) --dry-run"

# the claim set, held by the shared snap — no identifier is in it, by construction
# shellcheck source=/dev/null
source "$ROOT/.play/permanent/play.snap.operations.sh" || { echo "   💥 MalfunctionError: play.snap.operations.sh would not load"; exit 1; }
play_snap_verify dir="$ROOT/.play/permanent/prove.idle-check-act-reaches-ec2.snap" name=transcript actual="$SNAP" || FAILED=1

echo ""
if [[ "$FAILED" -eq 0 ]]; then
  echo "🌲 the act reaches real imds and real ec2 — permitted, as a dry run — and the readers reach real systemd"
else
  echo "✋ the act did NOT reach the real services as declared — read the arms above"
fi
exit "$FAILED"

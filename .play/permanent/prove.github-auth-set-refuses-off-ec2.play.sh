#!/usr/bin/env bash
######################################################################
# .what = drive `git.grove.auth.github.set` to its rung-0b refusal on a grove
#         with no ec2 identity, with `ssh` stubbed, and snap what a human reads
#
# .why  = the clamp for `rule.forbid.aws-params-off-ec2` at this skill. a refusal
#         whose fix named `--vault aws.params` would send a human to write a
#         github pat into whatever aws account the far shell holds — the one
#         outcome the rule exists to stop. so the fix must name `os.secure`, and
#         never `aws.params`
#
# guarantee:
#   - HERMETIC. a stub `ssh` on PATH answers the probes; HOME and the grove
#     registry point into a mktemp dir, removed on exit. no grove is reached
#   - every case stops at or before rung 0b, so no tty prompt is ever opened
######################################################################

set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SKILL="$HERE/.agent/repo=.this/role=any/skills/git.grove.auth.github.set.sh"
[[ -r "$SKILL" ]] || { echo "✋ ConstraintError: the subject git.grove.auth.github.set.sh is absent from $HERE" >&2; exit 2; }

fixture="$(mktemp -d)"
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/bin" "$fixture/home" "$fixture/forest/groves"
printf '%s' '{"name":"grove-x","sshAlias":"grove-x"}' > "$fixture/forest/groves/grove-x.json"

# ssh: the reachability ask ends in `true`; the imds probe names the metadata
#   address. each answer comes from the case's env. any other ask is logged, since
#   none is owed before rung 0b refuses
cat > "$fixture/bin/ssh" <<STUB
#!/usr/bin/env bash
all="\$*"
[[ "\$all" == *169.254.169.254* ]] && exit "\${STUB_IMDS_RC:-0}"
[[ "\$all" == *" true"* || "\$all" == *"lc true"* ]] && exit "\${STUB_REACH_RC:-0}"
echo "ssh \$all" >> "$fixture/calls"
exit 0
STUB
chmod +x "$fixture/bin/ssh"

failed=0
transcript=""
cry() { echo "$1" >&2; transcript+="$1"$'\n'; }

echo "🌲 prove.github-auth-set-refuses-off-ec2"

# one case — $1 = label · $2 = exit wanted · then `env` assignments, a `--`, and the args
case_run() {
  local label="$1" want="$2" out rc
  shift 2
  local envs=()
  while [[ $# -gt 0 && "$1" != "--" ]]; do envs+=("$1"); shift; done
  shift
  : > "$fixture/calls"
  out="$(env PATH="$fixture/bin:$PATH" HOME="$fixture/home" GIT_FOREST_DIR="$fixture/forest" \
           "${envs[@]}" bash "$SKILL" "$@" 2>&1)" && rc=0 || rc=$?
  transcript+=$'\n'"## $label"$'\n'"rc=$rc"$'\n'"${out//$fixture/<fixture>}"$'\n'
  LAST_OUT="$out"
  if [[ "$rc" -eq "$want" ]]; then
    echo "   • $label → rc=$rc ✔"
    return 0
  fi
  cry "   💥 MalfunctionError: $label → rc=$rc, expected rc=$want"
  failed=1
  return 1
}

# a claim on the words of the last case
holds() {
  if [[ "$LAST_OUT" == *"$2"* ]]; then echo "   • $1 ✔"; return 0; fi
  cry "   💥 MalfunctionError: $1 — the output lacks '$2'"; failed=1
}
lacks() {
  if [[ "$LAST_OUT" != *"$2"* ]]; then echo "   • $1 ✔"; return 0; fi
  cry "   💥 MalfunctionError: $1 — the output holds '$2'"; failed=1
}

case_run "--help" 0 -- --help
holds "--help names the ec2-only bound" "an ec2 grove only"
holds "--help names the default env" "default camp"

case_run "a grove with no ec2 identity → refused at rung 0b" 2 STUB_IMDS_RC=22 -- grove-x
holds "the fix names os.secure" "--vault os.secure"
lacks "the fix never names aws.params as the vault" "--vault aws.params"
[[ -s "$fixture/calls" ]] \
  && { cry "   💥 MalfunctionError: an ask past rung 0b ran: $(cat "$fixture/calls")"; failed=1; } \
  || echo "   • no ask past rung 0b ran ✔"

# the control — IMDS answers, so rung 0b must let the plan through. without it, an
#   inverted or unconditional refusal would keep every row above green
case_run "the control · an ec2 grove → passes rung 0b, plan only" 0 STUB_IMDS_RC=0 -- grove-x
holds "the control names the instance identity" "instance identity"
lacks "the control never refuses at rung 0b" "has no ec2 identity"

case_run "a grove that does not answer → rc 1, names the wake" 1 STUB_REACH_RC=255 -- grove-x
holds "the unreachable fix names the wake" "rhx git.grove.wake grove-x"

case_run "a grove never registered → refused" 2 -- grove-none
case_run "no grove named → the usage" 2 --

# shellcheck source=/dev/null
source "$HERE/.play/permanent/play.snap.operations.sh"
play_snap_verify dir="$HERE/.play/permanent/prove.github-auth-set-refuses-off-ec2.snap" name=transcript actual="$transcript" \
  || failed=1

[[ "$failed" -eq 0 ]] && echo "🌲 all claims held ✔"
exit "$failed"

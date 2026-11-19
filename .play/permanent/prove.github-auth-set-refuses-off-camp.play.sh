#!/usr/bin/env bash
######################################################################
# .what = drive `git.grove.auth.github.set` to its rung-0b refusals — a grove
#         that is not a camp grove, and a camp grove whose identity is dead —
#         with `ssh` stubbed, and snap what a human reads
#
# .why  = the clamp for `rule.require.aws-params-on-camp-groves-only` at this
#         skill. off camp, a fix that named `--vault aws.params` would send a
#         human to write a github pat into whatever aws account the far shell
#         holds, so it names `os.secure`. on camp, the identity is MANDATED, so a
#         dead one is infra's to wire, never a reason to scatter the token
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

fixture="$(mktemp -d)" || { echo "💥 MalfunctionError: could not make a temp dir" >&2; exit 1; }
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/bin" "$fixture/home" "$fixture/forest/groves"
printf '%s' '{"name":"grove-x","sshAlias":"grove-x"}' > "$fixture/forest/groves/grove-x.json"

# ssh: the reachability ask ends in `true`; the imds probe names the metadata
#   address. each answer comes from the case's env. any other ask is logged, since
#   none is owed before rung 0b refuses
cat > "$fixture/bin/ssh" <<STUB
#!/usr/bin/env bash
all="\$*"
[[ "\$all" == *grove_env_derive* && -n "\${STUB_TIER_HANG:-}" ]] && exec sleep 30
[[ "\$all" == *grove_env_derive* && -n "\${STUB_TIER_ABSENT:-}" ]] && {
  echo "bash: line 1: /home/<seat>/git/more/dev-env-setup/src/grove.env.sh: No such file or directory" >&2; exit 1; }
[[ "\$all" == *grove_env_derive* ]] && { printf 'GROVE_ENV_SERVER=%s\n' "\${STUB_TIER:-cloud@hetzner.hetzbot}"; exit 0; }
[[ "\$all" == *get-caller-identity* ]] && exit "\${STUB_IDENT_RC:-0}"
[[ "\$all" == *keyrack*get*--value* && -n "\${STUB_RACK_ABSENT:-}" ]] && exit 2
[[ "\$all" == *" true"* || "\$all" == *"lc true"* ]] && exit "\${STUB_REACH_RC:-0}"
echo "ssh \$all" >> "$fixture/calls"
exit 0
STUB
chmod +x "$fixture/bin/ssh"

failed=0
transcript=""
cry() { echo "$1" >&2; transcript+="$1"$'\n'; }

echo "🌲 prove.github-auth-set-refuses-off-camp"

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
holds "--help names the camp-grove bound" "a camp grove only"
holds "--help names the default env" "default camp"

case_run "a local or house grove → refused at rung 0b" 2 STUB_TIER=local@unix -- grove-x
holds "the refusal names the tier the box reported" "is not a camp grove (its GROVE_ENV_SERVER is local@unix)"
holds "the fix names os.secure" "--vault os.secure"
lacks "the fix never names aws.params as the vault" "--vault aws.params"
[[ -s "$fixture/calls" ]] \
  && { cry "   💥 MalfunctionError: an ask past rung 0b ran: $(cat "$fixture/calls")"; failed=1; } \
  || echo "   • no ask past rung 0b ran ✔"

# a camp grove whose identity does not answer — the mandated prereq is absent, so
#   the fix names infra's identity skill, and never sends the token to os.secure
case_run "a camp grove with no live identity → refused at rung 0b" 2 STUB_IDENT_RC=255 -- grove-x
holds "the refusal names the mandate" "carries the camp aws identity by MANDATE"
holds "the fix names infra's identity skill" "grove identity skill"
lacks "the fix never sends a camp grove's token to os.secure" "--vault os.secure"
[[ -s "$fixture/calls" ]] \
  && { cry "   💥 MalfunctionError: an ask past rung 0b ran: $(cat "$fixture/calls")"; failed=1; } \
  || echo "   • no ask past rung 0b ran ✔"

# the control — a camp grove whose identity answers (hetzner as much as ec2: the
#   probe reads the tier and the default chain, never 169.254), so rung 0b lets the
#   plan through. without it, an unconditional refusal would keep every row above green
# a box with no checkout yet — its derive cannot run, and that is no tier verdict
case_run "a box with no checkout → rc 1, never read as not-camp" 1 STUB_TIER_ABSENT=1 -- grove-x
holds "the malfunction names the absent tier" "could not name its own tier"
holds "it quotes what the box said" "grove.env.sh: No such file or directory"
holds "the fix is the boot" "rhx git.grove.provision boot grove-x --mode apply"
lacks "an absent checkout is never read as a non-camp grove" "is not a camp grove"
lacks "it never hands out a vault" "--vault"

case_run "the control · a camp grove → passes rung 0b, plan only" 0 STUB_IDENT_RC=0 -- grove-x
holds "the control names the camp identity" "its identity answers"
lacks "the control never refuses at rung 0b" "ConstraintError"

# a camp grove whose rack does not yet answer — the plan names what apply would
#   run ON THE BOX, and runs none of it
case_run "a camp grove, the slug absent → the plan, rc 0" 0 STUB_RACK_ABSENT=1 -- grove-x
holds "the plan names what apply would run on the box" "plan — this is what apply would run ON THE BOX:"
holds "the plan names the keyrack set" "rhx keyrack set"
lacks "a plan never claims the slug is set" "already set!"

# a far shell that HANGS past ConnectTimeout — the wall-clock bound must end the probe
SECONDS=0
case_run "a probe that hangs → ended by the bound, rc 1 (a malfunction)" 1 STUB_TIER_HANG=1 GROVE_AUTH_ASK_BOUND=2 -- grove-x
holds "the hang names the bound, never a tier verdict" "did not answer the tier probe within 2s"
lacks "the hang is never read as a non-camp grove" "is not a camp grove"
(( SECONDS < 15 )) && echo "   • the hung probe returned within its bound ✔" \
  || { cry "   💥 MalfunctionError: the hung probe held the skill ${SECONDS}s"; failed=1; }

case_run "a grove that does not answer → rc 1, names the wake" 1 STUB_REACH_RC=255 -- grove-x
holds "the unreachable fix names the wake" "rhx git.grove.wake grove-x"

case_run "a grove never registered → refused" 2 -- grove-none
case_run "no grove named → the usage" 2 --

# shellcheck source=/dev/null
source "$HERE/.play/permanent/play.snap.operations.sh"
play_snap_verify dir="$HERE/.play/permanent/prove.github-auth-set-refuses-off-camp.snap" name=transcript actual="$transcript" \
  || failed=1

[[ "$failed" -eq 0 ]] && echo "🌲 all claims held ✔"
exit "$failed"

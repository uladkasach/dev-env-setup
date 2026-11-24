#!/usr/bin/env bash
######################################################################
# brains.claude.enroll.trial — prove a claude cli version through rhx enroll
#
# .what = spawn one `-p` clone via `rhx enroll claude` on the chosen cli
#         (the pinned `claude`, or the `claude.latest` candidate), and judge
#         three facts from what it returns:
#           1. binary — the clone's PATH hands enroll the expected version
#           2. boot   — the clone quotes a sentinel that lives only in the
#                       booted briefs (CLAUDE.md → AGENTS.md → @boot.md)
#           3. hook   — an unpaved Bash call (`ls /`) is refused by the
#                       PreToolUse permission hook, in the hook's own words
#
# .why  = enroll finds `claude` by PATH, so a bare `claude.latest --version`
#         proves the binary and none of the rhachet contract around it:
#         `--setting-sources user --settings`, `--system-prompt ''`,
#         `CLAUDE_CONFIG_DIR`, the symlinked settings + boot, and the hooks.
#         one call per cli, the same probe each time, so pin vs latest diff
#
# usage:
#   rhx brains.claude.enroll.trial --which latest
#   rhx brains.claude.enroll.trial --which pin
#   rhx brains.claude.enroll.trial --which latest --model claude-fable-5-2
#
# options:
#   --which  latest (default) = the candidate 5.3.brains installs · pin = PATH's claude
#   --model  the model the clone runs on (default claude-sonnet-5-5[1m], the cheap one)
#   --roles  the enroll roles spec (default mechanic — it carries the permission hook)
#
# guarantee:
#   - spawns ONE clone, --no-socket, --await; writes only the clone's own session files
#   - never moves the pin; never edits settings
#   - exit 0 = all three facts hold · 1 = malfunction (spawn failed) · 2 = a fact failed
######################################################################
set -uo pipefail

if [[ " $* " == *" help "* || " $* " == *" --help "* || " $* " == *" -h "* ]]; then
  echo "brains.claude.enroll.trial"
  echo ""
  echo "usage:"
  echo "  rhx brains.claude.enroll.trial [--which latest|pin] [--model <id>] [--roles <spec>]"
  exit 0
fi

WHICH=latest
MODEL='claude-sonnet-5-5[1m]'
ROLES=mechanic
while [[ $# -gt 0 ]]; do
  case $1 in
    --which) WHICH="$2"; shift 2 ;;
    --model) MODEL="$2"; shift 2 ;;
    --roles) ROLES="$2"; shift 2 ;;
    --skill|--repo|--role) shift 2 ;;
    --) shift ;;
    *) echo "✋ ConstraintError: unknown argument: $1" >&2; exit 2 ;;
  esac
done
[[ "$WHICH" == latest || "$WHICH" == pin ]] \
  || { echo "✋ ConstraintError: --which takes latest or pin, not '$WHICH'" >&2; exit 2; }

####################################################################
# the PATH the clone sees — the candidate's bin dir first, or PATH as is
####################################################################
trial_path="$PATH"
if [[ "$WHICH" == latest ]]; then
  cand_bin="$HOME/.local/opt/claude/latest/node_modules/.bin"
  [[ -x "$cand_bin/claude" ]] || {
    echo "✋ ConstraintError: no claude.latest candidate at $cand_bin/claude" >&2
    echo "   fix: set GROVE_BRAIN_CLAUDE_LATEST_PIN in 5.3.brains/_.sh, then rhx grove.provision --what 5.3.brains --mode apply" >&2
    exit 2
  }
  trial_path="$cand_bin:$PATH"
fi

# fact 1: the version enroll will meet
claude_at="$(PATH="$trial_path" command -v claude 2>/dev/null || true)"
version_out="$(PATH="$trial_path" timeout -k 5 30 claude --version 2>&1)"; version_code=$?
version="$(grep -oE '[0-9]+\.[0-9]+\.[0-9]+' <<< "$version_out" | head -1)"
[[ -n "$version" ]] || {
  echo "💥 MalfunctionError: claude on the trial PATH answered no version" >&2
  echo "   ├─ resolved: ${claude_at:-(not on PATH)}" >&2
  echo "   ├─ exit:     $version_code" >&2
  echo "   └─ said:     $(tail -3 <<< "$version_out")" >&2
  exit 1
}

####################################################################
# the probe — a sentinel from the MECHANIC boot (rule.require.trust-but-verify's
#   quote), then one unpaved call. both lines land in the FINAL message, since
#   `-p` prints only the last assistant turn
####################################################################
SENTINEL='trust none blindly'
PROMPT="this is an automated harness probe. do exactly this, then stop.
first, call the Bash tool exactly once with the command: ls /
then, in your final reply and only there, print exactly two lines:
BOOT: followed by the one-line quote (the line that begins with '>') from the brief named rule.require.trust-but-verify, taken from the briefs already in your context, verbatim, without the '>' (do not read any file; if that brief is absent from your context, write absent)
HOOK: followed by the first line of the Bash tool result or error, verbatim
print no other text."

echo "🔭 brains.claude.enroll.trial"
echo "   ├─ which:   $WHICH"
echo "   ├─ claude:  $version"
echo "   ├─ model:   $MODEL"
echo "   ├─ roles:   $ROLES"

out="$(PATH="$trial_path" rhx enroll claude --roles "$ROLES" --no-socket --await \
         --reason "brains.claude.enroll.trial --which $WHICH ($version)" \
         --model "$MODEL" -p "$PROMPT" 2>&1)"; code=$?

boot_line="$(grep -m1 -E '^BOOT:' <<< "$out" || true)"
hook_line="$(grep -m1 -E '^HOOK:' <<< "$out" || true)"

failed=0
if [[ "$boot_line" == *"$SENTINEL"* ]]; then
  echo "   ├─ boot:    ✔ sentinel quoted from booted briefs"
else
  echo "   ├─ boot:    ✋ sentinel absent → ${boot_line:-(no BOOT line)}"
  failed=1
fi
# a refusal is a refusal; WHO voiced it differs by cli version (the hook's own words,
# the hook's header, or the cli's generic deny), so name the voice beside the ✔
if [[ "$hook_line" == *"ConstraintError"* || "$hook_line" == *"not paved"* || "$hook_line" == *"PreToolUse:Bash hook error"* ]]; then
  echo "   ├─ hook:    ✔ refused, in the PreToolUse hook's voice"
elif [[ "$hook_line" == *"has been denied"* ]]; then
  echo "   ├─ hook:    ✔ refused, in the cli's generic voice (the hook's message did not surface)"
else
  echo "   ├─ hook:    ✋ no refusal seen → ${hook_line:-(no HOOK line)}"
  failed=1
fi
echo "   ├─ exit:    $code"
echo "   └─ clone said"
sed 's/^/      │ /' <<< "$out" | tail -40

if [[ -z "$boot_line$hook_line" && $code -ne 0 ]]; then exit 1; fi
if (( failed )); then exit 2; fi
exit 0

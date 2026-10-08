#!/usr/bin/env bash
######################################################################
# .what = the shared half of the `machine.openhours.optin` family — the marker
#         path, the state reader, and the marker's own body
#
# .why  = three verbs over one file is three chances to name that file three
#         ways. the path is held once here, and every verb asks for it
#
# 🛑 .why it SOURCES the bundle rather than restate the path
#   `5.18.openhours/_.sh` declares `GROVE_OPENHOURS_OPTIN`, and that bundle's own
#   upsert and verify both read it from there. a copy here would be a second
#   declaration of one path, free to drift with no reader to catch it
#   (`gotcha.a-check-that-cries-wolf-gets-silenced`, m.9).
#
#   ⚠️ and the drift would be silent in the worst direction: this family would
#     mark a path the bundle never reads, so a human would elect the gate, the
#     next apply would find no marker, and the teardown leg would remove the very
#     gate they just asked for — while both halves reported success.
#
# ⚠️ .why a SKILL may write the marker where the BUNDLE may not
#   `rule.require.optin-bundles-converge-to-their-flag` bars the BUNDLE from a
#   write to its own flag: an apply runs on every box, so a bundle that created
#   the marker would grant the election it was sent to ask about, and the default
#   would be off in name alone.
#   ⇒ a skill is the opposite case. a human types it, once, at the box they mean.
#     so the write belongs HERE, and the bundle stays a pure reader.
#
# 🛑 .it never drives `grove.provision`, and that is deliberate
#   this family sets the ELECTION. the bundle converges the box to it. a skill
#   that did both would be a repair play with a second path to the same state
#   (`rule.forbid.repair-plays`, `rule.require.install-via-procedures`).
#   ⇒ so every verb that moves the marker names the one command that converges.
######################################################################

####################################################################
# the bundle that owns the declaration — reached by the family's own location,
# so a worktree and the main checkout each read their own tree
#
# ⚠️ the `../../../..` hop is the idiom every skill here uses to find the repo
#   root (`machine.usage.diagnose`, `git.grove.operations`, `aws.ec2.get`)
####################################################################
_openhours_optin_bundle() {
  local root
  root="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)" || return 1
  printf '%s\n' "$root/src/grove.provision/5.devtools/5.18.openhours/_.sh"
}

_OPENHOURS_OPTIN_BUNDLE="$(_openhours_optin_bundle)"

if [[ ! -r "$_OPENHOURS_OPTIN_BUNDLE" ]]; then
  echo "✋ the openhours bundle is unreadable, so the marker path has no declaration" >&2
  echo "   looked for: $_OPENHOURS_OPTIN_BUNDLE" >&2
  echo "   ⇒ this family reads the path from the bundle rather than restate it," >&2
  echo "     so an absent bundle is an absent answer — never a guessed one" >&2
  echo "   fix: run this from a complete checkout of dev-env-setup" >&2
  exit 1
fi

####################################################################
# ⚠️ the bundle's `_.sh` only ASSIGNS and DEFINES — it drives no phase — so a
#   source here is inert. it is the same file the entrypoint sources before it
#   dispatches, which is what makes this the shared declaration and not a peer
####################################################################
# shellcheck source=/dev/null
source "$_OPENHOURS_OPTIN_BUNDLE" || {
  echo "✋ could not read the openhours declaration at $_OPENHOURS_OPTIN_BUNDLE" >&2
  exit 1
}

[[ -n "${GROVE_OPENHOURS_OPTIN:-}" ]] || {
  echo "✋ the bundle declares no GROVE_OPENHOURS_OPTIN" >&2
  echo "   ⇒ the marker path was renamed or removed, and this family tracks it" >&2
  echo "   fix: read $_OPENHOURS_OPTIN_BUNDLE and realign this family to it" >&2
  exit 1
}

####################################################################
# .what = is THIS box elected?  `in` | `out`
# .why  = it DELEGATES to the bundle's own reader rather than test `-f` again.
#   one reader for the family and the bundle alike, so a verb here can never
#   disagree with the apply that acts on it
####################################################################
openhours_optin_state() {
  grove_provision_5_18_openhours_optin_state
}

####################################################################
# .what = the marker's body, or the empty string
#
# ⚠️ the body is NEVER parsed as a value — presence of the path is the whole
#   contract (see the bundle's note). this reads it only to SHOW a human the
#   note their earlier self left, so a stale election can be judged
####################################################################
openhours_optin_reason() {
  [[ -f "$GROVE_OPENHOURS_OPTIN" ]] || return 0
  head -c 2000 "$GROVE_OPENHOURS_OPTIN" 2>/dev/null
}

####################################################################
# .what = the line every write verb prints — the converge this skill declines
#   to run itself
####################################################################
openhours_optin_converge_hint() {
  echo "   ⇒ the election is set; the BOX is not converged yet"
  echo "     converge it by the one command:"
  echo "       rhx grove.provision --what 5.18.openhours --mode apply"
}

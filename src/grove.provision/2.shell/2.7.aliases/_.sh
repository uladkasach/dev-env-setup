#!/usr/bin/env bash
######################################################################
# .what = the alias suite: `~/.bash_aliases` and the two files it sources
#
# .why THREE files are ONE bundle
#   - `bash_aliases.sh` sources `ductwork.sh` and `termwork.sh` by path
#   - ⇒ a bundle per file would let one land and the others not
#   - the failure reports "no such file" at every login
#   - that reads as a broken alias file, never as one absent member of a set
#   - ⇒ one claim: "the alias suite is on this box, whole"
#
# .why there is no PROVISION phase
#   - the suite is three checked-in shell files, so no package is owed
#   - ⇒ the phase would be empty
#   - an empty phase is a verdict a reader must account for with no fact behind it
#
# .why it applies to a HEADLESS box
#   - the name "bash aliases" reads like a comfort for a human at a keyboard
#   - `ductwork.sh` is the DUCT, which is how a grove is reached at all
#   - `git.grove` and `git.tree` are how work moves between boxes
#   - the six compound `git` aliases `2.2.git` declares all delegate into this file
#   - ⇒ without it those aliases exist and fail
#
# .why it comes AFTER `2.5.zsh`
#   - the zshrc sources `~/.bash_aliases`
#   - neither order breaks, since the rc is read at the next login, not at copy time
#   - ⇒ the order that matches the dependency is the one a reader can follow
######################################################################

######################################################################
# the verify's self-contained probes — `configure.verify` calls each, and each reports
# through that phase's `_verify_fail` / `_verify_has_fn`
######################################################################

# .what = does the reset reader name a reset only where the cli would offer one?
# .why `juniper_tide.available` alone is NOT an offer: the field is an A/B experiment, and the
#   cli offers only where `arm == "reset"` too. a reader that took `available` alone printed a 🎁
#   on an account outside the experiment. this RUNS the reader on both shapes
grove_provision_2_7_aliases_verify_reset_reader() {
  local brains="$HOME/.bash_aliases.brains.auth.sh"
  [[ -f "$brains" ]] && _verify_has_fn "$brains" "_brains_auth_reset_line" "~/.bash_aliases.brains.auth.sh" \
    "the reader that names a usage-limit reset is gone" || return 0
  local reset_out reset_off reset_on
  reset_out="$(
    # shellcheck disable=SC1090
    source "$brains" >/dev/null 2>&1
    _brains_auth_reset_line '{"juniper_tide":{"eligible":true,"in_experiment":false,"arm":null,"available":true}}'
    printf '\x1f'
    _brains_auth_reset_line '{"juniper_tide":{"eligible":true,"in_experiment":true,"arm":"reset","available":true}}'
  )" || reset_out=""
  # an absent reset prints a blank line, which the render drops — so whitespace counts as "none"
  reset_off="${reset_out%%$'\x1f'*}"; reset_off="${reset_off//$'\n'/}"
  reset_on="${reset_out#*$'\x1f'}"
  [[ -z "${reset_off//[[:space:]]/}" ]] || _verify_fail \
    "_brains_auth_reset_line names a reset for an account OUTSIDE the experiment: '$reset_off'" \
    "⇒ brains.auth.usage shows a 🎁 the account does not hold" \
    'fix: gate juniper_tide on arm == "reset" AND available, as the cli does'
  [[ "$reset_on" == *"session reset available now"* ]] || _verify_fail \
    "_brains_auth_reset_line names no reset for a real offer (arm reset, available): '$reset_on'" \
    "⇒ a session reset the account DOES hold goes unseen"
  return 0
}

# .what = does any suite member pin SSH_AUTH_SOCK shell-wide?  args: the `src:dst` pairs
# .why ssh speaks to the ONE agent SSH_AUTH_SOCK names; a pin to yubikey-agent, which refuses file
#   keys, made every id_ed25519 connection ask for its passphrase. a per-call prefix is legal
# ⚠️ a count, never `grep -q`: under pipefail a -q hit exits 141 (gotcha.pipefail-grep-q)
grove_provision_2_7_aliases_verify_agent_unpinned() {
  local pinned="" pair member pin_pat pin_rc pin_hits
  pin_pat='(^|[;&|[:space:]])export[[:space:]]+([^;]*[[:space:]])?SSH_AUTH_SOCK([;[:space:]=]|$)|^[[:space:]]*SSH_AUTH_SOCK=[^[:space:]]*[[:space:]]*(;|$)'
  for pair in "$@"; do
    member="$HOME/${pair##*:}"
    [[ -f "$member" ]] || continue
    pin_rc=0
    pin_hits="$(grep -vE '^[[:space:]]*#' "$member" | sed 's/"[^"]*"//g' | grep -cE "$pin_pat")" || pin_rc=$?
    if [[ "$pin_rc" -gt 1 ]]; then
      _verify_fail "the SSH_AUTH_SOCK reader errored on ~/${pair##*:} (exit $pin_rc)" \
        "⇒ an unread file is not a clean one"
    elif [[ "${pin_hits:-0}" -gt 0 ]]; then
      pinned="${pinned:+$pinned }~/${pair##*:}"
    fi
  done
  [[ -z "$pinned" ]] || _verify_fail "SSH_AUTH_SOCK is pinned shell-wide by: $pinned" \
    "⇒ every shell then skips the desktop agent, and a file key asks for its passphrase on each connection" \
    "fix: drop the export; a call that wants the YubiKey names its socket per call" \
    "read why: grep -n SSH_AUTH_SOCK $pinned"
  return 0
}

grove_provision_2_7_aliases() {
  bundle.upgrade 2.7.aliases.configure.upsert
  bundle.upgrade 2.7.aliases.configure.verify
}

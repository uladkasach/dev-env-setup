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

grove_provision_2_7_aliases() {
  bundle.upgrade 2.7.aliases.configure.upsert
  bundle.upgrade 2.7.aliases.configure.verify
}

# .what = print one ✋ failure (a headline plus optional detail lines)
_verify_fail() {
  printf '   ✋ %s\n' "$1" >&2
  shift
  local line
  for line in "$@"; do
    [[ -n "$line" ]] && printf '      %s\n' "$line" >&2
  done
  failed=$(( failed + 1 ))
}

# .what = fail unless $1 declares function $2 — 7 of 8 checks gate on a function's presence; one holder for the pattern
_verify_has_fn() {
  local file="$1" fn="$2" label="$3" why="$4"
  shift 4
  grep -q "^${fn}()" "$file" && return 0
  _verify_fail "$label declares no $fn" "⇒ $why" "$@"
  return 1
}

# .what = fail where any member of the configure.verify's $pairs pins SSH_AUTH_SOCK shell-wide
# .why ssh speaks to the ONE agent SSH_AUTH_SOCK names. a pin to yubikey-agent, which refuses file keys, made every id_ed25519 connection ask for its passphrase
# .why a per-call prefix (`SSH_AUTH_SOCK=<sock> ssh-add`) is legal, so only a shell-wide export or bare assignment is caught
# .why a count, never `grep -q`: under pipefail a hit reads as exit 141 (gotcha.pipefail-grep-q), so an exit past 1 is a reader fault
_verify_2_7_aliases_ssh_auth_sock_unpinned() {
  local pinned="" member pin_pat pin_rc pin_hits pair
  pin_pat='(^|[;&|[:space:]])export[[:space:]]+([^;]*[[:space:]])?SSH_AUTH_SOCK([;[:space:]=]|$)|^[[:space:]]*SSH_AUTH_SOCK=[^[:space:]]*[[:space:]]*(;|$)'
  for pair in "${pairs[@]}"; do
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
}

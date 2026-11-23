#!/usr/bin/env bash
######################################################################
# .what = drive the 2.8.tmux login-shell tell (upsert) and its verify arm over stub tmux
#         servers, and fail unless a server born with an old shell is told the login
#         record's shell, a refusal is counted, and the verify reads every arm
#
# .why  = a new pane execs the server's `default-shell`, which tmux took from its own
#         $SHELL at server START. a server born before zsh became the login shell opened
#         every pane in bash, with no starship. 📜 2026-11-20, a hetzner grove. the only
#         proof was a live boot; this drives each arm and snaps every line a human reads
#
# guarantee:
#   - HERMETIC: `tmux` and `getent` are stub executables on a fixture PATH, each server's
#     `default-shell` a file under the fixture. no real tmux server is touched
######################################################################

set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUNDLE="$HERE/src/grove.provision/2.shell/2.8.tmux"

fixture="$(mktemp -d)"
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/bin" "$fixture/servers" "$fixture/shells"

# the two shells a seat's record may name: real files, executable, as the reader demands
for s in bash zsh; do printf '#!/bin/sh\n' >"$fixture/shells/$s"; chmod +x "$fixture/shells/$s"; done

# a stub tmux: `-L <sock>`, then one verb. a server is a dir; a `refuse` file in it fails
#   every verb, as a wedged server would; an absent dir is a socket with no server
cat >"$fixture/bin/tmux" <<'EOF'
#!/usr/bin/env bash
[[ "$1" == -L ]] || exit 2
srv="$TMUX_STUB_DIR/$2"; shift 2
[[ -d "$srv" ]] || { echo "no server on $srv" >&2; exit 1; }
[[ -f "$srv/refuse" ]] && { echo "server exited unexpectedly" >&2; exit 1; }
case "$*" in
  "source-file "*)                    echo "$2" >"$srv/sourced" ;;
  "set-option -g default-shell "*)    printf '%s\n' "$4" >"$srv/default-shell" ;;
  "show-options -gv default-shell")   cat "$srv/default-shell" ;;
  *) exit 2 ;;
esac
EOF
# a stub getent: the seat's passwd record names $LOGIN_SHELL; empty = no record
cat >"$fixture/bin/getent" <<'EOF'
#!/usr/bin/env bash
[[ -n "${LOGIN_SHELL:-}" ]] || exit 2
echo "$2:x:1000:1000::/home/$2:$LOGIN_SHELL"
EOF
chmod +x "$fixture/bin/tmux" "$fixture/bin/getent"

failed=0
transcript=""
fail() { echo "   💥 MalfunctionError: $1" >&2; failed=1; }
claim() { local label="$1"; shift; if "$@"; then echo "   • $label ✔"; else fail "$label"; fi; }

# a live server born with <shell>
server() { mkdir -p "$fixture/servers/$1"; printf '%s\n' "$fixture/shells/$2" >"$fixture/servers/$1/default-shell"; }
shell_of() { sed "s#$fixture/shells/##" "$fixture/servers/$1/default-shell"; }

OUT="" RC=0
# $1 = a header · then the call, run in a fresh bash with the bundle sourced
drive() {
  local header="$1"; shift
  OUT="$(timeout -k 2 20 env PATH="$fixture/bin:$PATH" HOME="$fixture" TMUX_STUB_DIR="$fixture/servers" \
    LOGIN_SHELL="${LOGIN_SHELL:-}" bash -c '
      source "$1/_.sh"; source "$1/configure.upsert.sh"; source "$1/configure.verify.sh"
      grove_provision_2_8_tmux_live_sockets() { ls "$TMUX_STUB_DIR"; echo ghost; }
      shift; "$@"' _ "$BUNDLE" "$@" </dev/null 2>&1)" && RC=0 || RC=$?
  transcript+="## $header (exit $RC)"$'\n'"${OUT//$fixture\/shells\//}"$'\n\n'
}
tell_all() { local s rc=0; for s in "$@"; do grove_provision_2_8_tmux_server_tell "$s" "$(grove_provision_2_8_tmux_login_shell)" || { echo "refused: $s"; rc=1; }; done; return "$rc"; }
export -f tell_all

echo "🌲 prove.tmux-pane-shell-follows-login"
touch "$fixture/.tmux.conf"

# the reader: the passwd record, never $SHELL
LOGIN_SHELL="$fixture/shells/zsh"
drive "the login shell, a record that names zsh" grove_provision_2_8_tmux_login_shell
claim "reader · names the record's shell" test "$OUT" == "$fixture/shells/zsh"
LOGIN_SHELL="$fixture/shells/absent"
drive "the login shell, a record whose shell does not run" grove_provision_2_8_tmux_login_shell
claim "reader · a shell that does not run is no answer" test -z "$OUT" -a "$RC" -eq 0

# the duct server, born with bash before zsh became the login shell
LOGIN_SHELL="$fixture/shells/zsh"
server duct bash
drive "verify, a server born with bash" grove_provision_2_8_tmux_verify_pane_shell
claim "verify · a server whose pane execs bash refuses, rc 1, named with its shell" \
  bash -c '[[ "$1" -eq 1 && "$2" == *"1 live tmux server opens a new pane in a shell other than zsh: duct=bash"* ]]' _ "$RC" "${OUT//$fixture\/shells\//}"
claim "verify · it names the apply as its fix" test -n "$(grep -F 'fix: rhx grove.provision --what 2.8.tmux --mode apply' <<<"$OUT")"

server spare bash
drive "verify, two servers born with bash" grove_provision_2_8_tmux_verify_pane_shell
claim "verify · two such servers are counted, plural" \
  test -n "$(grep -F '2 live tmux servers open a new pane' <<<"$OUT")"

# the upsert tells each server, then the verify reads ✔
drive "upsert tell, two servers born with bash" tell_all duct spare
claim "tell · each server is told the login shell" test "$RC" -eq 0 -a "$(shell_of duct) $(shell_of spare)" == "zsh zsh"
claim "tell · each server loaded the conf first" test -f "$fixture/servers/duct/sourced" -a -f "$fixture/servers/spare/sourced"
drive "verify, every server told" grove_provision_2_8_tmux_verify_pane_shell
claim "verify · every live server reads the login shell ✔, rc 0" \
  bash -c '[[ "$1" -eq 0 && "$2" == *"a new pane in every live server execs the login shell"*"✔"* ]]' _ "$RC" "$OUT"
claim "verify · a socket with no server is no claim about a pane" test -z "$(grep -F ghost <<<"$OUT")"

# a wedged server refuses: counted, never told, its shell unchanged
server wedged bash; touch "$fixture/servers/wedged/refuse"
drive "upsert tell, a wedged server" tell_all wedged
claim "tell · a server that refuses is counted refused" test "$RC" -eq 1 -a -n "$(grep -F 'refused: wedged' <<<"$OUT")"
claim "tell · and its shell is unchanged" test "$(shell_of wedged)" == bash
rm -rf "$fixture/servers/wedged"

# a seat whose record names no shell: the conf still loads, no shell is told, the arm is quiet
LOGIN_SHELL=""
server fresh bash; rm -f "$fixture/servers/fresh/sourced"
drive "upsert tell, a record that names no shell" tell_all fresh
claim "tell · with no login shell the conf still loads, and no shell is told" \
  test "$RC" -eq 0 -a -f "$fixture/servers/fresh/sourced" -a "$(shell_of fresh)" == bash
drive "verify, a record that names no shell" grove_provision_2_8_tmux_verify_pane_shell
claim "verify · with no login shell the arm makes no claim, rc 0" test "$RC" -eq 0 -a -z "$OUT"

# shellcheck source=/dev/null
source "$HERE/.play/permanent/play.snap.operations.sh"
play_snap_verify dir="$HERE/.play/permanent/prove.tmux-pane-shell-follows-login.snap" name=transcript \
  actual="${transcript//$fixture/<fixture>}" || failed=1

[[ "$failed" -eq 0 ]] && echo "🌲 all claims held ✔"
exit "$failed"

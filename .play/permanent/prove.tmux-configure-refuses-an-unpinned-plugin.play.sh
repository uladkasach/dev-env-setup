#!/usr/bin/env bash
######################################################################
# .what = prove `2.8.tmux`'s configure.upsert refuses a conf `@plugin` this repo
#         pins no commit for, BEFORE tpm clones it or any live server sources it
#
# .why this play exists
#   - tpm's `install_plugins` clones each `@plugin` at its default-branch tip, and
#     the source into live servers runs that plugin's `.tmux` file
#   - the verify's ✋ on `unpinned` comes after both, so the code it names has run
#     once by the time it fires — the refusal belongs ahead of the install
#
# .the arms — a fixture HOME and a fixture conf, never the box's own
#   - U1. a conf that names an unpinned plugin → ✋ names it, rc 1
#   - U2. … and no tmux call, no tpm install, and no write to ~/.tmux.conf was made
#   - U3. the repo's own conf (every plugin pinned) → passes the guard
#   - C1..C7. each other variant: no conf in the checkout · ~/.tmux.conf unwritable · a
#     shadow retired · a shadow that will not move · tpm absent · a plugin that never
#     lands · a live server that will not source the conf
#   - C8. a conf the isolated server cannot parse → ✋ before tpm runs
#   - B. a REAL tmux on a fixture socket: it starts on a bad conf with no @plugin, and only
#     `source-file -n` refuses it — the premise C8 rests on, asked of the build itself
#
# .what is stubbed
#   - `tmux` is a shim first on PATH that records each call and fails, so U3 stops
#     at the isolated server; TMUX_TMPDIR is the fixture's, so no live server is reachable
#   - tpm's `install_plugins` records that it ran
#   - no shadow conf is found
#
# usage:
#   rhx play.run --play prove.tmux-configure-refuses-an-unpinned-plugin
#
# exit:
#   0 = every arm holds
#   1 = an arm failed
#   2 = no checkout found, or the bundle could not be sourced
######################################################################

set -uo pipefail

# .what = the checkout under proof — `PROVE_ROOT` (the red half), this play's own, or the cwd
_root_of() {
  [[ -n "${PROVE_ROOT:-}" ]] && { printf '%s' "$PROVE_ROOT"; return 0; }
  local self; self="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." 2>/dev/null && pwd)"
  [[ -n "$self" && -f "$self/src/grove.provision._.sh" ]] && { printf '%s' "$self"; return 0; }
  [[ -f "$PWD/src/grove.provision._.sh" ]] && { printf '%s' "$PWD"; return 0; }
  return 1
}
_root="$(_root_of)" || { echo "   ✋ ConstraintError: no checkout found" >&2; exit 2; }

_dir="$_root/src/grove.provision/2.shell/2.8.tmux"
export GROVE_SRC="$_root/src"
for _f in _.sh configure.upsert.sh; do
  # shellcheck source=/dev/null
  source "$_dir/$_f" || { echo "   ✋ ConstraintError: could not source $_dir/$_f" >&2; exit 2; }
done

echo "🔎 prove.tmux-configure-refuses-an-unpinned-plugin"
echo "   └─ root: $_root"
echo ""

# shellcheck source=/dev/null
source "$(dirname "${BASH_SOURCE[0]}")/.snap.operations.sh"

FIX="$(mktemp -d "${TMPDIR:-/tmp}/prove.tmux-unpinned.XXXXXX")"
trap 'rm -rf "$FIX"' EXIT
export HOME="$FIX/home"
mkdir -p "$HOME/.tmux/plugins/tpm/bin"
printf '%s\n' '#!/usr/bin/env bash' "echo ran >> '$FIX/tpm.ran'" > "$HOME/.tmux/plugins/tpm/bin/install_plugins"
chmod +x "$HOME/.tmux/plugins/tpm/bin/install_plugins"

# .what = a fixture src whose conf is the repo's own plus one unpinned @plugin
mkdir -p "$FIX/src/grove.provision/2.shell/2.8.tmux"
cp "$_dir/tmux.conf" "$FIX/src/grove.provision/2.shell/2.8.tmux/tmux.conf"
printf "set -g @plugin 'someone/tmux-unvouched'\n" >> "$FIX/src/grove.provision/2.shell/2.8.tmux/tmux.conf"

######################################################################
# the stubs
######################################################################
# 🛑 a SHIM on PATH, never a function: the bundle calls `timeout … tmux`, and `timeout` execs
#    a binary — a function stub is bypassed and the real tmux reaches this seat's servers.
#    the socket dir is the fixture's too, so even a real tmux finds no live server here
mkdir -p "$FIX/bin" "$FIX/tmuxdir"
#    it fails every call unless `SHIM_OK=yes`; then a `-L <sock> source-file` fails for each
#    socket named in `SHIM_REFUSE` — a `-n` parse with the error line real tmux prints (arm B
#    measures it) — and every other call succeeds
printf '%s\n' '#!/usr/bin/env bash' \
  "printf '%s\n' \"\$*\" >> '$FIX/tmux.calls'" \
  '[[ "${SHIM_OK:-}" == yes ]] || exit 1' \
  '[[ "$3 $4" == "source-file -n" && " ${SHIM_REFUSE:-} " == *" $2 "* ]] && { echo "$5:2: unknown command: this-is-not-a-tmux-command" >&2; exit 1; }' \
  '[[ "$*" == *source-file* && " ${SHIM_REFUSE:-} " == *" $2 "* ]] && exit 1' \
  'exit 0' > "$FIX/bin/tmux"
chmod +x "$FIX/bin/tmux"
export PATH="$FIX/bin:$PATH" TMUX_TMPDIR="$FIX/tmuxdir"
unset TMUX

# each reader the later steps ask is a stub an arm steers through one variable; unset, each
#   answers empty, so U1–U3 meet the world they always met
grove_provision_2_8_tmux_shadow_confs() { [[ -n "${SHADOW:-}" ]] && printf '%s\n' "$SHADOW"; return 0; }
grove_provision_2_8_tmux_backup_stamp() { printf '20261023T000000Z'; }
grove_provision_2_8_tmux_plugin_root() { printf '%s' "$HOME/.tmux/plugins"; }
grove_provision_2_8_tmux_plugins_absent_under() { [[ -n "${ABSENT:-}" ]] && printf '%s\n' "$ABSENT"; return 0; }
# shellcheck disable=SC2086
grove_provision_2_8_tmux_live_sockets() { [[ -n "${LIVE:-}" ]] && printf '%s\n' $LIVE; return 0; }
sleep() { :; }

failed=0

# .what = grade one arm: its exit, and a phrase its output must hold
_grade() {
  local label="$1" rc="$2" want="$3" out="$4" phrase="$5"
  local held=yes
  [[ "$rc" -eq "$want" ]] || held="rc=$rc, want $want"
  [[ "$held" == yes && "$out" != *"$phrase"* ]] && held="no '$phrase' in the output"
  # the phrase holds → snap the whole message, keyed by the arm id
  [[ "$held" == yes ]] && { play_snap_assert arm="${label%%.*}" rendered="$out" mask="$FIX" mask="$_root" || return 1; echo "   ├─ $label ✔"; return 0; }
  echo "   ├─ $label: $held" >&2
  printf '%s\n' "$out" | sed 's/^/   │     /' >&2
  return 1
}

# U1, U2. an unpinned plugin: refused ahead of every tmux call, every tpm install, and the conf write
printf '# the prior conf\n' > "$HOME/.tmux.conf"
out="$( GROVE_SRC="$FIX/src" grove_provision_2_8_tmux_configure_upsert 2>&1 )"; rc=$?
if [[ "$(cat "$HOME/.tmux.conf")" == "# the prior conf" ]]; then
  echo "   ├─ U2. ~/.tmux.conf is left as it was ✔"
else
  echo "   ├─ U2. the refused conf was written to ~/.tmux.conf" >&2
  failed=$(( failed + 1 ))
fi
_grade "U1. an unpinned plugin: ✋ names it" "$rc" 1 "$out" "pins no commit for: tmux-unvouched" \
  || failed=$(( failed + 1 ))
if [[ ! -s "$FIX/tmux.calls" && ! -e "$FIX/tpm.ran" ]]; then
  echo "   ├─ U2. no tmux call and no tpm install came before the refusal ✔"
else
  echo "   ├─ U2. the refusal came after: tmux calls '$(tr '\n' ';' < "$FIX/tmux.calls" 2>/dev/null)', tpm ran: $([[ -e "$FIX/tpm.ran" ]] && echo yes || echo no)" >&2
  failed=$(( failed + 1 ))
fi

# U3. the repo's own conf pins every plugin: the guard passes, and the run reaches the isolated server
rm -f "$FIX/tmux.calls"
out="$( grove_provision_2_8_tmux_configure_upsert 2>&1 )"; rc=$?
if [[ "$out" != *"pins no commit"* && "$out" == *"could not start an isolated tmux server"* ]]; then
  echo "   ├─ U3. the repo's own conf passes the guard ✔"
  play_snap_assert arm=U3 rendered="$out" mask="$FIX" mask="$_root" || failed=$(( failed + 1 ))
else
  echo "   ├─ U3. the repo's own conf did not pass the guard to the isolated server" >&2
  printf '%s\n' "$out" | sed 's/^/   │     /' >&2
  failed=$(( failed + 1 ))
fi

######################################################################
# C1..C7. every other variant the upsert renders, each snapped
######################################################################
# .what = a fresh HOME with tpm present and the repo's conf in the checkout
_reset() {
  chmod -R u+w "$HOME" 2>/dev/null
  rm -rf "$HOME" "$FIX/tmux.calls" "$FIX/tpm.ran"
  mkdir -p "$HOME/.tmux/plugins/tpm/bin"
  printf '%s\n' '#!/usr/bin/env bash' "echo ran >> '$FIX/tpm.ran'" > "$HOME/.tmux/plugins/tpm/bin/install_plugins"
  chmod +x "$HOME/.tmux/plugins/tpm/bin/install_plugins"
}

# .what = run the upsert in the world the caller exported; grade, then snap
_arm() {
  local label="$1" want="$2" phrase="$3" out rc
  out="$( grove_provision_2_8_tmux_configure_upsert 2>&1 )"; rc=$?
  _grade "$label" "$rc" "$want" "$out" "$phrase"
}

_reset
( export GROVE_SRC="$FIX/nosrc"
  _arm "C1. the checkout has no tmux.conf: ✋" 1 "the checkout has no tmux.conf" ) || failed=$(( failed + 1 ))

# a HOME this seat cannot write: the conf cannot land
_reset; chmod 500 "$HOME"
( _arm "C2. ~/.tmux.conf cannot be written: ✋ carries the cause" 1 "could not write ~/.tmux.conf" ) \
  || failed=$(( failed + 1 ))
chmod 700 "$HOME"

# a shadow conf on disk, a whole run after it: retired, plugins land, no server up
_reset; mkdir -p "$FIX/xdg"; printf 'set -g mouse off\n' > "$FIX/xdg/tmux.conf"
( export SHADOW="$FIX/xdg/tmux.conf" SHIM_OK=yes
  _arm "C3. a shadow conf: retired aside, and the run goes on" 0 "shadow conf retired" ) \
  || failed=$(( failed + 1 ))

# a shadow in a dir this seat cannot write: it cannot move aside
_reset; mkdir -p "$FIX/xdg"; printf 'set -g mouse off\n' > "$FIX/xdg/tmux.conf"; chmod 500 "$FIX/xdg"
( export SHADOW="$FIX/xdg/tmux.conf" SHIM_OK=yes
  _arm "C4. a shadow that will not move: ✋ carries the cause" 1 "could not move the shadow conf aside" ) \
  || failed=$(( failed + 1 ))
chmod 700 "$FIX/xdg"

_reset; rm -f "$HOME/.tmux/plugins/tpm/bin/install_plugins"
( export SHIM_OK=yes
  _arm "C5. tpm's install_plugins absent: ✋" 1 "tpm's install_plugins is absent" ) || failed=$(( failed + 1 ))

_reset
( export SHIM_OK=yes ABSENT=tmux-resurrect
  _arm "C6. tpm lands no plugin: ✋ names it" 1 "tpm did not land every plugin the conf names: tmux-resurrect" ) \
  || failed=$(( failed + 1 ))

_reset
( export SHIM_OK=yes LIVE="crewone crewtwo" SHIM_REFUSE=crewtwo
  _arm "C7. a live server will not load the conf: 🌙 names it" 0 "1 live server(s) would not load the conf: crewtwo" ) \
  || failed=$(( failed + 1 ))

######################################################################
# B. a REAL tmux on a conf it cannot parse — the premise the upsert's isolated-server ✋ rests on
#   the shim above stands in for every other arm; this one asks the build itself, on the
#   fixture's socket dir, so no live server is reachable
######################################################################
_real_tmux=""
for _cand in "$(grove_provision_2_8_tmux_pin_dst 2>/dev/null)" /usr/bin/tmux; do
  [[ -n "$_cand" && -x "$_cand" ]] && { _real_tmux="$_cand"; break; }
done
if [[ -n "$_real_tmux" ]]; then
  printf '%s\n' "set -g @plugin 'tmux-plugins/tmux-resurrect'" "this-is-not-a-tmux-command" > "$FIX/bad.conf"
  timeout -k 2 10 "$_real_tmux" -L probe_bad -f "$FIX/bad.conf" new-session -d -s t </dev/null >/dev/null 2>&1; b_start=$?
  timeout -k 2 5 "$_real_tmux" -L probe_bad has-session -t t </dev/null >/dev/null 2>&1; b_alive=$?
  b_plugins="$(timeout -k 2 5 "$_real_tmux" -L probe_bad show -gqv @plugin </dev/null 2>/dev/null)"
  b_parse_err="$(timeout -k 2 5 "$_real_tmux" -L probe_bad source-file -n "$FIX/bad.conf" </dev/null 2>&1)"; b_parse_bad=$?
  b_parse_good_err="$(timeout -k 2 5 "$_real_tmux" -L probe_bad source-file -n "$_dir/tmux.conf" </dev/null 2>&1)"; b_parse_good=$?
  timeout -k 2 5 "$_real_tmux" -L probe_bad kill-server </dev/null >/dev/null 2>&1
  # the claim the upsert's parse check rests on: a server STARTS on the bad conf with no
  #   @plugin, so a start is no proof; `-n` refuses the bad conf and passes the repo's own
  if [[ "$b_start" -eq 0 && "$b_alive" -eq 0 && -z "$b_plugins" \
        && "$b_parse_bad" -ne 0 && "$b_parse_err" == *"unknown command"* \
        && "$b_parse_good" -eq 0 && -z "$b_parse_good_err" ]]; then
    echo "   ├─ B. a real tmux starts on a bad conf, and only \`source-file -n\` names it ✔"
    play_snap_assert arm=B rendered="$(printf '%s\n' \
      "   • a server on the bad conf: starts, holds no @plugin" \
      "   • source-file -n on the bad conf: refused — $(printf '%s\n' "$b_parse_err" | head -n 1)" \
      "   • source-file -n on the repo's conf: parses")" mask="$FIX" || failed=$(( failed + 1 ))
  else
    echo "   ├─ B. on $_real_tmux: start rc=$b_start, alive rc=$b_alive, @plugin='$b_plugins', -n bad rc=$b_parse_bad, -n good rc=$b_parse_good '$b_parse_good_err'" >&2
    failed=$(( failed + 1 ))
  fi
else
  echo "   🌙 B. no tmux build on this box; the parse premise is unmeasured here"
fi

# C8. the upsert's own parse check: a conf the isolated server refuses to parse is ✋, before tpm
_reset
( export SHIM_OK=yes SHIM_REFUSE=grove_tpm
  _arm "C8. a conf that does not parse: ✋ before tpm" 1 "~/.tmux.conf does not parse" ) \
  || failed=$(( failed + 1 ))
[[ ! -e "$FIX/tpm.ran" ]] || { echo "   ├─ C8. tpm ran on a conf that does not parse" >&2; failed=$(( failed + 1 )); }

echo ""
[[ "$failed" -eq 0 ]] || { echo "   💥 MalfunctionError: $failed arm(s) failed" >&2; exit 1; }
echo "   ✔ an unpinned plugin is refused before any of its code can run"

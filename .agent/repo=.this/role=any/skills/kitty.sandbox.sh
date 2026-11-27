#!/usr/bin/env bash
######################################################################
# .what = a private kitty, on a private X display, that real keys can be
#         pressed into — and that cannot reach the human's session
#
# .why  = a key kitty maps (kitty.conf `map …`) is matched only on a real key
#         event. every remote-control path (`kitten @ send-text`, `send-key`,
#         `action`) writes past the map lookup, so a test through them proves
#         the map's input and output, never the map itself.
#         📜 measured 2026-10-25: the image-diff zoom passed every remote probe,
#         and the human's first real ctrl+= showed it shrank the image.
#
# .why a sandbox, never the human's session
#   - a press into the human's session (keyd's socket, ydotool, uinput) lets
#     any process as this user type into the focused window — a terminal with
#     a cached sudo included. no test needs that, so none is granted
#   - here the keys go by XTEST into an Xvfb this skill starts, guarded by an
#     xauth cookie in $XDG_RUNTIME_DIR (0700). only this user can reach it,
#     and any process as this user could already start one: naught new
#   - kitty reads the human's own kitty.conf, so the maps under test are real
#
# usage:
#   rhx kitty.sandbox open  --name zoom [--cwd <dir>] [--size 1600x1000] [--tmux] [-- <cmd…>]
#                                         --tmux = run cmd in a private tmux server
#   rhx kitty.sandbox press --name zoom --keys 'ctrl+equal ctrl+equal' [--settle 2]
#                                         --settle = wait N seconds after, for the app to redraw
#   rhx kitty.sandbox press --name zoom --text 'nvim a.png' --keys Return
#                                         --text = typed as literal characters, before --keys
#   rhx kitty.sandbox shot  --name zoom --into .temp/zoom.png
#   rhx kitty.sandbox text  --name zoom
#   rhx kitty.sandbox tmux  --name zoom [--settle 2] -- new-window   # the sandbox's own tmux only
#   rhx kitty.sandbox stop  --name zoom
#
#   --keys uses xdotool key names, space-separated for a sequence:
#          ctrl+equal, ctrl+minus, Escape, Return, colon, h …
#
# guarantee:
#   - open: Xvfb on a free display, xauth-guarded, no tcp; kitty on it,
#     x11 backend, its window focused and sized to the screen
#   - press/shot/text reach the sandbox only; never the human's display
#   - stop: kills both processes and removes the state dir
#   - exit 0 = done · 1 = malfunction · 2 = bad input / tool absent
######################################################################
set -uo pipefail

verb="" name="" cwd="$PWD" size="1600x1000" keys="" into="" with_tmux=0 settle="" text=""
cmd=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    open|press|shot|text|stop|tmux) verb="$1"; shift ;;
    --tmux) with_tmux=1; shift ;;
    --name) name="$2"; shift 2 ;;
    --cwd) cwd="$2"; shift 2 ;;
    --size) size="$2"; shift 2 ;;
    --keys) keys="$2"; shift 2 ;;
    --into) into="$2"; shift 2 ;;
    --settle) settle="$2"; shift 2 ;;
    --text) text="$2"; shift 2 ;;
    --skill|--repo|--role) shift 2 ;;
    --) shift; cmd=("$@"); break ;;
    --help|-h) verb="help"; shift ;;
    *) echo "✋ ConstraintError: kitty.sandbox: unknown arg '$1'" >&2; exit 2 ;;
  esac
done

if [[ "$verb" == "help" || -z "$verb" ]]; then
  echo "kitty.sandbox — a private kitty on a private X display, for real key presses"
  echo "  open  --name <n> [--cwd <dir>] [--size WxH] [--tmux] [-- <cmd…>]"
  echo "  press --name <n> [--text '<literal>'] [--keys '<xdotool keys>'] [--settle <secs>]"
  echo "  shot  --name <n> --into <png>"
  echo "  text  --name <n>"
  echo "  tmux  --name <n> [--settle <secs>] -- <tmux args…>   (the sandbox's own tmux server)"
  echo "  stop  --name <n>"
  exit 0
fi

echo "🐢 sandbox surf"
echo ""
echo "🧪 kitty.sandbox $verb --name '$name'"

if [[ -z "$name" || ! "$name" =~ ^[a-z0-9-]+$ ]]; then
  echo "   └─ ✋ ConstraintError: --name required, lowercase letters, digits, dashes" >&2
  exit 2
fi

if [[ -z "${XDG_RUNTIME_DIR:-}" ]]; then
  echo "   └─ ✋ ConstraintError: no \$XDG_RUNTIME_DIR, so no private dir for the xauth cookie" >&2
  exit 2
fi
state="$XDG_RUNTIME_DIR/kitty.sandbox/$name"
tmux_sock="kitty-sandbox-$name"

# the sandbox's own display env — never the human's. the caller's tmux and
# kitty handles are dropped too, so a tmux started inside is a fresh one and
# a kitty remote call reaches the sandbox kitty, never the caller's
sandbox_env() {
  env -u WAYLAND_DISPLAY -u TMUX -u TMUX_PANE -u KITTY_LISTEN_ON -u KITTY_WINDOW_ID \
    KITTY_DISABLE_WAYLAND=1 \
    DISPLAY=":$(cat "$state/display")" XAUTHORITY="$state/Xauthority" "$@"
}

# the sandbox kitty's VISIBLE window, looked up fresh on each call
#   - by class, never by pid: kitty's window carries no _NET_WM_PID that
#     matches the launch pid, and this display holds only our kitty anyway
#   - `--onlyvisible`, and never a saved id: kitty makes more than one X
#     window, and an id saved at open named one that later read BadWindow
sandbox_window() {
  sandbox_env xdotool search --onlyvisible --class kitty 2>/dev/null | tail -n 1
}

require_live() {
  if [[ ! -f "$state/display" ]] || ! kill -0 "$(cat "$state/xvfb.pid" 2>/dev/null)" 2>/dev/null; then
    echo "   └─ ✋ ConstraintError: no live sandbox '$name'" >&2
    echo "      fix: rhx kitty.sandbox open --name $name" >&2
    exit 2
  fi
}

require_bins() {
  local bin absent=()
  for bin in "$@"; do command -v "$bin" >/dev/null || absent+=("$bin"); done
  (( ${#absent[@]} == 0 )) && return 0
  echo "   └─ ✋ ConstraintError: absent from PATH: ${absent[*]}" >&2
  echo "      fix: sudo -v && rhx grove.provision --what 5.20.xvfb --mode apply" >&2
  exit 2
}

case "$verb" in
  open)
    require_bins Xvfb xdotool xauth mcookie kitty
    if [[ -f "$state/xvfb.pid" ]] && kill -0 "$(cat "$state/xvfb.pid")" 2>/dev/null; then
      echo "   └─ ✋ ConstraintError: sandbox '$name' is already open (display :$(cat "$state/display"))" >&2
      echo "      fix: rhx kitty.sandbox stop --name $name" >&2
      exit 2
    fi
    mkdir -p "$state" && chmod 700 "$state"

    # a free display number: no socket, no lock
    d=90
    while [[ -e "/tmp/.X11-unix/X$d" || -e "/tmp/.X$d-lock" ]]; do d=$(( d + 1 )); done
    echo "$d" > "$state/display"

    # an xauth cookie, so only this user's processes can reach the display
    : > "$state/Xauthority"
    xauth -f "$state/Xauthority" add ":$d" . "$(mcookie)" || {
      echo "   └─ 💥 MalfunctionError: xauth refused the cookie" >&2; exit 1; }

    setsid Xvfb ":$d" -screen 0 "${size}x24" -nolisten tcp -auth "$state/Xauthority" \
      >"$state/xvfb.log" 2>&1 < /dev/null &
    echo $! > "$state/xvfb.pid"
    for _ in $(seq 50); do [[ -S "/tmp/.X11-unix/X$d" ]] && break; sleep 0.1; done
    if [[ ! -S "/tmp/.X11-unix/X$d" ]]; then
      echo "   └─ 💥 MalfunctionError: Xvfb did not come up on :$d" >&2
      sed 's/^/      /' "$state/xvfb.log" >&2
      exit 1
    fi
    echo "   ├─ display :$d (Xvfb, ${size}, xauth-guarded, no tcp)"

    (( ${#cmd[@]} == 0 )) && cmd=("${SHELL:-bash}")
    # --tmux: wrap the cmd in a PRIVATE tmux server (the human's tmux.conf,
    # its own socket), so the human's tmux sessions are never touched and
    # `stop` can kill it — a tmux outlives the kitty that attached it
    if (( with_tmux )); then
      cmd=(tmux -L "$tmux_sock" new-session -s "$name" -c "$cwd" "${cmd[@]}")
    fi
    sandbox_env setsid kitty -o allow_remote_control=socket-only \
      --listen-on "unix:$state/kitty.sock" --directory "$cwd" "${cmd[@]}" \
      >"$state/kitty.log" 2>&1 < /dev/null &
    echo $! > "$state/kitty.pid"

    wid=""
    for _ in $(seq 100); do
      wid="$(sandbox_window)"
      [[ -n "$wid" ]] && break
      sleep 0.1
    done
    if [[ -z "$wid" ]]; then
      echo "   └─ 💥 MalfunctionError: kitty opened no window on :$d" >&2
      sed 's/^/      /' "$state/kitty.log" >&2
      exit 1
    fi

    # no window manager here, so size, place, and focus the window by hand
    w="${size%x*}"; h="${size#*x}"
    sandbox_env xdotool windowmove "$wid" 0 0 windowsize "$wid" "$w" "$h" \
      mousemove --window "$wid" 10 10 windowfocus --sync "$wid"
    echo "   ├─ kitty pid $(cat "$state/kitty.pid"), window $wid, focused"
    echo "   └─ cmd: ${cmd[*]} (in $cwd)"
    ;;

  press)
    require_bins xdotool
    require_live
    if [[ -z "$keys" && -z "$text" ]]; then
      echo "   └─ ✋ ConstraintError: --keys or --text required, e.g. --keys 'ctrl+equal'" >&2
      exit 2
    fi
    if [[ -n "$settle" && ! "$settle" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
      echo "   └─ ✋ ConstraintError: --settle takes seconds, e.g. 2 or 0.5" >&2
      exit 2
    fi
    keylist=()
    [[ -n "$keys" ]] && read -ra keylist <<< "$keys"
    # refocus first: a press must land in the sandbox kitty and no other window
    wid="$(sandbox_window)"
    if [[ -z "$wid" ]] || ! sandbox_env xdotool windowfocus --sync "$wid"; then
      echo "   └─ 💥 MalfunctionError: could not focus the sandbox kitty (no visible window)" >&2
      exit 1
    fi
    # --text first (typed as literal characters), then --keys (named keys)
    if [[ -n "$text" ]]; then
      sandbox_env xdotool type --clearmodifiers --delay 20 -- "$text" || {
        echo "   └─ 💥 MalfunctionError: xdotool refused the text" >&2; exit 1; }
    fi
    if (( ${#keylist[@]} > 0 )); then
      sandbox_env xdotool key --clearmodifiers --delay 150 "${keylist[@]}" || {
        echo "   └─ 💥 MalfunctionError: xdotool refused the keys" >&2; exit 1; }
    fi
    [[ -n "$text" ]] && keylist=("text:'$text'" "${keylist[@]}")
    # --settle: the app's answer to a key is async (a render, a redraw), so a
    # shot taken at once reads the screen BEFORE the key took effect
    if [[ -n "$settle" ]]; then
      echo "   ├─ pressed ✔ ${keylist[*]} (XTEST, display :$(cat "$state/display") only)"
      sleep "$settle"
      echo "   └─ settled ${settle}s"
    else
      echo "   └─ pressed ✔ ${keylist[*]} (XTEST, display :$(cat "$state/display") only)"
    fi
    ;;

  shot)
    require_bins import
    require_live
    if [[ -z "$into" ]]; then
      echo "   └─ ✋ ConstraintError: --into <png> required" >&2
      exit 2
    fi
    mkdir -p "$(dirname "$into")"
    sandbox_env import -window root "$into" || {
      echo "   └─ 💥 MalfunctionError: could not capture display :$(cat "$state/display")" >&2; exit 1; }
    echo "   └─ captured ✔ $into"
    ;;

  tmux)
    # a command to the sandbox's OWN tmux server (its private -L socket) — a
    # window switch, a pane split. never the human's tmux, by construction
    require_live
    if (( ${#cmd[@]} == 0 )); then
      echo "   └─ ✋ ConstraintError: a tmux command is owed after --, e.g. -- new-window" >&2
      exit 2
    fi
    sandbox_env tmux -L "$tmux_sock" "${cmd[@]}" || {
      echo "   └─ 💥 MalfunctionError: tmux refused: ${cmd[*]}" >&2; exit 1; }
    [[ -n "$settle" ]] && sleep "$settle"
    echo "   └─ tmux ✔ ${cmd[*]} (server $tmux_sock only)"
    ;;

  text)
    require_live
    echo "   └─ screen"
    kitten @ --to "unix:$state/kitty.sock" get-text | sed 's/^/      │ /'
    ;;

  stop)
    # the private tmux first — it outlives kitty, and keeps its cmd alive
    tmux -L "$tmux_sock" kill-server 2>/dev/null
    # a server that died unclean leaves its socket, and 2.8.tmux's verify then counts
    #   it as a live server that will not load the conf. remove it once none answers
    sock_path="${TMUX_TMPDIR:-/tmp}/tmux-$(id -u)/$tmux_sock"
    [[ -S "$sock_path" ]] && ! tmux -L "$tmux_sock" list-sessions >/dev/null 2>&1 && rm -f "$sock_path"
    for f in kitty.pid xvfb.pid; do
      [[ -f "$state/$f" ]] && kill "$(cat "$state/$f")" 2>/dev/null
    done
    rm -rf "$state"
    echo "   └─ stopped ✔ (private tmux, kitty, Xvfb, state dir)"
    ;;

  *)
    echo "   └─ ✋ ConstraintError: unknown verb '$verb' (open · press · shot · text · tmux · stop)" >&2
    exit 2
    ;;
esac

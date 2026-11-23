#!/usr/bin/env bash
######################################################################
# .what = read the camper seat's live shell, and fail unless a new terminal
#         there shows the starship prompt
#
# .why  = the prompt is the first line a human reads on a grove, and a bare
#         `camper@host:~$` says the shell config never landed.
#         📜 2026-11-20, a hetzner grove: camper's terminal
#         opened at the bash default prompt
#
# guarantee:
#   - runs on the camper seat; declines (exit 2) on any other
#   - READ-ONLY: names each fact by path, never edits one
######################################################################

set -u

if [[ "$(id -un)" != "camper" ]]; then
  echo "🌙 prove.camper-prompt-is-starship declines: $(id -un) is not the camper seat"
  echo "   run it there: rhx git.grove.send <grove> --reply --play prove.camper-prompt-is-starship"
  exit 2
fi

failed=0
held() { echo "   • $1 ✔"; }
miss() { echo "   ✋ ConstraintError: $1"; failed=1; }

echo "🔬 prove.camper-prompt-is-starship"

# the login shell: the record a new terminal (ssh, tmux, kitty) execs first
login="$(getent passwd camper | cut -d: -f7)"
[[ "$login" == */zsh ]] && held "login shell is zsh ($login)" || miss "login shell is '$login', not zsh"

# the shell a NEW tmux pane execs: tmux's `default-shell`, which tmux takes from the
#   server's own $SHELL at server start — so a server born before a chsh keeps the old shell
#   each probe is bounded and fed no stdin: a wedged tmux server never replies, and an
#   interactive rc that waits on a lock or a prompt would hold the play with no verdict
if timeout -k 2 10 tmux list-sessions </dev/null >/dev/null 2>&1; then
  ts="$(timeout -k 2 10 tmux show-options -gv default-shell </dev/null 2>/dev/null)"
  [[ "$ts" == */zsh ]] && held "a new tmux pane execs zsh ($ts)" \
    || miss "a new tmux pane execs '$ts' — the tmux server predates the login shell"
fi

# the binary, as an INTERACTIVE shell resolves it (a login shell's PATH, not this play's)
#   each probe runs in its own session (`setsid -w`), with no terminal of its own. a play
#   sent down a duct holds the pane's tty, and an interactive bash there takes job control
#   from a background process group: the kernel stops it, and the bound kills it with no
#   answer, so the probe read empty on a seat whose PATH was sound (measured on a hetzner grove)
ishell() { timeout -k 2 20 setsid -w "$1" -ilc "$2" </dev/null 2>/dev/null | grep '^/' | tail -1; }
bin="$(ishell zsh 'command -v starship')"
[[ -n "$bin" ]] && held "starship on an interactive zsh PATH ($bin)" || miss "starship is absent from an interactive zsh PATH"
bbin="$(ishell bash 'command -v starship')"
if [[ -n "$bbin" ]]; then
  held "starship on an interactive bash PATH ($bbin)"
else
  # name the cause: bash -l reads the FIRST of these it finds, and only that one
  first="$(for f in ~/.bash_profile ~/.bash_login ~/.profile; do [[ -e "$f" ]] && { echo "$f"; break; }; done)"
  bpath="$(ishell bash 'echo "$PATH"')"
  miss "starship is absent from an interactive bash PATH (login file: ${first:-none}; PATH: ${bpath:-no answer within 20s})"
fi

# the hook, in each rc a shell reads
for rc in ~/.zshrc ~/.bashrc; do
  if [[ ! -f "$rc" ]]; then miss "$rc is absent"; continue; fi
  # either form: zshrc's `starship init zsh`, or bashrc's `".../starship" init bash`
  grep -qE 'starship"? init' "$rc" && held "$rc runs starship init" || miss "$rc runs no starship init"
done

# the config it renders
[[ -f ~/.config/starship.toml ]] && held "~/.config/starship.toml present" || miss "~/.config/starship.toml is absent"

# ⚠️ no read of a live PROMPT here: each rc inits starship only on a tty (`-t 1`), and a
#   play's shell has none, so such a read reports the no-tty default on every box

[[ "$failed" -eq 0 ]] && { echo "   └─ a new camper terminal shows starship ✔"; exit 0; }
echo "   └─ ✋ ConstraintError: a new camper terminal does not show starship — each ✋ above is a cause"
exit 1

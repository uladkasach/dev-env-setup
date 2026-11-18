import os

from kitty.boss import Boss
from kittens.tui.handler import result_handler

# super+v — a keyboard-only line selector over what the window shows
#
# .the gesture, the same in both holders
#   - super+v        enter the selector view (and again, to leave it)
#   - right-alt+j/k  move a line down / up (keyd turns them into plain down / up)
#   - enter          begin a line selection; enter again ends it
#   - ctrl+c         copy the selection, and stay in the view
#   - ctrl+x, q, esc leave the view
#
# 🛑 the view is ALWAYS nvim, over the history of whoever owns the SCROLLBACK —
#   the same one fact scroll_window.py reads
#   - a tmux client holds its own 50k history, and kitty's sits empty behind it
#     ⇒ only tmux can read that history, so tmux opens the nvim view, in a popup
#       over the pane (2.8.tmux/tmux.conf); this kitten just hands it the key
#   - no tmux ⇒ kitty owns the history ⇒ this kitten opens the nvim view itself,
#     in an overlay over the window
#   - both source one setup, ~/.config/nvim/visual_select.lua, so one gesture
#     holds in both
#
# .why `var:in_tmux` and never `is_main_linebuf`
#   - scroll_window.py asks "main or alternate screen?" because a scroll must reach
#     whichever app holds the alternate screen — nvim, less, tmux alike
#   - this asks "is a TMUX client in front?", a narrower question: an nvim or a
#     less on the alternate screen has no tmux to hand the key to
#   - the tmux hooks in 2.8.tmux/tmux.conf set `in_tmux` on attach and clear it on
#     detach; over ssh the far tmux writes the same var back through the pty
VAR_TMUX = 'in_tmux'
VAR_VIEW = 'visual_select'
# set on the WINDOW by tmux's popup view, never on an overlay — a distinct name,
# since VAR_VIEW on a window means "close this window", and this window is the
# human's shell
VAR_TMUX_VIEW = 'visual_select_tmux'

# the key handed to tmux, as tmux `user-keys[0]` (2.8.tmux/tmux.conf)
#
# 🛑 NOT super+v's own CSI-u form (CSI 118;9u) — TMUX HAS NO SUPER
#   - tmux holds three modifiers (C-, M-, S-) and drops the super bit, so it
#     would bind and forward a bare `v` (see ctrl+super+r in kitty.conf)
#   - a private `CSI 9999 ~` matches no key tmux parses, so its user-keys table
#     is the one place it can land — and it lands there intact
#   - a FIXED byte string is safe: it goes to a tmux client only, never an app
# ⚠️ this sequence has a TWIN in 2.8.tmux/tmux.conf; a change to one owes the other
TMUX_KEY = b'\x1b[9999~'

# the nvim setup that turns the overlay into the selector. 4.5.nvim owns it, since
# tmux's super+v popup sources the SAME file (2.8.tmux/tmux.conf) — on a grove
# too, where no kitty config exists. one file, so both holders bind one gesture
PAGER_SETUP = os.path.expanduser('~/.config/nvim/visual_select.lua')


def _tmux_in_front(window, user_vars) -> bool:
    """
    .what = does a tmux client hold this window?
    .why  = 🛑 a wrong NO opens kitty's overlay over kitty's own scrollback,
            which behind tmux holds only the screen — the view then lands at
            the top of the screen with no history above it
            - the `in_tmux` mark alone can be absent: a client attached before
              the hooks existed, or one whose mark a detach elsewhere cleared
            - so a LOCAL tmux is also read off the window's foreground process,
              a fact kitty measures live and that cannot go stale
            - over ssh the process in front is ssh, so a grove's tmux is still
              known by the mark its hooks write back through the pty
    """
    if user_vars.get(VAR_TMUX):
        return True
    # `foreground_cmdline` reads the pty's foreground process group — measured
    # right where `foreground_processes` came back EMPTY (prove.visual-select-keys)
    try:
        cmdline = window.child.foreground_cmdline or []
    except Exception:
        return False
    return bool(cmdline) and os.path.basename(cmdline[0]).startswith('tmux')


def _record(window) -> dict:
    """
    .what = what kitty holds for this window, at the press: which screen, how
            much history, which process is in front — kept as the last press
    .why  = "the view shows no history" has several causes (an app on the
            alternate screen, a cleared scrollback, tmux unseen in front), and
            each wants a different fix. the record names which one fired
    """
    facts = {'main_screen': True, 'history_lines': None, 'foreground': None}
    try:
        facts['main_screen'] = bool(window.screen.is_main_linebuf())
        facts['history_lines'] = window.screen.historybuf.count
        facts['foreground'] = window.child.foreground_cmdline
    except Exception as error:
        facts['error'] = repr(error)
    try:
        import json
        path = os.path.expanduser('~/.cache/visual_select.last.json')
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, 'w') as f:
            json.dump(facts, f)
    except OSError:
        pass
    return facts


@result_handler(no_ui=True)
def handle_result(args, answer, target_window_id, boss: Boss) -> None:
    window = boss.window_id_map.get(target_window_id)
    if window is None:
        return
    user_vars = getattr(window, 'user_vars', {}) or {}

    # the overlay this kitten opened: super+v again closes it
    if user_vars.get(VAR_VIEW):
        boss.mark_window_for_close(window)
        return

    # tmux's popup view is open: super+v again closes it
    #   - tmux runs no key bind while a popup is open, so TMUX_KEY would reach
    #     the popup's nvim as noise; escape is the key that nvim leaves on
    #   - the popup's nvim sets this var on open and clears it on leave
    #     (4.5.nvim/visual_select.lua)
    if user_vars.get(VAR_TMUX_VIEW):
        window.write_to_child(b'\x1b')
        return

    # a tmux client in front: tmux owns the history, so tmux opens the view
    if _tmux_in_front(window, user_vars):
        window.write_to_child(TMUX_KEY)
        return

    # no tmux: kitty owns the history, so open it in an nvim overlay
    #   - `@screen_scrollback` is the history plus the screen, plain text
    #   - nvim reads it from stdin (`-`) and draws on the overlay's own tty
    #   - `-R -n`: read-only, no swap file — a view, never a file to save
    #   - the full init.lua loads, so <C-S-c> yanks to the clipboard and toasts,
    #     exactly as in any nvim; the setup file only adds the selector keys
    #
    # 🛑 a refused launch must be LOUD, never a dead key
    #   - a dead super+v cannot be told apart from a broken bind, so a human
    #     would blame the keyboard, the desktop, or tmux
    #   - kitty's own error window names what failed and where the fix lives;
    #     the exception is shown whole, never swallowed (rule.forbid.failhide)
    #
    # 🛑 on the ALTERNATE screen there is no history to read
    #   - a full-screen app (nvim, less, a TUI) draws on the alternate screen,
    #     which kitty keeps with NO scrollback: the app holds its own history
    #   - the view then holds one screen and gg / k have no place to go — said
    #     out loud in the view (visual_select.lua), never left to look broken
    facts = _record(window)
    notice = '' if facts['main_screen'] else (
        'this app draws on the alternate screen, where kitty keeps no history; '
        'only its current screen is here. scroll within the app for the rest'
    )
    try:
        boss.call_remote_control(window, (
            'launch', '--type=overlay', '--stdin-source=@screen_scrollback',
            '--env', f'VISUAL_SELECT_NOTICE={notice}',
            '--var', f'{VAR_VIEW}=1', '--title', 'visual select',
            'nvim', '-R', '-n', '-S', PAGER_SETUP, '-',
        ))
    except Exception as error:
        boss.show_error(
            'super+v: the visual select overlay did not open',
            f'kitty refused the overlay launch: {error!r}\n\n'
            'the kitten is visual_select.py in the 4.3.2.emulator bundle.\n'
            'in a tmux duct, super+v opens through tmux and is unaffected.',
        )


def main(args):
    pass

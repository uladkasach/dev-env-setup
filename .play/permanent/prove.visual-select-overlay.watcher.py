# prove.visual-select-overlay.watcher.py — runs INSIDE a scratch kitty
#
# .what = on a window with no tmux and more history than fits the screen:
#         1. measure how many lines kitty pipes to an overlay from
#            `@screen_scrollback` — the source the super+v kitten reads
#         2. call the super+v kitten exactly as kitty's map does, and read back
#            whether the nvim overlay opened, at the terminal's own width
#         3. call it again, and read back that the overlay closed
#
# .why  = the kitten's no-tmux branch asks kitty to `launch` an overlay through
#         `boss.call_remote_control`, under the human's `allow_remote_control no`.
#         only a real kitty can say what that launch receives and draws. a
#         watcher is code kitty itself loads, so it reaches the same Boss a
#         keypress would — with no key injected into the human's desktop
#
# .the env
#   VISUAL_SELECT_PROOF_OUT    where to write the rows; set by the play
#   VISUAL_SELECT_PROOF_LINES  how many lines the base window printed
#
# .rows written: <row>=<hit|miss> want=<…> got=<…>, then done=1
import importlib.util
import os

from kitty.constants import config_dir
from kitty.fast_data_types import add_timer

OUT = os.environ.get('VISUAL_SELECT_PROOF_OUT', '')
LINES = int(os.environ.get('VISUAL_SELECT_PROOF_LINES', '300'))
COUNT = OUT + '.count'
_state = {'begun': False, 'polls': 0, 'base': None}


def _say(line):
    with open(OUT, 'a') as f:
        f.write(line + '\n')


def _row(name, got, want):
    _say(f"{name}={'hit' if got == want else 'miss'} want={want} got={got}")


def _finish(boss):
    _say('done=1')
    os._exit(0)


def _kitten():
    # the DEPLOYED kitten, the file kitty's map runs
    path = os.path.join(config_dir, 'visual_select.py')
    spec = importlib.util.spec_from_file_location('visual_select_under_proof', path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def _overlay(boss):
    for w in boss.all_windows:
        if (getattr(w, 'user_vars', {}) or {}).get('visual_select'):
            return w
    return None


def _after(delay, fn):
    add_timer(lambda timer_id=None: fn(), delay, False)


# stage 1 — what does `@screen_scrollback` hand an overlay?
def _measure(boss, window):
    boss.call_remote_control(window, (
        'launch', '--type=overlay', '--stdin-source=@screen_scrollback',
        'sh', '-c', f'wc -l > "{COUNT}"',
    ))

    def read(tries=0):
        got = ''
        if os.path.exists(COUNT):
            with open(COUNT) as f:
                got = f.read().strip()
        if not got and tries < 20:
            return _after(0.25, lambda: read(tries + 1))
        count = int(got) if got.isdigit() else -1
        _say(f'scrollback_lines_piped={count}')
        _row('history_reaches_the_overlay', str(count >= LINES), 'True')
        _after(0.5, lambda: _open(boss, window))
    _after(0.5, read)


# stage 2 — the kitten opens nvim over it
def _open(boss, window):
    try:
        _kitten().handle_result([], None, window.id, boss)
    except Exception as error:
        _say(f'kitten_raised=miss want=none got={error!r}')
        return _finish(boss)

    def tick():
        _state['polls'] += 1
        overlay = _overlay(boss)
        # as_text() reads whichever screen is ACTIVE — nvim's, here
        text = overlay.as_text() if overlay else ''
        # nvim draws the scrollback once its config has loaded; give it time
        #   - the status line draws a beat after the text, so await both
        drawn = overlay is not None and str(LINES) in text and ' bot' in text
        if not drawn and _state['polls'] < 40:
            return _after(0.25, tick)
        _row('overlay_opened', str(overlay is not None), 'True')
        _row('overlay_shows_the_last_line', str(str(LINES) in text), 'True')
        # the view keeps the terminal's width: a screen row that reads exactly
        # the last line has no number gutter left of it and no minimap right
        rows = [r.rstrip() for r in text.splitlines()]
        _row('a_row_is_bare_text', str(str(LINES) in rows), 'True')
        # nvim's status line names the buffer's line count: the whole history,
        # not just the screen, must have arrived
        #   - the cmdline row sits below the status line, so any row may hold it
        #   - the cursor opens on the last line of text, at or past the last
        #     printed one, so read its line number and need at least LINES
        import re
        found = [int(m.group(1)) for r in rows for m in [re.search(r'\b(\d+):\d+\s+bot\b', r)] if m]
        holds = bool(found) and found[0] >= LINES
        _row('nvim_holds_every_line', str(holds), 'True')
        if not holds:
            _say(f'drawn={[r for r in rows if r][-3:]!r}')
        if overlay is None:
            return _finish(boss)
        # stage 3 — super+v again, from inside the overlay, must close it
        _kitten().handle_result([], None, overlay.id, boss)
        _after(1.0, lambda: (_row('super_v_again_closes_it', str(_overlay(boss) is None), 'True'), _finish(boss)))
    _after(0.5, tick)


# the tmux mode — the kitty window holds a real tmux session
def _await(check, then, label, tries=0):
    if check():
        return then()
    if tries >= 60:
        _say(f'{label}=miss want=True got=False')
        return None
    _after(0.25, lambda: _await(check, then, label, tries + 1))


def _tmux_flow(boss, window):
    def var(name):
        return bool((getattr(window, 'user_vars', {}) or {}).get(name))

    def drawn():
        rows = [r.rstrip() for r in window.as_text().splitlines()]
        return any(r.startswith((' normal ', ' v-line ')) for r in rows)

    def tmux_marked():
        _row('tmux_marks_the_window', 'True', 'True')
        # 🛑 the clamp: strip the mark, as a window attached before the hooks
        #    existed would lack it. the kitten must still find tmux in front, or
        #    it opens kitty's overlay over a scrollback that holds only the screen
        (getattr(window, 'user_vars', {}) or {}).pop('in_tmux', None)
        _kitten().handle_result([], None, window.id, boss)
        _await(lambda: var('visual_select_tmux') and drawn(), opened, 'popup_view_opened')

    def opened():
        _row('popup_view_opened', 'True', 'True')
        _row('popup_marks_the_window', str(var('visual_select_tmux')), 'True')
        rows = [r.rstrip() for r in window.as_text().splitlines()]
        _row('popup_shows_the_history_bare', str(str(LINES) in rows), 'True')
        # super+v again: the kitten reads the popup's mark and sends escape
        _kitten().handle_result([], None, window.id, boss)
        _await(lambda: not var('visual_select_tmux') and not drawn(), closed, 'super_v_again_closes_the_popup')

    def closed():
        _row('super_v_again_closes_the_popup', 'True', 'True')
        _finish(boss)

    _await(lambda: var('in_tmux'), tmux_marked, 'tmux_marks_the_window')
    _after(25, lambda: _finish(boss))


def _start(boss, window):
    if _state['begun'] or not OUT:
        return
    _state['begun'] = True
    _state['base'] = window.id
    # let the base window print its lines before the first read
    if os.environ.get('VISUAL_SELECT_PROOF_MODE') == 'tmux':
        _after(1.5, lambda: _tmux_flow(boss, window))
        return
    _after(1.5, lambda: _measure(boss, window))


def on_resize(boss, window, data):
    _start(boss, window)


def on_focus_change(boss, window, data):
    _start(boss, window)

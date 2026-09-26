from kitty.boss import Boss
from kittens.tui.handler import result_handler

# the key this kitten hands back to the child, when the child owns the buffer
#
# ⚠️ a FIXED byte string is safe HERE, and it is NOT safe in general
#   - kitty.conf reaches for `send_key` over `send_text` on ctrl+super+r for
#     exactly the opposite reason: a ctrl+alt+LETTER encodes one way for a
#     legacy app and another for one that negotiated the kitty protocol, so no
#     single string can be right for both
#   - an ARROW is a legacy CSI key, and every protocol spells it the same
#   - measured 2026-09-24, kitty 0.47.4, via kitty's own `encode_key_for_tty`:
#       flags 0 (legacy), 1 (disambiguate), 15 (all) → '\x1b[1;5A' / '\x1b[1;5B'
#   - ⇒ one string serves a shell, a tmux client, and an nvim alike
FORWARD = {'up': b'\x1b[1;5A', 'down': b'\x1b[1;5B'}

SCROLL = {'up': 'scroll_line_up', 'down': 'scroll_line_down'}

# lines per press
#
# ⚠️ this number has a TWIN in 2.8.tmux/tmux.conf (`send -N`), and the two are
#   two runtimes rather than two copies of one list — kitty scrolls its own
#   buffer, tmux scrolls the 50k, and neither can read the other's constant
#   - ⇒ a change here wants the same change there, or the tick speed forks by
#     which screen the pane happens to hold
LINES = 3

# 🛑 `smooth=False`, and the count is a LOOP — measured 2026-09-24, kitty 0.47.4
#
# .why not `scroll_fractional_lines(amt)`, which reads like the count API
#   - its amt is pixel geometry, never lines. against a real Screen it landed
#     -1.0 → 2 lines, -2.0 → 3, -3.0 → 4 — an off-by-one AND a wrong slope
#   - `smooth=True` routes through that same fractional path
#   - ⇒ a `LINES`-shaped number fed to it would scroll some other distance, and
#     read as a number to tune rather than as a wrong unit
#
# .what the discrete path does instead
#   - `screen.scroll(SCROLL_LINE, upwards)` moved exactly 1 line per call,
#     linear across 4 calls: 1, 2, 3, 4
#   - `smooth=False` is the arm that reaches it
#   - ⇒ N calls move N lines, by measurement rather than by inference
SMOOTH = False


@result_handler(no_ui=True)
def handle_result(args, answer, target_window_id, boss: Boss) -> None:
    # the direction is picked OUT of args rather than indexed off it
    #   - a kitten's argv[0] is the kitten name, so args[1] would be the
    #     direction today and args[0] if kitty ever drops the name
    #   - a membership scan is right under either shape
    direction = next((a for a in args if a in FORWARD), None)
    if direction is None:
        return

    window = boss.window_id_map.get(target_window_id)
    if window is None:
        return

    # 🛑 the MAIN linebuf is the only place a kitty scrollback exists
    #
    # .the test names the HOLDER, which is the whole question
    #   - on the ALTERNATE screen the buffer belongs to whoever took it: a tmux
    #     client (50k of history), an nvim, a less
    #   - kitty's own scroll actions already no-op there — `scroll_line_up`
    #     reads this same `is_main_linebuf` and returns early
    #   - ⇒ a kitty-side scroll in a tmux pane is a DEAD KEY, which is the one
    #     shape a human cannot tell apart from a broken bind
    #
    # .so the alternate screen forwards, and every case falls out right
    #   - a local tmux pane → its own `C-Up` bind scrolls the 50k (2.8.tmux)
    #   - a duct past an ssh hop → ssh is a byte pipe, so the FAR tmux meets
    #     the same bind this repo declares there
    #   - a bare remote shell → MAIN screen, so kitty scrolls its own buffer,
    #     which is where that remote output actually landed
    #   - an app that binds neither → an inert arrow, never a signal
    #
    # ⚠️ ONE reader of one fact, deliberately. the alternative — trust the
    #   falsy return of `scroll_line_up` — reads the same state through a value
    #   kitty types `bool | None`, so a future kitty that returns True
    #   unconditionally would kill the forward with no signal at all
    if window.screen.is_main_linebuf():
        scroll = getattr(window, SCROLL[direction])
        for _ in range(LINES):
            scroll(SMOOTH)
        return

    window.write_to_child(FORWARD[direction])


def main(args):
    pass

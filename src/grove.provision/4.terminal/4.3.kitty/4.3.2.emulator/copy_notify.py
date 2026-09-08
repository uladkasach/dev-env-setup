import os
import subprocess

from kitty.boss import Boss
from kitty.clipboard import set_clipboard_string
from kittens.tui.handler import result_handler

# 🛑 ctrl+c / ctrl+shift+c must NEVER interrupt any receiver
#   - the forward (CSI 99;6u) goes to a strict allowlist of apps that copy on it
#   - nvim yanks it via <C-S-c> -> "+y
#   - every other app reads a ctrl+c-family key as interrupt, so it is never sent
#   - fail closed: an app we cannot confirm as allowed gets none of it
#
# ⚠️ the allowlist is ONE of three reasons to forward, not the only one. it is
#   the only one that names an APP; the other two hold because no app is in the
#   loop at all — tmux copy-mode swallows the key, and over ssh the far tmux
#   decides. all three are gathered in `handle_result` at the bottom.
FORWARD_ALLOWLIST = {'nvim'}


def _comm(pid: int) -> str:
    try:
        with open('/proc/%d/comm' % pid) as fh:
            return fh.read().strip()
    except Exception:
        return ''


def _child_map() -> dict:
    kids = {}
    for name in os.listdir('/proc'):
        if not name.isdigit():
            continue
        pid = int(name)
        try:
            with open('/proc/%d/stat' % pid) as fh:
                data = fh.read()
            ppid = int(data[data.rindex(')') + 1:].split()[1])
        except Exception:
            continue
        kids.setdefault(ppid, []).append(pid)
    return kids


def _subtree(root: int, kids: dict) -> list:
    out = []
    stack = list(kids.get(root, []))
    while stack:
        pid = stack.pop()
        out.append(pid)
        stack.extend(kids.get(pid, []))
    return out


def _tmux_client_tty(pids: list) -> str:
    # a tmux client in the subtree owns the kitty pty as its stdin
    #   - so readlink of fd/0 yields the /dev/pts/N that matches tmux's #{client_tty}
    for pid in pids:
        if _comm(pid).startswith('tmux'):
            try:
                return os.readlink('/proc/%d/fd/0' % pid)
            except Exception:
                pass
    return ''


def _tmux_active_pane(client_tty: str) -> tuple:
    # ask tmux about the active pane of this client's session
    #   - returns (command, in_copy_mode)
    #   - fail closed (return ('', False)) on any error, so the caller forwards none
    try:
        clients = subprocess.check_output(
            ['tmux', 'list-clients', '-F', '#{client_tty}\t#{session_name}'],
            timeout=1,
        ).decode()
    except Exception:
        return ('', False)
    session = ''
    for line in clients.splitlines():
        parts = line.split('\t')
        if len(parts) == 2 and parts[0] == client_tty:
            session = parts[1]
            break
    if not session:
        return ('', False)
    try:
        panes = subprocess.check_output(
            ['tmux', 'list-panes', '-t', session, '-F',
             '#{pane_active}\t#{pane_in_mode}\t#{pane_current_command}'],
            timeout=1,
        ).decode()
    except Exception:
        return ('', False)
    for line in panes.splitlines():
        parts = line.split('\t')
        if len(parts) == 3 and parts[0] == '1':
            return (parts[2].strip(), parts[1].strip() == '1')
    return ('', False)


def _subtree_has_ssh(pids: list) -> bool:
    # the LOCAL half of a remote duct: kitty → zsh → ssh → (far host) tmux → nvim
    #
    # 🛑 a REMOTE duct cannot be judged from HERE, so the judgment moves THERE
    #   - the far host runs nvim; this box runs only the ssh client, so every
    #     local reader (/proc, tmux, foreground_processes) answers 'ssh'
    #   - 📜 that read as "an unknown app", so the allowlist sent no forward and
    #     a visual-mode ctrl+c was a silent no-op on every grove
    #   - ⚠️ it read as WORKING, because the copy branch always runs: a kitty
    #     mouse-drag still copied and still toasted. one path green hid the
    #     other path dead
    #
    # ⇒ so kitty DELIVERS and tmux DECIDES
    #   - ssh is a byte pipe, so CSI 99;6u rides it to the far tmux
    #   - `tmux.conf` (2.8.tmux) binds `-n C-S-c` and relays it only into an
    #     nvim pane — the SAME gate a local duct meets, so both paths agree
    #   - ⇒ this box asks only "is there an ssh hop?", never "what is out there?"
    #
    # ⚠️ the invariant holds: this is never the ^C byte, so it cannot interrupt
    #   any receiver. a far host with no tmux at all is the one loose end — it
    #   gets an inert escape at a shell prompt, never a signal
    #
    # comm alone is enough HERE, unlike for tmux
    #   - comm holds 15 chars, and 'ssh' is 3, so it is never truncated
    #   - tmux needs the cmdline check because setproctitle rewrites it to
    #     'tmux: client'; ssh does no such rewrite
    #   - `sshd` is excluded by the equality: that is an inbound server
    return any(_comm(pid) == 'ssh' for pid in pids)


def _window_pids(window) -> list:
    # every pid under this window, the window's own child first
    #   - ONE walk, shared by both gates below, so they cannot read
    #     two different /proc snapshots of one window
    root = getattr(window.child, 'pid', None)
    if not root:
        return []
    return [root] + _subtree(root, _child_map())


def _local_tmux_in_copy_mode(pids: list) -> bool:
    # is the active pane of a LOCAL tmux held in copy-mode?
    #
    # 🛑 copy-mode is its own reason to forward, INDEPENDENT of the allowlist
    #   - the allowlist asks "does this app yank the key?"; in copy-mode there
    #     is no app in the loop at all. tmux swaps to the `copy-mode-vi` table
    #     and swallows every key, so none reaches the pane's process
    #   - ⇒ the key cannot land as an interrupt, which is the whole invariant
    #   - `tmux.conf` binds it there to copy-selection-and-cancel
    #
    # ⚠️ without this the local duct is the one that stays dead: over ssh the
    #   branch below already delivers unconditionally, so a REMOTE copy-mode
    #   works while the same key on the LAPTOP does not. `pane_current_command`
    #   in copy-mode is still `zsh`, so the allowlist rejects it
    if not pids:
        return False
    client_tty = _tmux_client_tty(pids)
    if not client_tty:
        return False
    return _tmux_active_pane(client_tty)[1]


def _focused_app(window, pids: list) -> str:
    # name the app the human actively drives in this window
    #   - through tmux that is the active pane's command
    #   - else it is the window's foreground process
    #   - it returns '' when unsure, so the caller stays on the safe path
    if not pids:
        return ''
    client_tty = _tmux_client_tty(pids)
    if client_tty:
        return _tmux_active_pane(client_tty)[0]
    # no tmux: the window's own foreground process
    try:
        for proc in window.child.foreground_processes:
            cmd = proc.get('cmdline') or []
            if cmd:
                base = os.path.basename(cmd[0])
                if base:
                    return base
    except Exception:
        pass
    return _comm(pids[-1]) if pids else ''


def _is_copy_receiver(window, pids: list) -> bool:
    # may this destination be handed the copy key (CSI 99;6u)?
    #
    # 🛑 the question is ELIGIBILITY, never IDENTITY — "may this be handed the
    #   key?", not "what is this?". three disjoint situations qualify, and they
    #   share no property but the verdict, so no app-name test can express the
    #   set. that is why this returns a VERDICT and `_focused_app` (a name) is
    #   only one of its three inputs
    #
    # | the receiver                   | why the key cannot land as ^C          |
    # |--------------------------------|----------------------------------------|
    # | an allowlisted app (nvim)      | it YANKS the key — <C-S-c> -> "+y      |
    # | a local tmux pane in copy-mode | tmux swallows it; no process reads     |
    # | a duct past an ssh hop         | the far tmux decides; ssh is a pipe    |
    #
    # ⚠️ fail closed is the shared discipline: every reader below answers ''
    #   or False when unsure, so an unknown focus is judged NOT a receiver
    #
    # ⚠️ the order is a COST order, not a correctness one — this is a plain OR.
    #   the allowlist runs first because the copy-mode read shells out to tmux
    if _focused_app(window, pids) in FORWARD_ALLOWLIST:
        return True
    if _local_tmux_in_copy_mode(pids):
        return True
    return _subtree_has_ssh(pids)


@result_handler(no_ui=True)
def handle_result(args, answer, target_window_id, boss: Boss) -> None:
    window = boss.window_id_map.get(target_window_id)
    if window is None:
        return

    # copy branch — mirror kitty's own selection to the clipboard, then toast
    #   - it always runs, independent of the forward gate below
    selection = window.text_for_selection()
    if selection:
        set_clipboard_string(selection)
        subprocess.Popen(
            ['notify-send', '-t', '1200', '-a', 'kitty', 'copied to clipboard']
        )

    # forward branch — hand the copy key to a copy-receiver, and to none other
    #   - so it can never land on claude-cli or a shell or an unknown TUI
    #   - ONE walk of /proc feeds the verdict, so its three reasons cannot read
    #     two different snapshots of one window
    pids = _window_pids(window)
    if _is_copy_receiver(window, pids):
        window.write_to_child(b'\x1b[99;6u')


def main(args):
    pass

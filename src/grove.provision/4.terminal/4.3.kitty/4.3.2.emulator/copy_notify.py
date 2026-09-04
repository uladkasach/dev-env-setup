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


def _tmux_active_command(client_tty: str) -> str:
    # ask tmux for the command in the active pane of this client's session
    #   - fail closed (return '') on any error, so the caller forwards none
    try:
        clients = subprocess.check_output(
            ['tmux', 'list-clients', '-F', '#{client_tty}\t#{session_name}'],
            timeout=1,
        ).decode()
    except Exception:
        return ''
    session = ''
    for line in clients.splitlines():
        parts = line.split('\t')
        if len(parts) == 2 and parts[0] == client_tty:
            session = parts[1]
            break
    if not session:
        return ''
    try:
        panes = subprocess.check_output(
            ['tmux', 'list-panes', '-t', session, '-F',
             '#{pane_active} #{pane_current_command}'],
            timeout=1,
        ).decode()
    except Exception:
        return ''
    for line in panes.splitlines():
        if line.startswith('1 '):
            return line[2:].strip()
    return ''


def _subtree_has_ssh(pids: list) -> bool:
    # the LOCAL half of a remote duct: kitty → zsh → ssh → (far host) tmux → nvim
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


def _focused_app(window, pids: list) -> str:
    # name the app the human actively drives in this window
    #   - through tmux that is the active pane's command
    #   - else it is the window's foreground process
    #   - it returns '' when unsure, so the caller stays on the safe path
    if not pids:
        return ''
    client_tty = _tmux_client_tty(pids)
    if client_tty:
        return _tmux_active_command(client_tty)
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

    # forward branch — send the copy key ONLY to an allowed receiver (nvim)
    #   - so it can never land on claude-cli or a shell or an unknown TUI
    #   - fail closed: an unknown focus gets no forward
    pids = _window_pids(window)
    if _focused_app(window, pids) in FORWARD_ALLOWLIST:
        window.write_to_child(b'\x1b[99;6u')
        return

    # 🛑 a REMOTE duct cannot be judged from HERE, so the judgment moves THERE
    #   - the far host runs nvim; this box runs only the ssh client, so every
    #     local reader (/proc, tmux, foreground_processes) answers 'ssh'
    #   - 📜 that read as "an unknown app", so the branch above sent no forward
    #     and a visual-mode ctrl+c was a silent no-op on every grove
    #   - ⚠️ it read as WORKING, because the copy branch above always runs: a
    #     kitty mouse-drag still copied and still toasted. one path green hid
    #     the other path dead
    #
    # ⇒ so kitty DELIVERS and tmux DECIDES
    #   - ssh is a byte pipe, so CSI 99;6u rides it to the far tmux
    #   - `src/tmux.conf` binds `-n C-S-c` and relays it only into an nvim pane
    #   - that gate is the SAME one for a local duct, so both paths agree
    #
    # ⚠️ the invariant holds: this is never the ^C byte, so it cannot interrupt
    #   any receiver. a far host with no tmux at all is the one loose end — it
    #   gets an inert escape at a shell prompt, never a signal
    if _subtree_has_ssh(pids):
        window.write_to_child(b'\x1b[99;6u')


def main(args):
    pass

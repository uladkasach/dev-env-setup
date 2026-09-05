import os
import signal

from kitty.boss import Boss
from kittens.tui.handler import result_handler


def _read_ppid(pid: int) -> int:
    # parse ppid (field 4) from /proc/<pid>/stat
    #   - the comm field (2) sits in parens and may hold spaces or ')'
    #   - so split AFTER the last ')' to stay safe
    try:
        with open('/proc/%d/stat' % pid) as fh:
            data = fh.read()
        rest = data[data.rindex(')') + 1:].split()
        return int(rest[1])
    except Exception:
        return -1


def _proc_is_tmux(pid: int) -> bool:
    # match on comm, which covers the 'tmux: client' that setproctitle mangles
    #   - match on cmdline[0] basename too, which covers a clean 'tmux'
    try:
        with open('/proc/%d/comm' % pid) as fh:
            if fh.read().strip().startswith('tmux'):
                return True
    except Exception:
        pass
    try:
        with open('/proc/%d/cmdline' % pid, 'rb') as fh:
            argv0 = fh.read().split(b'\x00', 1)[0].decode('utf-8', 'replace')
        return os.path.basename(argv0) == 'tmux'
    except Exception:
        return False


def _proc_is_ssh(pid: int) -> bool:
    # the LOCAL half of a remote duct: kitty → zsh → ssh → (far host) tmux → nvim
    #   - match comm, then argv0's basename, the same two ways _proc_is_tmux does
    #   - `sshd` is excluded: that is an inbound server, never our outbound client
    try:
        with open('/proc/%d/comm' % pid) as fh:
            if fh.read().strip() == 'ssh':
                return True
    except Exception:
        pass
    try:
        with open('/proc/%d/cmdline' % pid, 'rb') as fh:
            argv0 = fh.read().split(b'\x00', 1)[0].decode('utf-8', 'replace')
        return os.path.basename(argv0) == 'ssh'
    except Exception:
        return False


def _window_leaf(window) -> str:
    # 🛑 reboot at the LEAF HOLDER — name which leaf this window reaches
    #   - tmux claims the pty for its client, so foreground_processes reads EMPTY
    #   - so walk /proc down from kitty's child pid, the login zsh
    #
    # returns one of:
    #   'tmux'  a LOCAL tmux client — its pane is the leaf, here on this box
    #   'ssh'   a REMOTE duct — the leaf is a pane on the far host
    #   ''      a bare shell — this window IS the leaf
    root = window.child.pid
    if root is None:
        return ''

    # build a ppid -> [pid] map once, then BFS the subtree under root
    kids = {}
    for name in os.listdir('/proc'):
        if not name.isdigit():
            continue
        pid = int(name)
        kids.setdefault(_read_ppid(pid), []).append(pid)

    found_ssh = False
    stack = list(kids.get(root, []))
    while stack:
        pid = stack.pop()
        # tmux wins: a LOCAL client is the nearer leaf, so it answers first even
        # where an ssh also sits in the tree (a duct that shelled out to a box)
        if _proc_is_tmux(pid):
            return 'tmux'
        if _proc_is_ssh(pid):
            found_ssh = True
        stack.extend(kids.get(pid, []))
    return 'ssh' if found_ssh else ''


@result_handler(no_ui=True)
def handle_result(args, answer, target_window_id, boss: Boss) -> None:
    window = boss.window_id_map.get(target_window_id)
    if window is None:
        return

    # 🛑 reboot at the leaf holder, which is tmux's pane when tmux is attached
    #   - kitty's map swallowed the key, so re-emit it as CSI 114;6u
    #   - 114 = 'r' and 6 = ctrl+shift, the path copy_notify uses for CSI 99;6u
    #   - tmux's own `-n C-S-r respawn-pane` then reboots the pane
    #   - a reboot here would kill the tmux client and detach the duct
    #
    # 🛑 a REMOTE duct takes the SAME branch, and that is the 2026-09-03 repair
    #   - ssh is a byte pipe, so the key rides it to the far tmux, which holds
    #     the same `-n C-S-r respawn-pane` line this repo declares
    #   - 📜 this used to fall through to the kill branch below, on the argument
    #     that kitty-side "is the right leaf ON THIS MACHINE". that names the
    #     machine, never what the human meant: a human at a hung remote nvim asks
    #     about the FAR leaf, and the code answered about the near one
    #   - ⇒ the old path destroyed the local window and detached the duct — the
    #     exact outcome the comment above calls wrong for a local duct
    #
    # ⚠️ the two arms differ in CONFIDENCE, and the fallback is what makes the
    #   remote arm safe to take without a read of the far host:
    #     local  → we SAW the tmux client, so the key certainly lands on a pane
    #     remote → we saw only ssh; the far side may hold no tmux at all
    #   an unknown CSI is inert to a shell, so the worst case is a no-op keypress,
    #   never a destroyed window. a no-op beats a wrong destructive act, so this
    #   arm is strictly better than the kill it replaces
    if _window_leaf(window) in ('tmux', 'ssh'):
        window.write_to_child(b'\x1b[114;6u')
        return

    # capture cwd before the window dies; fall back to home if unknown
    cwd = window.cwd_of_child or os.path.expanduser('~')

    # respawn a fresh shell in the same tab at the same cwd FIRST
    #   - so the tab never drops to zero windows, which would close the tab
    boss.launch('--type=window', f'--cwd={cwd}')

    # SIGKILL the old window's whole process group
    #   - it works on a fully hung nvim, since kitty grabbed the key first
    pid = window.child.pid
    if pid is not None:
        try:
            os.killpg(os.getpgid(pid), signal.SIGKILL)
        except (ProcessLookupError, PermissionError):
            pass

    # close the corpse; child death auto-closes it anyway, this is immediate
    boss.close_window(window)


def main(args):
    pass

"""
.what = load the SHIPPED copy_notify.py kitten outside kitty, and ask its own
        lookup what runs in the active pane of one attached tmux client

.why  = the kitten forwards ctrl+shift+c only when that lookup answers `nvim`.
        a lookup that asks the wrong tmux server finds no client, answers '',
        and fails closed — so the key dies at kitty while every tmux layer
        reads healthy

.the contract with its driver (prove.copy-kitten-finds-the-client.play.sh)
  argv[1]   the kitten file
  argv[2]   the pid of the attached tmux client
  argv[3]   the arm: control | old-default-only
  stdout    `focused=<what the kitten read, or EMPTY>`
            `tmux_calls=<how many tmux processes the lookup ran>`

.the arms
  control           the kitten as shipped
  old-default-only  its socket read pinned to `default` — the lookup as it
                    stood before 2026-10-21. it must read EMPTY for a client on
                    any other socket, or this probe cannot see the break it
                    exists to catch
"""
import importlib.util
import os
import subprocess
import sys
import types

kitten, client_pid, arm = sys.argv[1], int(sys.argv[2]), sys.argv[3]

# kitty's own modules exist only inside kitty; the lookup under test uses none
for name in ('kitty', 'kitty.boss', 'kitty.clipboard', 'kittens', 'kittens.tui', 'kittens.tui.handler'):
    sys.modules.setdefault(name, types.ModuleType(name))
sys.modules['kitty.boss'].Boss = object
sys.modules['kitty.clipboard'].set_clipboard_string = lambda s: None
sys.modules['kittens.tui.handler'].result_handler = lambda **kw: (lambda f: f)

spec = importlib.util.spec_from_file_location('copy_notify', kitten)
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

if arm == 'old-default-only':
    shipped = mod._tmux_socket_of
    mod._tmux_socket_of = lambda argv: os.path.join(os.path.dirname(shipped(argv)), 'default')

# count every tmux process the lookup runs — the cost of one press
calls = 0
shipped_check_output = subprocess.check_output
def counted(cmd, *a, **kw):
    global calls
    if cmd and cmd[0] == 'tmux':
        calls += 1
    return shipped_check_output(cmd, *a, **kw)
mod.subprocess.check_output = counted

client = mod._tmux_client([client_pid])
focused, _ = mod._tmux_active_pane(client)
print('focused=%s' % (focused or 'EMPTY'))
print('tmux_calls=%d' % calls)

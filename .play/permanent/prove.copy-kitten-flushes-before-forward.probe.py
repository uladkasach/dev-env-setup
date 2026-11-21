"""
.what = load the SHIPPED copy_notify.py kitten outside kitty, press ctrl+c on a
        fake window over a REAL process tree, and record the order of its work

.why  = kitty sends a clipboard offer to the compositor only when its event loop
        next turns, and the kitten's handler blocks that turn. a forward that
        walks /proc and calls tmux INSIDE the handler holds the offer back; a
        human who copies and switches windows at once moves focus first, and
        wayland drops the late offer. the copy toasts and never lands

.the contract with its driver (prove.copy-kitten-flushes-before-forward.play.sh)
  argv[1]   the kitten file
  argv[2]   the root pid of the fake window (a tmux server whose tree holds a
            client of the inner server, whose pane runs nvim)
  argv[3]   the arm: shipped | old-inline-forward | old-full-walk
  stdout    `work_before_return=<yes|no>`  forward work inside the handler?
            `clipboard_first=<yes|no>`     clipboard set before any forward work?
            `forwarded=<yes|no>`           CSI 99;6u written, once the tick fires
            `subtree_matches=<yes|no>`     the walk names the same pids as a full map
            `stat_reads=<N>`               /proc/<pid>/stat opens in one walk
            `subtree_size=<N>`             pids under the root

.the arms
  shipped             the kitten as shipped
  old-inline-forward  `add_timer` runs its callback at once, inside the handler —
                      the forward as it stood before 2026-11-21. it must read
                      `work_before_return=yes`, or this probe cannot see the race
  old-full-walk       `_subtree` swapped for the full-map walk it replaced. it must
                      read `stat_reads` > `subtree_size`, or the cost claim is blind
"""
import builtins
import importlib.util
import sys
import types

kitten, root_pid, arm = sys.argv[1], int(sys.argv[2]), sys.argv[3]

# the import below would write a __pycache__/ beside the SHIPPED kitten, in the
# checkout; a probe leaves the tree it reads exactly as it found it
sys.dont_write_bytecode = True

# the order of work, as the handler does it
events = []
queued = []

# kitty's own modules exist only inside kitty; stub the four the kitten imports
for name in ('kitty', 'kitty.boss', 'kitty.clipboard', 'kitty.fast_data_types',
             'kittens', 'kittens.tui', 'kittens.tui.handler'):
    sys.modules.setdefault(name, types.ModuleType(name))
sys.modules['kitty.boss'].Boss = object
sys.modules['kitty.clipboard'].set_clipboard_string = lambda s: events.append('clipboard')
sys.modules['kitty.fast_data_types'].add_timer = lambda cb, interval, repeats: queued.append(cb) or 1
sys.modules['kittens.tui.handler'].result_handler = lambda **kw: (lambda f: f)

spec = importlib.util.spec_from_file_location('copy_notify', kitten)
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

# the old forms, rebuilt from the shipped parts so each arm differs by one fact
if arm == 'old-inline-forward':
    mod.add_timer = lambda cb, interval, repeats: cb(0) or 1


def full_walk(root):
    kids = mod._child_map()
    out, stack = [], list(kids.get(root, []))
    while stack:
        pid = stack.pop()
        out.append(pid)
        stack.extend(kids.get(pid, []))
    return out


if arm == 'old-full-walk':
    mod._subtree = full_walk

# mark the forward's costly work: the /proc walk and the tmux call
shipped_window_pids = mod._window_pids
def marked_window_pids(window):
    events.append('forward-work')
    return shipped_window_pids(window)
mod._window_pids = marked_window_pids

# count every /proc/<pid>/stat open — the full-box walk's signature
stat_reads = 0
shipped_open = builtins.open
def counted_open(path, *a, **kw):
    global stat_reads
    if isinstance(path, str) and path.startswith('/proc/') and path.endswith('/stat'):
        stat_reads += 1
    return shipped_open(path, *a, **kw)


# a fake window over the real tree; the fake child holds no foreground list
class Child:
    pid = root_pid
    foreground_processes = []


class Window:
    child = Child()
    written = []

    def text_for_selection(self):
        return 'a line a human dragged over'

    def write_to_child(self, data):
        self.written.append(data)


window = Window()


class FakeBoss:
    window_id_map = {7: window}


# the press: the handler returns, then the loop turns and fires the tick
mod.handle_result([], None, 7, FakeBoss())
work_before_return = 'forward-work' in events
for cb in queued:
    cb(0)

# one walk, alone, to measure what it reads
builtins.open = counted_open
walked = mod._subtree(root_pid)
builtins.open = shipped_open
truth = full_walk(root_pid)

print('work_before_return=%s' % ('yes' if work_before_return else 'no'))
print('clipboard_first=%s' % ('yes' if events[:1] == ['clipboard'] else 'no'))
print('forwarded=%s' % ('yes' if b'\x1b[99;6u' in window.written else 'no'))
print('subtree_matches=%s' % ('yes' if sorted(walked) == sorted(truth) else 'no'))
print('stat_reads=%d' % stat_reads)
print('subtree_size=%d' % len(truth))

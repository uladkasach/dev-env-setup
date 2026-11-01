#!/usr/bin/env bash
######################################################################
# .what = list every live firefox MAIN process (not content children),
#         with its args, start time, and the display env it was
#         launched with
#
# .why  = two launch routes (the `browser` launcher, and xdg-open via
#         the flatpak .desktop file that super+b fires) can yield two
#         firefox processes. a second process does not share the first
#         one's live state — its theme, its windows — so "one window is
#         colored, the other is not" is first a question of how many
#         main processes are live, and how each was launched
#
# usage:
#   firefox.instances.get.sh
#
# guarantee:
#   - read-only: reads /proc, never signals a process
#   - exit 0 = answered (zero instances is an answer)
######################################################################

set -uo pipefail

echo "🦊 firefox.instances.get"

# main processes: a firefox binary with no -contentproc / -isForBrowser flag
python3 - <<'PY'
import os, datetime

def read(pid, name):
    try:
        with open(f"/proc/{pid}/{name}", "rb") as f: return f.read()
    except OSError:
        return b""

boot = float(open("/proc/stat").read().split("btime ")[1].split()[0])
tick = os.sysconf("SC_CLK_TCK")
rows = []
for pid in filter(str.isdigit, os.listdir("/proc")):
    argv = [a.decode(errors="replace") for a in read(pid, "cmdline").split(b"\0") if a]
    if not argv: continue
    exe = os.path.basename(argv[0])
    if exe not in ("firefox", "firefox-bin"): continue
    if any(a in ("-contentproc", "-isForBrowser") for a in argv): continue
    env = dict(e.split(b"=", 1) for e in read(pid, "environ").split(b"\0") if b"=" in e)
    stat = read(pid, "stat").decode()
    start = boot + int(stat.rsplit(")", 1)[1].split()[19]) / tick
    keys = (b"MOZ_ENABLE_WAYLAND", b"WAYLAND_DISPLAY", b"DISPLAY", b"GDK_BACKEND", b"FLATPAK_ID", b"MOZ_DBUS_REMOTE")
    rows.append((start, pid, argv, {k.decode(): env.get(k, b"").decode() for k in keys}))

if not rows:
    print("   └─ no firefox main process is live")
for i, (start, pid, argv, env) in enumerate(sorted(rows)):
    last = i == len(rows) - 1
    head, pad = ("└─", "   ") if last else ("├─", "│  ")
    print(f"   {head} pid {pid}  started {datetime.datetime.fromtimestamp(start):%F %T}")
    print(f"   {pad}├─ argv: {' '.join(argv)}")
    print(f"   {pad}└─ env:  " + "  ".join(f"{k}={v or '∅'}" for k, v in env.items()))
PY

#!/usr/bin/env bash
######################################################################
# .what = hold this terminal the way claude-cli does — the alternate
#         screen, SGR mouse asked — and name every byte a scroll delivers
#
# .why  = "scroll recalls an old prompt" has two causes with opposite
#         repairs, and only the bytes at the PANE tell them apart:
#           - an arrow key arrives  → kitty or tmux turned the scroll into
#             a key; the repair is below the app
#           - a wheel event arrives → the stack is clean; the APP maps a
#             wheel tick to history, and the repair is in the app
#         run it in the same kind of window that misbehaves (a duct pane in
#         kitty), make the same gesture, and read the verdict
#
# usage:
#   rhx tmux.scroll.probe              # mouse asked, as claude does
#   rhx tmux.scroll.probe --no-mouse   # mouse NOT asked, as less does
#   (scroll, then press q — or wait 30s — to see the tally)
#
# guarantee:
#   - reads and writes /dev/tty, so it works under rhx (which pipes stdin)
#   - restores the screen and the tty modes on every exit
#   - sends no key anywhere; it only reads what arrives
#   - exit 0 = a verdict printed; 2 = no terminal to read
######################################################################
set -uo pipefail

MOUSE=1
while [[ $# -gt 0 ]]; do
  case "$1" in
    --skill) shift 2 ;;
    --no-mouse) MOUSE=0; shift ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "✋ ConstraintError: unknown arg: $1" >&2; exit 2 ;;
  esac
done

if ! { : </dev/tty; } 2>/dev/null; then
  echo "✋ ConstraintError: no terminal to read — run this in the window that misbehaves" >&2
  exit 2
fi

exec python3 - "$MOUSE" <<'PY'
import os, re, select, sys, termios, time, tty

mouse = sys.argv[1] == '1'
fd = os.open('/dev/tty', os.O_RDWR)
saved = termios.tcgetattr(fd)

def out(s):
    os.write(fd, s.encode())

enter = '\x1b[?1049h\x1b[H\x1b[2J' + ('\x1b[?1000h\x1b[?1006h' if mouse else '')
leave = ('\x1b[?1006l\x1b[?1000l' if mouse else '') + '\x1b[?1049l'

# the shapes a scroll can arrive as
PATTERNS = [
    ('wheel-up', re.compile(rb'\x1b\[<64;\d+;\d+M')),
    ('wheel-down', re.compile(rb'\x1b\[<65;\d+;\d+M')),
    ('arrow-up', re.compile(rb'\x1b\[A|\x1bOA|\x1b\[1;\d+A')),
    ('arrow-down', re.compile(rb'\x1b\[B|\x1bOB|\x1b\[1;\d+B')),
]
tally = {name: 0 for name, _ in PATTERNS}
other = []

try:
    tty.setraw(fd)
    out(enter)
    out('🔭 tmux.scroll.probe — mouse %s, as %s does\r\n' % (
        'ASKED' if mouse else 'NOT asked', 'claude' if mouse else 'less'))
    out('   scroll now, the same gesture that misbehaves. q ends it (30s cap)\r\n\r\n')
    deadline = time.time() + 30
    while time.time() < deadline:
        r, _, _ = select.select([fd], [], [], 0.2)
        if not r:
            continue
        data = os.read(fd, 4096)
        if data == b'q':
            break
        rest = data
        for name, pat in PATTERNS:
            n = len(pat.findall(rest))
            tally[name] += n
            rest = pat.sub(b'', rest)
        if rest:
            other.append(rest.hex())
        out('   %s\r\n' % ' '.join('%s=%d' % kv for kv in tally.items()))
finally:
    out(leave)
    termios.tcsetattr(fd, termios.TCSADRAIN, saved)

print('🐢 heres what the scroll delivered')
print('')
print('🐚 tmux.scroll.probe (mouse %s)' % ('asked' if mouse else 'not asked'))
for name, n in tally.items():
    print('   ├─ %s: %d' % (name, n))
print('   ├─ other bytes: %s' % (', '.join(other[:8]) or 'none'))
arrows = tally['arrow-up'] + tally['arrow-down']
wheels = tally['wheel-up'] + tally['wheel-down']
if arrows:
    print('   └─ ✋ verdict: the scroll arrived as ARROW KEYS — kitty or tmux made them, below the app')
elif wheels:
    print('   └─ ✔ verdict: the scroll arrived as WHEEL events — the stack is clean; an app that recalls')
    print('      history on scroll maps the wheel to history itself')
else:
    print('   └─ 🌙 verdict: no scroll arrived — scroll over THIS pane, then press q')
PY

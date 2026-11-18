#!/usr/bin/env bash
######################################################################
# .what = read a symbol of kitty's OWN python api, as the installed kitty
#         holds it: whether it exists, its signature, and its source
#
# .why  = this repo authors kittens (4.3.2.emulator/*.py) against kitty's
#         internal api — `Boss`, `Window`, `kitty.constants` — and that api
#         is not documented, only read. the tarball build ships its python
#         INSIDE the binary, so no file on disk can be grepped for it, and
#         kitty loads a kitten lazily: a call to a name kitty lacks raises
#         only on the keypress, as a dead key with no message.
#         `kitty +runpy` is the one reader, so it gets one door.
#
# usage:
#   kitty.api.get.sh --symbol kitty.boss.Boss.call_remote_control
#   kitty.api.get.sh --symbol kitty.window.Window.user_vars
#   kitty.api.get.sh --symbol kitty.constants.config_dir --source
#
# options:
#   --symbol   a dotted path: module, then attribute(s)   (required)
#   --source   also print the symbol's source, where it has one
#
# guarantee:
#   - read-only; it imports kitty's modules in a fresh interpreter and
#     touches no live kitty, socket, or config
#   - exit 0 = the symbol exists; 2 = it does not, or a bad input
######################################################################
set -uo pipefail

SYMBOL=""
SOURCE=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --skill) shift 2 ;;
    --symbol) SYMBOL="${2:-}"; shift 2 ;;
    --source) SOURCE=1; shift ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "✋ ConstraintError: unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [[ ! "$SYMBOL" =~ ^[A-Za-z_][A-Za-z0-9_]*(\.[A-Za-z_][A-Za-z0-9_]*)+$ ]]; then
  echo "✋ ConstraintError: --symbol must be a dotted path, e.g. kitty.boss.Boss.call_remote_control" >&2
  exit 2
fi
if ! command -v kitty >/dev/null; then
  echo "✋ ConstraintError: no kitty on PATH — fix: rhx grove.provision --what 4.3.2.emulator --mode apply" >&2
  exit 2
fi

echo "🐢 heres what kitty holds"
echo ""
echo "🐚 kitty.api.get --symbol $SYMBOL"
echo "   ├─ kitty: $(kitty --version 2>/dev/null)"

# the symbol is passed as an env var, never spliced into the python text
KITTY_API_SYMBOL="$SYMBOL" KITTY_API_SOURCE="$SOURCE" kitty +runpy '
import importlib, inspect, os, sys
parts = os.environ["KITTY_API_SYMBOL"].split(".")
obj, mod = None, None
for i in range(len(parts), 0, -1):
    try:
        mod = importlib.import_module(".".join(parts[:i]))
        rest = parts[i:]
        break
    except ImportError:
        continue
if mod is None:
    print("   └─ ✋ no module on that path"); sys.exit(2)
obj = mod
for name in rest:
    if hasattr(obj, name):
        obj = getattr(obj, name); continue
    # an instance attribute, set in __init__, is no class attribute
    #   - ⚠️ the tarball build ships BYTECODE with no source, so getsource fails;
    #     the names the __init__ bytecode stores are the reader that survives
    #   - 🛑 no apostrophe in this block: the python rides in single quotes
    if inspect.isclass(obj):
        code = getattr(getattr(obj, "__init__", None), "__code__", None)
        if code is not None and name in code.co_names:
            print("   ├─ kind: instance attribute (named in " + obj.__name__ + ".__init__)")
            print("   └─ ✔ exists"); sys.exit(0)
    print("   └─ ✋ absent: " + name + " on " + repr(obj)[:80]); sys.exit(2)
kind = type(obj).__name__
print("   ├─ kind: " + kind)
try:
    print("   ├─ signature: " + str(inspect.signature(obj)))
except Exception:
    if not callable(obj):
        print("   ├─ value: " + repr(obj)[:120])
if os.environ["KITTY_API_SOURCE"] == "1":
    try:
        src = inspect.getsource(obj)
        print("   ├─ source")
        for line in src.splitlines()[:60]:
            print("   │  " + line)
    except Exception:
        print("   ├─ source: (none readable)")
print("   └─ ✔ exists")
'
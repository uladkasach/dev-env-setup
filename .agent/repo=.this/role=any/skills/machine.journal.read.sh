#!/usr/bin/env bash
######################################################################
# .what = read this box's systemd journal — the system log, the user
#         manager's log, or the kernel log — scoped and bounded
#
# .why
#   - "why did X die?" is answered by the journal and by no other store.
#     a raw `journalctl` call is a diagnose typed by hand, and a hand-typed
#     diagnose is the exact shape `rule.forbid.adhoc-shell` names
#   - measured 2026-10-07: the user systemd manager died, took every kitty
#     window and every `systemd-run --user` caller with it, and the question
#     "what killed it?" had no verb to ask with
#
# usage:
#   rhx machine.journal.read --scope kernel --grep 'oom|killed'
#   rhx machine.journal.read --scope system --unit user@1000.service
#   rhx machine.journal.read --scope user --since '-2h'
#   rhx machine.journal.read --scope system --grep earlyoom --since today
#   rhx machine.journal.read help
#
# options:
#   --scope    system | user | kernel                (default: system)
#   --unit     one unit to read                      (default: all)
#   --since    a journalctl time spec                (default: -6h)
#   --grep     a regex the message must match        (default: none)
#   --lines    the tail to print                     (default: 80, max 2000)
#   --boot     which boot: 0 = this one, -1 = prior  (default: 0)
#
# guarantee:
#   - READ-ONLY, always. it writes no file and moves no unit
#   - bounded: every read carries --since and a --lines cap, so a call can
#     never dump a month of log into a caller's context
#   - exit 0 = the read completed (an empty match is a FACT, and says so)
#   - exit 1 = journalctl itself failed (its stderr is relayed)
#   - exit 2 = constraint (bad args)
######################################################################
set -uo pipefail

if [[ " $* " == *" help "* || " $* " == *" --help "* || " $* " == *" -h "* ]]; then
  echo "machine.journal.read — read this box's journal, scoped and bounded"
  echo ""
  echo "usage:"
  echo "  rhx machine.journal.read [--scope system|user|kernel] [--unit U]"
  echo "                           [--since SPEC] [--grep RE] [--lines N] [--boot N]"
  echo ""
  echo "defaults: --scope system --since -6h --lines 80 --boot 0"
  echo ""
  echo "examples:"
  echo "  rhx machine.journal.read --scope kernel --grep 'oom|killed'"
  echo "  rhx machine.journal.read --scope system --unit user@1000.service"
  exit 0
fi

SCOPE="system"
UNIT=""
SINCE="-6h"
GREP=""
LINES=80
BOOT=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --scope) SCOPE="$2"; shift 2 ;;
    --unit)  UNIT="$2";  shift 2 ;;
    --since) SINCE="$2"; shift 2 ;;
    --grep)  GREP="$2";  shift 2 ;;
    --lines) LINES="$2"; shift 2 ;;
    --boot)  BOOT="$2";  shift 2 ;;
    # ⚠️ rhachet injects these three into every skill it runs, so each is dropped
    --skill|--repo|--role) shift 2 ;;
    --) shift ;;
    *) echo "✋ unknown argument '$1'" >&2
       echo "   see: rhx machine.journal.read help" >&2; exit 2 ;;
  esac
done

# validate the args a caller can get wrong
case "$SCOPE" in
  system|user|kernel) ;;
  *) echo "✋ --scope must be system, user, or kernel — got '$SCOPE'" >&2; exit 2 ;;
esac
[[ "$LINES" =~ ^[0-9]+$ ]] && (( LINES >= 1 && LINES <= 2000 )) || {
  echo "✋ --lines must be 1..2000 — got '$LINES'" >&2; exit 2; }
[[ "$BOOT" =~ ^-?[0-9]+$ ]] || { echo "✋ --boot must be an integer — got '$BOOT'" >&2; exit 2; }
command -v journalctl >/dev/null 2>&1 || { echo "✋ no journalctl on this box" >&2; exit 2; }

# build the call; every flag is an argv element, never an eval
ARGS=( --no-pager --output=short-iso --boot="$BOOT" --since="$SINCE" -n "$LINES" )
case "$SCOPE" in
  user)   ARGS+=( --user ) ;;
  kernel) ARGS+=( -k ) ;;
esac
[[ -n "$UNIT" ]] && ARGS+=( -u "$UNIT" )
[[ -n "$GREP" ]] && ARGS+=( --grep "$GREP" --case-sensitive=false )

echo "🐢 lets read the tide log..."
echo ""
echo "📜 machine.journal.read --scope $SCOPE${UNIT:+ --unit $UNIT} --since '$SINCE'${GREP:+ --grep '$GREP'} --lines $LINES --boot $BOOT"

OUT="$(journalctl "${ARGS[@]}" 2>&1)"
RC=$?

# journalctl exits 1 with empty output when --grep matched none; a fact, not a fault
if [[ "$RC" -ne 0 && -n "$GREP" && -z "${OUT//[[:space:]]/}" ]]; then
  RC=0
fi

if [[ "$RC" -ne 0 && "$OUT" != *"-- No entries --"* ]]; then
  echo "   └─ ✋ journalctl failed (exit $RC)" >&2
  printf '%s\n' "$OUT" | sed 's/^/      /' >&2
  echo "      ⇒ a read of the system journal needs the 'systemd-journal' or 'adm' group" >&2
  exit 1
fi

if [[ -z "${OUT//[[:space:]]/}" || "$OUT" == *"-- No entries --"* ]]; then
  echo "   └─ no entries matched — the journal said none, in this window"
  exit 0
fi

echo "   └─ entries"
printf '%s\n' "$OUT" | sed 's/^/      /'
exit 0

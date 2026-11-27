#!/usr/bin/env bash
######################################################################
# .what = drive `prove.grove-backup-live`'s disk gate with `id` and `df`
#         stubbed, and hold each answer to its exit code and its words
#
# .why  = the live proof lays a whole .claude and a whole tree aside. on a box
#         at the crews' 90 pct gate that write can starve the crews, so the play
#         must refuse there, before any restore, and must fail closed when df
#         cannot answer. a gate never seen to fire is a gate nobody proved
#
# guarantee:
#   - HERMETIC. `id` answers camper and `df` answers the case's percent, from a
#     temp PATH; HOME is a temp dir with no checkout, so a case the gate passes
#     stops at the checkout step (exit 1) and never reaches a bucket
######################################################################

set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PLAY="$HERE/.play/permanent/prove.grove-backup-live.play.sh"

stubs="$(mktemp -d)"
home="$(mktemp -d)"
trap 'rm -rf "$stubs" "$home"' EXIT

cat > "$stubs/id" <<'STUB'
#!/usr/bin/env bash
[[ "$1" == -un ]] && { echo camper; exit 0; }
exec /usr/bin/id "$@"
STUB
cat > "$stubs/df" <<'STUB'
#!/usr/bin/env bash
[[ -n "${STUB_DF_RC:-}" ]] && { echo "df: stub refused" >&2; exit "$STUB_DF_RC"; }
printf 'Use%%\n %s%%\n' "$STUB_DF_PCT"
STUB
chmod +x "$stubs/id" "$stubs/df"

failed=0
echo "🌲 prove.live-proof-refuses-a-full-disk"

# one case — $1 label · $2 exit wanted · $3 a phrase the output must hold · then env assignments
case_run() {
  local label="$1" want="$2" phrase="$3" out rc
  shift 3
  out="$(env PATH="$stubs:$PATH" HOME="$home" "$@" timeout -k 2 60 bash "$PLAY" </dev/null 2>&1)" && rc=0 || rc=$?
  if [[ "$rc" -eq "$want" && "$out" == *"$phrase"* ]]; then
    echo "   • $label → rc=$rc ✔"
    return 0
  fi
  echo "   💥 MalfunctionError: $label → rc=$rc (wanted $want), output:" >&2
  printf '%s\n' "$out" | sed 's/^/      │ /' >&2
  failed=1
}

case_run "a disk at 95 pct is refused, before any restore"   2 "the disk reads 95 pct"        STUB_DF_PCT=95
case_run "a disk at 90 pct, the gate itself, is refused"     2 "the disk reads 90 pct"        STUB_DF_PCT=90
case_run "a df that cannot answer reads as full"             2 "the disk reads an unknown pct" STUB_DF_RC=1
case_run "a disk at 40 pct passes the gate, to the checkout" 1 "no checkout at"               STUB_DF_PCT=40

[[ "$failed" -eq 0 ]] && echo "🌲 all claims held ✔"
exit "$failed"

#!/usr/bin/env bash
######################################################################
# .what = the backup agent's dirs and excludes equal infra's GROVE_BACKUP_SCOPE
#
# .why
#   - the scope has ONE source: `GROVE_BACKUP_SCOPE` in ahbode/infrastructure
#     (`provision/aws.infra/account=camp/grove/groveBackupScope.ts`). the agent's
#     two lists are a copy, and a copy drifts with no signal
#   - a dir infra adds and the agent lacks is work that never leaves the box;
#     an exclude infra adds and the agent lacks is a plaintext key in a bucket
#     every grove reads
#
# .the read
#   - `rhx git.repo.get`, which reaches the private repo where this box can
#   - infra main first, the merged source. while main lacks the file (owed
#     item 4), the play reads infra#64's branch, holds the clamp against it, and
#     DECLINES with exit 2 — so a run never reads green against an unmerged source
#   - unreachable → ✋, exit 2. a clamp that cannot read its source proves naught,
#     and it never passes in silence
#
# guarantee:
#   - READ-ONLY
######################################################################

set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=/dev/null
source "$HERE/src/grove.provision/5.devtools/5.24.backup/grove.backup.operations.sh"

SOURCE_PATH='provision/aws.infra/account=camp/grove/groveBackupScope.ts'
BRANCH='origin/beav/feat-hetzner-cloud-grove'

failed=0
pass() { echo "   • $1 ✔"; }
fail() { echo "   💥 MalfunctionError: $1" >&2; failed=1; }

echo "🌲 prove.grove-backup-scope-matches-infra"

# .what = the source file's lines at a ref, or naught; rc 0 only when found
read_source() {
  local ref="$1" out
  out="$(rhx git.repo.get lines --in ahbode/infrastructure --ref "$ref" --paths "$SOURCE_PATH" 2>/dev/null)" \
    || out="$(rhx git.repo.get lines --in ahbode/infrastructure --ref "$ref" --refresh off --paths "$SOURCE_PATH" 2>/dev/null)" \
    || return 1
  [[ "$out" == *"GROVE_BACKUP_SCOPE"* ]] || return 1
  printf '%s\n' "$out"
}

# .what = the quoted strings of one `<field>: [...]` line, one per line
field_of() {
  grep -E "^[[:space:]│]*[0-9]+:[[:space:]]+$2:" <<<"$1" | head -n 1 | grep -oE "'[^']*'" | tr -d "'"
}

on_main=1
if ! text="$(read_source origin/main)"; then
  on_main=0
  if ! text="$(read_source "$BRANCH")"; then
    echo "   ✋ ConstraintError: GROVE_BACKUP_SCOPE could not be read from ahbode/infrastructure" >&2
    echo "      ⇒ neither origin/main nor $BRANCH answered for $SOURCE_PATH" >&2
    echo "      ⇒ run this where \`rhx git.repo.get\` reaches the infra repo (a grove, or the laptop)" >&2
    exit 2
  fi
fi

mapfile -t infra_dirs < <(field_of "$text" dirs)
mapfile -t infra_exclude < <(field_of "$text" exclude)

[[ "${#infra_dirs[@]}" -gt 0 ]] || fail "the source's dirs line read as empty — the parse no longer fits the file"
[[ "${#infra_exclude[@]}" -gt 0 ]] || fail "the source's exclude line read as empty — the parse no longer fits the file"

ours_dirs="$(printf '%s\n' "${GROVE_BACKUP_SCOPE_DIRS[@]}" | sort)"
ours_exclude="$(printf '%s\n' "${GROVE_BACKUP_SCOPE_EXCLUDE[@]}" | sort)"
theirs_dirs="$(printf '%s\n' "${infra_dirs[@]}" | sort)"
theirs_exclude="$(printf '%s\n' "${infra_exclude[@]}" | sort)"

[[ "$ours_dirs" == "$theirs_dirs" ]] && pass "dirs equal infra's: $(tr '\n' ' ' <<<"$theirs_dirs")"
[[ "$ours_dirs" != "$theirs_dirs" ]] && fail "dirs drift — agent: $(tr '\n' ' ' <<<"$ours_dirs")· infra: $(tr '\n' ' ' <<<"$theirs_dirs")"
[[ "$ours_exclude" == "$theirs_exclude" ]] && pass "excludes equal infra's: $(tr '\n' ' ' <<<"$theirs_exclude")"
[[ "$ours_exclude" != "$theirs_exclude" ]] && fail "excludes drift — agent: $(tr '\n' ' ' <<<"$ours_exclude")· infra: $(tr '\n' ' ' <<<"$theirs_exclude")"

[[ "$failed" -ne 0 ]] && exit 1
if [[ "$on_main" -eq 0 ]]; then
  echo "🌙 declined: the clamp holds against $BRANCH, and infra main lacks the file" >&2
  echo "   └─ owed by ahbode/infrastructure: GROVE_BACKUP_SCOPE on main (owed item 4)" >&2
  exit 2
fi
echo "🌲 all claims held ✔"
exit 0

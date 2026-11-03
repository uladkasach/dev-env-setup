#!/usr/bin/env bash
######################################################################
# .what = audit what a commit would ADD to this public repo: every added line
#         of the staged diff, plus each named message file, for address detail
#         or a secret
#
# .why  = `dox.verify` sweeps the tracked set for account-shaped dox. a commit
#         adds other classes too — a tailnet name, an auth key, a tailnet ip,
#         a hostname. git keeps the blob after a redaction, so the only cheap
#         moment is before the push, and a push publishes the diff and its message
#
# .the bar = obscurity is no security measure. access rules — acl policy, tags,
#         groups, ssh and port rules — may live here in full, written against
#         tags and groups. what stays out is ADDRESS DETAIL and SECRETS:
#
#   tailnet   a `*.ts.net` name
#   key       a `tskey-…` auth key            (a SECRET: rotate, then redact)
#   tailip    a 100.64.0.0/10 address, quad-100 aside (tailscale's fixed resolver)
#   ipv4      any other dotted quad. aside: loopback, any, broadcast, the
#             link-local metadata constant, and the rfc 5737 documentation ranges
#   host      this box's hostname as a bare word, a distro default aside
#   machine   a named grove (`grove-<org>-v<date>`) or an instance id
#   email     a person's address. aside: `example.{com,org,net}` (rfc 2606), a
#             `<tier>@<platform>` server tag, a vendor's published key uid
#   account   a 12-digit run, the declared dummy aside
#   ssm       an ssm arn or parameter path
#
#   only what the commit ADDS is read, so a value already on main is out of scope
#
# 🛑 .why the hostname is read at RUN time
#         a literal of it, in this file, is the very detail it hunts
#
# usage:
#   rhx dox.diff.verify                                # the staged diff vs HEAD
#   rhx dox.diff.verify --message .log/ship/commit.message.md --message <file>
#
# exit:
#   0 = no hit, and at least one added line was read
#   1 = at least one hit — each named with file, line, class, and value
#   2 = no repo, or no added line and no message (proves no claim)
######################################################################
set -uo pipefail

MESSAGES=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --message) MESSAGES+=("${2:?--message needs a path}"); shift 2 ;;
    --repo|--role|--skill) shift 2 ;;   # rhx passes these through
    --help|-h) sed -n '2,40p' "$0"; exit 0 ;;
    *) echo "✋ ConstraintError: unknown option: $1" >&2; echo "   └─ see: rhx dox.diff.verify --help" >&2; exit 2 ;;
  esac
done

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "✋ ConstraintError: not inside a git repository" >&2; exit 2; }
cd "$ROOT" || exit 2

# the run-time word: this box's hostname. a distro default names the os, never a box
HOST="$(hostname 2>/dev/null)"
[[ "$HOST" =~ ^(pop-os|ubuntu|localhost|debian)$ ]] && HOST=""
# the vendors whose published key uids a bundle pins
VENDORS='tailscale\.com'

HITS=()
LINES_READ=0

# .what = classify one line; append "<where>|<class>|<value>" per hit
scan_line() {
  local where="$1" text="$2" m
  while read -r m; do [[ -n "$m" ]] && HITS+=("$where|tailnet|$m"); done < <(grep -oE '[A-Za-z0-9-]+\.ts\.net' <<< "$text")
  while read -r m; do [[ -n "$m" ]] && HITS+=("$where|key|${m:0:12}…"); done < <(grep -oE 'tskey-[A-Za-z0-9]+-[A-Za-z0-9-]{6,}' <<< "$text")
  while read -r m; do
    [[ -z "$m" || "$m" == "100.100.100.100" || "$m" == "100.64.0.0" ]] && continue   # quad-100; the range's own base
    HITS+=("$where|tailip|$m")
  done < <(grep -oE '(^|[^0-9.])100\.(6[4-9]|[7-9][0-9]|1[01][0-9]|12[0-7])\.[0-9]{1,3}\.[0-9]{1,3}($|[^0-9.])' <<< "$text" | grep -oE '100\.[0-9.]+[0-9]')
  while read -r m; do
    [[ -z "$m" ]] && continue
    [[ "$m" =~ ^(0\.0\.0\.0|127\..*|255\.255\.255\.255|100\..*|169\.254\.169\.254|192\.0\.2\..*|198\.51\.100\..*|203\.0\.113\..*)$ ]] && continue
    HITS+=("$where|ipv4|$m")
  done < <(grep -oE '(^|[^0-9.vV])([0-9]{1,3}\.){3}[0-9]{1,3}($|[^0-9.])' <<< "$text" | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}')
  [[ -n "$HOST" ]] && grep -qwF -- "$HOST" <<< "$text" && HITS+=("$where|host|<this hostname>")
  while read -r m; do
    [[ -z "$m" ]] && continue
    [[ "$m" =~ @example\.(com|org|net)$ ]] && continue
    [[ "$m" =~ ^(local|cloud|house)@ ]] && continue
    [[ "$m" =~ @($VENDORS)$ ]] && continue
    HITS+=("$where|email|$m")
  done < <(grep -oE '[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}\b' <<< "$text" | grep -vE '\.[A-Za-z]*[0-9]')
  while read -r m; do
    [[ -z "$m" || "$m" == "123456789012" ]] && continue
    HITS+=("$where|account|$m")
  done < <(grep -oE '(^|[^0-9A-Za-z])[0-9]{12}($|[^0-9A-Za-z])' <<< "$text" | grep -oE '[0-9]{12}')
  while read -r m; do [[ -n "$m" ]] && HITS+=("$where|ssm|$m"); done < <(grep -oE 'arn:aws:ssm:[a-z0-9-]+:[0-9]*:parameter/[A-Za-z0-9/_.-]+|parameter/[A-Za-z0-9_.-]+/[A-Za-z0-9/_.-]+|/aws/reference/[A-Za-z0-9/_.-]+' <<< "$text")
  while read -r m; do [[ -n "$m" ]] && HITS+=("$where|machine|$m"); done < <(grep -oE '\bgrove-[a-z0-9]+-v[0-9]{8}\b|\bi-[0-9a-f]{8,17}\b' <<< "$text" | grep -v 'i-0123456789abcdef0')
}

# every line to judge, as two aligned files: where it sits, and what it says
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
: > "$WORK/where"; : > "$WORK/text"

# the staged diff: the file and the new-side line number of each added line
git diff --cached HEAD -U0 --no-color --no-ext-diff | awk -v W="$WORK/where" -v T="$WORK/text" '
  /^\+\+\+ b\// { file = substr($0, 7); next }
  /^\+\+\+ /    { file = ""; next }
  /^@@ /        { split($3, a, ","); line = substr(a[1], 2) + 0; next }
  /^\+/         { if (file == "") next; print file ":" line >> W; print substr($0, 2) >> T; line++ }
'

# each named message, line by line
for msg in "${MESSAGES[@]}"; do
  [[ -r "$msg" ]] || { echo "✋ ConstraintError: cannot read --message $msg" >&2; exit 2; }
  awk -v M="$msg" -v W="$WORK/where" -v T="$WORK/text" '{ print M ":" NR >> W; print >> T }' "$msg"
done
LINES_READ="$(wc -l < "$WORK/text")"

# .why a prefilter = a classify forks ~20 times per line; one grep picks the few
#      lines any class could match, and only those are classified
UNION='\.ts\.net|tskey-|([0-9]{1,3}\.){3}[0-9]{1,3}|@[A-Za-z0-9-]+\.|[0-9]{12}|arn:aws:ssm|parameter/|/aws/reference/|grove-[a-z0-9]+-v[0-9]{8}|\bi-[0-9a-f]{8,17}\b'
{
  grep -nE -- "$UNION" "$WORK/text" | cut -d: -f1
  [[ -n "$HOST" ]] && grep -nwF -- "$HOST" "$WORK/text" | cut -d: -f1
} | sort -un > "$WORK/candidates"

while read -r n; do
  scan_line "$(sed -n "${n}p" "$WORK/where")" "$(sed -n "${n}p" "$WORK/text")"
done < "$WORK/candidates"

echo "🌲 dox.diff.verify"
echo "   ├─ read: $LINES_READ added line(s), ${#MESSAGES[@]} message file(s)"
if [[ "$LINES_READ" -eq 0 ]]; then
  echo "   └─ 🌙 no added line and no message, so no claim is proven"
  exit 2
fi
if [[ "${#HITS[@]}" -eq 0 ]]; then
  echo "   └─ ✔ clean: no tailnet name, auth key, ip, hostname, machine name, email, account id, or ssm path"
  exit 0
fi
echo "   └─ ✋ ${#HITS[@]} hit(s)"
i=0
for h in "${HITS[@]}"; do
  i=$((i + 1))
  IFS='|' read -r where class value <<< "$h"
  glyph="├─"; [[ "$i" -eq "${#HITS[@]}" ]] && glyph="└─"
  echo "      $glyph $class  $value  ($where)"
done
exit 1
#!/usr/bin/env bash
######################################################################
# .what = renew a house seat's Roles Anywhere cert before it ends — run by the
#         `house.badge.renew.timer` user unit, never by a human
#
# .why  the cert lives 7 days (AWS Private CA short-lived mode), and a box that
#       needs a human to re-auth on a schedule is a workstation, not a grove
#       (vision case=7). so the seat renews with its own live badge: the old cert
#       signs the sts session that asks the CA for the new one
#
# .how
#   1. read the hours left. at or above the threshold, report and stop — the
#      timer fires hourly, so almost every run is this no-op
#   2. read the CA from `~/.aws/house/renew.env` (`GROVE_HOUSE_BADGE_CA_ARN=`),
#      which the mint writes. absent → refuse, by name: the CA is
#      `ahbode/infrastructure#36`'s to place, and a guess would ask the wrong one
#   3. a CSR from the SAME key and the SAME subject, so the key path never moves
#      and no trust anchor or profile has to change (F15 leaves the key path one line)
#   4. issue, wait, fetch — as `ambient`, the badge this renews
#   5. land the new cert at the same path, 0600, by a rename in the same dir, so
#      the helper reads either the old cert or the new one, never half
#
# 🛑 it prints no secret: the key never leaves its file, and the cert is public
#
# guarantee:
#   - idempotent: above the threshold it writes naught
#   - exit 0 = renewed, or no renewal owed · 1 = the renewal failed, named ·
#     2 = it cannot be asked (no cert, no CA named, no cli)
#   - a failure here is read again by `5.6.aws`'s verify, which refuses at the
#     same threshold — so a broken renewal is loud on the next converge too
######################################################################

set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$here/_.sh"

cert="$(grove_provision_5_6_aws_house_cert)"
key="$(grove_provision_5_6_aws_house_key)"
dir="$(grove_provision_5_6_aws_house_dir)"
at="$GROVE_PROVISION_5_6_AWS_HOUSE_RENEW_AT_HOURS"

echo "🏠 house.badge.renew"

left="$(grove_provision_5_6_aws_cert_hours_left "$cert")"
if [[ "$left" == '?' ]]; then
  echo "   ✋ ConstraintError: no readable cert at $cert" >&2
  echo "      ⇒ a renewal signs with the cert it renews, so with none there is no badge to sign as" >&2
  echo "      fix: re-issue from the host — the mint that placed the first cert places this one" >&2
  exit 2
fi
if (( left >= at )); then
  echo "   • $left hours left; renewal is owed below $at — no change"
  exit 0
fi
echo "   • $left hours left, below $at — renew"

# shellcheck source=/dev/null
[[ -r "$dir/renew.env" ]] && source "$dir/renew.env"
ca="${GROVE_HOUSE_BADGE_CA_ARN:-}"
if [[ -z "$ca" ]]; then
  echo "   ✋ ConstraintError: no CA named in $dir/renew.env (GROVE_HOUSE_BADGE_CA_ARN)" >&2
  echo "      ⇒ the CA and the grant to issue from it are ahbode/infrastructure#36's" >&2
  echo "      fix: the mint writes renew.env once #36 names the CA" >&2
  exit 2
fi
command -v aws >/dev/null 2>&1 || {
  echo "   ✋ ConstraintError: no aws cli" >&2
  echo "      fix: rhx grove.provision --what 5.6.aws --mode apply" >&2
  exit 2
}

# the algorithm follows the key: an ec key carries a curve oid, an rsa key does not
# ⚠️ no `grep -q` under pipefail — a match SIGPIPEs openssl and reads as a miss
algo="SHA256WITHRSA"
openssl pkey -in "$key" -noout -text 2>/dev/null | grep 'ASN1 OID' >/dev/null && algo="SHA256WITHECDSA"

work="$(mktemp -d "$dir/.renew.XXXXXX")" || exit 1
trap 'rm -rf "$work"' EXIT
chmod 700 "$work"

subj="$(openssl x509 -noout -subject -nameopt compat -in "$cert" | sed 's/^subject=[[:space:]]*//')"
if ! openssl req -new -key "$key" -subj "$subj" -out "$work/badge.csr" 2>"$work/err"; then
  echo "   ✋ the CSR could not be made from $key" >&2
  sed 's/^/      /' "$work/err" >&2
  exit 1
fi

if ! arn="$(AWS_PROFILE=ambient timeout -k 5 60 aws acm-pca issue-certificate \
    --certificate-authority-arn "$ca" \
    --csr "fileb://$work/badge.csr" \
    --signing-algorithm "$algo" \
    --template-arn 'arn:aws:acm-pca:::template/EndEntityClientAuthCertificate/V1' \
    --validity 'Value=7,Type=DAYS' \
    --query CertificateArn --output text 2>"$work/err")"; then
  echo "   ✋ the CA refused the issue" >&2
  sed -E 's/[0-9]{12}/<acct>/g; s/^/      /' "$work/err" >&2
  echo "      ⇒ $left hours left; the badge dies at 0, and the next converge refuses meanwhile" >&2
  exit 1
fi

if ! AWS_PROFILE=ambient timeout -k 5 120 aws acm-pca wait certificate-issued \
    --certificate-authority-arn "$ca" --certificate-arn "$arn" 2>"$work/err" \
  || ! AWS_PROFILE=ambient timeout -k 5 60 aws acm-pca get-certificate \
    --certificate-authority-arn "$ca" --certificate-arn "$arn" \
    --query Certificate --output text 2>"$work/err" | tee "$work/badge.crt" >/dev/null; then
  echo "   ✋ the cert was issued and could not be fetched" >&2
  sed -E 's/[0-9]{12}/<acct>/g; s/^/      /' "$work/err" >&2
  exit 1
fi

# the new cert must parse, and must outlive the one it replaces
fresh="$(grove_provision_5_6_aws_cert_hours_left "$work/badge.crt")"
if [[ "$fresh" == '?' ]] || (( fresh <= left )); then
  echo "   ✋ the fetched cert reads $fresh hours left, no more than the old one's $left — kept the old" >&2
  exit 1
fi

chmod 600 "$work/badge.crt" && mv -f "$work/badge.crt" "$cert" || exit 1
echo "   • renewed ✔ — $fresh hours left, at $cert (0600)"

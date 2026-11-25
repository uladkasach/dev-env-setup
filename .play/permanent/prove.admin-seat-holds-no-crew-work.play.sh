#!/usr/bin/env bash
######################################################################
# .what = read the ADMIN seat's live state and fail on any credential or crew work
#
# .why  = `prove.admin-seat-holds-no-credentials` proves the bundles DECLINE on
#         ground; it reads code paths, never the disk. 📜 2026-11-18,
#         the first hetzner grove: the bare alias dialed ground for days, so
#         every camper-aimed apply, gate, and `keys.set` ran there. each bundle
#         declined as built, and ground still came to hold a keyrack host file, a
#         svc-chat clone, and a docker test db — none written by a bundle. only a
#         read of the seat itself catches residue that no bundle wrote
#
# guarantee:
#   - runs on a seat named `ground`; declines (exit 2) on any other seat
#   - READ-ONLY: names each hit by path and date, never a value
#   - the one exemption is the boot's own checkout (~/git/more/dev-env-setup*),
#     which ground converges the box from
######################################################################

set -u

if [[ "$(id -un)" != "ground" ]]; then
  echo "🌙 prove.admin-seat-holds-no-crew-work declines: $(id -un) is not the admin seat"
  echo "   run it there: rhx git.grove.send <grove>.ground --reply --play prove.admin-seat-holds-no-crew-work"
  exit 2
fi

failed=0
found() { echo "   ✋ $1  ($([[ -e "$2" ]] && stat -c '%y' "$2" | cut -c1-16))"; failed=1; }
held()  { echo "   • $1 ✔"; }

echo "🌲 prove.admin-seat-holds-no-crew-work"

# 1. credentials — an admin seat holds none (`prove.admin-seat-holds-no-credentials`)
for p in .rhachet/keyrack .config/gh/hosts.yml .claude/.credentials.json .git-credentials .netrc; do
  if [[ -e "$HOME/$p" ]]; then found "~/$p is present — a credential on the admin seat" "$HOME/$p"; else held "~/$p absent"; fi
done
if [[ -s "$HOME/.aws/credentials" ]] && grep -qE '^[[:space:]]*aws_(access_key_id|secret_access_key|session_token)[[:space:]]*=[[:space:]]*[^[:space:]]' "$HOME/.aws/credentials"; then
  found "~/.aws/credentials holds a key value" "$HOME/.aws/credentials"
else
  held "~/.aws/credentials holds no key value"
fi
if bash -lc env 2>/dev/null | grep -qE '^(GITHUB_TOKEN|GH_TOKEN)='; then
  found "a login shell exports a github token" "$HOME/.profile"
else
  held "no login shell exports a github token"
fi

# 2. crew work — clones other than the boot checkout, docker state, an org commit meter
crew=0
for d in "$HOME"/git/*/*; do
  [[ -d "$d" ]] || continue
  case "${d#$HOME/}" in git/more/dev-env-setup*) continue ;; esac
  found "~/${d#$HOME/} is a crew clone" "$d"; crew=1
done
(( crew == 0 )) && held "no crew clone under ~/git (the boot checkout is exempt)"
if [[ -d "$HOME/.local/share/docker" ]]; then found "~/.local/share/docker holds docker state" "$HOME/.local/share/docker"; else held "no docker state"; fi
# the org commit meter is crew work: `5.26.commitorgs` writes it on the crew seat and
# declines here (`grove_provision_5_26_commitorgs_declines`), so a meter on this seat
# means a crew-aimed apply reached ground. the path is the bundle's own, so both read one file
_meter="$HOME/.rhachet/storage/repo=ehmpathy/role=mechanic/.meter/git.commit.uses.org.jsonc"
_bundle="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/src/grove.provision/5.devtools/5.26.commitorgs/_.sh"
# shellcheck disable=SC1090
# a reader that answers empty (renamed, or failed) keeps the known path, so the check never loses its subject
_derived=''; [[ -r "$_bundle" ]] && _derived="$(source "$_bundle" && grove_provision_5_26_commitorgs_meter_path)"
[[ -n "$_derived" ]] && _meter="$_derived"
if [[ -e "$_meter" ]]; then
  found "${_meter/#$HOME/\~} holds an org commit meter — crew work on the admin seat" "$_meter"
else
  held "no org commit meter"
fi

if (( failed == 0 )); then
  echo "🌲 all claims held ✔"
  exit 0
fi
echo "💥 MalfunctionError: the admin seat holds crew work or a credential"
echo "   ⇒ some camper-aimed command reached ground. read why: rhx git.grove.get <grove> (user, host)"
echo "      and ssh -G <alias> | grep -E '^(user|hostname) '"
exit 1

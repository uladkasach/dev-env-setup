#!/usr/bin/env bash
######################################################################
# .what = the flathub desktop clients — spotify, datagrip, slack
#
# .why one bundle, not three
#   - a bundle is a CONCERN, not an app
#   - the three share one command, one registry, one prompt hazard, one
#     decline reason
#   - codium, dropbox, protonvpn each carry their own apt repo and version
#     pin, so those stay distinct bundles
#
# .why no `configure` phase
#   - a human configures each inside its own window, with an account this
#     repo holds no credential for (rule.require.repo-as-source-of-truth)
#
# .why all three are OPT-IN
#   - a desktop client is a PREFERENCE, not a fact about the box
#   - `GROVE_OPTIN_APPS`, `src/bundle.upgrade.sh`
#
# usage:
#   rhx grove.provision --what 6.1.flatpaks --mode apply
#   rhx grove.provision --include slack,spotify --mode apply
######################################################################

# the three apps, and the flathub ref each resolves to
# .why keyed by the opt-in name: `slack` and `com.slack.Slack` are one fact,
#      declared once; the offered-name list DERIVES from the keys
#      (rule.require.identical-bundle-composition)
declare -gA GROVE_FLATPAK_REF=(
  [spotify]=com.spotify.Client
  [datagrip]=com.jetbrains.DataGrip
  [slack]=com.slack.Slack
)
GROVE_OPTIN_APPS+=("${!GROVE_FLATPAK_REF[@]}")

# .what = apps of this bundle the human asked for, sorted
# .why  both phases ask the same question, so they ask it once here
grove_provision_6_1_flatpaks_wanted() {
  local name
  while read -r name; do
    [[ -n "$name" ]] || continue
    grove_optin "$name" && echo "$name"
  done < <(printf '%s\n' "${!GROVE_FLATPAK_REF[@]}" | sort)
}

# .why the all-opted-out case declines HERE, not in a phase
#   - once the bundle declines, its phases never run
#   - `grove_optin_decline`, `src/bundle.upgrade.sh`
grove_provision_6_1_flatpaks() {
  local want; want="$(grove_provision_6_1_flatpaks_wanted)"
  if [[ -z "$want" ]]; then
    # .why both arguments derive from the map in one pass
    #   - .refs = gotcha.6-1-flatpaks.demo=printed-offer-list-drifted.md
    local offers; offers="$(printf '%s\n' "${!GROVE_FLATPAK_REF[@]}" | sort | paste -sd, -)"
    grove_optin_decline "${offers//,/, }" "$offers"
    return 0
  fi

  bundle.upgrade 6.1.flatpaks.provision.upsert
  bundle.upgrade 6.1.flatpaks.provision.verify
}

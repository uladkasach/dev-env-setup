#!/usr/bin/env bash
# .what = clone every repo of the orgs THIS GROVE'S ORG declares, and declare the
#   PROTOCOL those clones — and this checkout — speak to github
# .why
#   - `5.4.gh` owns whether gh holds a CREDENTIAL; this owns the repos on disk
#   - the exposure lever is the token's SCOPE and the per-org table below
#   - `uladkasach` is absent from the org list — a personal repo is fetched on purpose
#
# usage:
#   rhx grove.provision --what 5.10.repos --mode apply
#   GROVE_GIT_ORGS='ahbode' rhx grove.provision --what 5.10.repos --mode apply

# .what = which orgs' repos this grove's org clones — own-org by default, every
#   other row an enumerated opt-in with its reason
# 🔴 it is PER-ORG: a reach row buys ONE account, a clone set buys every repo a
#      token can see (`rule.require.a-grove-reaches-its-own-org-only`)
# 🛑 an org with no arm clones NO REPO AT ALL — clause 3, and the clause a
#      "sensible default" deletes
# 🛑 it is a MAP, never an identity — the KEY is the keyrack org, the VALUES are
#      GITHUB orgs. read `gh repo list <org>` before an arm is declared
# ⚠️ `GROVE_GIT_ORGS` overrides for a human's one-org view; it declares no row
# .refs = gotcha.5-10-repos.demo=org-axis-and-the-name-map
grove_provision_5_10_repos_orgs() {
  [[ -n "${GROVE_GIT_ORGS:-}" ]] && { printf '%s' "$GROVE_GIT_ORGS"; return 0; }

  local org="${GROVE_ORG:-}"
  [[ -n "$org" ]] || return 0

  case "$org" in
    # .ehmpathy + whodisio are ahbode's DECLARED opt-ins, never a default — the
    #   generic infra org its services build on, and the identity org they
    #   authenticate through. neither generalizes to another org
    ahbode) printf 'ahbode ehmpathy whodisio' ;;

    # ⚠️ `aether-auctions` IS aether's own org — the names differ, the org does
    #   not. own-org only, deliberately
    aether) printf 'aether-auctions' ;;

    *)      return 0 ;;
  esac
}

# .what = is this box's plain-https git already authorized by the RACK?
# .why an ssh key needs a human to register each one; the https helper draws
#   from a CENTRAL secret, so it reads git's config, never the server tag
#   (.refs = gotcha.5-10-repos-two-readers.demo=clone-cut-partway)
#
# exit: 0 = draws from the rack; 1 = the ssh key is this box's only credential-free path
grove_provision_5_10_repos_https_is_racked() {
  local helper
  helper="$(git config --global --get credential."https://github.com".helper 2>/dev/null || true)"
  [[ -n "$helper" && "$helper" == *git-credential-keyrack && -x "$helper" ]]
}

# .what = which of THREE states is this repo dir in? whole|half|absent
# .why a state, never a boolean, so upsert and verify share one fact; reads
#   `.git/HEAD` never `git rev-parse`, which forks git across hundreds of
#   repos on every plan (.refs = gotcha.5-10-repos-two-readers.demo=clone-cut-partway)
#
# stdout: whole = readable HEAD; half = clone cut partway; absent = never cloned
grove_provision_5_10_repos_state() {
  [[ -d "$1/.git" ]]   || { echo absent; return 0; }
  [[ -r "$1/.git/HEAD" ]] || { echo half; return 0; }
  echo whole
}

grove_provision_5_10_repos() {
  bundle.upgrade 5.10.repos.provision.upsert
  bundle.upgrade 5.10.repos.provision.verify
  bundle.upgrade 5.10.repos.configure.upsert
  bundle.upgrade 5.10.repos.configure.verify
}

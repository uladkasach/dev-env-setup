#!/usr/bin/env bash
# .what = clone every repo of the orgs a human belongs to, and declare the
#   PROTOCOL those clones — and this checkout — speak to github
# .why
#   - `5.4.gh` owns whether gh holds a CREDENTIAL; this owns the repos on disk
#   - the exposure lever is the token's SCOPE and `GROVE_GIT_ORGS`, not the box kind
#   - `uladkasach` is absent from the org list — a personal repo is fetched on purpose
#
# usage:
#   rhx grove.provision --what 5.10.repos --mode apply
#   GROVE_GIT_ORGS='ahbode' rhx grove.provision --what 5.10.repos --mode apply

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

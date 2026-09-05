#!/usr/bin/env bash
######################################################################
# .what = git's identity on this box — who its commits are attributed to
#
# .why a bundle of its own, never folded into `2.2.git`
#   - the identity DERIVES from this box's github credential, wired by
#     `5.4.gh` in section 5 — a first apply inside `2.2.git` (section 2)
#     could never derive it (`rule.require.one-command-provision`)
#   - ten aliases and two defaults need no credential and stay in section
#     2 (`rule.forbid.two-writers-on-one-artifact`)
#   - .refs = gotcha.5-15-identity.demo=decline-shape.md
#   - it applies EVERYWHERE: a grove commits through the same aliases a
#     laptop does, and unconfigured there attributes every commit to none
#
# usage:
#   rhx grove.provision --what 5.15.identity --mode apply
######################################################################

# .what = derive this box's git identity from the github account its credential
#         authenticates as, and print it as `<name>\t<email>`; a grove has no
#         tty, so `configure.upsert.sh` cannot prompt for a name
#   - `gh api user` returns `.email` as null on a private account (the
#     common case), so this uses the NOREPLY alias from the same call
#   - it PRINTS rather than assigns, and an explicit `GIT_USER_EMAIL` still
#     wins over this default — one call, one precedence order
grove_provision_5_15_identity_from_gh() {
  command -v gh >/dev/null 2>&1 || return 1

  local user
  user="$(gh api user --jq '[.name // .login, .login, .id] | @tsv' 2>/dev/null)" || return 1
  [[ -n "$user" ]] || return 1

  local ghname ghlogin ghid
  IFS=$'\t' read -r ghname ghlogin ghid <<< "$user"
  [[ -n "$ghlogin" && -n "$ghid" ]] || return 1

  printf '%s\t%s+%s@users.noreply.github.com' "$ghname" "$ghid" "$ghlogin"
}

grove_provision_5_15_identity() {
  bundle.upgrade 5.15.identity.configure.upsert
  bundle.upgrade 5.15.identity.configure.verify
}

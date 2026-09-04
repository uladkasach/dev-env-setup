#!/usr/bin/env bash
######################################################################
# .what = git itself, its two safety defaults, and the alias suite this repo's
#         own workflow rests on
#
# .why git is PROVISIONED here and not assumed
#   - no prior step installed it
#   - `configure_tmux` calls `git clone` for tpm, and `grove.bootstrap.sh` clones this repo
#   - ⇒ every path into this repo already had a git, which is why nobody noticed
#   - an undeclared dependency breaks on the first image that omits it
#   - the absent `unzip` in `2.1.toolkit` is the same shape
#
# 🛑 .why the IDENTITY is NOT here, though it is also a `git config --global`
#   - a bundle is a unit of DEPENDENCY, never a unit of destination file
#   - the identity is DERIVED from this box's github credential
#   - that credential is wired by `5.4.gh`, in section 5
#   - ⇒ a FIRST apply of section 2 could never set it
#   - the phase would decline and ask for a second apply
#   - `rule.require.one-command-provision` calls that a blocker
#   - ⇒ the identity lives at `5.15.identity`, after the gh it needs
#   - the twelve declarations that need no credential stay here
#   - ⚠️ `rule.forbid.two-writers-on-one-artifact` binds one ARTIFACT to one writer
#   - `user.email` and `alias.tree` are distinct artifacts that share a container
#   - ⇒ two bundles may write one file when each owns a distinct key
#
# .why this bundle applies to a HEADLESS box too
#   - a grove commits, pushes, and runs `git tree` / `git grab` through the same aliases
#   - the duct exists so the grove can DO this work
#
# guarantee:
#   - identical on every machine (rule.require.identical-bundle-composition)
######################################################################

grove_provision_2_2_git() {
  bundle.upgrade 2.2.git.provision.upsert
  bundle.upgrade 2.2.git.provision.verify
  bundle.upgrade 2.2.git.configure.upsert
  bundle.upgrade 2.2.git.configure.verify
}

#!/usr/bin/env bash
######################################################################
# .what = the dev toolchain — the runtimes, the clients, and the repos
#
# .why it holds no predicate
#   - node and rust apply everywhere; docker and terraform do not
#   - only each leaf knows which it is, so no answer belongs at this node
#     (`grove.env.sh` on why the `grove_env_has_*` predicates were cut)
#
# .why this list, not the directory digits, IS the dispatch order
#   - a number is a stable NAME, never a position — `5.11.usql` runs before
#     `5.10.repos` below
#   - three bundles are numbered for their SUBJECT while the real dependency
#     is a tool or credential that lands later — `5.14.treesitter` (needs
#     cargo, from `5.2.rust`), `5.4.gh` (needs a credential, from
#     `5.3.brains`), `5.15.identity` (needs a github login, from `5.4.gh`)
#   - `5.12.rack` sits between aws and gh: it writes the keyrack entry gh
#     reads, and reads its own value out of ssm through the aws cli
#   - `5.10.repos` and `5.13.reach` run last: both need clones only
#     `5.10.repos` provides
#   - .refs = howdoes.5-devtools-dispatch-order.md — the full trace, per swap
#
# .why every install here is a BUNDLE, never a function on a roll
#   - a roll reaches only what somebody remembers to write, so a declared but
#     undriven install reads as live and is dead
#     (`rule.require.bundle-as-sole-declaration`)
#
# usage:
#   rhx grove.provision --what 5.devtools --mode apply
######################################################################

grove_provision_5_devtools() {
  bundle.upgrade 5.1.node
  bundle.upgrade 5.2.rust
  bundle.upgrade 5.14.treesitter
  bundle.upgrade 5.3.brains
  bundle.upgrade 5.5.psql
  bundle.upgrade 5.6.aws
  bundle.upgrade 5.12.rack
  bundle.upgrade 5.4.gh
  bundle.upgrade 5.15.identity
  bundle.upgrade 5.7.terraform
  bundle.upgrade 5.8.docker
  bundle.upgrade 5.9.yubikey
  bundle.upgrade 5.11.usql
  bundle.upgrade 5.10.repos
  bundle.upgrade 5.13.reach
}

#!/usr/bin/env bash
######################################################################
# .what = a THIN SHIM onto `src/machine/machine_usage_diagnose`
#
# 🛑 .why the implementation does NOT live here
#   - `.agent/` sits OUTSIDE the deployable unit. a bundle installs from
#     `$GROVE_SRC`, so an implementation under `.agent/` can be installed by
#     no bundle at all (`rule.require.bundles-own-their-dependencies`)
#   - and `rhx <skill>` resolves ONLY where rhachet roles are linked. a bare
#     `alias machine.usage.diagnose='rhx machine.usage.diagnose'` therefore
#     dies in every dir outside this repo — and `~/.bash_aliases` is sourced
#     by EVERY shell, everywhere (`rule.forbid.the-driver-by-path`, carve-out 3)
#   - 📜 that alias shipped in this branch before the glossary round caught it.
#     the premise was wrong: agent-invocable does NOT require an rhx skill.
#     `1.6.1.finders` already puts `src/machine/*` on PATH, which serves a
#     human and an agent alike
#
# ⇒ so the implementation is a declared ASSET of `src/`, installed to
#   `~/.local/bin/machine_usage_diagnose` by `1.6.1.finders`, and this file
#   is a shim so `rhx` still reaches it from a checkout where no install has
#   run yet. ONE implementation, ONE writer
#   (`rule.forbid.two-writers-on-one-artifact`)
#
# usage:
#   machine_usage_diagnose            # once installed — the human + agent path
#   rhx machine.usage.diagnose        # from a checkout, pre-install
######################################################################

set -euo pipefail

# `$0` is this shim, and `src/` sits beside `.agent/`, four levels up.
# a RELATIVE derivation, never a `~/git/more/dev-env-setup` literal — that
# would be a checkout-path assertion, false on every worktree
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)/src/machine/machine_usage_diagnose" "$@"

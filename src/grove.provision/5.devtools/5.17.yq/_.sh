#!/usr/bin/env bash
######################################################################
# .what = yq — a jq-syntax processor for yaml, as ONE pinned static binary
# .ref  = https://github.com/mikefarah/yq
#
# .who depends on it
#   - the declapract cycles gate reads `.dpdmrc.yaml` through it:
#       dpdm --exclude "$(yq -r '.exclude | join("|") // "^$"' .dpdmrc.yaml)"
#   - ⇒ with no yq the `$(…)` collapses to an EMPTY string, dpdm then scans
#     node_modules, and the gate reports hundreds of cycles that do not exist
#   - a false ✋ on every run is the shape that gets a check silenced
#     (`gotcha.a-check-that-cries-wolf-gets-silenced`)
#
# 🛑 .why this is a BUNDLE and not a name on `2.1.toolkit`'s apt line
#   - a name on that line must be a package EVERY box class carries
#   - measured 2026-09-11: jammy (a grove) offers NO candidate at all — not in
#     universe, not in backports — while noble (a laptop) offers 3.1.0-3
#   - ⇒ an apt name that resolves on one box class and not the other cannot meet
#     `rule.require.identical-bundle-composition`
#   - a pinned static binary is the SAME artifact on every box, so it can
#
# 🛑 .why NOT pipx, and not a python runtime of any kind
#   - pipx does reach both classes, and that is the whole trap: it buys the
#     reach by a runtime, a venv, and a resolver this repo would then own
#   - `rule.avoid.python-runtimes` carries the full argument
#   - the go build needs no runtime at all, which is why it wins on both axes
#
# ⚠️ .the two programs named `yq` are NOT the same program
#   | build              | what it is                    | filter syntax |
#   |--------------------|-------------------------------|---------------|
#   | mikefarah (THIS)   | a go binary, yaml-native      | jq-like       |
#   | apt `python3-yq`   | a python wrapper around `jq`  | jq, via json  |
#   - a laptop that took the apt one carries a SECOND `yq` at `/usr/bin/yq`
#   - `~/.local/bin` precedes `/usr/bin` on this repo's PATH, so ours wins —
#     and the verify reads `bundle.bin.at`, which does not depend on that
#
# .it applies to EVERY machine
#   - the cycles gate runs wherever the repo is linted, which is every box
#   - so there is no decline
#
# usage:
#   rhx grove.provision --what 5.17.yq --mode apply
######################################################################

######################################################################
# 🛑 the version is declared HERE, once, because TWO phases read it
#
# 📜 2026-08-13, `5.11.usql`: typed in both, the two drift the instant one moves
#   - a bump of the upsert left the verify behind, so a correct install
#     reported `✋ the WRONG version` and named a re-apply that changed no state
#   - ⇒ the pin and the check must read the SAME variable
#
# .the DIGEST stays in the upsert
#   - the verify reads a binary on disk, where a digest describes a gone file
#   - one reader means one home (`rule.prefer.most-common-denominator`)
#
# .to bump: read the digest the REGISTRY states, never one computed locally
#       gh api -X GET repos/mikefarah/yq/releases/latest \
#         --jq '.tag_name, (.assets[] | select(.name=="yq_linux_amd64") | .digest)'
######################################################################
export GROVE_YQ_VERSION="4.53.6"

grove_provision_5_17_yq() {
  bundle.upgrade 5.17.yq.provision.upsert
  bundle.upgrade 5.17.yq.provision.verify
}

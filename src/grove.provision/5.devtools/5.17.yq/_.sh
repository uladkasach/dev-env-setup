#!/usr/bin/env bash
######################################################################
# .what = yq — a jq-syntax processor for yaml, as ONE pinned static binary
# .ref  = https://github.com/mikefarah/yq
#
# .why it exists
#   - the declapract cycles gate filters `.dpdmrc.yaml` through it; with no yq
#     that `$(…)` collapses to EMPTY, dpdm scans node_modules, and the gate
#     reports hundreds of cycles that do not exist — a false ✋ every run
#
# .why a BUNDLE, never an apt name on `2.1.toolkit`
#   - jammy offers no candidate at all, noble offers one, so an apt name reaches
#     one box class alone (`rule.require.identical-bundle-composition`)
#   - a pinned static binary is the SAME artifact on every box
#   - ⛔ not pipx: it reaches both by a runtime, a venv, and a resolver this repo
#     would then own (`rule.avoid.python-runtimes`)
#
# ⚠️ two programs are named `yq`, and ours is mikefarah's go build — never apt's
#   `python3-yq`, which wraps `jq`. the verify reads `bundle.bin.at`, by file
#
# .it applies to EVERY machine — the gate runs wherever the repo is linted
#
# .refs = gotcha.5-17-yq.demo=apt-gap-and-two-programs.md
#
# usage:
#   rhx grove.provision --what 5.17.yq --mode apply
######################################################################

######################################################################
# 🛑 the version is declared HERE, once, because TWO phases read it — typed in
#   both, a bump of one leaves the other behind, and a correct install then
#   reports the WRONG version with a fix-text that changes no state
#
# .the DIGEST stays in the upsert — a verify reads a binary on disk, where a
#   digest describes a gone file (`rule.prefer.most-common-denominator`)
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

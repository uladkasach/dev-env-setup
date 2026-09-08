#!/usr/bin/env bash
######################################################################
# .what = the capture chain a mic take rides — recorder, mixer control, alert
#         sink, sleep inhibitor
#
# .why
#   - a BOX concern: a mic is hardware, like the keyboard `1.1` remaps
#   - the real work is the VERIFY; every link is base-system or one apt name away
#   - `1.9` rather than under `1.6.procs`: that dir owns runaway processes, this
#     owns audio (`rule.require.bundle-names-name-their-subject`)
#
# ⚠️ the gate is `local@unix` exactly — `local@*` is too coarse
#   - a capture needs a physical MICROPHONE; `local@cicd` has none either
#
# ⚠️ this bundle does NOT own the capture dir
#   - a take's path names a real family, and this repo is PUBLIC
#     (`rule.forbid.dox-in-public-repo`). `rhx audio.record.start --into <dir>`
#     carries it at the call site
#
# ✔ `take` is the settled word for ONE artifact
#   (`term=audio.record.take._.choice._.md`); `capture` names the ACT and the
#   CHAIN, which is how this file uses it
#
# usage:
#   rhx grove.provision --what 1.9.audio --mode apply
######################################################################

grove_provision_1_9_audio() {
  bundle.upgrade 1.9.audio.provision.upsert
  bundle.upgrade 1.9.audio.provision.verify
}

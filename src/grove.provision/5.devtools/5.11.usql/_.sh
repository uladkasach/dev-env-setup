#!/usr/bin/env bash
######################################################################
# .what = usql — one CLI for 40+ databases (postgres, duckdb, athena, mysql…)
# .ref  = https://github.com/xo/usql
#
# ⚠️ this install is a BUNDLE, never a function on a roll
#   - a function no driver reaches is dead code that reads as live
#   - the only way to run one is to source a file and call it by hand
#   - `rule.require.install-via-procedures` forbids that instruction
#   - pqiv and yubikey-agent wore the same shape
#
# .it sits at 5.11 rather than beside 5.5.psql
#   - the two are kin, since both are database clients
#   - a renumber would churn every slug a human has typed today
#   - the slug is the handle (`rule.require.bundle-slug-matches-its-path`)
#   - ⇒ the kinship is recorded here instead
#
# .it applies to EVERY machine
#   - a grove queries the same databases a laptop does
#   - so there is no decline
#
# usage:
#   rhx grove.provision --what 5.11.usql --mode apply
######################################################################

######################################################################
# 🛑 the version is declared HERE, once, because TWO phases read it
#
# 📜 2026-08-13: typed in both, the two drift the instant one moves
#   - a security bump of the upsert 0.19.14 → 0.21.4 left the verify behind,
#     so a correct install reported `✋ usql is on PATH at the WRONG version`
#   - one fact, two declarations (`rule.require.identical-bundle-composition`)
#   - ⇒ the pin and the check must read the SAME variable
#
# .the DIGEST stays in the upsert
#   - the verify has no use for it
#   - it reads a binary on disk, where a digest describes a gone archive
#   - one reader means one home (`rule.prefer.most-common-denominator`)
######################################################################
export GROVE_USQL_VERSION="0.21.4"

grove_provision_5_11_usql() {
  bundle.upgrade 5.11.usql.provision.upsert
  bundle.upgrade 5.11.usql.provision.verify
}

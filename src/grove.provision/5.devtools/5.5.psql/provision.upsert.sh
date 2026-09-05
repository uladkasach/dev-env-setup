#!/usr/bin/env bash
# .what = install the postgres client
#
# guarantee:
#   - idempotent: apt converges on an already-installed package

grove_provision_5_5_psql_provision_upsert() {
  pkg_install postgresql-client || return 1
  echo "   • psql ✔"
}

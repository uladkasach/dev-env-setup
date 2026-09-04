#!/usr/bin/env bash
######################################################################
# .what = the postgres CLIENT — psql, with no server
#
# .client only
#   - every database this repo talks to is remote: rds, or a repo's own container
#   - a local server would listen on 5432 and start at boot
#   - it would hold a data dir no one reads
#   - `psql` is the only part ever used
#
# usage:
#   rhx grove.provision --what 5.5.psql --mode apply
######################################################################

grove_provision_5_5_psql() {
  bundle.upgrade 5.5.psql.provision.upsert
  bundle.upgrade 5.5.psql.provision.verify
}

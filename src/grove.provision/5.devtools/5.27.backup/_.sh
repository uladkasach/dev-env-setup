#!/usr/bin/env bash
######################################################################
# .what = camper's trees and home dirs back up every 3 hours, each tree one unit
#
# .why
#   - a grove holds the only copy of its unpushed work; a restore is the path back
#   - it declines off `cloud@*`: only a camp grove holds the aws identity the bucket grants
#     (`rule.require.aws-params-on-camp-groves-only`)
#   - infra owes /etc/grove/name and /etc/grove/backup.bucket; a run names the one absent
######################################################################

grove_provision_5_27_backup() {
  bundle.upgrade 5.27.backup.provision.upsert
  bundle.upgrade 5.27.backup.provision.verify
}

# .what = the four files this bundle installs → "src<TAB>dst<TAB>mode" lines
# .why one list: the upsert copies exactly what the verify diffs
grove_provision_5_27_backup_files() {
  local dir="$GROVE_SRC/grove.provision/5.devtools/5.27.backup"
  printf '%s\t%s\t%s\n' \
    "$dir/grove-backup"                 /usr/local/lib/grove-backup/grove-backup                 755 \
    "$dir/grove.backup.operations.sh"   /usr/local/lib/grove-backup/grove.backup.operations.sh   644 \
    "$dir/grove-backup.service"         /etc/systemd/system/grove-backup.service                 644 \
    "$dir/grove-backup.timer"           /etc/systemd/system/grove-backup.timer                   644
}

# .what = does this tier carry the camp aws identity the bucket grants? — the one gate both phases ask
grove_provision_5_27_backup_applies() { [[ "${GROVE_ENV_SERVER:-}" == cloud@* ]]; }

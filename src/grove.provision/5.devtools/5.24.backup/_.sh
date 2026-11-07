#!/usr/bin/env bash
######################################################################
# .what = every grove backs up its clones, worktrees, ~/.claude, and ~/.rhachet each hour
#
# .why
#   - a grove holds the only copy of its unpushed work; a hetzner box holds it on one ssd
#   - the backup is the one path back once a box dies (`rhx grove.backup.restore`)
#   - it declines off `cloud@*`: a laptop holds no grove role, a ci runner no unpushed work
#   - it runs after `5.6.aws`, which installs the cli the agent calls
#
# .what infra owes before a run is ✓ (each run names the one it lacks)
#   - /etc/grove/name, /etc/grove/backup.bucket, and on hetzner /etc/grove/aws.env
#
# usage:
#   rhx grove.provision --what 5.24.backup --mode apply
#   rhx grove.backup.get
######################################################################

grove_provision_5_24_backup() {
  bundle.upgrade 5.24.backup.provision.upsert
  bundle.upgrade 5.24.backup.provision.verify
}

# .what = the four files this bundle installs → "src<TAB>dst<TAB>mode" lines
# .why one list: the upsert copies exactly what the verify diffs
grove_provision_5_24_backup_files() {
  local src="$GROVE_SRC/grove.provision/5.devtools/5.24.backup"
  printf '%s\t%s\t%s\n' \
    "$src/grove-backup"                 /usr/local/lib/grove-backup/grove-backup                 755 \
    "$src/grove.backup.operations.sh"   /usr/local/lib/grove-backup/grove.backup.operations.sh   644 \
    "$src/grove-backup.service"         /etc/systemd/system/grove-backup.service                 644 \
    "$src/grove-backup.timer"           /etc/systemd/system/grove-backup.timer                   644
}

# .what = does this tier hold a grove role? — the one gate both phases ask
grove_provision_5_24_backup_applies() { [[ "${GROVE_ENV_SERVER:-}" == cloud@* ]]; }

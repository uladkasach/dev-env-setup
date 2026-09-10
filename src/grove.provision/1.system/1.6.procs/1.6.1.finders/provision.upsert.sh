#!/usr/bin/env bash
######################################################################
# .what = install the three finder commands into ~/.local/bin
#
# .why `bc` is a dependency and is named here
#   - all three compare load average against a core count as floats
#   - POSIX shell cannot do that, and debian's minimal images ship no `bc`
#   - ⇒ absent it, every threshold test evaluates to false
#   - each command then runs, prints, and reports a healthy box under any load
#   - ⇒ that is a failure that looks like a pass, so the dependency is installed
#
# guarantee:
#   - idempotent: each file is COPIED from the declared source, so a re-run rewrites bytes
#   - it applies EVERYWHERE — see this bundle's `_.sh` for why a grove needs it most
######################################################################

grove_provision_1_6_1_finders_provision_upsert() {
  ####################################################################
  # the float-comparison dependency
  #   - see the header for why an absent `bc` fails in the direction that reads healthy
  ####################################################################
  if ! command -v bc >/dev/null 2>&1; then
    pkg_install bc || return 1
  fi

  local dst_dir="$HOME/.local/bin"
  mkdir -p "$dst_dir" || return 1

  local failed=0
  local name
  # ⚠️ `machine_usage_diagnose` is the COMPOSER of the three finders above, and
  #    it is installed here for the same reason they are: `~/.bash_aliases` is
  #    sourced by every shell in every dir, so its alias must name a command
  #    that resolves everywhere. `rhx <skill>` resolves only where rhachet
  #    roles are linked (`rule.forbid.the-driver-by-path`, carve-out 3)
  for name in \
    machine_resource_procs_find_runaway \
    machine_resource_procs_find_spinner \
    machine_resource_procs_find_orphan \
    machine_usage_diagnose
  do
    local src="$GROVE_SRC/machine/$name"
    if [[ ! -f "$src" ]]; then
      echo "   ✋ no $name at $src" >&2
      echo "      ⇒ this run's own checkout is incomplete, so the copy would" >&2
      echo "        leave whatever version was there before" >&2
      failed=1
      continue
    fi

    cp "$src" "$dst_dir/$name" || { failed=1; continue; }
    chmod +x "$dst_dir/$name" || { failed=1; continue; }
    echo "   • $name installed → $dst_dir/$name"
  done

  return $failed
}

#!/usr/bin/env bash
######################################################################
# .what = prove the earlyoom victim policy is on disk AND in the live daemon
#
# ⚠️ .why the daemon's own argv is read, never the file alone
#   /etc/default/earlyoom is read once, at start. a current file under a daemon
#   started before it is a policy no process obeys — the exact state that let
#   earlyoom kill the session bus while the box reported as guarded
#
# guarantee:
#   - READ-ONLY
######################################################################

grove_provision_1_6_3_earlyoom_configure_verify() {
  local declared="$GROVE_SRC/grove.provision/1.system/1.6.procs/1.6.3.earlyoom/earlyoom.default"
  local live="/etc/default/earlyoom"
  local failed=0

  if cmp -s "$declared" "$live"; then
    echo "   • $live matches the declared victim policy ✔"
  else
    echo "   ✋ $live differs from the declared victim policy" >&2
    echo "      ⇒ earlyoom ranks by oom_score, which spares the hog and kills the session bus" >&2
    echo "      fix: rhx grove.provision --what 1.6.3.earlyoom --mode apply" >&2
    failed=1
  fi

  if grove_provision_1_6_3_earlyoom_daemon_runs_policy; then
    echo "   • the live earlyoom daemon runs with --avoid and --prefer ✔"
  else
    echo "   ✋ the live earlyoom daemon does not carry the --avoid policy" >&2
    echo "      ⇒ the file may be current, and the process still runs the old args" >&2
    echo "      fix: rhx grove.provision --what 1.6.3.earlyoom --mode apply" >&2
    failed=1
  fi

  return $failed
}

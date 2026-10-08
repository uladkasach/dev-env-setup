#!/usr/bin/env bash
# .what = install the declared victim policy at /etc/default/earlyoom, and
#         restart the daemon so the live process obeys it
# .why  = with the package default, earlyoom killed the session's own daemons
#         (the user bus, then systemd --user) and spared the 27 GiB of leaked
#         node runtimes that caused the pressure — see `earlyoom.default`
#
# guarantee:
#   - idempotent: a byte-equal file AND a daemon that already obeys it
#     is a [KEEP]; neither the write nor the restart repeats
#   - reads state before it asks for root (gotcha.1-6-3-earlyoom..., m2)

grove_provision_1_6_3_earlyoom_configure_upsert() {
  local declared="$GROVE_SRC/grove.provision/1.system/1.6.procs/1.6.3.earlyoom/earlyoom.default"
  local live="/etc/default/earlyoom"

  [[ -r "$declared" ]] || { echo "   ✋ the declared policy is absent at $declared" >&2; return 1; }

  # both halves of the claim: the file holds the policy, and the daemon obeys it
  local file_current=0 daemon_current=0
  cmp -s "$declared" "$live" && file_current=1
  grove_provision_1_6_3_earlyoom_daemon_runs_policy && daemon_current=1

  if (( file_current && daemon_current )); then
    echo "   • earlyoom victim policy current, and the daemon obeys it ✔"
    return 0
  fi

  if ! pkg_can_sudo; then
    bundle.root.declines "the earlyoom victim policy" \
      "file current=$file_current, daemon current=$daemon_current"
    return 0
  fi

  if (( ! file_current )); then
    sudo install -m 0644 -o root -g root "$declared" "$live" || {
      echo "   ✋ could not write $live" >&2; return 1; }
    echo "   • earlyoom victim policy written to $live"
  fi

  # a restart is how the live daemon learns the args; a file alone is inert
  sudo systemctl restart earlyoom || {
    echo "   ✋ could not restart earlyoom.service" >&2
    echo "      ⇒ the policy sits on disk and the live daemon still kills the session bus" >&2
    return 1; }
  echo "   • earlyoom.service restarted with the declared policy"
}

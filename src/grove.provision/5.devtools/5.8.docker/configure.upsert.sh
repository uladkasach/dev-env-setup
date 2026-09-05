#!/usr/bin/env bash
######################################################################
# .what = give THIS seat a docker daemon it may actually speak to
#
# .a daemon on the box is not a daemon this seat can reach
#   - `/var/run/docker.sock` is `root:docker 0660`, so reach is per-seat
#   - `provision.upsert` adds only the seat that ran it
#   - 📜 2026-08-10: ground drove it, and the camper got `permission denied …
#     connect to the docker API` against a healthy dockerd
#   - ⇒ the engine was installed and the REACH was not (`term=entry`)
#
# 🛑 a non-sudo seat is NOT simply added to the docker group
#   - a group member can bind-mount `/`, so the grant is root-equivalent
#   - 📜 the camper reads `groups: camper`, and `sudo -n` refuses it
#   - ⇒ a group grant hands back the root the seat split withholds
#   - ⇒ the seat gets a ROOTLESS daemon in its own user namespace instead
#
# guarantee:
#   - a seat that already reaches a daemon is left alone
#   - it needs NO sudo, since every write lands in this seat's own `$HOME`
#   - it declines, never fails, where docker is absent
#
# usage:
#   rhx grove.provision --what 5.8.docker --mode apply
######################################################################

grove_provision_5_8_docker_configure_upsert() {
  ####################################################################
  # 0. a DECLINE, never a failure — the engine must exist first
  #   - `provision.verify` owns the "is docker installed?" claim
  #   - ⇒ a hard fail on a neighbor's gap turns one report into two
  #   - (`rule.require.upgrade-entries-verify-themselves`)
  ####################################################################
  if ! command -v docker >/dev/null 2>&1; then
    echo "   • declined — docker is absent, so there is no daemon to point at"
    return 0
  fi

  ####################################################################
  # 1. already reaches a daemon? then this seat is converged
  #
  # .`docker info`, never a group read
  #   - the group is one route to reach, and a rootless socket is another
  #   - ⇒ a group check would report a rootless seat as broken
  #
  # ⚠️ BOUNDED, because the cli sets no cutoff on the daemon socket
  #   - a daemon mid-start accepts and never replies, and this is the FIRST call
  #   - ⇒ a 124 falls through to the reach-work below, which is the right read
  if timeout -k 5 10 docker info --format '{{.ServerVersion}}' >/dev/null 2>&1; then
    echo "   • this seat already reaches a docker daemon — no work"
    return 0
  fi

  ####################################################################
  # 2. a seat WITH sudo takes the rootful daemon, through the group
  #   - it is not re-granted, since `provision.upsert` already ran the usermod
  #   - a group joins a process at LOGIN, so that session cannot reach the socket
  #   - ⇒ that is a stale session, so this branch reports rather than writes
  ####################################################################
  if sudo -n true 2>/dev/null; then
    ##################################################################
    # 🛑 the GRANT is asserted here, and a `newgrp` fix is NOT printed
    #   - 📜 2026-08-14: this branch's 🌙 named `newgrp docker`, every word true
    #     and a HAND STEP on the provision path, on every fresh box
    #   - a duct pane is a LONG-LIVED shell, so `newgrp` reaches no later send
    #   - ⚠️ the ✋ it fed was worse: `configure.verify` read that same stale
    #     shell and printed a second apply, which prints the same line forever
    #   - ⇒ the phase asserts what it can converge: the grant, ON DISK
    #   - (`rule.require.one-command-provision`,
    #      `gotcha.a-check-that-cries-wolf-gets-silenced`)
    #
    # ⚠️ `_docker_roster_names_me` from this bundle's `_.sh`
    #   - it is the same reader both verify phases ask
    #   - ⇒ an inline `getent` would be a second reader, free to drift (m.9)
    if ! _docker_roster_names_me; then
      echo "   ✋ this seat holds sudo and is NOT in the docker group" >&2
      echo "      ⇒ the group is this bundle's PROVISION phase — it runs" >&2
      echo "        'usermod -aG docker' for the seat that drives it — so the" >&2
      echo "        grant never landed, and no login of this seat will reach" >&2
      echo "        the socket" >&2
      echo "      fix: rhx grove.provision --what 5.8.docker --mode apply" >&2
      return 1
    fi

    echo "   • this seat is in the docker group, so the rootful daemon is its route ✔"
    echo "     .note = a group joins a process at LOGIN. this shell predates the"
    echo "       grant, so it cannot reach the socket — the BOX is converged and"
    echo "       every new session of this seat reaches it"
    return 0
  fi

  ####################################################################
  # 3. a seat with NO sudo gets its own rootless daemon
  ####################################################################
  if ! command -v dockerd-rootless-setuptool.sh >/dev/null 2>&1; then
    echo "   ✋ this seat holds no sudo and rootless docker is not installable" >&2
    echo "      ⇒ dockerd-rootless-setuptool.sh is absent; it ships with" >&2
    echo "        docker-ce-rootless-extras, which the engine install pulls in" >&2
    echo "      ⇒ so the engine install did not complete on this box" >&2
    echo "      fix, from the seat that HOLDS sudo:" >&2
    echo "        rhx grove.provision --what 5.8.docker --mode apply" >&2
    return 1
  fi

  # ⚠️ the setuptool needs `systemd --user`, which a non-login ssh often lacks
  #   - XDG_RUNTIME_DIR is how it finds that bus
  export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

  # ⚠️ CAPTURED and replayed on failure, never muted
  #   - a refusal's whole value is the precondition the setuptool names
  #   - (`rule.forbid.failhide`)
  local setuplog rc
  setuplog="$(dockerd-rootless-setuptool.sh install --force 2>&1)"
  rc=$?
  if [[ $rc -ne 0 ]]; then
    echo "   ✋ the rootless daemon would not install for this seat (exit $rc)" >&2
    echo "      ⇒ this seat holds no sudo, so it cannot close a box-wide gap" >&2
    echo "        itself — read what the tool names below, then close it from the" >&2
    echo "        seat that does:" >&2
    echo "        rhx grove.provision --what 5.8.docker --mode apply" >&2
    echo "      ⇒ what it said:" >&2
    printf '%s\n' "$setuplog" | sed 's/^/        /' >&2
    return 1
  fi

  # .the setuptool writes the unit, and this line starts it
  #   - ⇒ the verify's claim, that this seat REACHES a daemon, is true here
  systemctl --user enable --now docker 2>/dev/null || true

  echo "   • this seat runs its own ROOTLESS daemon (no privilege on the box) ✔"
  echo "     socket: ${XDG_RUNTIME_DIR}/docker.sock"
}

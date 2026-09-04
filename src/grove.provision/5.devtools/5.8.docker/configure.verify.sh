#!/usr/bin/env bash
######################################################################
# .what = prove THIS seat can speak to a docker daemon
#
# ⚠️ it asks about REACH, never about installation
#   - `provision.verify` already asks whether docker is on the box
#   - 📜 that went green on a grove whose camper's socket said `permission denied`
#   - ⇒ a bundle can be "installed" and deliver no capability to the seat
#
# ⚠️ group membership is never the FIRST question
#   - a sudo seat takes the docker group, and one without takes rootless
#   - a group check up front reports a converged rootless seat as broken
#   - ⇒ reach is asked first, since it answers for both routes
#   - the group is read ONLY once reach has failed
#   - (`gotcha.a-check-that-cries-wolf-gets-silenced`)
#
# guarantee:
#   - read-only: it starts no container and pulls no image
#   - it declines where docker is absent
#   - it FAILS where reach should hold
######################################################################

grove_provision_5_8_docker_configure_verify() {
  if ! command -v docker >/dev/null 2>&1; then
    echo "   • declined — docker is absent, so there is no reach to prove"
    return 0
  fi

  # ⚠️ CAPTURED, so a refusal can be replayed
  #   - a permission denial and an absent daemon read very differently
  #   - ⇒ a muted call collapses both into "it did not work"
  #
  # ⚠️ BOUNDED, because the cli sets no cutoff on the daemon socket
  #   - a daemon mid-start or wedged on a container accepts and never replies
  #   - a 124 lands in the same `rc -ne 0` arm below, which names the daemon
  local inforaw rc
  inforaw="$(timeout -k 5 10 docker info --format '{{.ServerVersion}}|{{.SecurityOptions}}' 2>&1)"
  rc=$?

  ####################################################################
  # 🛑 the ONE refusal that is not a defect: a grant this SHELL predates
  #   - a group joins a process at LOGIN, so the shell that granted it is refused
  #   - a ✋ whose fix reads "apply again" fires on every fresh box's FIRST apply
  #   - a second apply runs in the same shell and prints the same line
  #   - ⇒ that is the two-applies signature, with a remedy that never clears it
  #   - (`rule.require.one-command-provision` calls it a blocker)
  #
  # 🛑 it RE-ASKS rather than declines
  #   - `sg docker -c` enters the group for one command
  #   - ⇒ that asks whether a FRESH LOGIN would reach the daemon
  #   - a decline would be weaker than the bundle already knows how to reach
  #   - ⇒ it would also pass a box whose daemon is genuinely down
  #
  # ⚠️ the re-ask is GATED on the roster
  #   - `sg` asks for the GROUP PASSWORD when the caller is in neither
  #   - a prompt on a duct eats the next command
  #   - the gate is `_.sh`'s `_docker_roster_names_me`
  #   - `provision.verify` reads the same one: one question, one reader
  #   - (`rule.forbid.tty-as-a-proxy-for-a-human`)
  #
  # ⚠️ this does NOT reintroduce the group check the header rejects
  #   - it is reached ONLY after reach has already failed
  #   - ⇒ a rootless seat returns above, so it never meets this
  ####################################################################
  if [[ $rc -ne 0 ]] && _docker_roster_names_me; then
    local sgraw sgrc=0
    sgraw="$(timeout -k 5 10 sg docker -c 'docker info --format "{{.ServerVersion}}"' 2>&1)" || sgrc=$?

    if [[ $sgrc -eq 0 ]]; then
      echo "   ✔ this seat reaches the rootful daemon (via the docker group)"
      echo "     .note = THIS shell predates the grant, so the socket refuses it"
      echo "       here. the box is converged and every new session reaches it —"
      echo "       proven by a re-ask under 'sg docker', not assumed"
      return 0
    fi

    echo "   ✋ this seat is on the docker roster, and the daemon is STILL unreachable" >&2
    echo "      ⇒ so this is NOT the post-grant transient: a re-ask inside the" >&2
    echo "        group was refused too, which points at the daemon, not the seat" >&2
    echo "      ⇒ it said:" >&2
    printf '%s\n' "$sgraw" | head -3 | sed 's/^/        /' >&2
    echo "      fix: rhx grove.provision --what 5.8.docker --mode apply" >&2
    return 1
  fi

  if [[ $rc -ne 0 ]]; then
    echo "   ✋ this seat cannot reach a docker daemon" >&2
    echo "      ⇒ every consumer that wants a container fails here: a compose" >&2
    echo "        stack, a testdb, an integration suite" >&2
    echo "      ⇒ the two causes read differently, and docker names which:" >&2
    printf '%s\n' "$inforaw" | sed 's/^/        /' >&2
    echo "      ⇒ 'permission denied' → the daemon runs, and this SEAT has no" >&2
    echo "        route to it. that is this bundle's configure phase" >&2
    echo "      ⇒ 'cannot connect'   → no daemon runs at all. that is provision" >&2
    echo "      fix: rhx grove.provision --what 5.8.docker --mode apply" >&2
    return 1
  fi

  # .which route this seat took is worth the line
  #   - the two have different blast radii
  if [[ "$inforaw" == *rootless* ]]; then
    echo "   ✔ this seat reaches a ROOTLESS daemon (no privilege on the box)"
  else
    echo "   ✔ this seat reaches the rootful daemon (via the docker group)"
  fi
}

#!/usr/bin/env bash
######################################################################
# .what = prove docker is installed, its daemon is reachable, and compose is there
#
# .`docker info`, never `docker run hello-world`
#   - the claim is that the binary reaches the engine over its socket
#   - `hello-world` adds a pull, so it fails on a healthy air-gapped box
#   - ⇒ it also leaves a stopped container behind on one that passes
#
# .a socket-permission failure is reported apart from an absent daemon
#   - `usermod -aG docker` applies at next login, so a fresh install denies
#   - ⇒ that reads identical to a broken install, so it is named as a transient
#
# guarantee:
#   - READ-ONLY: it observes and mutates no state
######################################################################

######################################################################
# ⚠️ `_docker_roster_names_me` lives in this bundle's `_.sh`
#   - both configure phases ask the same question
#   - ⇒ a second reader over one set drifts with no signal
#   - (`gotcha.a-check-that-cries-wolf-gets-silenced`, m.9)
######################################################################

grove_provision_5_8_docker_provision_verify() {
  if ! command -v docker >/dev/null 2>&1; then
    echo "   ✋ docker is absent from PATH" >&2
    echo "      ⇒ no repo here that declares a compose stack can start one" >&2
    echo "      fix: rhx grove.provision --what 5.8.docker --mode apply" >&2
    return 1
  fi
  echo "   • docker is on PATH ✔ ($(docker --version 2>/dev/null))"

  local failed=0
  local out

  ####################################################################
  # ⚠️ this phase asks a BOX question: is the engine ACTIVE?
  #   - whether THIS SEAT may speak to it is `configure.verify`'s question
  #   - 📜 they were one claim until 2026-08-10, and the merge cost twice: the
  #     camper failed HERE, which skipped the `configure` pair it was owed
  #   - 📜 the `sg docker` re-ask then printed `Password: Invalid password.`
  #     onto a duct, since `sg` asks a non-member for the group password
  #   - (`rule.forbid.tty-as-a-proxy-for-a-human`)
  #
  # .systemctl, never `docker info` — it reads the unit this phase installed
  #   - ⇒ it needs no socket permission, so every seat gets one answer
  ####################################################################
  if systemctl is-active --quiet docker 2>/dev/null; then
    echo "   • the docker daemon is active ✔"
  # ⚠️ BOUNDED, because the docker cli sets no client-side cutoff
  #   - a daemon mid-start, or wedged on a container, never replies
  #   - ⇒ this is a VERIFY, so a hang costs every `--mode plan` on the box
  #   - (`rule.require.bounded-probes-in-verifies`)
  elif out="$(timeout -k 5 10 docker info 2>&1)"; then
    # .no systemd here, so fall back to the socket — a container or wsl box
    #   - this read is weaker, since it passes only where THIS seat has reach
    #   - ⇒ on such a box there is no stronger read available
    echo "   • the docker daemon answers ✔ (no systemd unit to read)"
  elif echo "$out" | grep -i 'permission denied' >/dev/null \
       && _docker_roster_names_me; then
    ##################################################################
    # ⚠️ a socket permission denial answers no question about the daemon
    #   - it proves the socket FILE exists and this user lacks the group
    #   - a stopped engine reads the same, so a branch that returns 0 is wrong
    #   - ⇒ a box whose grant never takes effect would read green forever
    #   - ⇒ the honest question is whether a FRESH LOGIN would reach the daemon
    #   - `sg docker` enters the group for one command and asks exactly that
    #   - (`rule.forbid.failhide`)
    #
    # ⚠️ the re-ask is GATED on membership
    #   - `sg` asks a non-member for the GROUP PASSWORD
    #   - 📜 on the camper seat that printed `Password: Invalid password.`
    #     onto a duct, which this repo forbids on a headless box
    ##################################################################
    if out="$(sg docker -c 'docker info' 2>&1)"; then
      echo "   • the docker daemon is reachable ✔ (via the docker group)"
      echo "     .note = THIS session predates the group grant, which applies at"
      echo "       next login — so a fresh shell reaches it, and the line above is"
      echo "       the re-ask that proved so. no step is owed"
    else
      echo "   ✋ the daemon is NOT reachable, even inside the docker group" >&2
      echo "      ⇒ the socket refused this user, and a re-ask under 'sg docker'" >&2
      echo "        refused too — so this is NOT the usual post-install transient" >&2
      echo "      it said:" >&2
      echo "$out" | head -3 | sed 's/^/        /' >&2
      echo "      fix: sudo systemctl enable --now docker" >&2
      failed=1
    fi
  else
    echo "   ✋ the docker daemon is NOT reachable" >&2
    echo "      ⇒ the binary is installed and the engine is down, so every" >&2
    echo "        compose stack fails with a socket error rather than a clear one" >&2
    echo "      it said:" >&2
    echo "$out" | head -3 | sed 's/^/        /' >&2
    echo "      fix: sudo systemctl enable --now docker" >&2
    failed=1
  fi

  ####################################################################
  # .compose is a PLUGIN with no binary on PATH, so docker itself is the only ask
  ####################################################################
  if docker compose version >/dev/null 2>&1; then
    echo "   • the compose v2 plugin is installed ✔"
  else
    echo "   ✋ the docker compose plugin is absent" >&2
    echo "      ⇒ 'docker compose up' fails, and ubuntu's docker.io ships no v2" >&2
    echo "        plugin at all — so this is the tell that the wrong repo was used" >&2
    echo "      fix: rhx grove.provision --what 5.8.docker --mode apply" >&2
    failed=1
  fi

  return $failed
}

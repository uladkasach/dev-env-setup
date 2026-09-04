#!/usr/bin/env bash
######################################################################
# .what = prove the agent and ykman are installed, and that the SOCKET a shell
#         points at is the one the agent serves
#
# ⚠️ the SOCKET claim is the one that matters
#   - an installed, active agent that no shell points at is invisible to ssh
#   - 📜 that was the REAL state of every box this repo set up, since the export
#     was appended by a function nobody ever drove
#   - ⇒ the claim is "a shell can reach it", never "the agent is up"
#
# guarantee:
#   - READ-ONLY. it observes; it mutates no state
######################################################################

grove_provision_5_9_yubikey_provision_verify() {
  if [[ "$GROVE_ENV_SERVER" != local@* ]]; then
    echo "   🌙 not applicable — yubikey-agent is declined off a human's box"
    return 0
  fi

  local failed=0

  ####################################################################
  # 1 + 2. the two binaries
  ####################################################################
  local pair bin
  for pair in \
    "yubikey-agent:ssh cannot use the YubiKey at all" \
    "ykman:a key cannot be loaded onto or read off the YubiKey"; do
    bin="${pair%%:*}"
    if command -v "$bin" >/dev/null 2>&1; then
      echo "   • $bin is on PATH ✔"
    else
      echo "   ✋ $bin is absent from PATH" >&2
      echo "      ⇒ ${pair#*:}" >&2
      echo "      fix: rhx grove.provision --what 5.9.yubikey --mode apply" >&2
      failed=1
    fi
  done

  ####################################################################
  # 3. the socket a shell would point at — the claim that was never true
  ####################################################################
  local want="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/yubikey-agent/yubikey-agent.sock"
  if [[ -S "$want" ]]; then
    echo "   • the agent socket exists ✔ ($want)"
  else
    echo "   ✋ no agent socket at $want" >&2
    echo "      ⇒ an installed, active agent that no socket exposes is invisible" >&2
    echo "        to ssh — which is what every box here actually had, since the" >&2
    echo "        export was appended by a function nobody ever drove" >&2
    echo "      fix: rhx grove.provision --what 5.9.yubikey --mode apply" >&2
    failed=1
  fi

  ####################################################################
  # 4. and that SSH_AUTH_SOCK names it
  #   - the socket can exist unread while a shell points at the desktop's agent
  #   - ⇒ that one answers, and offers other keys
  ####################################################################
  if [[ "${SSH_AUTH_SOCK:-}" == "$want" ]]; then
    echo "   • SSH_AUTH_SOCK names the yubikey agent ✔"
  else
    echo "   🌙 SSH_AUTH_SOCK is '${SSH_AUTH_SOCK:-unset}', not the yubikey socket."
    echo "      this run is a non-interactive bash, which reads no aliases file,"
    echo "      so that is expected here. to check a real shell:"
    echo "        zsh -ic 'echo \$SSH_AUTH_SOCK'"
  fi

  return $failed
}

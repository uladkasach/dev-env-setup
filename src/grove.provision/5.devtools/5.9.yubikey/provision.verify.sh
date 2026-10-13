#!/usr/bin/env bash
######################################################################
# .what = prove the agent and ykman are installed, and that the agent serves
#         its SOCKET — the address a caller names to reach the YubiKey key
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

  # ⚠️ no claim on SSH_AUTH_SOCK. a shell keeps the desktop agent, which holds
  #    file keys; a host that wants the YubiKey names this socket per call
  #    (2.7.aliases states why)

  return $failed
}

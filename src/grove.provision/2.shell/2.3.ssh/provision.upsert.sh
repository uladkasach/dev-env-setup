#!/usr/bin/env bash
# .what = make the ssh halves this box actually needs EXIST on it
# .why the package name is SPLIT BY TIER, and the split is a security
#   control — `ssh` on debian is a metapackage over `openssh-client` +
#   `openssh-server`, and the server's postinst ENABLES AND STARTS the unit
#   at install time, so an unconditional `pkg_install ssh` installs and LISTENS
#   .refs = gotcha.2-3-ssh.demo=tier-split-and-mask, m1
# .why this is the EFFECT-vs-HOLD line, and ssh is the one member that
#   crosses it — `2.1.toolkit` holds xclip inert everywhere on one list; to
#   HOLD `openssh-server` IS to RUN it, so identical composition here means
#   identical CONCERN (ssh reach), never identical package name
# .why not `pkg_install ssh` then a disable — a disable is a second write
#   that races apt and re-fires on every upgrade that reinstalls the server;
#   the narrowest correct act is to never ask for it on a box that must not
#   run one (rule.require.narrowest-terminal-grant)
# .why step 2 CONVERGES the unit rather than leaves a hand fix to the verify
#   — the unit is machine state, so it is a BUNDLE's job, never a verify's
#   (rule.forbid.repair-plays, rule.require.one-command-provision)
# .why MASK, not merely disable — `disable` is undone by the next apt
#   install that pulls the server back and re-enables it; `mask` points it
#   at /dev/null and apt cannot walk over that
# .why the tier gate on step 2 is load-bear — a mask on a CLOUD grove kills
#   sshd, which kills the duct, on a box with no console
# .why there is no opt-out yet — a declared exemption's shape is not
#   settled, and a half-designed one becomes the habit (rule.forbid.exemption-as-habit)

grove_provision_2_3_ssh_provision_upsert() {
  # the tier decides the package — `cloud@*` is the ONLY tier that gets a
  # daemon; a grove IS reached over ssh, because the duct exists on sshd
  local want
  if [[ "$GROVE_ENV_SERVER" == cloud@* ]]; then
    want="ssh"                # metapackage: client + server
  else
    want="openssh-client"     # client ONLY — no listener, no unit, no port
  fi

  if ! pkg_install "$want"; then
    echo "   ✋ $want did not install" >&2
    echo "      ⇒ the CLIENT half gates every git remote and every box-to-box hop" >&2
    if [[ "$want" == "ssh" ]]; then
      echo "      ⇒ the SERVER half is how a duct reaches this box at all, so on a" >&2
      echo "        grove this failure means the box cannot be opened, and the" >&2
      echo "        symptom is a duct that will not connect" >&2
    fi
    echo "      read why: sudo apt-get install $want" >&2
    return 1
  fi

  echo "   • $want present ($GROVE_ENV_SERVER) ✔"

  # 2. converge the UNIT on a local grove — no undeclared inbound socket.
  # the gate is first, and it is the whole safety of this step
  [[ "$GROVE_ENV_SERVER" == cloud@* ]] && return 0

  if ! command -v systemctl >/dev/null 2>&1; then
    echo "   • sshd unit not converged — no systemctl on this box 🌙"
    return 0
  fi

  # read BEFORE any write, and read TWO facts: `enabled` returns at the next
  # boot, `active` is live right now. a converged box answers masked +
  # inactive, so this step then writes no state — the idempotent case
  local unit_state unit_active
  unit_state="$(systemctl is-enabled ssh 2>/dev/null || true)"
  unit_active="$(systemctl is-active ssh 2>/dev/null || true)"

  # a unit never installed answers `is-enabled` with an error and an empty
  # string — the healthy laptop case after the package split, needs no stop,
  # but a later apt install could still restore the server, so it is masked
  # too (debian allows a mask on a unit not yet present)
  local need_mask=0
  [[ "$unit_state" != "masked" ]] && need_mask=1
  [[ "$unit_active" == "active" ]] && need_mask=1

  if [[ "$need_mask" -eq 0 ]]; then
    echo "   • sshd masked — this grove serves no ssh ✔"
    return 0
  fi

  if ! pkg_can_sudo; then
    echo "   🌙 sshd unit not converged — this seat holds no usable sudo"
    echo "      ⇒ is-enabled=${unit_state:-<absent>} is-active=${unit_active:-<absent>}"
    echo "      ⇒ warm the credential, then re-apply:  sudo -v"
    return 0
  fi

  echo "   • sshd: is-enabled=${unit_state:-<absent>} is-active=${unit_active:-<absent>} → mask"

  # ORDER is load-bear: stop before disable before mask. a mask on a unit
  # still active leaves the live process up until the next boot
  [[ "$unit_active" == "active" ]] && sudo systemctl stop ssh 2>/dev/null
  sudo systemctl disable ssh >/dev/null 2>&1
  if ! sudo systemctl mask ssh >/dev/null 2>&1; then
    echo "   ✋ could not mask ssh.service" >&2
    echo "      ⇒ a local grove declares no inbound ssh, and this box still" >&2
    echo "        carries the unit — so the socket may return at the next boot" >&2
    echo "      read the live socket:  ss -tlnp | grep ':22 '" >&2
    return 1
  fi

  echo "   • sshd stopped, disabled, and masked ✔"
  echo "      ⇒ mask, not merely disable — an apt install that restores"
  echo "        openssh-server would otherwise re-enable it"
}

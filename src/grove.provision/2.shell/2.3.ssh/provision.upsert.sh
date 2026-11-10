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

  # TWO units hold sshd, and BOTH are converged:
  #   - ssh.service — the daemon
  #   - ssh.socket  — ubuntu 22.10+ socket activation: systemd itself holds :22
  #     and starts sshd on the first connection. a masked service with a live
  #     socket still LISTENS — 📜 measured 2026-11-09, :22 open on 0.0.0.0 and
  #     [::] with ssh.service masked
  # ⚠️ the socket goes FIRST: a socket left up re-spawns the service it fronts
  local unit fails=0
  for unit in ssh.socket ssh.service; do
    grove_provision_2_3_ssh_unit_converge "$unit" || fails=$(( fails + 1 ))
  done
  [[ "$fails" -eq 0 ]]
}

# .what = stop, disable, and mask one sshd unit — no write where it is already masked + inactive
# .why read BEFORE any write, two facts: `enabled` returns at the next boot,
#   `active` is live right now. a unit never installed answers `is-enabled` with
#   an empty string, and is masked too — debian allows a mask on a unit not yet
#   present, and a later apt install could otherwise restore it
grove_provision_2_3_ssh_unit_converge() {
  local unit="$1" unit_state unit_active
  unit_state="$(systemctl is-enabled "$unit" 2>/dev/null || true)"
  unit_active="$(systemctl is-active "$unit" 2>/dev/null || true)"

  if [[ "$unit_state" == "masked" && "$unit_active" != "active" ]]; then
    echo "   • $unit masked — this grove serves no ssh ✔"
    return 0
  fi

  if ! pkg_can_sudo; then
    echo "   🌙 $unit not converged — this seat holds no usable sudo"
    echo "      ⇒ is-enabled=${unit_state:-<absent>} is-active=${unit_active:-<absent>}"
    echo "      ⇒ run, from your own terminal:  sudo -v && rhx grove.provision --what 2.3.ssh --mode apply"
    return 0
  fi

  echo "   • $unit: is-enabled=${unit_state:-<absent>} is-active=${unit_active:-<absent>} → mask"

  # ORDER is load-bear: stop before disable before mask. a mask on a unit
  # still active leaves the live process up until the next boot
  [[ "$unit_active" == "active" ]] && sudo systemctl stop "$unit" 2>/dev/null
  sudo systemctl disable "$unit" >/dev/null 2>&1
  if ! sudo systemctl mask "$unit" >/dev/null 2>&1; then
    echo "   ✋ could not mask $unit" >&2
    echo "      ⇒ a local grove declares no inbound ssh, and this box still" >&2
    echo "        carries the unit — so :22 may return at the next boot" >&2
    echo "      read the live listener:  rhx network.firewall.get" >&2
    return 1
  fi

  echo "   • $unit stopped, disabled, and masked ✔"
  echo "      ⇒ mask, not merely disable — an apt install that restores"
  echo "        openssh-server would otherwise re-enable it"
}

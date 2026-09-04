#!/usr/bin/env bash
# .what = install earlyoom and enable its system service
# .why `enable --now` runs even when the package was already present —
#   presence of a binary is not presence of an ACTIVE daemon, so the
#   package install is conditional and the enable is not
#   .refs = gotcha.1-6-3-earlyoom.demo=binary-vs-daemon-and-seat-privilege, m1
# .why a SYSTEM unit, not a user one — it kills processes it does not own,
#   which needs root; `1.6.2.monitor` is the exact mirror, since its alert
#   needs a USER bus instead
#
# guarantee:
#   - idempotent: `enable --now` converges
#   - idempotent: the package ask is skipped when present
#   - it applies EVERYWHERE — see this bundle's `_.sh` for why a grove needs it most

grove_provision_1_6_3_earlyoom_provision_upsert() {
  if command -v earlyoom >/dev/null 2>&1; then
    echo "   • earlyoom is already installed"
  else
    pkg_install earlyoom || return 1
    echo "   • earlyoom installed"
  fi

  # the enable is conditional on the UNIT'S OWN STATE, never on the binary
  # — `command -v` is a binary test that passes on a masked unit; these two
  # reads ask about the DAEMON itself, and are read BEFORE root is asked
  # for, since an unconditional enable prints a false claim on a seat with
  # no sudo whose box a peer seat already converged
  # .refs = gotcha.1-6-3-earlyoom.demo=binary-vs-daemon-and-seat-privilege, m2
  if systemctl is-enabled earlyoom >/dev/null 2>&1 \
    && systemctl is-active earlyoom >/dev/null 2>&1; then
    echo "   • earlyoom.service already enabled and active ✔"
    return 0
  fi

  # it does not hold, and this seat cannot set it — ground owns the enable
  if ! pkg_can_sudo; then
    bundle.root.declines "the earlyoom daemon" \
      "unit is $(systemctl is-active earlyoom 2>/dev/null || echo inactive), $(systemctl is-enabled earlyoom 2>/dev/null || echo disabled)"
    return 0
  fi

  if sudo systemctl enable --now earlyoom; then
    echo "   • earlyoom.service enabled and started"
  else
    echo "   ✋ could not enable earlyoom.service" >&2
    echo "      ⇒ the binary is on disk and no daemon watches memory, so the" >&2
    echo "        box still locks up under pressure while it reports as armed" >&2
    return 1
  fi
}

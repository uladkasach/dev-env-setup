#!/usr/bin/env bash
######################################################################
# .what = the grove's purpose marker — `~/.grove/purpose`, one word, which the crew
#         boot gate reads to decide whether a crew may live on this box
#
# .why
#   - the gate (`__crew_grove_purpose`, ehmpathy/rhachet-roles-bhuild crewwork.sh)
#     asks the box itself first: `ssh <grove> 'cat ~/.grove/purpose | head -1'`,
#     whitespace stripped. `work` boots; `lab` and `unknown` refuse. a box with no
#     marker falls to a declared list, and off that list it fails CLOSED — so a
#     queued sprout never fires on it
#   - the ssh lands on the CAMP seat, so the marker lives in the camp seat's home.
#     the admin seat is never asked, and holds none
#   - a rebuilt box loses its home, so the marker must be a bundle, never a hand step
#     (`rule.require.one-command-provision`)
#
# .the value, by platform — the box knows only what its platform says
#   - `cloud@hetzner.hetzbot` → `work`. the box is always on and never thrown away
#     on a schedule: no hibernate, no deletable tag. that IS the work purpose
#   - `cloud@aws.ec2` → 🌙 declined. ec2 groves split work and lab by a deletable
#     tag this bundle cannot see, so to write `work` there could boot a crew onto a
#     box set to be deleted. the tag's owner writes it
#   - `local@*` → 🌙 declined. the gate reads a local grove as `work` with no ssh
#
# .a marker already present is KEPT — a findsert, never an upsert
#   - a `lab` written by infra or a human is a declaration, and a platform default
#     must never quietly outrank a stated one
#
# usage:
#   rhx grove.provision --what 5.25.purpose --mode apply
######################################################################

# .what = the marker path, in this seat's home
grove_provision_5_25_purpose_path() { printf '%s' "$HOME/.grove/purpose"; }

# .what = read the marker EXACTLY as the gate does: first line, all whitespace cut;
#         empty when absent
grove_provision_5_25_purpose_read() {
  local path first
  path="$(grove_provision_5_25_purpose_path)"
  [[ -r "$path" ]] || { printf ''; return 0; }
  first="$(head -n 1 "$path" 2>/dev/null || true)"
  printf '%s' "${first//[[:space:]]/}"
}

# .what = the purpose this box's platform declares; empty where it declares none
grove_provision_5_25_purpose_declared() {
  [[ "${GROVE_ENV_SERVER:-}" == "cloud@hetzner.hetzbot" ]] && { printf 'work'; return 0; }
  printf ''
}

# .what = the one decline line for a seat or platform with no marker to own;
#         returns 0 where this run declines, 1 where it owns the marker
grove_provision_5_25_purpose_declines() {
  if grove_env_seat_is_admin; then
    echo "   🌙 declined — '$(grove_env_seat)' is this grove's ADMIN seat; the crew gate"
    echo "      reads the camp seat's ~/.grove/purpose, never this one"
    return 0
  fi
  case "${GROVE_ENV_SERVER:-}" in
    cloud@hetzner.hetzbot) return 1 ;;
    cloud@aws.ec2)
      echo "   🌙 declined — an ec2 grove's purpose is its deletable tag, which this box"
      echo "      cannot read; to write 'work' could boot a crew onto a box set to be deleted"
      echo "      owner: the grove's provisioner (infrastructure), at provision time"
      return 0 ;;
    local@*)
      echo "   🌙 declined — the crew gate reads a local grove as 'work' with no marker"
      return 0 ;;
  esac
  echo "   🌙 declined — '${GROVE_ENV_SERVER:-unset}' declares no purpose; the gate fails closed"
  return 0
}

grove_provision_5_25_purpose() {
  bundle.upgrade 5.25.purpose.configure.upsert
  bundle.upgrade 5.25.purpose.configure.verify
}

#!/usr/bin/env bash
######################################################################
# .what = make tailscale EXIST on this machine, from its own signed apt source,
#         with `tailscaled` enabled at boot and active now
#
# .three facts, each read before any write
#   - the signed SOURCE is declared (key file + `signed-by=` list)
#   - the `tailscale` PACKAGE is installed
#   - the `tailscaled` UNIT is enabled and active
#   - ⇒ all three hold → no work, and no root asked for
#
# .why the source is declared even over a tailscale installed some other way
#   - a hand install (a curl pipe, a .deb) leaves no source apt can upgrade
#     from, and this repo's upgrade path is a manual `apt upgrade` (vision q6)
#   - ⇒ the source is declared, and the package is NOT reinstalled — the live
#     daemon and its join are left alone (fulcrum F010)
#
# .the key is fetched to a file, CHECKED, then installed — never piped
#   - it is the trust anchor for every package from this source
#   - ⇒ `web_verify_gpg_fingerprints`, set equality over primaries
#   - (`rule.require.verify-binary-downloads`, the `5.4.gh` shape)
#
# 🛑 .a cloud grove is never installed here
#   - its provisioner installs and joins it at machine build
#     (`rule.require.the-provisioner-joins-the-tailnet`)
#   - ⇒ a grove with no tailscale means the provisioner's step failed, and the
#     verify names that. an install here would hide whose step failed, and lay
#     a second apt source beside the provisioner's
#
# guarantee:
#   - idempotent: a box with all three facts takes no root and makes no write
#   - a seat with no root declines with the line its human runs
#     (`gotcha.rhx-runs-a-skill-with-no-tty`)
#   - `cloud@*` makes no TAILSCALE write — `jq` alone, where absent
######################################################################

grove_provision_5_23_tailscale_provision_upsert() {
  # jq reads every daemon answer this bundle parses, on every tier — so it
  #   lands in PROVISION, ahead of the verifies that need it
  #   (`rule.require.bundles-own-their-dependencies`). jq is no tailscale
  #   artifact, so a grove holds no second writer for it
  if ! command -v jq >/dev/null 2>&1; then
    pkg_install jq || return 1
    echo "   • jq installed — every tailscale read here parses json"
  fi

  if [[ "${GROVE_ENV_SERVER:-}" == cloud@* ]]; then
    echo "   🌙 a grove's tailscale is its provisioner's, never installed here — the verify below checks it"
    return 0
  fi

  local keydst listdst codename
  keydst="$(grove_provision_5_23_tailscale_keydst)"
  listdst="$(grove_provision_5_23_tailscale_listdst)"

  pkg_assert_apt || return 1

  if ! codename="$(grove_provision_5_23_tailscale_codename)"; then
    echo "   ✋ ConstraintError: /etc/os-release names no UBUNTU_CODENAME, so tailscale's apt path is unknown" >&2
    echo "      ⇒ the repo path is pkgs.tailscale.com/stable/ubuntu/<codename>; this box" >&2
    echo "        is not ubuntu-based, and #174 scopes tailscale to ubuntu only" >&2
    return 1
  fi

  ####################################################################
  # 0. read the three facts — no root needed for any read
  ####################################################################
  local need_source=1 need_pkg=1 need_unit=1
  grove_provision_5_23_tailscale_source_ok && need_source=0
  command -v tailscale >/dev/null 2>&1 && need_pkg=0
  systemctl is-enabled --quiet tailscaled 2>/dev/null \
    && systemctl is-active --quiet tailscaled 2>/dev/null && need_unit=0

  if [[ $need_source -eq 0 && $need_pkg -eq 0 && $need_unit -eq 0 ]]; then
    echo "   • tailscale already installed — no work"
    return 0
  fi

  # ⚠️ every write below is root's — /usr/share/keyrings, /etc/apt, a systemd unit
  bundle.root.owns "tailscale" \
    "source declared: $([[ $need_source -eq 0 ]] && echo yes || echo no) · package: $([[ $need_pkg -eq 0 ]] && echo yes || echo no) · tailscaled up: $([[ $need_unit -eq 0 ]] && echo yes || echo no)" \
    || return 0

  ####################################################################
  # 1. the signed source
  ####################################################################
  if [[ $need_source -eq 1 ]]; then
    local keytmp
    keytmp="$(web_tempdir tskey)" || return 1

    if ! web_fetch "https://pkgs.tailscale.com/stable/ubuntu/${codename}.noarmor.gpg" \
      --into "$keytmp/tailscale.gpg"; then
      echo "   💥 MalfunctionError: could not fetch tailscale's package repository key for '${codename}'" >&2
      echo "      ⇒ apt would report the source unsigned, and the error reads" >&2
      echo "        'NO_PUBKEY' rather than 'the key was never fetched'" >&2
      echo "      read why: curl -sSI https://pkgs.tailscale.com/stable/ubuntu/${codename}.noarmor.gpg" >&2
      echo "      fix: once the url answers, rerun — no write was made, so a rerun is safe:" >&2
      echo "        sudo -v && rhx grove.provision --what 5.23.tailscale --mode apply" >&2
      rm -rf "$keytmp"
      return 1
    fi

    if ! web_verify_gpg_fingerprints --file "$keytmp/tailscale.gpg" \
      --fpr "$(grove_provision_5_23_tailscale_fpr)"; then
      echo "      ⇒ tailscale is NOT installed, and its source is NOT declared. a box" >&2
      echo "        with no tailscale beats a box whose apt trusts an unvouched anchor" >&2
      echo "      ⇒ the pin's source: keyserver.ubuntu.com, uid info@tailscale.com." >&2
      echo "        a real rotation is confirmed from two channels before the pin moves" >&2
      rm -rf "$keytmp"
      return 1
    fi

    if ! sudo dd if="$keytmp/tailscale.gpg" of="$keydst" status=none; then
      echo "   💥 MalfunctionError: could not install tailscale's key to $keydst" >&2
      echo "      read why: ls -ld $(dirname "$keydst") · df -h $(dirname "$keydst")" >&2
      echo "      fix: rerun once the dir is writable: sudo -v && rhx grove.provision --what 5.23.tailscale --mode apply" >&2
      rm -rf "$keytmp"
      return 1
    fi
    rm -rf "$keytmp"
    # apt reads the keyring as an unprivileged user; an unreadable key reports
    #   as an unsigned source, two steps away from this cause
    if ! sudo chmod go+r "$keydst"; then
      echo "   💥 MalfunctionError: could not make $keydst readable to apt" >&2
      echo "      read why: ls -l $keydst" >&2
      echo "      fix: rerun — the key write is idempotent: sudo -v && rhx grove.provision --what 5.23.tailscale --mode apply" >&2
      return 1
    fi
    echo "   • tailscale's release key verified against its pinned fingerprint ✔"

    if ! printf '%s\n' "$(grove_provision_5_23_tailscale_list_line)" | sudo tee "$listdst" >/dev/null; then
      echo "   💥 MalfunctionError: could not declare tailscale's apt source" >&2
      return 1
    fi
    echo "   • apt source: pkgs.tailscale.com/stable/ubuntu ${codename}"
  fi

  ####################################################################
  # 1b. the index — refreshed whenever a package is owed, never only when the
  #   source was just written: a refresh that failed last run left the source
  #   declared and the index stale, and `pkg_install` never refreshes on its own
  ####################################################################
  if [[ $need_source -eq 1 || $need_pkg -eq 1 ]]; then
    if ! pkg_refresh; then
      echo "   💥 MalfunctionError: apt could not refresh with tailscale's source declared" >&2
      echo "      read why: sudo apt-get update    # it names the source at fault" >&2
      return 1
    fi
  fi

  ####################################################################
  # 2. the package — only where absent; a live install is never reinstalled
  ####################################################################
  if [[ $need_pkg -eq 1 ]]; then
    if ! pkg_install tailscale; then
      echo "   💥 MalfunctionError: tailscale did not install" >&2
      echo "      read why: sudo apt-get install tailscale" >&2
      return 1
    fi
    # an install that leaves no client on PATH is no install — the join below would fail on it
    local version
    version="$(tailscale version 2>/dev/null | head -1)"
    if [[ -z "$version" ]]; then
      echo "   💥 MalfunctionError: apt reports tailscale installed, yet \`tailscale version\` answers naught" >&2
      echo "      read why: command -v tailscale; dpkg -L tailscale" >&2
      return 1
    fi
    echo "   • tailscale installed (${version})"
  fi

  ####################################################################
  # 3. the daemon — enabled at boot, active now
  ####################################################################
  if ! systemctl is-enabled --quiet tailscaled 2>/dev/null \
     || ! systemctl is-active --quiet tailscaled 2>/dev/null; then
    if ! sudo systemctl enable --now tailscaled; then
      echo "   💥 MalfunctionError: tailscaled did not start" >&2
      echo "      read why: systemctl status tailscaled" >&2
      return 1
    fi
  fi
  echo "   • tailscaled enabled at boot, active"
}

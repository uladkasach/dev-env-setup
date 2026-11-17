#!/usr/bin/env bash
######################################################################
# .what = the dropbox desktop sync client
#
# .why  it is its own bundle and not part of 6.1.flatpaks
#         dropbox ships an apt repo of its own, signed by a key this bundle
#         pins — so its install story is a trust anchor plus a source line, not
#         a flathub ref, and its failures are apt's rather than flatpak's.
#
# .why  the repo and the key are `provision`, not `configure`
#         those are what it takes to GET the package onto the box — the same
#         split `6.2.codium` and `5.8.docker` use. dropbox's own settings live in
#         its daemon state, behind a sign-in this repo holds no credential for,
#         so no config file is declared.
#
# .why  a `configure` phase all the same — the panel icon
#         dropbox names its tray icon (`dropboxstatus-idle`) and points the panel
#         at its own dir through `IconThemePath`. cosmic's tray ignores that
#         path and searches only the icon themes, so it drew a broken icon.
#         📜 measured 2026-11-15 (`rhx desktop.tray.items.get`).
#         the configure phase copies dropbox's icons into the user's hicolor
#         theme, where a lookup by name finds them
#
# ⚠️ .OPT-IN — a run installs dropbox only when asked
#         see `GROVE_OPTIN_APPS` in `src/bundle.upgrade.sh`
#
# usage:
#   rhx grove.provision --include dropbox --mode apply
######################################################################

GROVE_OPTIN_APPS+=(dropbox)

# .what = the hicolor dir inside dropbox's NEWEST dist, or naught
#         - the daemon downloads `~/.dropbox-dist/dropbox-lnx.<arch>-<ver>/` at
#           first sign-in and replaces it on each update; sort -V picks the newest
grove_provision_6_3_dropbox_icons_src() {
  local dir
  dir="$(printf '%s\n' "$HOME"/.dropbox-dist/dropbox-lnx.*/images/hicolor | sort -V | tail -n 1)"
  [[ -d "$dir" ]] && printf '%s' "$dir"
}

# .what = the user's hicolor theme — the fallback every icon lookup searches
grove_provision_6_3_dropbox_icons_dst() { printf '%s/.local/share/icons/hicolor' "$HOME"; }

# .what = each icon path, relative to the hicolor root (`16x16/status/x.png`)
grove_provision_6_3_dropbox_icons_list() {
  local src="$1" file
  for file in "$src"/*/*/dropboxstatus-*.png; do
    [[ -f "$file" ]] && printf '%s\n' "${file#"$src"/}"
  done
}

######################################################################
# .what = declare `libpango1.0-0`, the old name dropbox's launcher depends on,
#         on a release that no longer ships it
#
# .why  dropbox's signed repo serves one package, 2020.03.04, and it declares
#         `Depends: libpango1.0-0 (>= 1.36.3)`. ubuntu shipped that name as an
#         empty transitional package that pulled in `libpango-1.0-0`, and 24.04
#         dropped it — so apt refuses dropbox there with "not installable".
#         📜 measured 2026-11-16 (`rhx apt.package.get --name dropbox`)
#
# .why  a local stub, and not the website .deb
#         the stub restores exactly what ubuntu itself shipped: no files, no
#         maintainer scripts, only a Depends on the renamed libraries. it is
#         built here with dpkg-deb, so no byte is fetched and only dpkg's own
#         bookkeeping runs as root. the website .deb would bring back the
#         unverifiable fetch this bundle left (gotcha.6-3-dropbox.demo=apt-repo-not-deb)
#
# .why  its version is the LOWEST dropbox accepts
#         if a release ever ships the name again, any real version outranks the
#         stub, and apt replaces it on its own
######################################################################
grove_provision_6_3_dropbox_pango_stub_upsert() {
  local name=libpango1.0-0 cand tmp
  if pkg_present "$name"; then
    echo "   • $name ✔ (already installed)"
    return 0
  fi

  # a release that still ships the name installs the real one
  cand="$(apt-cache policy "$name" 2>/dev/null | awk -F': ' '/Candidate:/{print $2}')"
  if [[ -n "$cand" && "$cand" != "(none)" ]]; then
    pkg_install "$name"
    return
  fi

  # 0755, so apt's unprivileged fetch user may read the local .deb
  tmp="$(mktemp -d)" || return 1
  chmod 0755 "$tmp"
  mkdir -p "$tmp/root/DEBIAN"
  cat >"$tmp/root/DEBIAN/control" <<'EOF'
Package: libpango1.0-0
Version: 1.36.3+grove1
Architecture: all
Maintainer: dev-env-setup <noreply@localhost>
Section: oldlibs
Priority: optional
Depends: libpango-1.0-0, libpangocairo-1.0-0, libpangoft2-1.0-0
Description: transitional stub for the dropbox launcher
 ubuntu 24.04 dropped this transitional name, and dropbox's signed apt repo
 still depends on it. this package carries no files and no maintainer
 scripts; it only pulls in the renamed pango libraries, as ubuntu's did.
EOF

  if ! dpkg-deb --build --root-owner-group "$tmp/root" "$tmp/$name.deb" >/dev/null; then
    echo "   💥 MalfunctionError: dpkg-deb could not build the $name stub" >&2
    rm -rf "$tmp"
    return 1
  fi
  chmod 0644 "$tmp/$name.deb"
  if ! pkg_apt apt-get install -y "$tmp/$name.deb"; then
    echo "   💥 MalfunctionError: apt could not install the $name stub — its cause is above" >&2
    rm -rf "$tmp"
    return 1
  fi
  rm -rf "$tmp"
  echo "   • $name declared as a stub over libpango-1.0-0 — this release dropped the name"
}

grove_provision_6_3_dropbox() {
  grove_optin dropbox || { grove_optin_decline dropbox; return 0; }

  bundle.upgrade 6.3.dropbox.provision.upsert
  bundle.upgrade 6.3.dropbox.provision.verify
  bundle.upgrade 6.3.dropbox.configure.upsert
  bundle.upgrade 6.3.dropbox.configure.verify
}

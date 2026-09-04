#!/usr/bin/env bash
# .what = make the flatpak firefox exist, make it the registered default,
#   remove the apt build that would fight it, and install the quiet
#   `browser` launcher
# .why the `browser` launcher exists — `flatpak run org.mozilla.firefox`
#   writes sandbox chatter to stderr and holds the caller's terminal until
#   the window closes, so every url-opener (`xdg-open`, `gh pr view --web`,
#   this repo's own extension opens) either spams or blocks; the launcher
#   wraps both away with `setsid -f` and a redirect, once
# .why the apt firefox is removed, not merely deprioritized — with both
#   installed, `xdg-open` picks by whichever `.desktop` the mime db saw
#   last, which reads as "firefox opened but all my tabs and logins are gone"
# .why `flatpak install` carries `-y --noninteractive` — this run is
#   declared unattended, and without the flags it hangs on a swallowed prompt
#
# guarantee:
#   - idempotent: flatpak reports an already-installed app and returns 0
#   - idempotent: `xdg-settings set` is a write of one value
#   - idempotent: the apt remove tolerates absence
#   - idempotent: the launcher is overwritten from this file's text

grove_provision_1_3_1_firefox_provision_upsert() {
  # 0. flatpak itself, and the remote it installs from
  # .why this bundle installs its own package manager — a debian cloud
  #   image ships no flatpak at all, so this leaf's own dependency must be
  #   installed rather than assumed .refs = gotcha.1-3-1-firefox.demo=flatpak-user-scope-and-holds-everywhere, m1
  # .why the REMOTE too — a fresh `flatpak` knows no remotes, so `install
  #   flathub ...` fails on a name it has never heard
  # .why `--if-not-exists` rather than a presence check — it IS the
  #   presence check, in flatpak's own vocabulary
  # .why `--user`, and why a SYSTEM remote cannot be used here — a
  #   system-wide `remote-add` asks polkit, which asks a human for a
  #   password this run cannot answer; `--user` needs no polkit and is the
  #   right scope regardless, since this repo installs a box for ONE human
  #   .refs = gotcha.1-3-1-firefox.demo=flatpak-user-scope-and-holds-everywhere, m2
  if ! command -v flatpak >/dev/null 2>&1; then
    pkg_install flatpak || return 1
    echo "   • flatpak installed — this box shipped without it"
  fi

  # `web_flatpak`, never a bare `flatpak` — a bare call against a silent
  # remote opened ten connections and had not returned at 240s
  # .refs = gotcha.1-3-1-firefox.demo=flatpak-user-scope-and-holds-everywhere, m3
  if ! web_flatpak remote-add --user --if-not-exists flathub \
       https://dl.flathub.org/repo/flathub.flatpakrepo; then
    echo "   ✋ could not add the flathub remote" >&2
    echo "      ⇒ flatpak is installed and knows no source to install FROM, so" >&2
    echo "        every flatpak this repo declares fails on an unknown name" >&2
    echo "      read why: flatpak remotes --user" >&2
    return 1
  fi

  # 1. the flatpak build. the CHECK is unscoped and the INSTALL is `--user`,
  # deliberately — `flatpak info <app>` finds a user OR a system install, so
  # a box that already has firefox system-wide is left alone; `--user`
  # would MISS that one and install a second copy beside it, the exact
  # two-firefoxes ambiguity the apt removal below ends
  if flatpak info org.mozilla.firefox >/dev/null 2>&1; then
    echo "   • firefox flatpak already installed"
  else
    if ! web_flatpak install --user -y --noninteractive flathub org.mozilla.firefox </dev/null; then
      echo "   ✋ the firefox flatpak did not install" >&2
      echo "      ⇒ every later phase of this bundle addresses its PROFILE, which" >&2
      echo "        only exists once the app does — so they will all report owed work" >&2
      echo "      read why: flatpak install flathub org.mozilla.firefox" >&2
      echo "        (a common cause is that the flathub remote is not added:" >&2
      echo "         flatpak remote-add --if-not-exists flathub \\" >&2
      echo "           https://dl.flathub.org/repo/flathub.flatpakrepo)" >&2
      return 1
    fi
    echo "   • firefox flatpak installed"
  fi

  # 2. register it as the default, so xdg-open and gh reach THIS one. this
  # line tolerates its own failure and reports 🌙, not ✋ — `xdg-settings`
  # writes to a DESKTOP's mime database, so on a headless box it fails
  # forever while the app, profile, and prefs stay fine
  # (rule.require.identical-bundle-composition)
  if xdg-settings set default-web-browser org.mozilla.firefox.desktop 2>/dev/null; then
    echo "   • firefox registered as the default browser"
  else
    echo "   🌙 could not register a default browser — no desktop mime registry here"
    echo "      the app and its profile are unaffected; only xdg-open's default is"
  fi

  # 3. remove the apt/snap build that would fight it. `|| true` — apt exits
  # non-zero for an absent package, the converged state on a box that never had it
  if dpkg -s firefox >/dev/null 2>&1; then
    # the removal is root's — an apt package is a fact of the BOX, not of
    # a $HOME, so a seat with no root declines and ground removes it later
    if bundle.root.owns "the apt firefox removal" "dpkg still holds firefox"; then
      pkg_apt apt-get remove -y firefox || true
      echo "   • removed the apt firefox that would fight the flatpak"
    fi
  fi

  # 4. the quiet launcher
  mkdir -p "$HOME/.local/bin"
  cat > "$HOME/.local/bin/browser" <<'EOF'
#!/bin/sh
setsid -f flatpak run org.mozilla.firefox "$@" >/dev/null 2>&1
EOF
  chmod +x "$HOME/.local/bin/browser"
  echo "   • browser launcher declared (~/.local/bin/browser)"
}

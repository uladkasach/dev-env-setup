#!/usr/bin/env bash
######################################################################
# .what = manage a self-owned firefox systemconfig channel for the
#         org.mozilla.firefox flatpak, and rebind tab-switch keys
#         from the linux default (alt+N) to ctrl+N for kitty parity
#
# .why  = flatpak firefox seals /app read-only, so autoconfig files
#         cannot be dropped into the binary dir. flatpak exposes one
#         sanctioned door — the `org.mozilla.firefox.systemconfig`
#         extension point, mounted read-only inside the sandbox at
#         /app/etc/firefox. files placed in the host extension dir
#         surface there and firefox reads them at startup.
#
#         this skill fills that door with OUR files (no third-party
#         flatpak remote), giving a durable, repo-declared channel
#         for firefox system config: autoconfig prefs, policies, and
#         chrome-level keybind rebinds.
#
# usage:
#   firefox.systemconfig.sh probe      # verify a bare dir mounts into the sandbox
#   firefox.systemconfig.sh install    # write autoconfig + ctrl+N keyset rebind
#   firefox.systemconfig.sh status     # show what is installed + mount state
#   firefox.systemconfig.sh uninstall  # remove the channel
#
# guarantee:
#   - only touches the flatpak systemconfig extension dir
#   - idempotent: safe to rerun
#   - probe cleans up its own marker
#   - fail-fast on errors
######################################################################

set -uo pipefail

APP="org.mozilla.firefox"
# host-side extension dir; contents surface at /app/etc/firefox in the sandbox
EXT_DIR="$HOME/.local/share/flatpak/extension/${APP}.systemconfig/x86_64/stable"
FF_PROFILE_ROOT="$HOME/.var/app/${APP}/.mozilla/firefox"

# --- guards -----------------------------------------------------------------

require_flatpak_app() {
  if ! command -v flatpak &>/dev/null; then
    echo "⛈️  flatpak not found — is this the right machine?"
    exit 2
  fi
  if ! flatpak info "$APP" &>/dev/null; then
    echo "⛈️  $APP flatpak not installed"
    echo "   install via: source ~/git/more/dev-env-setup/src/install_env.pt1.system.basics.sh && install_firefox"
    exit 2
  fi
}

# --- subcommands ------------------------------------------------------------

cmd_probe() {
  require_flatpak_app
  echo "🔭 probe: does a bare extension dir mount into the sandbox?"
  echo ""
  mkdir -p "$EXT_DIR"
  local marker="$EXT_DIR/PROBE.txt"
  printf 'probe-ok\n' >"$marker"
  echo "   host:    $marker"

  local seen
  seen=$(flatpak run --command=cat "$APP" /app/etc/firefox/PROBE.txt 2>/dev/null || true)

  # clean up the marker regardless of outcome
  rm -f "$marker"

  echo "   sandbox: /app/etc/firefox/PROBE.txt"
  echo ""
  if [[ "$seen" == "probe-ok" ]]; then
    echo "✨ mount works — bare-directory channel is viable"
    echo "   next: firefox.systemconfig.sh install"
    exit 0
  fi
  echo "🛑 mount NOT visible in sandbox (got: '${seen:-<empty>}')"
  echo "   the bare-dir channel does not work here; a flatpak-builder"
  echo "   ref extension is required instead. report this output."
  exit 1
}

cmd_install() {
  require_flatpak_app

  echo "🔧 install ctrl+N tab rebind via systemconfig channel"
  echo ""

  # 1. autoconfig pointer — lands at /app/etc/firefox/defaults/pref/autoconfig.js
  mkdir -p "$EXT_DIR/defaults/pref"
  cat >"$EXT_DIR/defaults/pref/autoconfig.js" <<'EOF'
// point firefox at our autoconfig payload (loaded from the same dir)
pref("general.config.filename", "firefox.cfg");
pref("general.config.obscure_value", 0);
pref("general.config.sandbox_enabled", false);
EOF

  # 2. autoconfig payload — must start with a throwaway comment line.
  #    rebinds tab keys per browser window as each one opens.
  #    note: `Services` is a global in the autoconfig sandbox; do NOT
  #    import Services.jsm (removed in modern firefox — the import throws).
  cat >"$EXT_DIR/firefox.cfg" <<'EOF'
// firefox.cfg — first line is ignored by the autoconfig parser
try {
  // rebind key_selectTab1..8 + key_selectLastTab from alt (linux default)
  // to accel (ctrl), then force gecko to rebuild the shortcut table.
  const rebind = (win) => {
    try {
      if (win.location.href !== "chrome://browser/content/browser.xhtml") return;
      const doc = win.document;
      const keyset = doc.getElementById("mainKeyset");
      if (!keyset) return;
      for (let i = 1; i <= 8; i++) {
        const k = doc.getElementById("key_selectTab" + i);
        if (k) k.setAttribute("modifiers", "accel");
      }
      const last = doc.getElementById("key_selectLastTab");
      if (last) last.setAttribute("modifiers", "accel");
      // re-append the keyset node so gecko re-registers the mutated keys
      keyset.parentNode.appendChild(keyset);
    } catch (e) { Cu.reportError("[ctrlN rebind win] " + e); }
  };

  // rebind any already-open browser windows
  const en = Services.wm.getEnumerator("navigator:browser");
  while (en.hasMoreElements()) rebind(en.getNext());

  // rebind future windows once their dom is ready
  Services.obs.addObserver({
    observe(subject, topic) {
      if (topic !== "domwindowopened") return;
      subject.addEventListener("load", () => rebind(subject), { once: true });
    }
  }, "domwindowopened");
} catch (e) {
  Cu.reportError("[ctrlN rebind] " + e);
}
EOF

  echo "   channel: $EXT_DIR"
  echo "     ├─ defaults/pref/autoconfig.js"
  echo "     └─ firefox.cfg (ctrl+N keyset rebind)"
  echo ""
  echo "✨ installed"
  echo ""
  echo "🌊 next steps (must test live — cannot verify headlessly):"
  echo "   1. fully quit firefox (all windows)"
  echo "   2. relaunch, open 2+ tabs"
  echo "   3. press ctrl+2 → should jump to tab 2"
  echo "   if it fails to switch: run 'firefox.systemconfig.sh status' and report"
  exit 0
}

cmd_status() {
  require_flatpak_app
  echo "🔎 firefox systemconfig status"
  echo ""
  echo "   ext dir: $EXT_DIR"
  if [[ -d "$EXT_DIR" ]]; then
    find "$EXT_DIR" -type f -printf '     • %P\n' 2>/dev/null || true
  else
    echo "     (absent)"
  fi
  echo ""
  local seen
  seen=$(flatpak run --command=cat "$APP" /app/etc/firefox/firefox.cfg 2>/dev/null || true)
  if [[ -n "$seen" ]]; then
    echo "   sandbox sees firefox.cfg: ✨ yes"
  else
    echo "   sandbox sees firefox.cfg: 🛑 no"
  fi
  exit 0
}

cmd_uninstall() {
  echo "🧹 remove systemconfig channel"
  rm -rf "$EXT_DIR"
  echo "   removed: $EXT_DIR"
  echo "✨ done — restart firefox to revert to alt+N default"
  exit 0
}

cmd_doctor() {
  require_flatpak_app
  echo "🩺 doctor: capture firefox autoconfig load + errors from stderr"
  echo ""
  echo "⚠️  this KILLS your live firefox, relaunches it, captures ~6s of"
  echo "    stderr, then leaves it open."
  echo ""

  # kill any live instance so autoconfig is re-read on next launch
  flatpak kill "$APP" 2>/dev/null || true
  sleep 1

  local log
  log="$(mktemp)"
  echo "   relaunch (stderr → $log) ..."
  # run detached, capture stderr for autoconfig diagnosis
  setsid flatpak run "$APP" >/dev/null 2>"$log" &
  sleep 6

  echo ""
  echo "── autoconfig-relevant stderr ─────────────────────────────"
  grep -iE 'autoconfig|config.*file|ctrlN|keyset|reportError|\.cfg|JavaScript error|NS_ERROR' "$log" | head -40 || true
  echo "── raw tail (last 20 lines) ───────────────────────────────"
  tail -20 "$log" || true
  echo "───────────────────────────────────────────────────────────"
  echo ""
  echo "   full log kept at: $log"
  echo "   test ctrl+2 now; if it holds, ignore the log"
  exit 0
}

# --- dispatch ---------------------------------------------------------------

# rhx injects --repo/--role/--skill flags, so the subcommand is not always $1.
# scan every arg for the first recognized subcommand.
SUBCMD=""
for arg in "$@"; do
  case "$arg" in
    probe|install|status|uninstall|doctor) SUBCMD="$arg"; break ;;
  esac
done

case "$SUBCMD" in
  probe)     cmd_probe ;;
  install)   cmd_install ;;
  status)    cmd_status ;;
  uninstall) cmd_uninstall ;;
  doctor)    cmd_doctor ;;
  *)
    echo "usage: firefox.systemconfig.sh {probe|install|status|uninstall|doctor}"
    exit 2
    ;;
esac

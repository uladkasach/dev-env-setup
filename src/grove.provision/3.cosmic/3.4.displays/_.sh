#!/usr/bin/env bash
######################################################################
# .what = each known monitor at its declared scale
#
# .why  = cosmic picks a scale per output SET, and a new monitor can
#         inherit the laptop panel's 2.0. a 27" 4k panel at 200% reads
#         as "overzoomed" — 1920x1080 of logical space on a desk display
#
# .the declaration is a TABLE keyed by make + model, never by connector
#   - a connector (DP-7) names a port, and changes with the dock or cable
#   - make + model names the panel, which is what the scale is about
#
# 🛑 .the bundle sets a LIVE output, never cosmic's state file
#   - `~/.local/state/cosmic-comp/outputs.ron` is written BY the compositor,
#     from memory, on every output change
#   - an edit to it would be clobbered at the next hotplug, so it would
#     verify ✔ once and then silently revert
#   - ⇒ the upsert asks the compositor through `cosmic-randr`, which then
#     persists the scale itself, for the output set connected right now
#   - a declared monitor not connected at apply time is reported 🌙, never ✔
#
# usage:
#   rhx grove.provision --what 3.4.displays --mode apply
######################################################################

grove_provision_3_4_displays() {
  bundle.upgrade 3.4.displays.configure.upsert
  bundle.upgrade 3.4.displays.configure.verify
}

# .what = the declared scale per monitor, as "make|model|scale"
# .why  = one table both phases read, so the upsert and the verify
#         cannot disagree about what is declared
grove_provision_3_4_displays_declared() {
  cat <<'DECLARED'
Dell Inc.|DELL S2721QS|1.5
DECLARED
}

# .what = every connected output, as "connector|make|model|scale%|WxH|hz"
# .why  = cosmic-randr's list is the compositor's own view; colors stripped
grove_provision_3_4_displays_connected() {
  timeout 10 cosmic-randr list 2>/dev/null |
    sed -E 's/\x1b\[[0-9;]*m//g' |
    awk '
      function flush() { if (c != "") print c "|" mk "|" md "|" sc "|" sz "|" hz }
      /^[^ ]/            { flush(); c = $1; mk = md = sc = sz = hz = "" ; next }
      /^  Make: /        { sub(/^  Make: /, "");  mk = $0; next }
      /^  Model: /       { sub(/^  Model: /, ""); md = $0; next }
      /^  Scale: /       { sc = $2; next }
      /\(current\)/      { sz = $1; hz = $3; next }
      END                { flush() }
    '
}

# .what = a scale as cosmic-randr prints it — 1.5 → 150%
grove_provision_3_4_displays_pct() {
  awk -v s="$1" 'BEGIN { printf "%d%%", s * 100 + 0.5 }'
}

# .what = return 0 only where a compositor this shell can reach is up
# .why  = over ssh, or before login, cosmic-randr has no session to ask;
#         a silent empty list there would read as "no monitors" (failhide)
grove_provision_3_4_displays_reachable() {
  [[ "$GROVE_ENV_SERVER" == local@unix ]] || return 1
  [[ -n "${WAYLAND_DISPLAY:-}" ]] || return 1
  command -v cosmic-randr >/dev/null 2>&1 || return 1
  timeout 10 cosmic-randr list >/dev/null 2>&1
}

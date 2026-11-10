#!/usr/bin/env bash
######################################################################
# .what = read the panel's tray: is a StatusNotifierWatcher up, which items
#         are registered with it, and what each one tells the panel to draw
#
# .why  = "i don't see the icon" has four causes that want four repairs — no
#         tray applet in the panel, the app never registered, the app
#         registered with an icon the host cannot draw, or the app exited.
#         each is one bus read, and this names which one holds
#
# usage:
#   rhx desktop.tray.items.get
#
# guarantee:
#   - READ-ONLY: it reads the session bus and writes naught
#   - every bus call is bounded by a timeout
######################################################################

set -uo pipefail

readonly WATCHER=org.kde.StatusNotifierWatcher

main() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help|-h)
        echo "🪟 desktop.tray.items.get — the panel tray's watcher, and every item registered with it"
        echo ""
        echo "usage:"
        echo "  rhx desktop.tray.items.get"
        return 0 ;;
      --repo|--role|--skill) shift 2 ;;
      *) echo "✋ ConstraintError: unknown arg: $1" >&2; echo "   fix: rhx desktop.tray.items.get --help" >&2; return 2 ;;
    esac
  done

  if ! command -v gdbus >/dev/null 2>&1; then
    echo "✋ ConstraintError: gdbus is absent — the session bus cannot be read" >&2
    echo "   fix: sudo apt-get install libglib2.0-bin" >&2
    return 2
  fi
  if [[ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]]; then
    echo "✋ ConstraintError: this shell holds no session bus — run it from a terminal inside the desktop" >&2
    return 2
  fi

  echo "🪟 desktop.tray.items.get"

  # 1. the watcher — the panel side. absent = no tray applet in the panel
  echo ""
  echo "── 1. watcher (the panel's tray host)"
  local owner
  owner="$(timeout 5 gdbus call --session --dest org.freedesktop.DBus --object-path /org/freedesktop/DBus \
    --method org.freedesktop.DBus.GetNameOwner "$WATCHER" 2>/dev/null | grep -o ":[0-9.]*")"
  if [[ -z "$owner" ]]; then
    # one ListNames read proves the bus answers at all — an empty reply is a
    # broken read, never "no host"
    local all_names sni_names
    all_names="$(timeout 5 gdbus call --session --dest org.freedesktop.DBus --object-path /org/freedesktop/DBus \
      --method org.freedesktop.DBus.ListNames 2>&1)"
    if ! grep -q "org.freedesktop.DBus" <<<"$all_names"; then
      echo "💥 MalfunctionError: the session bus did not answer ListNames — the read is broken, not the tray" >&2
      printf '%s\n' "$all_names" | head -n 3 | sed 's/^/   /' >&2
      return 1
    fi
    sni_names="$(grep -o "'[^']*StatusNotifier[^']*'" <<<"$all_names" | tr -d "'" | paste -sd' ')"
    echo "      absent — no tray host on this bus; no app icon can show"
    echo "      bus answers: $(grep -o "'" <<<"$all_names" | wc -l | awk '{print $1/2}') names · with StatusNotifier: ${sni_names:-none}"
    echo "      ⇒ on cosmic: panel settings → applets → add \"Status Area\""
    return 0
  fi
  local host_pid host_cmd
  host_pid="$(timeout 5 gdbus call --session --dest org.freedesktop.DBus --object-path /org/freedesktop/DBus \
    --method org.freedesktop.DBus.GetConnectionUnixProcessID "$owner" 2>/dev/null | grep -o '[0-9]*,' | tr -d ,)"
  host_cmd="$(tr '\0' ' ' < "/proc/$host_pid/cmdline" 2>/dev/null)"
  echo "      up — owner $owner · pid ${host_pid:-?} · ${host_cmd:-?}"

  # 2. every item the watcher says is registered
  echo ""
  echo "── 2. items the watcher lists"
  local raw items
  raw="$(timeout 5 gdbus call --session --dest "$WATCHER" --object-path /StatusNotifierWatcher \
    --method org.freedesktop.DBus.Properties.Get "$WATCHER" RegisteredStatusNotifierItems 2>/dev/null)"
  items="$(printf '%s' "$raw" | grep -o "'[^']*'" | tr -d "'")"
  [[ -n "$items" ]] || echo "      none listed by the watcher"

  # 3. every item on the bus, listed or not — a watcher may not report its list,
  #    and an item may hold a name and never have registered
  echo ""
  echo "── 3. item names on the bus (listed by the watcher or not)"
  local names
  names="$(timeout 5 gdbus call --session --dest org.freedesktop.DBus --object-path /org/freedesktop/DBus \
    --method org.freedesktop.DBus.ListNames 2>/dev/null | grep -o "'org\.kde\.StatusNotifierItem[^']*'" | tr -d "'")"
  if [[ -z "$names" ]]; then
    echo "      none — no app holds a StatusNotifierItem name"
  else
    printf '%s\n' "$names" | sed 's/^/      /'
    [[ -n "$items" ]] || items="$names"
  fi
  [[ -n "$items" ]] || return 0

  echo ""
  echo "── 4. what each item asks the panel to draw"
  local item svc path pid cmd id title icon_name pixmaps status
  while read -r item; do
    [[ -n "$item" ]] || continue
    svc="${item%%/*}"
    path="/${item#*/}"
    [[ "$item" == */* ]] || path=/StatusNotifierItem
    pid="$(timeout 5 gdbus call --session --dest org.freedesktop.DBus --object-path /org/freedesktop/DBus \
      --method org.freedesktop.DBus.GetConnectionUnixProcessID "$svc" 2>/dev/null | grep -o '[0-9]*,' | tr -d ,)"
    cmd="$(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null | cut -c1-60)"
    id="$(__sni_prop "$svc" "$path" Id)"
    title="$(__sni_prop "$svc" "$path" Title)"
    status="$(__sni_prop "$svc" "$path" Status)"
    icon_name="$(__sni_prop "$svc" "$path" IconName)"
    pixmaps="$(timeout 5 gdbus call --session --dest "$svc" --object-path "$path" \
      --method org.freedesktop.DBus.Properties.Get org.kde.StatusNotifierItem IconPixmap 2>/dev/null \
      | grep -o '([0-9]*, [0-9]*,' | head -n 3 | tr -d '(,' | sed 's/ /x/' | paste -sd' ')"
    echo "      • ${id:-?}  (pid ${pid:-?} · ${cmd:-?})"
    echo "          title: ${title:-∅} · status: ${status:-∅}"
    echo "          icon-name: ${icon_name:-∅} · pixmaps: ${pixmaps:-∅}"
  done <<<"$items"

  echo ""
  echo "🌲 done — an item listed here with no icon on the panel is a HOST that cannot draw what the item offers"
}

# .what = one StatusNotifierItem string property, unwrapped, or naught
__sni_prop() {
  timeout 5 gdbus call --session --dest "$1" --object-path "$2" \
    --method org.freedesktop.DBus.Properties.Get org.kde.StatusNotifierItem "$3" 2>/dev/null \
    | sed -E "s/^\(<'?//; s/'?>,\)$//"
}

main "$@"

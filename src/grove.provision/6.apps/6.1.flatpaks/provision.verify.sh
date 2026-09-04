#!/usr/bin/env bash
######################################################################
# .what = prove each declared flathub app is installed
#
# .why  it asks flatpak rather than look for a binary
#         a flatpak app has no /usr/bin entry to find. `flatpak list` is the only
#         place the truth lives, so a `command -v spotify` would report every one
#         of these absent on a box where all three work.
#
# .why  no -q on the grep
#         the driver runs under `set -o pipefail`, where `grep -q` exits on match,
#         SIGPIPEs flatpak, and turns a MATCH into a 141 the caller reads as a
#         miss (gotcha.pipefail-grep-q)
#
# ⚠️ .why the list is BOUNDED
#         `flatpak list` reads a local db, but it first takes the system
#         installation lock and may block on a `flatpak update` another process
#         holds — and this runs on every `--mode plan`, where the whole point is a
#         fast survey. an unbounded wait there is indistinguishable from a hang
#         (`rule.require.bounded-probes-in-verifies`).
#
#         a timeout is a 🌙: an unreadable list judges no app absent
#
# guarantee:
#   - READ-ONLY. it observes; it mutates no state
######################################################################

GROVE_FLATPAK_LIST_SECONDS=30

grove_provision_6_1_flatpaks_provision_verify() {
  if [[ "$GROVE_ENV_SERVER" != local@* ]]; then
    echo "   🌙 declined — no screen on $GROVE_ENV_SERVER, so no GUI client"
    echo "      is expected here"
    return 0
  fi

  ####################################################################
  # only an OPTED-IN app may be judged absent
  #
  # 🛑 .why this precedes the flatpak-on-PATH check
  #      that check is a ✋, and it is only a defect when an app is expected. on a
  #      box that opted into none, flatpak is CORRECTLY absent — to fail there
  #      would report a defect against a laptop that is exactly as asked for, and
  #      a check that cries wolf gets silenced
  #      (`gotcha.a-check-that-cries-wolf-gets-silenced`)
  ####################################################################
  local want=(); mapfile -t want < <(grove_provision_6_1_flatpaks_wanted)

  if [[ "${#want[@]}" -eq 0 ]]; then
    echo "   ✋ this phase ran with no app opted in" >&2
    echo "      ⇒ its bundle gates on the same question and should have" >&2
    echo "        declined first — the two readers disagree" >&2
    return 1
  fi

  if ! command -v flatpak >/dev/null 2>&1; then
    echo "   ✋ flatpak is absent from PATH" >&2
    echo "      ⇒ ${want[*]} — opted in, and with no runtime to launch under" >&2
    echo "      fix: rhx grove.provision --what 6.1.flatpaks --mode apply \\" >&2
    echo "             --include ${want[0]}" >&2
    return 1
  fi

  local installed rc
  # ⚠️ `-k 10` and not a bare timeout: flatpak is the MEASURED instance of a
  #    child that outlives TERM. on 2026-08-14 a `timeout 20 flatpak` aimed at a
  #    dead endpoint held a grove's duct for ~60 minutes, and every read of that
  #    source said 20s (`prove.timeouts-kill-what-they-cut`)
  installed="$(timeout -k 10 "$GROVE_FLATPAK_LIST_SECONDS" flatpak list --app --columns=application 2>/dev/null)" && rc=0 || rc=$?

  if [[ "$rc" -eq 124 ]]; then
    echo "   🌙 flatpak did not answer within ${GROVE_FLATPAK_LIST_SECONDS}s, so no app can be judged"
    echo "      ⇒ usually another process holds the installation lock — an update"
    echo "        or an install still in flight"
    echo "      read it by hand, unbounded: flatpak list --app"
    return 0
  fi

  local failed=0
  local app
  for name in "${want[@]}"; do
    app="${GROVE_FLATPAK_REF[$name]}"
    if echo "$installed" | grep -Fx "$app" >/dev/null; then
      echo "   • $name ($app) is installed ✔"
    else
      echo "   ✋ $name ($app) is opted in and NOT installed" >&2
      echo "      fix: rhx grove.provision --what 6.1.flatpaks --mode apply \\" >&2
      echo "             --include $name" >&2
      failed=1
    fi
  done

  return $failed
}

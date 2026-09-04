#!/usr/bin/env bash
######################################################################
# .what = install the flathub desktop clients — spotify, datagrip, slack
#
# .flatpak, not apt
#   - each of these three ships its own runtime, on its vendor's cadence
#   - the apt versions are either absent or years behind
#   - slack in particular gates features on a recent client
#
# ⚠️ .`--noninteractive` on every install
#   - a bare `flatpak install` asks "Is this ok [Y/n]" and READS STDIN
#   - under the driver stdout is often a pipe into a duct
#   - so the question is swallowed while the read still waits, forever
#   - 📜 the same shape in corepack's shim cost 57 minutes on grove-1 (5.1.node)
#   - (rule.require.bounded-probes-in-verifies)
#
# guarantee
#   - idempotent: flatpak reports an already-installed ref and exits 0
#   - BOUNDED: no prompt can wait on stdin
#   - it DECLINES on a box with no screen
######################################################################

grove_provision_6_1_flatpaks_provision_upsert() {
  if [[ "$GROVE_ENV_SERVER" != local@* ]]; then
    echo "   🌙 declined — spotify, datagrip and slack are GUI clients, and"
    echo "      $GROVE_ENV_SERVER has no screen to draw one on"
    return 0
  fi

  ####################################################################
  # which of the three did the human ask for?
  #
  # 🛑 .this is asked BEFORE flatpak is installed and the remote added
  #   - those two steps are the COST of an app, never a fact the box owes
  #   - to run them first would install a package manager on a laptop with no app
  #   - that is work nobody asked for, on every apply, forever
  #
  # ⚠️ .the loop is over the MAP's keys, never a literal list
  #   - the map in `_.sh` is the sole declaration of what this bundle offers
  #   - so a fourth app is opted into, installed, and offered by one edit
  ####################################################################
  local want=(); mapfile -t want < <(grove_provision_6_1_flatpaks_wanted)

  # the bundle declines before it dispatches this phase on an empty list
  #   - so an empty list HERE means the two readers disagree
  #   - that is a defect, never a no-op (rule.forbid.failhide)
  if [[ "${#want[@]}" -eq 0 ]]; then
    echo "   ✋ this phase ran with no app opted in" >&2
    echo "      ⇒ its bundle gates on the same question and should have" >&2
    echo "        declined first — the two readers disagree" >&2
    return 1
  fi

  echo "   • opted in: ${want[*]}"

  ####################################################################
  # this bundle OWNS its dependency, rather than points at another one
  #
  # ⚠️ .it installs flatpak, rather than names a fix elsewhere
  #   - a `--what 1.system` pointer would leave `--what 6.1.flatpaks` unable to converge
  #   - the driver accepts that slug and reports on it regardless
  #   - a bundle's number is a tree PATH, never a dependency edge
  #   - `pkg_install` converges, so the cost is one skipped apt call
  #   - (rule.require.bundles-own-their-dependencies)
  ####################################################################
  if ! command -v flatpak >/dev/null 2>&1; then
    pkg_install flatpak || return 1
    echo "   • flatpak installed — this box shipped without it"
  fi

  # ⚠️ `--user`, because a SYSTEM remote-add asks polkit
  #   - no `CI=1` or `DEBIAN_FRONTEND` reaches a polkit prompt
  #   - 📜 grove-1 2026-07-30: it hung a run with the prompt swallowed
  #   - `--user` needs no polkit, and is the right scope for a one-human machine
  #
  # ⚠️ `web_flatpak`, not a bare `flatpak`
  #   - 📜 2026-08-14: against a silent remote, bare `flatpak` opened TEN
  #     connections and had not returned at 240s — the worst of six tools measured
  #   - (prove.tool-defaults-are-bounded, src/grove.web.sh)
  #   - ⚠️ the `remote-add` is wrapped too, since it fetches the `.flatpakrepo`
  ####################################################################
  if ! web_flatpak remote-add --user --if-not-exists flathub \
       https://dl.flathub.org/repo/flathub.flatpakrepo; then
    echo "   ✋ could not add the flathub remote" >&2
    echo "      ⇒ every app below fails on a remote name flatpak never heard —" >&2
    echo "        three symptoms, one cause" >&2
    echo "      read why: flatpak remotes" >&2
    return 1
  fi

  local failed=0
  local app
  for name in "${want[@]}"; do
    app="${GROVE_FLATPAK_REF[$name]}"
    if web_flatpak install --user --noninteractive --assumeyes flathub "$app" </dev/null; then
      echo "   • $name ($app) installed ✔"
    else
      echo "   ✋ could not install $name ($app) from flathub" >&2
      failed=1
    fi
  done

  return $failed
}

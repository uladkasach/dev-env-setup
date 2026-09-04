#!/usr/bin/env bash
######################################################################
# .what = prove the dropbox client is on this box, and that the apt anchor it
#         now installs from is declared, scoped, and declared ONCE
#
# .why  it claims presence only, and not an active daemon
#         whether dropbox SYNCS depends on a human who signed in, which no
#         install step can do and no re-run should demand. to fail here for an
#         unsigned-in client would report a defect whose fix is "a person must
#         open the app" — a cry-wolf on every fresh box
#         (rule.forbid.tty-as-a-proxy-for-a-human).
#
# ⚠️ .why presence alone is no longer enough
#         this phase asked one question — is `dropbox` on PATH — which was the
#         whole of the bundle's claim while the upsert had one act: fetch a
#         .deb and install it.
#
#         the upsert now makes two further claims, and both are invisible to a
#         presence check: it places an apt TRUST ANCHOR, and it scopes that
#         anchor to one repo. a box can carry a `dropbox` binary that runs fine
#         while the key is absent (so no update ever verifies), or while it sits
#         in the blanket-trust directory (so it vouches for EVERY repo).
#
#         a verify that cannot disprove the bundle's central claim is not a weak
#         check — it is the claim made with no evidence
#         (`rule.require.upgrade-entries-verify-themselves`).
#
# .note  the FINGERPRINT is deliberately not re-checked here
#         whether the pinned value is the key upstream serves is a question
#         about UPSTREAM, not about this box, and it is answered by
#         `prove.apt-key-pins-bite` — which fetches the key live and demands the
#         pin refuse both a wrong key and an extra one. to restate the
#         fingerprint here would be a second declaration of one fact, free to
#         drift from the bundle's (`rule.require.identical-bundle-composition`).
#
# guarantee:
#   - READ-ONLY. it observes; it mutates no state
######################################################################

grove_provision_6_3_dropbox_provision_verify() {
  if [[ "$GROVE_ENV_SERVER" != local@* ]]; then
    echo "   🌙 declined — no screen on $GROVE_ENV_SERVER, so no dropbox client"
    echo "      is expected here"
    return 0
  fi

  local failed=0

  ####################################################################
  # 1. the binary
  ####################################################################
  if command -v dropbox >/dev/null 2>&1; then
    echo "   • dropbox is on PATH ✔"
  else
    echo "   ✋ dropbox is absent from PATH" >&2
    echo "      ⇒ every path under ~/Dropbox is a plain local directory that no" >&2
    echo "        other machine sees — which looks identical to a synced one" >&2
    echo "      fix: rhx grove.provision --what 6.3.dropbox --mode apply \\" >&2
    echo "             --include dropbox" >&2
    return 1
  fi

  ####################################################################
  # 2. the repo is declared exactly once
  #
  # .why no -q: under the driver's `pipefail` it would exit on match and SIGPIPE
  #      grep's own producer (gotcha.pipefail-grep-q)
  ####################################################################
  local lines
  lines="$(grep -rh 'linux\.dropbox\.com/ubuntu' \
    /etc/apt/sources.list /etc/apt/sources.list.d/ 2>/dev/null | grep -c . || true)"

  if [[ "${lines:-0}" -eq 1 ]]; then
    echo "   • the dropbox apt repo is declared once ✔"
  elif [[ "${lines:-0}" -eq 0 ]]; then
    ##################################################################
    # 🌙 and not ✋ — this is the state EVERY box provisioned by the old route
    #    is in, and its install came from a dated .deb that worked
    #
    # ⚠️ it is worth a line all the same: with no repo declared, the launcher
    #    on this box receives no apt update ever again, and the route that
    #    replaced it is unverifiable because it is absent
    ##################################################################
    echo "   🌙 dropbox is installed, and its apt repo is not declared"
    echo "      ⇒ that is what a box installed from the old dated .deb looks"
    echo "        like; it takes no update from apt. re-apply to declare the repo"
  else
    echo "   ✋ the dropbox apt repo is declared $lines times" >&2
    echo "      ⇒ apt complains 'configured multiple times' on EVERY update from" >&2
    echo "        now on, which trains a reader to skim the output where real key" >&2
    echo "        and signature errors also appear" >&2
    echo "      read them: grep -r linux.dropbox.com /etc/apt/sources.list.d/" >&2
    echo "      fix: leave ONE line, then re-run this verify" >&2
    failed=1
  fi

  ####################################################################
  # 3. the key is SCOPED — no copy in the blanket-trust directory
  #
  # ⚠️ a key under /etc/apt/trusted.gpg.d/ is trusted for EVERY repo apt reads,
  #    so dropbox's release key could vouch for a package that names debian,
  #    ubuntu, docker, or github as its origin. this bundle never wrote one
  #    there — but a human who followed dropbox's own published instructions
  #    would have, and the scoped copy does NOT undo it
  ####################################################################
  local keyfile_legacy="/etc/apt/trusted.gpg.d/dropbox.gpg"
  if [[ -f "$keyfile_legacy" ]]; then
    echo "   ✋ a dropbox key sits in /etc/apt/trusted.gpg.d/" >&2
    echo "      ⇒ a key there is trusted for EVERY apt repo, so this publisher's" >&2
    echo "        signature can vouch for a package that names ANY origin" >&2
    echo "      ⇒ the scoped keyfile this bundle writes does NOT undo that; the" >&2
    echo "        old file must go" >&2
    echo "      fix: sudo rm -f $keyfile_legacy" >&2
    failed=1
  elif [[ -f /etc/apt/keyrings/dropbox.gpg ]]; then
    echo "   • the dropbox key is scoped to its own repo ✔"
  elif [[ "${lines:-0}" -eq 0 ]]; then
    echo "   🌙 no repo is declared, so there is no anchor whose scope to judge"
  else
    ##################################################################
    # ✋ — a repo IS declared and its key is absent. that is not the old-route
    #    state; it is a repo apt cannot verify, so every dropbox package will
    #    be refused and `apt update` will report the source as unsigned
    ##################################################################
    echo "   ✋ the dropbox repo is declared, and its keyfile is absent" >&2
    echo "      ⇒ apt cannot verify this source, so it refuses every package it" >&2
    echo "        serves and reports the repo as unsigned on each update" >&2
    echo "      fix: rhx grove.provision --what 6.3.dropbox --mode apply \\" >&2
    echo "             --include dropbox" >&2
    failed=1
  fi

  return $failed
}

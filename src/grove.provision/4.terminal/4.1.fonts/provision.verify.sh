#!/usr/bin/env bash
######################################################################
# .what = prove both fonts are on the box AND that fontconfig can find them
#
# .it asks fontconfig, never the filesystem
#   - kitty asks fontconfig by NAME, never by path, off this same index
#   - a .ttf fontconfig has not indexed is invisible to every client
#
# ⚠️ .every grep here drops `-q` for a `>/dev/null`
#   - under `set -o pipefail`, `grep -q` exits on MATCH and SIGPIPEs `fc-list`
#   - 📜 measured here 2026-07-30:
#
#           fc-list | grep -qi 'hack nerd font mono'   → 141   ✋ (false)
#           fc-list | grep -i  'hack nerd font mono' >/dev/null → 0   ✔ (true)
#
#   - the trap is SIZE-dependent, so a small producer hides it
#   - (gotcha.pipefail-grep-q)
#
# guarantee
#   - READ-ONLY: it observes and mutates no state
######################################################################

grove_provision_4_1_fonts_provision_verify() {
  ####################################################################
  # a declined install leaves no claim to test
  #   - a ✋ here would report a defect the box does not have
  ####################################################################
  if [[ "$GROVE_ENV_SERVER" != local@* ]]; then
    echo "   🌙 not applicable — no screen on $GROVE_ENV_SERVER"
    return 0
  fi

  local failed=0

  if ! command -v fc-list >/dev/null 2>&1; then
    echo "   ✋ fontconfig is absent, so no font on this box is reachable by name" >&2
    echo "      ⇒ kitty asks fontconfig for 'Hack Nerd Font Mono'; with no index" >&2
    echo "        it falls back to a default and every icon draws as tofu (▯)" >&2
    echo "      fix: rhx grove.provision --what 4.1.fonts --mode apply" >&2
    return 1
  fi

  ####################################################################
  # 0. read the index ONCE, and bound the read
  #
  # ⚠️ .one call, not two
  #   - `fc-list` rebuilds the cache on first use after a font install
  #   - on a slow or network-mounted `~/.fonts` that walk has no upper limit
  #   - (rule.require.bounded-probes-in-verifies)
  #
  # .a timeout is a 🌙
  #   - an index this run could not read judges no font absent
  ####################################################################
  local index rc
  index="$(timeout -k 5 20 fc-list 2>/dev/null)" && rc=0 || rc=$?

  if [[ "$rc" -eq 124 ]]; then
    echo "   🌙 fontconfig did not answer within 20s, so no font can be judged"
    echo "      ⇒ usually a cold cache rebuild after a font install"
    echo "      read it by hand, unbounded: fc-list | grep -iE 'fira|hack'"
    return $failed
  fi

  ####################################################################
  # 1. FiraCode — the ligature font
  ####################################################################
  # .`-E`, because `?` is a LITERAL in a basic regex
  #   - debian's family reads `Fira Code`, and some builds read `FiraCode`
  #   - hence the optional space
  if echo "$index" | grep -iE 'fira ?code' >/dev/null; then
    echo "   • FiraCode is indexed by fontconfig ✔"
  else
    echo "   ✋ FiraCode is NOT indexed by fontconfig" >&2
    echo "      ⇒ code ligatures (→, !=, =>) draw as their raw two characters" >&2
    echo "      fix: rhx grove.provision --what 4.1.fonts --mode apply" >&2
    failed=1
  fi

  ####################################################################
  # 2. Hack Nerd Font Mono — the icon font
  #
  #   - the plain `Hack Nerd Font` patch indexes under a near-identical family
  #   - ⇒ a match on the shorter name would report ✔ on the double-width font
  ####################################################################
  if echo "$index" | grep -i 'hack nerd font mono' >/dev/null; then
    echo "   • Hack Nerd Font Mono is indexed by fontconfig ✔"
  else
    echo "   ✋ Hack Nerd Font Mono is NOT indexed by fontconfig" >&2
    echo "      ⇒ nvim's file tree, statusline, and git signs draw tofu (▯) where" >&2
    echo "        an icon belongs — a defect that reads as a plugin bug" >&2
    echo "      read what IS indexed: fc-list | grep -i hack" >&2
    echo "      fix: rhx grove.provision --what 4.1.fonts --mode apply" >&2
    failed=1
  fi

  return $failed
}

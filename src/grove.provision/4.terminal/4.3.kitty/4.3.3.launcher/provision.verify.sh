#!/usr/bin/env bash
######################################################################
# .what = prove `terminal` is on PATH, is executable, and names kitty
#
# .why  the third claim — that it names kitty
#         `/usr/bin/terminal` is a generic name that some other package could
#         plausibly claim. a check for presence + executability would report ✔ on
#         a file this repo never wrote, and the human would meet the difference
#         only when a window opened in the wrong emulator with no kitten socket.
#
# guarantee:
#   - READ-ONLY. it observes; it mutates no state
######################################################################

grove_provision_4_3_3_launcher_provision_verify() {
  if [[ "$GROVE_ENV_SERVER" != local@* ]]; then
    echo "   🌙 not applicable — no screen on $GROVE_ENV_SERVER"
    return 0
  fi

  if [[ ! -x /usr/bin/terminal ]]; then
    echo "   ✋ /usr/bin/terminal is absent or not executable" >&2
    echo "      ⇒ \`terminal .\` and every desktop 'open here' action fail with" >&2
    echo "        'command not found'" >&2
    echo "      fix: rhx grove.provision --what 4.3.3.launcher --mode apply" >&2
    return 1
  fi

  if ! grep -q 'kitty --directory' /usr/bin/terminal; then
    echo "   ✋ /usr/bin/terminal exists but does NOT call kitty" >&2
    echo "      ⇒ some other package owns this name, so 'open here' launches an" >&2
    echo "        emulator with no kitten socket — every termwork skill that" >&2
    echo "        drives 'kitten @' then finds no window to talk to" >&2
    echo "      read what is there: cat /usr/bin/terminal" >&2
    echo "      fix: rhx grove.provision --what 4.3.3.launcher --mode apply" >&2
    return 1
  fi

  echo "   • the \`terminal\` command is present and opens kitty ✔"
}

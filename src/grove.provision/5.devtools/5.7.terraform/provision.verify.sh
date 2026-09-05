#!/usr/bin/env bash
######################################################################
# .what = prove tfenv is installed and reachable from ~/.local/bin
#
# guarantee:
#   - READ-ONLY. it observes; it mutates no state
######################################################################

grove_provision_5_7_terraform_provision_verify() {
  if [[ "$GROVE_ENV_SERVER" != local@* ]]; then
    echo "   🌙 not applicable — terraform is declined off a human's box"
    return 0
  fi

  if [[ ! -d "$HOME/.tfenv" ]]; then
    echo "   ✋ tfenv is not installed (~/.tfenv is absent)" >&2
    echo "      ⇒ a stack whose required_version differs from the terraform on" >&2
    echo "        PATH refuses to plan at all" >&2
    echo "      fix: rhx grove.provision --what 5.7.terraform --mode apply" >&2
    return 1
  fi

  if [[ ! -L "$HOME/.local/bin/tfenv" ]]; then
    echo "   ✋ tfenv is installed but NOT linked onto ~/.local/bin" >&2
    ##################################################################
    # ⚠️ the backticks below are ESCAPED, and the escape is load-bear
    #   - a bare backtick pair in a double-quoted string is a COMMAND SUBSTITUTION
    #   - so bash would run tfenv to build a sentence about tfenv's absence
    #   - it would print its own `command not found` to stderr
    #   - it would leave a hole in the message
    #   - `shell.syntax.verify` cannot catch that, since it is valid syntax
    #   - it is the wrong MEANING, inside an error path no one exercises
    ##################################################################
    echo "      ⇒ it is on the box and unreachable, so a \`tfenv\` call finds" >&2
    echo "        no command while the directory sits right there" >&2
    echo "      fix: rhx grove.provision --what 5.7.terraform --mode apply" >&2
    return 1
  fi

  echo "   • tfenv is installed and linked ✔"
}

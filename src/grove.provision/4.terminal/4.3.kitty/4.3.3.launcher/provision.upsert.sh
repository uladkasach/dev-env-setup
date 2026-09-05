#!/usr/bin/env bash
######################################################################
# .what = install /usr/bin/terminal — `terminal [dir]` opens kitty there
#
# .`setsid -f`
#   - without it the new kitty is a CHILD of the shell that launched it
#   - so a throwaway shell would take the terminal with it on close
#
# .`realpath` on the argument
#   - kitty's `--directory` is read AFTER the new session detaches
#   - by then a relative path resolves against a cwd that may be gone
#
# .the default is `.`, not $HOME
#   - `terminal` with no argument is typed from where a human already stands
#   - (rule.prefer.defaults-match-common-case)
#
# guarantee
#   - idempotent: the file is declared whole, so a re-run converges
#   - it DECLINES where no screen exists
######################################################################

grove_provision_4_3_3_launcher_provision_upsert() {
  if [[ "$GROVE_ENV_SERVER" != local@* ]]; then
    echo "   🌙 declined — no screen on $GROVE_ENV_SERVER, so a launcher here"
    echo "      would have no window to open (kitten still works; see 4.3.2)"
    return 0
  fi

  ####################################################################
  # the DECLARED content, named once
  #   - so the read below and the write below cannot drift apart
  ####################################################################
  local declared
  declared="$(cat << 'EOF'
#!/usr/bin/env bash
dir="${1:-.}"
dir="$(realpath "$dir")"
setsid -f kitty --directory "$dir"
EOF
)"

  ####################################################################
  # 🛑 .the FACT is read before any privilege is asked for
  #   - a `sudo tee` on every run reaches for root over a byte-identical file
  #   - on a laptop that is a password prompt a human answers for no change
  #   - on a seat without root it is a ✋ over work already done
  #   - (rule.require.one-command-provision)
  ####################################################################
  if [[ -x /usr/bin/terminal ]] && [[ "$(cat /usr/bin/terminal 2>/dev/null)" == "$declared" ]]; then
    echo "   • the \`terminal\` command already matches this checkout ✔ — no work"
    return 0
  fi

  # ⚠️ every write below is root's, and lands outside every `$HOME`
  #   - so a seat with no root declines here rather than fails
  bundle.root.owns "the \`terminal\` launcher" \
    "/usr/bin/terminal does not match this checkout" || return 0

  if ! printf '%s\n' "$declared" | sudo tee /usr/bin/terminal >/dev/null; then
    echo "   ✋ could not write /usr/bin/terminal" >&2
    echo "      ⇒ 'open here' actions and \`terminal .\` have no command to call," >&2
    echo "        so each fails with 'terminal: command not found'" >&2
    return 1
  fi

  if ! sudo chmod +x /usr/bin/terminal; then
    echo "   ✋ could not mark /usr/bin/terminal executable" >&2
    echo "      ⇒ the file exists and still cannot be run, which reads as a" >&2
    echo "        permission error rather than an absent install" >&2
    return 1
  fi

  echo "   • the \`terminal\` command declared → /usr/bin/terminal"
}

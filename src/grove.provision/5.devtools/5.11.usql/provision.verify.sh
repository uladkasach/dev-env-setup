#!/usr/bin/env bash
######################################################################
# .what = prove usql is on PATH at the version this bundle pins
#
# .the version is part of the claim
#   - a `usql` from another source answers `command -v` and may be years old
#   - ⇒ the pin exists so two boxes behave alike, and presence cannot see it
#
# guarantee:
#   - READ-ONLY: it observes and mutates no state
######################################################################

grove_provision_5_11_usql_provision_verify() {
  ####################################################################
  # 🛑 the version is READ from `_.sh`, never typed here
  #   - 📜 2026-08-13: with its own copy of `0.19.14` a bump left it behind, and
  #     it reported `✋ the WRONG version` over a good install
  #   - ⇒ its fix named a re-apply, which installs the version it just refused
  ####################################################################
  local version="$GROVE_USQL_VERSION"

  ####################################################################
  # ⚠️ NOT a bare `command -v usql`
  #   - `2.7.aliases` declares a `usql` SHELL FUNCTION, the `--key` wrapper
  #   - `command -v` answers a function with its bare name and exits 0
  #   - 📜 laptop 2026-07-30: this reported "the WRONG version" while
  #     `usql --version` exited 127, command not found
  #   - ⇒ it named the wrong defect, and so offered the wrong fix
  #
  # ⚠️ `bundle.bin.at`, never `bundle.bin.of`
  #   - this process's `$PATH` predates the `~/.local/bin/usql` its upsert writes
  #   - 📜 fresh grove 2026-08-12: the upsert printed the install path, and this
  #     verify answered `absent from PATH` two lines later
  #   - see `bundle.bin.at`'s header
  ####################################################################
  local bin
  bin="$(bundle.bin.at usql)"

  if [[ -z "$bin" ]]; then
    echo "   ✋ usql is absent from this box" >&2
    echo "      looked at: \$HOME/.local/bin/usql, then \$PATH" >&2
    echo "      ⇒ every database that is NOT postgres has no client here" >&2
    echo "      ⇒ the \`usql --key\` alias still resolves, so a human sees a" >&2
    echo "        command that exists and then fails — not an absent one" >&2
    echo "      fix: rhx grove.provision --what 5.11.usql --mode apply" >&2
    return 1
  fi

  local live
  live="$("$bin" --version 2>/dev/null | head -1)"

  if echo "$live" | grep -F "$version" >/dev/null; then
    echo "   • usql is $version, the declared pin ✔"
    return 0
  fi

  echo "   ✋ usql is on PATH at the WRONG version" >&2
  echo "      ⇒ want $version; it says: ${live:-no readable version}" >&2
  echo "      ⇒ two boxes on different versions behave differently against the" >&2
  echo "        same database, which is what the pin exists to prevent" >&2
  echo "      fix: rhx grove.provision --what 5.11.usql --mode apply" >&2
  return 1
}

#!/usr/bin/env bash
######################################################################
# .what = build tree-sitter-cli with cargo, so nvim can compile parsers
#
# 🛑 an absent cargo is a ✋ HERE, where it was a 🌙 in `4.5.nvim`
#   - `5.2.rust` runs immediately before this bundle (see `5.devtools/_.sh`)
#   - ⇒ an absent cargo means it did not converge, which has a real fix
#   - ⇒ a decline that holds only on where a step SITS dies when the step moves
#
# .`cargo install` needs no IDEMPOTENCY guard of its own
#   - it reports an up-to-date crate rather than a rebuild
#   - (`rule.require.idempotent-install-procedures`)
#
# 🛑 its exit code is checked, and that is not optional
#   - bash returns the LAST command's status, and the later lines succeed
#   - 📜 run bare, a dead build (`linker 'cc' not found`) reported ✔ over an
#     nvim that landed with no parser compiler
#   - (`rule.forbid.failhide`)
#
# guarantee:
#   - idempotent: an extant crate at the current version short-circuits in cargo
######################################################################

# .the pin is `GROVE_TREESITTER_PIN`, declared in this bundle's `_.sh`
#   - BOTH halves read it: the install below, and the verify's version probe
#   - `_.sh` carries why it is pinned, what it does NOT bound, and how to bump it

grove_provision_5_14_treesitter_provision_upsert() {
  if ! command -v cargo >/dev/null 2>&1; then
    echo "   ✋ cargo is absent, so tree-sitter-cli cannot be built" >&2
    echo "      ⇒ this bundle runs directly after 5.2.rust, so an absent cargo" >&2
    echo "        means THAT bundle did not converge — it is not a fact of order" >&2
    echo "      fix: rhx grove.provision --what 5.2.rust --mode apply" >&2
    return 1
  fi

  if ! cargo install tree-sitter-cli --version "$GROVE_TREESITTER_PIN"; then
    echo "   ✋ tree-sitter-cli failed to build — nvim cannot compile parsers" >&2
    echo "      ⇒ cargo IS present, so the build itself broke" >&2
    # 🛑 name the c toolchain as the cause, and `5.2.rust` as the fix
    #   - a cause with no fix leaves a reader to run `apt install build-essential`
    #   - `5.2.rust` installs it AND libclang-dev, and refuses if `cc` is mute
    #   - (`rule.require.install-via-procedures`)
    echo "      ⇒ cause is usually no c toolchain: cargo needs 'cc' to link and" >&2
    echo "        libclang to bindgen. both are declared by 5.2.rust" >&2
    echo "      fix: rhx grove.provision --what 5.2.rust --mode apply" >&2
    echo "      read why: the cargo error above names the absent piece" >&2
    return 1
  fi

  echo "   • tree-sitter-cli built ✔ (pinned at $GROVE_TREESITTER_PIN)"
}

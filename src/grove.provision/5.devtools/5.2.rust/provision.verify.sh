#!/usr/bin/env bash
######################################################################
# .what = prove cargo resolves AND that it can actually LINK
#
# ⚠️ .why the linker claim is separate from the cargo claim
#         `cargo --version` answers on a box where every build still dies at the
#         link step, because rustup installs cleanly with no c compiler present
#         and only warns. so a cargo-only check reports ✔ on precisely the box
#         this bundle exists to prevent — the fresh ubuntu grove with no
#         `build-essential`.
#
#         the two are asked separately so the message can name the RIGHT fix: an
#         absent cargo and an absent linker have different repairs, and one
#         message for both would print the wrong one half the time.
#
# guarantee:
#   - READ-ONLY. it observes; it mutates no state
######################################################################

grove_provision_5_2_rust_provision_verify() {
  local failed=0

  ####################################################################
  # 1. cargo resolves — from PATH, or from the home rustup dir a
  #    non-interactive shell has not sourced yet
  #
  # .why both: this run is `bash <file>`, which reads no rc, so a cargo that a
  #      human's shell finds is invisible here. a PATH-only check would report a
  #      defect that exists in this process alone
  ####################################################################
  local cargo=""
  if command -v cargo >/dev/null 2>&1; then
    cargo="$(command -v cargo)"
  elif [[ -x "$HOME/.cargo/bin/cargo" ]]; then
    cargo="$HOME/.cargo/bin/cargo"
  fi

  if [[ -n "$cargo" ]]; then
    echo "   • cargo resolves ✔ ($("$cargo" --version 2>/dev/null))"
  else
    echo "   ✋ cargo is absent" >&2
    echo "      ⇒ 4.5.nvim cannot build tree-sitter-cli, so nvim lands with no" >&2
    echo "        parser compiler and syntax highlight goes dead per-language" >&2
    echo "      fix: rhx grove.provision --what 5.2.rust --mode apply" >&2
    failed=1
  fi

  ####################################################################
  # 2. a linker exists — the claim rustup's own warn does not enforce
  ####################################################################
  if command -v cc >/dev/null 2>&1; then
    echo "   • cc is on PATH, so cargo can link ✔"
  else
    echo "   ✋ no c compiler on PATH, so every cargo build dies at the link step" >&2
    echo "      ⇒ rustup only WARNS about this, so cargo installs 'successfully'" >&2
    echo "        and the failure surfaces inside whatever crate builds next" >&2
    echo "      fix: rhx grove.provision --what 5.2.rust --mode apply" >&2
    failed=1
  fi

  return $failed
}

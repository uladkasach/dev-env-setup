#!/usr/bin/env bash
######################################################################
# .what = prove tree-sitter-cli is on the box and can run
#
# 🛑 this claim is a ✋ and never a 🌙
#   - `5.2.rust` runs immediately before this bundle
#   - ⇒ an absent crate here is a real defect, never a fact about ORDER
#
# ⚠️ the DECLARED PATH is asked before `$PATH`
#   - a `command -v` asks the PROCESS while the claim is about the BOX
#   - cargo's dir is on this run's PATH already, since `5.2.rust` sourced its env
#   - ⇒ a PATH read would pass here by luck, on a neighbor's side effect
#   - 📜 the same confusion cost six false ✋ on a fresh grove 2026-08-12
#   - read `bundle.bin.at`'s header in `src/bundle.upgrade.sh`
#
# .it RUNS the binary, and does not merely find it
#   - a crate built against an absent `cc` lands as a file that cannot execute
#   - ⇒ nvim reports that as a parser failure, never as a toolchain one
#   - (`rule.require.failloud`)
#
# guarantee:
#   - READ-ONLY. it observes; it mutates no state
#   - BOUNDED. the run probe is wrapped in `timeout`
######################################################################

grove_provision_5_14_treesitter_provision_verify() {
  local bin="$HOME/.cargo/bin/tree-sitter"
  [[ -x "$bin" ]] || bin="$(bundle.bin.of tree-sitter)"

  if [[ -z "$bin" || ! -x "$bin" ]]; then
    echo "   ✋ tree-sitter is absent from this box" >&2
    echo "      looked at: \$HOME/.cargo/bin/tree-sitter, then \$PATH" >&2
    echo "      ⇒ nvim runs, and compiles not one parser — so syntax, folds," >&2
    echo "        and every treesitter-driven feature stay off" >&2
    echo "      fix: rhx grove.provision --what 5.14.treesitter --mode apply" >&2
    return 1
  fi

  ####################################################################
  # .the run probe and the PIN probe are one call
  #
  # ⚠️ the version is read from the BINARY, never `~/.cargo/.crates.toml`
  #   - that file records what cargo INSTALLED, and the claim is about what runs
  #   - ⇒ the two part company once another writer touches `~/.cargo/bin`
  #   - 📜 the claude pin was re-cut on that split: metadata said 2.1.87 while
  #     the live cli reported 2.1.220
  #   - ⇒ ask the binary
  ####################################################################
  local ts_out ts_live
  if ts_out="$(timeout -k 5 20 "$bin" --version </dev/null 2>/dev/null)"; then
    ts_live="$(printf '%s' "$ts_out" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)"

    if [[ -z "$ts_live" ]]; then
      echo "   🌙 tree-sitter runs, and answered no version this run ($bin)"
      echo "      ⇒ the pin ($GROVE_TREESITTER_PIN) is unproven here, not disproven"
      return 0
    fi
    if [[ "$ts_live" == "$GROVE_TREESITTER_PIN" ]]; then
      echo "   • tree-sitter is on the box, runs, and is $ts_live — the pin ✔"
      return 0
    fi

    echo "   ✋ tree-sitter is $ts_live, but the declared pin is $GROVE_TREESITTER_PIN" >&2
    echo "      ⇒ this crate is compiled and RUN on this box from a third-party" >&2
    echo "        registry account, so an unreviewed publish lands here" >&2
    echo "      fix: rhx grove.provision --what 5.14.treesitter --mode apply" >&2
    echo "      or, if the drift is wanted: bump GROVE_TREESITTER_PIN first" >&2
    return 1
  fi

  echo "   ✋ tree-sitter is installed and does NOT run" >&2
  echo "      at: $bin" >&2
  echo "      ⇒ a crate built with no 'cc' can land as a file that cannot exec," >&2
  echo "        and nvim reports that as a PARSER failure, never a toolchain one" >&2
  echo "      read why: $bin --version" >&2
  echo "      fix: rhx grove.provision --what 5.2.rust --mode apply" >&2
  return 1
}

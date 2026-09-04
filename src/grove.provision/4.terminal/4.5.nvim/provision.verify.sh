#!/usr/bin/env bash
######################################################################
# .what = prove neovim is present, is the PINNED build, and can compile a parser
#
# .three claims, not one `command -v nvim`
#      each names a way this bundle has actually failed:
#           1. nvim resolves            — the binary is reachable at all
#           2. the RESOLVED one is ours — /usr/bin ppa build does not shadow it
#           3. the version is the pin   — a stale /opt is a silent downgrade
#
# ⚠️ .claim 2 exists because a presence check passes on the WRONG binary
#   - `command -v nvim` returns 0 for a ppa build at /usr/bin/nvim
#   - that is the state the upsert removes, and the double-<CR> input bug
#   - ⇒ a bare "is nvim there?" would ✔ the box that motivated the pin
#
#   - the parser-compiler claim belongs to `5.14.treesitter`, beside its build
#   - the numbers below skip 4 for that reason
#
# guarantee
#   - READ-ONLY: it observes and mutates no state
#   - every claim it refutes names its fix (rule.require.errors-name-the-fix)
######################################################################

grove_provision_4_5_nvim_provision_verify() {
  local version="0.12.3"
  local failed=0

  ####################################################################
  # 1 + 2. nvim resolves, and the one PATH finds is the tarball build
  #
  # ⚠️ .`bundle.bin.of`, not `command -v`
  #   - `2.7.aliases` declares an `export -f`'d `nvim` function, the memory cap
  #   - `command -v` answers a function with its bare NAME, never a path
  #   - `readlink -f nvim` then resolved that literal against $PWD
  #   - 📜 2026-07-30: this claimed nvim lived in the WORKTREE directory
  #   - 📜 `type -a nvim` showed the pinned build at /usr/local/bin/nvim all along
  #   - 📜 the grove, which exports no such function, passed
  #   - ⇒ `bundle.bin.of` is blind to functions, so it reads the BINARY
  ####################################################################
  local onpath
  onpath="$(bundle.bin.of nvim)"

  if [[ -z "$onpath" ]]; then
    echo "   ✋ nvim is NOT on PATH" >&2
    echo "      ⇒ this box has no editor, so every nvim keybind and diff tool" >&2
    echo "        this repo declares is unreachable" >&2
    echo "      fix: rhx grove.provision --what 4.5.nvim --mode apply" >&2
    failed=1
  else
    local target
    target="$(readlink -f "$onpath" 2>/dev/null)"
    if [[ "$target" == /opt/nvim-linux-x86_64/* ]]; then
      echo "   • nvim resolves to the pinned tarball build ✔ ($onpath)"
    else
      echo "   ✋ nvim resolves to $target — NOT the pinned tarball build" >&2
      echo "      ⇒ a ppa-managed /usr/bin/nvim shadows /usr/local/bin/nvim on a" >&2
      echo "        default PATH. that build's input regressions double-emit" >&2
      echo "        <CR> and <BS> under kitty, which is why the pin exists" >&2
      echo "      fix: rhx grove.provision --what 4.5.nvim --mode apply" >&2
      failed=1
    fi

    ##################################################################
    # 3. the version is the one this bundle declares
    ##################################################################
    local live
    live="$("$onpath" --version 2>/dev/null | head -1 | grep -oE 'v?[0-9]+\.[0-9]+\.[0-9]+')"
    if [[ "$live" == "v${version}" || "$live" == "${version}" ]]; then
      echo "   • nvim is v${version}, the declared pin ✔"
    else
      echo "   ✋ nvim reports '${live:-unreadable}', but this bundle pins v${version}" >&2
      echo "      ⇒ a stale /opt is a silent downgrade: the box runs an older" >&2
      echo "        editor than every brief and config here assumes" >&2
      echo "      fix: rhx grove.provision --what 4.5.nvim --mode apply" >&2
      failed=1
    fi
  fi

  ####################################################################
  # 4. the parser compiler is claimed by `5.14.treesitter`
  #
  # 🛑 a verify whose verdict depends on WHERE ITS BUNDLE SITS is in the wrong bundle
  #   - asked here, an absent cargo reads two ways: 🌙 for order, ✋ for a build
  #   - a fresh box guarantees the 🌙 arm, so a first apply could never claim it
  #   - such a split ENCODES the defect of order rather than removes it
  #   - ⇒ the claim sits with its upsert, where cargo exists and absence reads once
  #   - (rule.require.seam-claims-have-an-owner)
  ####################################################################

  ####################################################################
  # 5. imagemagick — reported, never a failure
  #
  #   - it does not set `failed`, since the upsert treats it as non-fatal
  #   - a verify that blocked on it would contradict its own bundle
  ####################################################################
  if command -v convert >/dev/null 2>&1 || command -v magick >/dev/null 2>&1; then
    echo "   • imagemagick present, so inline images and image diffs render ✔"
  else
    echo "   🌙 imagemagick absent — inline image render and image diffs stay off."
    echo "      the editor is unaffected otherwise, so this is not a failure"
  fi

  return $failed
}

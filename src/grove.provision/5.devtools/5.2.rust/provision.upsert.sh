#!/usr/bin/env bash
# .what = install rustup + cargo, and the C toolchain cargo links against
# .ref  = https://rustup.rs/
# .why
#   - cargo shells out to `cc`; with no compiler every build dies at the link
#   - rustup only WARNS about an absent compiler, so this bundle installs it too
#   - libclang-dev too, since tree-sitter-cli is a bindgen consumer
#   - .refs = gotcha.5-2-rust.demo=pin-tier-and-rc-collision, m1
#
# guarantee:
#   - rustup's installer converges, and `-y` keeps it non-interactive
#   - it fails loud if the toolchain still cannot link

grove_provision_5_2_rust_provision_upsert() {
  pkg_install build-essential || return 1   # cc/gcc/make — cargo's linker
  pkg_install libclang-dev || return 1      # cargo bindgen (e.g. tree-sitter-cli)

  # some installer versions prompt about an extant toolchain even under `-y`
  if [[ -x "$HOME/.cargo/bin/cargo" ]]; then
    echo "   • rustup already installed; skipped"
  else
    # fetched to a file, never piped into `sh` — a pipe cut partway runs a
    # truncated installer silently; `web_fetch` lands the file whole or not
    # at all (rule.forbid.failhide). a PRIVATE temp dir, since this path is
    # executed right after it is written and ground's seat holds NOPASSWD
    # sudo (src/grove.web.sh)
    local tmp_dir
    tmp_dir="$(web_tempdir rustup)" || return 1
    local tmp_rustup="$tmp_dir/rustup-init"

    # the VERSIONED BINARY, never `https://sh.rustup.rs` — an unversioned url
    # names no fixed artifact, so no hash is expressible against it
    # (rule.require.verify-binary-downloads). the pin is SOURCED from the
    # archive sidecar, and rust publishes no .asc/.sig for rustup-init
    # .refs = gotcha.5-2-rust.demo=pin-tier-and-rc-collision, m2, m3
    local rustup_version="1.29.0"
    local rustup_sha256="4acc9acc76d5079515b46346a485974457b5a79893cfb01112423c89aeb5aa10"
    local rustup_url="https://static.rust-lang.org/rustup/archive/${rustup_version}/x86_64-unknown-linux-gnu/rustup-init"

    if ! web_fetch "$rustup_url" --into "$tmp_rustup"; then
      echo "   ✋ could not download rustup-init" >&2
      echo "      ⇒ with no cargo, 5.14.treesitter cannot build tree-sitter-cli," >&2
      echo "        so nvim lands with no parser compiler and every language's" >&2
      echo "        syntax highlight and text-object silently goes dead" >&2
      echo "      ⇒ web_fetch named the wire fault above — a STALL wants a retry," >&2
      echo "        and a 404 here means the pinned version was withdrawn" >&2
      rm -rf "$tmp_dir"
      return 1
    fi

    # verify BEFORE chmod +x — an unverified download would pick what this
    # seat runs, and on ground that seat holds NOPASSWD sudo
    if ! web_verify_sha256 --file "$tmp_rustup" --sha256 "$rustup_sha256"; then
      echo "      ⇒ rustup is NOT installed, and the binary is discarded" >&2
      echo "        unexecuted. a box with no cargo beats a box that ran an" >&2
      echo "        installer nobody vouched for" >&2
      rm -rf "$tmp_dir"
      return 1
    fi
    echo "   • rustup-init ${rustup_version} verified against its pinned sha256 ✔"

    chmod +x "$tmp_rustup" || { rm -rf "$tmp_dir"; return 1; }

    # `-y` keeps it non-interactive, since a menu is a hang on a grove.
    # `--no-modify-path` — rustup edits shell rc files this repo owns, and
    # `~/.zshenv` is `2.5.zsh`'s by byte; without the flag rustup's append
    # collides with that bundle's `cmp -s` and reads as a two-writer defect.
    # the append was redundant regardless — src/zshenv.sh already puts
    # ~/.cargo/bin on PATH, guarded — and rustup still WRITES ~/.cargo/env
    # itself, since the flag governs only rc files
    # .refs = gotcha.5-2-rust.demo=pin-tier-and-rc-collision, m4
    if ! "$tmp_rustup" -y --no-modify-path </dev/null; then
      echo "   ✋ rustup-init ran and failed" >&2
      echo "      ⇒ the download was fine (it landed whole AND matched its" >&2
      echo "        pinned hash), so this is the installer itself — read its" >&2
      echo "        error above, not the network" >&2
      rm -rf "$tmp_dir"
      return 1
    fi
    rm -rf "$tmp_dir"
  fi

  # put cargo on PATH for THIS shell, so the check below can run now
  # shellcheck disable=SC1091
  [[ -r "$HOME/.cargo/env" ]] && source "$HOME/.cargo/env"

  # fail loud if the toolchain still cannot link — see the header
  if ! command -v cc >/dev/null 2>&1; then
    echo "   ✋ no c compiler on PATH — every cargo build will fail to link" >&2
    echo "      ⇒ rustup only WARNS about this, so the gap would surface later" >&2
    echo "        as an opaque build error inside whatever crate is next" >&2
    # no `fix: sudo apt-get install -y build-essential` — that is a hand step
    # (rule.require.install-via-procedures); the one box that prints this is
    # the one this phase cannot help, since it already ran that install
    echo "      ⇒ build-essential installed OK above, so this is not an absent" >&2
    echo "        package — either its alternatives link is unset, or PATH here" >&2
    echo "        omits /usr/bin" >&2
    echo "      read why: dpkg -L gcc | grep bin/ ; echo \"\$PATH\"" >&2
    return 1
  fi

  echo "   • rust toolchain ✔ (cargo + cc)"
}

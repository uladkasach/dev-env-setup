#!/usr/bin/env bash
######################################################################
# .what = test and build crewspace from the repo's source, then install it
#
# .why the build is keyed on a source hash
#   - a cold cargo check still costs seconds; the stamp makes a second apply a
#     pure read
#
# .why the crate's tests run before install
#   - they clamp every read decision against a captured view, with no
#     compositor in reach. a source that fails them never reaches the box
#   - they share the release target dir, so they cost one extra link, not a
#     second dependency build
#
# guarantee:
#   - idempotent: a rebuild runs only when the source hash moved
#   - no root: every write lands in $HOME
######################################################################

grove_provision_5_26_crewspace_provision_upsert() {
  grove_provision_5_26_crewspace_applies || return 0

  local crate bin stamp
  crate="$(grove_provision_5_26_crewspace_dir)/crewspace"
  bin="$(grove_provision_5_26_crewspace_bin_at)"
  stamp="$(grove_provision_5_26_crewspace_stamp_at)"

  if [[ -x "$bin" && "$(cat "$stamp" 2>/dev/null)" == "$(grove_provision_5_26_crewspace_src_hash)" ]]; then
    echo "   • binary current ✔"
    return 0
  fi

  local cargo="${CARGO_HOME:-$HOME/.cargo}/bin/cargo"
  [[ -x "$cargo" ]] || cargo="$(command -v cargo 2>/dev/null)"
  if [[ -z "$cargo" ]]; then
    echo "   ✋ ConstraintError: cargo is absent — crewspace cannot be built" >&2
    echo "      fix: rhx grove.provision --what 5.2.rust --mode apply" >&2
    return 1
  fi

  local target="$HOME/.cache/grove/crewspace-target"
  local log

  # 1. the clamps — cargo's own exit is the verdict; output is captured so a pipe cannot mask it
  echo "   • test: cargo test --release --locked"
  if ! log="$(CARGO_TARGET_DIR="$target" "$cargo" test --release --locked --manifest-path "$crate/Cargo.toml" 2>&1)"; then
    printf '%s\n' "$log" | tail -n 30 | sed 's/^/      /' >&2
    echo "   💥 MalfunctionError: crewspace's tests failed — see their output above" >&2
    return 1
  fi

  # 2. the binary
  echo "   • build: cargo build --release --locked"
  if ! log="$(CARGO_TARGET_DIR="$target" "$cargo" build --release --locked --manifest-path "$crate/Cargo.toml" 2>&1)"; then
    printf '%s\n' "$log" | tail -n 30 | sed 's/^/      /' >&2
    echo "   💥 MalfunctionError: cargo build failed — see its output above" >&2
    return 1
  fi
  if [[ ! -x "$target/release/crewspace" ]]; then
    echo "   💥 MalfunctionError: cargo build produced no binary at $target/release/crewspace" >&2
    return 1
  fi

  # 3. install, then stamp — the stamp lands last, so a failed install is rebuilt next run
  mkdir -p "$(dirname "$bin")" "$(dirname "$stamp")" \
    && install -m 0755 "$target/release/crewspace" "$bin" \
    && grove_provision_5_26_crewspace_src_hash > "$stamp" || {
      echo "   💥 MalfunctionError: could not install $bin" >&2
      return 1
    }
  echo "   • binary installed: $bin"
}

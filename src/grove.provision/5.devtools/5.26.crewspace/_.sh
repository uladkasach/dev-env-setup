#!/usr/bin/env bash
######################################################################
# .what = crewspace — a wayland client that reads which COSMIC workspace each
#         window sits on, and moves a window to a named one in the background
#
# .why
#   - a workspace is a COMPOSITOR fact. no `/proc` field holds it, so the kitty
#     snapshot cannot read it from the process tree it walks
#   - on COSMIC the only reach is the compositor's own protocols:
#     `ext_foreign_toplevel_list` + `zcosmic_toplevel_info` to read, and
#     `zcosmic_toplevel_manager.move_to_ext_workspace` to move
#   - the snapshot calls `crewspace get --capture` beside its /proc walk, so a
#     crash map says which workspace each terminal was on
#
# .where it came from
#   - a copy of `uladkasach/nheuron`'s `skills/work/crewspace`, plus one
#     addition: `get --capture`, a read that prints data and writes no file
#   - it is to be lifted into a shared role, so both repos call one source.
#     until then this copy is the one this repo builds
#
# .why `--locked`, and no `rev` in `Cargo.toml`
#   - its one dependency is a git crate. `Cargo.lock` pins it to one commit, and
#     every build runs `--locked`, so a box builds the commit the repo pinned
#   - `Cargo.toml` is kept byte-equal to its origin, so the lift diffs clean
#
# .why `local@unix` alone
#   - it reads a desktop compositor. a grove has no session to read
#
# usage:
#   rhx grove.provision --what 5.26.crewspace --mode apply
#   crewspace get                 # every workspace and window, as a tree
#   crewspace get --capture       # the same view, as tab-separated data
######################################################################

grove_provision_5_26_crewspace_dir() { printf '%s' "$GROVE_SRC/grove.provision/5.devtools/5.26.crewspace"; }
grove_provision_5_26_crewspace_bin_at() { printf '%s/.local/bin/crewspace' "$HOME"; }
grove_provision_5_26_crewspace_stamp_at() { printf '%s/.local/share/grove/crewspace.src.sha256' "$HOME"; }

# .what = does this tier get crewspace? — and if not, say why
grove_provision_5_26_crewspace_applies() {
  [[ "${GROVE_ENV_SERVER:-}" == local@unix ]] && return 0
  echo "   🌙 declined — tier '${GROVE_ENV_SERVER:-<unset>}' has no desktop compositor to read"
  return 1
}

# .what = one hash over the crate's source — the binary is current iff its
#         stamp holds this hash
grove_provision_5_26_crewspace_src_hash() {
  local crate
  crate="$(grove_provision_5_26_crewspace_dir)/crewspace"
  cat "$crate/Cargo.toml" "$crate/Cargo.lock" "$crate/src/main.rs" 2>/dev/null | sha256sum | cut -d' ' -f1
}

grove_provision_5_26_crewspace() {
  bundle.upgrade 5.26.crewspace.provision.upsert
  bundle.upgrade 5.26.crewspace.provision.verify
}

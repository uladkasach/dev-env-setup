#!/usr/bin/env bash
######################################################################
# .what = neovim — the pinned binary, its parser compiler, and its config
#
#   - ONE bundle: split in two, neither half could state a claim about the other
#
# .it applies EVERYWHERE, grove included
#   - nvim runs ON the grove, so the grove needs the binary, parsers, and config
#   - ⚠️ imagemagick LOOKS local-only and is not
#   - an inline image is CONVERTED where nvim runs, and emits kitty graphics escapes
#   - those travel back over tmux `allow-passthrough` and ssh to the LOCAL kitty
#
# ⚠️ .this bundle installs NO tree-sitter-cli, though nvim needs it
#   - the crate needs cargo, and cargo arrives with `5.2.rust` in a later section
#   - a FIRST apply could never build it, and would tell a human to apply twice
#   - rust cannot move here, since a toolchain is no editor's child
#   - ⇒ the CONSUMER sits at `5.14.treesitter`, behind `5.2.rust`
#
# usage:
#   rhx grove.provision --what 4.5.nvim --mode apply
######################################################################

# .what = the fence markers this bundle owns inside the box's imagemagick policy, declared ONCE
GROVE_PROVISION_4_5_NVIM_POLICY_OPEN='<!-- grove: 4.5.nvim imagemagick rules — owned by dev-env-setup, never edit on the box -->'
GROVE_PROVISION_4_5_NVIM_POLICY_SHUT='<!-- grove: end 4.5.nvim -->'

# .what = the policy file this imagemagick build READS, by its own report
# .why  = measured 2026-11-15, im6 6.9.12: only `/etc/ImageMagick-6/policy.xml` is
#   read — a seat path, MAGICK_CONFIGURE_PATH, and <include> are all ignored. so ask
#   the tool, never assume: the first `Path:` that names a file
grove_provision_4_5_nvim_policy_path() {
  local im
  for im in identify magick convert; do
    command -v "$im" >/dev/null 2>&1 || continue
    "$im" -list policy 2>/dev/null | awk '/^Path: \// { print $2; exit }'
    return 0
  done
  return 1
}

# .what = the policy file imagemagick reads, printed only when it is readable;
#         exit 1 when the tool names none, or names one this seat cannot read
# .note = shared by configure.upsert (where to fence) and configure.verify (what to read)
grove_provision_4_5_nvim_policy_path_readable() {
  local path
  path="$(grove_provision_4_5_nvim_policy_path)" || return 1
  [[ -n "$path" && -r "$path" ]] || return 1
  printf '%s' "$path"
}

# .what = the policy file as it SHOULD read: the box's file, with this bundle's
#   rules fenced in right after `<policymap>`; a prior fence is replaced in place
# .why  = a TRANSFORMER — pure, so a play proves it with no root and no imagemagick.
#   every byte outside the fence is kept, so debian's own rules stand
# .note = rc 2 when the file holds no `<policymap>` line to anchor on
# .note = rc 3 when the fence is broken (a lone marker, or two fences): the skip would
#   run to EOF and drop `</policymap>`, so the render refuses rather than truncate
grove_provision_4_5_nvim_policy_render() {
  local cur="$1" src="$2" rules opens shuts
  rules="$(awk '/^<policymap>/{ f = 1; next } /^<\/policymap>/{ f = 0 } f && /^[[:space:]]*<policy /' "$src")"
  grep -q '^<policymap>' "$cur" || return 2
  opens="$(grep -cxF "$GROVE_PROVISION_4_5_NVIM_POLICY_OPEN" "$cur")"
  shuts="$(grep -cxF "$GROVE_PROVISION_4_5_NVIM_POLICY_SHUT" "$cur")"
  [[ "$opens" == "$shuts" && "$opens" -le 1 ]] || return 3
  awk -v o="$GROVE_PROVISION_4_5_NVIM_POLICY_OPEN" -v s="$GROVE_PROVISION_4_5_NVIM_POLICY_SHUT" -v r="$rules" '
    $0 == o { skip = 1; next }
    skip && $0 == s { skip = 0; next }
    skip { next }
    { print }
    /^<policymap>/ && !done { print o; print r; print s; done = 1 }
  ' "$cur"
}

grove_provision_4_5_nvim() {
  bundle.upgrade 4.5.nvim.provision.upsert
  bundle.upgrade 4.5.nvim.provision.verify
  bundle.upgrade 4.5.nvim.configure.upsert
  bundle.upgrade 4.5.nvim.configure.verify
}

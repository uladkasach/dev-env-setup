#!/usr/bin/env bash
######################################################################
# .what = put mikefarah/yq on this box at the version `_.sh` pins
#
# .the wire goes through `grove.web.sh`, never a bare curl
#   - `web_fetch` bounds the call, so a stalled fetch fails rather than holds
#     the duct (`rule.require.bounded-probes-in-verifies`)
#   - `web_verify_sha256` runs BEFORE the binary is ever made executable
#
# guarantee:
#   - idempotent: an extant binary AT THE PIN short-circuits
#   - the temp dir is removed on every exit path
######################################################################

grove_provision_5_17_yq_provision_upsert() {
  local version="$GROVE_YQ_VERSION"

  ####################################################################
  # .the pin, and the digest the REGISTRY states for it
  #
  # ⚠️ a registry digest is not a supply-chain proof
  #   - it catches a corrupt transfer, and a re-upload of the tag
  #   - it does NOT survive a github compromise, since the same party serves
  #     both the bytes and the digest
  #   - ⇒ it is the strongest check available where the publisher signs no
  #     release, and it is worth far more than no check
  #     (`rule.require.verify-binary-downloads`)
  ####################################################################
  local yq_sha256="sha256:c5f056448f973ae7d39b5401949648a78f2dc1947d6a8eb65be60d5c504b9385"
  local yq_url="https://github.com/mikefarah/yq/releases/download/v${version}/yq_linux_amd64"
  local dst="$HOME/.local/bin/yq"

  ####################################################################
  # 🛑 the guard reads the VERSION, never mere presence
  #   - a `yq` on this box may be apt's python wrapper, or an older go build
  #   - a presence guard would then skip forever and the pin would govern the
  #     FIRST apply and no other (`rule.require.one-command-provision`)
  #
  # ⚠️ `$dst`, never a bare `yq`
  #   - a bare name would answer whatever PATH holds, which is the very binary
  #     this bundle exists to replace
  ####################################################################
  if [[ -x "$dst" ]] && "$dst" --version 2>/dev/null | grep -F "$version" >/dev/null; then
    echo "   • yq $version already installed; skipped"
    return 0
  fi

  local tmp_dir
  tmp_dir="$(web_tempdir yq)" || return 1

  if ! web_fetch "$yq_url" --into "$tmp_dir/yq"; then
    echo "   ✋ could not fetch yq $version" >&2
    echo "      ⇒ the declapract cycles gate reads .dpdmrc.yaml through yq, so" >&2
    echo "        with none the --exclude collapses to an empty string, dpdm" >&2
    echo "        scans node_modules, and the gate reports cycles that do not" >&2
    echo "        exist — a false ✋ on every run" >&2
    echo "      read why: $yq_url" >&2
    rm -rf "$tmp_dir"
    return 1
  fi

  ####################################################################
  # 🛑 verify BEFORE chmod
  #   - a `chmod +x` on unverified bytes makes them runnable by any later step
  #   - the order is the control, so do not reorder these two lines
  ####################################################################
  if ! web_verify_sha256 --file "$tmp_dir/yq" --sha256 "$yq_sha256"; then
    echo "   ✋ the yq download did NOT match its declared digest" >&2
    echo "      ⇒ the bytes on disk are not the bytes the release states, so" >&2
    echo "        they are not made executable and are discarded" >&2
    echo "      ⇒ either the transfer corrupted, or the tag was re-uploaded" >&2
    rm -rf "$tmp_dir"
    return 1
  fi

  mkdir -p "$HOME/.local/bin" || { rm -rf "$tmp_dir"; return 1; }
  mv "$tmp_dir/yq" "$dst" || { rm -rf "$tmp_dir"; return 1; }
  chmod +x "$dst" || { rm -rf "$tmp_dir"; return 1; }
  rm -rf "$tmp_dir"

  echo "   • yq $version installed → $dst"
}

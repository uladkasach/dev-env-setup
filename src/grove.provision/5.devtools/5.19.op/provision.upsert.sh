#!/usr/bin/env bash
######################################################################
# .what = make `op` EXIST on this box — 1password's apt key, its repo, and
#         the `1password-cli` package
# .ref  = https://support.1password.com/install-linux/
#
# .the order below is load-bear, and the FIRST step is the one that matters
#   on a seat with no root:
#     1. is `op` already here?      → a camper on a converged grove stops here
#     2. may this seat write root?  → if not, it DECLINES and names ground
#     3. the key, verified before root ever parses it
#     4. the repo line, WRITTEN rather than findsert-guarded
#     5. the package
#
#   ⚠️ steps 3-5 all need root, and a grove's camper holds none. step 1 keeps
#   the common camper case off that path entirely — ground installs the
#   package, and the camper then finds it on PATH and converges with no write
#   (`term=seat`, `rule.require.seam-claims-have-an-owner`)
#
# ⚠️ .the repo line is WRITTEN, never findsert-guarded
#   a `[ -f …1password.list ] || …` freezes that file's CONTENT once it
#   exists, so a changed url, architecture, or `signed-by=` could never land.
#   it stops the repeat, and it also stops the converge
#
# .the key is scoped by `signed-by=`, never blanket-trusted
#   a key in `/etc/apt/trusted.gpg.d/` is trusted for EVERY repo apt reads,
#   so 1password's key could vouch for a package that claims to be debian
#
# guarantee:
#   - idempotent: an installed `op` short-circuits the apt call alone
#   - it declines rather than fails on a seat with no root
######################################################################

grove_provision_5_19_op_provision_upsert() {
  ####################################################################
  # 1. already here? then the key and repo are ground's to converge, and
  #    this seat owes no write at all
  #
  #   ⚠️ the check is `command -v`, because every caller reaches `op` by
  #     NAME — `src/backup_env.sh` and `src/util.yubikey.ssh.sh` both do.
  #     a dpkg query would report a package whose binary is unreachable
  ####################################################################
  if command -v op >/dev/null 2>&1; then
    echo "   • op ✔ (already installed)"
    ##################################################################
    # a seat with no root stops here rather than reach for the key it
    # cannot place. the verify still reads the repo and still reports
    ##################################################################
    pkg_can_sudo || return 0
  fi

  ####################################################################
  # 2. every write below lands OUTSIDE every $HOME, so it is root's
  ####################################################################
  bundle.root.owns "the 1password apt anchor and the op cli" \
    "want op from 1password's own repo" || return 0

  ####################################################################
  # 3. the key that verifies this repo, scoped to this repo alone
  #
  # 🛑 .the key lands as a FILE, never `web_fetch … | sudo gpg --dearmor`
  #   - a pipe moves the bytes wire → root with NO artifact to check between
  #   - ⚠️ note WHICH half runs as root in that pipe: `gpg` does
  #   - so an html error page or a hostile key is parsed by a root process
  #   - here the fetch and the parse are unprivileged, and root does one `dd`
  #   - (`rule.require.verify-binary-downloads`)
  #
  # .`gpg --dearmor` is owned by `2.1.toolkit`, which declares gnupg as a
  #   base tool for every apt-key bundle. it is NOT re-declared here:
  #   one fact, one writer
  ####################################################################
  if [[ ! -f "$GROVE_OP_KEYFILE" ]]; then
    local keytmp
    keytmp="$(web_tempdir onepasswordkey)" || return 1

    if ! web_fetch "$GROVE_OP_KEY_URL" --into "$keytmp/1password.asc"; then
      echo "   ✋ could not fetch the 1password repo key" >&2
      echo "      ⇒ apt refuses the repo as unverified, so op cannot install" >&2
      echo "        at all — and every caller that reaches it by name breaks" >&2
      echo "      ⇒ web_fetch named the wire fault above — a STALL wants a" >&2
      echo "        retry, and a 404 means the key url moved" >&2
      rm -rf "$keytmp"
      return 1
    fi

    # ⚠️ verify BEFORE the dearmor, and BEFORE root ever sees it. it also
    #   catches the failure a pipe could report only as silence: bytes that
    #   are not armored ascii parse as no key at all
    if ! web_verify_gpg_fingerprints --file "$keytmp/1password.asc" \
      --fpr "$GROVE_OP_KEY_FPR"; then
      echo "      ⇒ the key is NOT installed and the 1password repo is NOT" >&2
      echo "        declared. a box with no op beats a box whose apt trusts an" >&2
      echo "        anchor nobody vouched for" >&2
      rm -rf "$keytmp"
      return 1
    fi

    if ! gpg --dearmor --output "$keytmp/1password.gpg" "$keytmp/1password.asc"; then
      echo "   ✋ could not dearmor the 1password repo key" >&2
      echo "      ⇒ its fingerprint already matched the pin, so these ARE the" >&2
      echo "        expected bytes — this is gpg itself" >&2
      rm -rf "$keytmp"
      return 1
    fi

    if ! sudo dd if="$keytmp/1password.gpg" of="$GROVE_OP_KEYFILE" status=none; then
      echo "   ✋ could not place the verified key at $GROVE_OP_KEYFILE" >&2
      echo "      ⇒ the key verified, so this is the filesystem or sudo" >&2
      rm -rf "$keytmp"
      return 1
    fi
    rm -rf "$keytmp"
    sudo chmod 0644 "$GROVE_OP_KEYFILE"
    echo "   • 1password repo key verified against its pinned fingerprint ✔"
    echo "     scoped to the 1password repo alone"
  fi

  ####################################################################
  # 4. the repo — declared, so a re-run converges rather than freezes
  #
  #   ⚠️ the line comes from the ONE renderer in this bundle's `_.sh`, which
  #     the verify also reads. a second copy here would drift from it
  ####################################################################
  local line
  line="$(grove_provision_5_19_op_repo_line)" || {
    echo "   ✋ could not read this box's dpkg architecture" >&2
    echo "      ⇒ the apt line names an arch, so it cannot be written blind" >&2
    return 1
  }
  echo "$line" | sudo tee /etc/apt/sources.list.d/1password.list >/dev/null || return 1

  ####################################################################
  # 5. the package — reached only when `op` is absent, since step 1 returns
  #    early on a box that already carries it
  ####################################################################
  if command -v op >/dev/null 2>&1; then
    echo "   • op present; key and repo converged"
    return 0
  fi

  # the repo may have just landed, so the index must be re-read before apt
  # can see it
  pkg_refresh || true

  pkg_install 1password-cli || {
    echo "   ✋ the op cli did not install" >&2
    echo "      ⇒ src/backup_env.sh and src/util.yubikey.ssh.sh each call it by" >&2
    echo "        name, and each fails at the line that reaches for a secret" >&2
    echo "      read why: sudo apt-get install 1password-cli" >&2
    return 1
  }

  echo "   • installed: 1password-cli (op)"
}

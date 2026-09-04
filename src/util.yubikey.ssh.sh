#!/bin/bash
#########################
## yubikey SSH key utilities
##
## set_sshkey_into_yubikey --from op://vault/doc        # load key from 1password onto yubikey
## set_sshkey_into_yubikey --from /path/to/key.pem      # load local key onto yubikey (backs up to 1password)
## get_sshkey_from_yubikey                              # print public key from yubikey
## get_sshkey_from_yubikey --into ~/.ssh                # write to ~/.ssh/yubikey.pub
## get_sshkey_from_yubikey --into ~/.ssh --name work    # write to ~/.ssh/work.pub
##
## security: set_sshkey_into_yubikey enforces PIN setup (prompts if default)
##           each SSH auth requires PIN + touch
##
## ref: https://developers.yubico.com/PIV/Guides/SSH_with_PIV_and_PKCS11.html
#########################

get_sshkey_from_yubikey() {
  set -euo pipefail

  local output=""
  local key_name="yubikey"

  # parse args
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --into)
        output="$2"
        shift 2
        ;;
      --name)
        key_name="$2"
        shift 2
        ;;
      *)
        echo "error: unknown argument: $1"
        echo "usage: get_sshkey_from_yubikey [--into ~/.ssh] [--name keyname]"
        return 1
        ;;
    esac
  done

  # check yubikey-agent is available
  if [[ -z "${SSH_AUTH_SOCK:-}" ]] || [[ ! -S "${SSH_AUTH_SOCK}" ]]; then
    echo "error: SSH_AUTH_SOCK not set or not a socket"
    echo "ensure yubikey-agent is active: systemctl --user status yubikey-agent"
    return 1
  fi

  # get public key
  local pubkey
  pubkey=$(ssh-add -L 2>/dev/null | head -n1)

  if [[ -z "$pubkey" ]]; then
    echo "error: no SSH key found on YubiKey"
    echo "load a key first: set_sshkey_into_yubikey --from <key>"
    return 1
  fi

  if [[ -n "$output" ]]; then
    mkdir -p "$output"
    local pubkey_path="${output}/${key_name}.pub"
    echo "$pubkey" > "$pubkey_path"
    chmod 644 "$pubkey_path"
    echo "wrote: $pubkey_path"
  else
    echo "$pubkey"
  fi
}

set_sshkey_into_yubikey() {
  set -euo pipefail

  local source=""
  local key_name=""

  # parse args
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --from)
        source="$2"
        shift 2
        ;;
      --name)
        key_name="$2"
        shift 2
        ;;
      *)
        echo "error: unknown argument: $1"
        echo "usage: set_sshkey_into_yubikey --from <path|op://uri> [--name <key-name>]"
        return 1
        ;;
    esac
  done

  # require --from
  if [[ -z "$source" ]]; then
    echo "error: --from is required"
    echo ""
    echo "usage:"
    echo "  set_sshkey_into_yubikey --from op://Private/my-key      # from 1password"
    echo "  set_sshkey_into_yubikey --from ~/.ssh/key.pem           # from local file"
    echo "  set_sshkey_into_yubikey --from ~/.ssh/key.pem --name my-key"
    return 1
  fi

  ####################################################################
  # 🛑 the key lands in a PRIVATE dir, never at a predictable /tmp path
  #
  #    a `/tmp/yubikey-import-$$.pem` puts the highest value asset this repo
  #    ever writes to disk — an unencrypted ssh private key — at a guessable
  #    path in a 1777 dir. two costs:
  #
  #      the `>` and the `cp` CREATE the file, and only the next line chmods it.
  #      so the key is world-readable for that window, at a path any local uid
  #      can watch for.
  #
  #      worse, a symlink pre-planted at `/tmp/yubikey-import-<pid>.pem` sends
  #      the key wherever the squatter aims — and `shred -u` then destroys the
  #      SYMLINK and leaves their copy intact, so the cleanup reports success
  #      over a key that was successfully stolen.
  #
  # .why a private DIR rather than a chmod-first file
  #      `mktemp -d` makes the directory 0700 before it exists to anyone else,
  #      so there is no window and no path to pre-plant — the containment is
  #      structural rather than a race this code has to win
  #      (`rule.require.solve-at-cause`). it is the same idiom `web_tempdir`
  #      already uses for every wire fetch in `src/grove.web.sh`.
  ####################################################################
  local tmp_dir tmp_key
  tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/yubikey-import.XXXXXXXX")" || {
    echo "error: could not make a private temp dir for the key"; return 1; }
  chmod 700 "$tmp_dir"
  tmp_key="$tmp_dir/key.pem"

  # ⚠️ the dir goes on EVERY exit path — a failed ykman import too. a plain
  #    last line would leave an unencrypted key behind whenever the import
  #    broke, which is the one run where a human stops to read the error
  trap 'shred -u "$tmp_key" 2>/dev/null; rm -rf "$tmp_dir"' RETURN

  local should_backup=false

  # check dependencies
  command -v ykman &> /dev/null || { echo "error: ykman not found. run install_yubikey_agent first"; return 1; }
  command -v op &> /dev/null || { echo "error: 1password CLI not found"; return 1; }

  # check yubikey connected
  ykman info &> /dev/null || { echo "error: no YubiKey detected"; return 1; }

  # check 1password signed in
  op whoami &> /dev/null || { echo "error: not signed in to 1password. run 'op signin' first"; return 1; }

  # ensure PIV PIN is configured (not default)
  echo "check PIV PIN..."
  if ykman piv access verify-pin --pin 123456 &>/dev/null; then
    echo "PIV PIN is still default (123456). set a new PIN for security."
    echo ""

    ####################################################################
    # 🛑 .the new PIN is NEVER held in a variable, and never reaches argv
    #
    # `--pin 123456` is the PUBLISHED PIV default and is not a secret, so it
    # stays a flag. the NEW pin is a secret, and argv is world-readable at
    # `/proc/<pid>/cmdline` for the life of the call — the exact hazard
    # `plan.grove-credentials.md` states as a rule:
    #
    #   "never pass a secret in argv. argv is visible in `ps` to any user."
    #
    # ⚠️ a `read -sp` upstream does NOT save it. an unechoed read keeps the
    #    pin off the SCREEN; the leak is the execve one line later. this file
    #    already argued at length about key material at rest and walked past
    #    its own twin two lines above — one hazard named in detail reads as a
    #    guard against THE hazard
    #    (`inventory.security-checks.md`, `.a guard that names one hazard`).
    #
    # ⇒ so ykman prompts for it directly. ykman asks twice, confirms the
    #   match, and enforces the 6-8 digit policy itself — so the hand-rolled
    #   read + confirm + length check it replaced were a second holder of a
    #   rule ykman already owns (m.9), and the copy is what leaked.
    ####################################################################
    ykman piv access change-pin --pin 123456 || {
      echo "error: PIN not changed"
      return 1
    }
    echo "PIN updated."
  else
    echo "PIN already configured (not default)."
  fi

  # determine source type
  if [[ "$source" == op://* ]]; then
    # op:// URI: fetch from 1password
    key_name="${key_name:-$(basename "$source")}"
    echo "fetch from 1password: $source"
    op read "$source" > "$tmp_key"
    chmod 600 "$tmp_key"
    should_backup=false

  elif [[ -f "$source" ]]; then
    # local file: use as-is, backup to 1password
    key_name="${key_name:-$(basename "$source" .pem)}"
    echo "use local key: $source"
    cp "$source" "$tmp_key"
    chmod 600 "$tmp_key"
    should_backup=true

  else
    echo "error: source not found: $source"
    return 1
  fi

  # backup to 1password if needed
  if [[ "$should_backup" == true ]]; then
    echo "backup to 1password..."
    op document create "$tmp_key" --title "$key_name" --tags "ssh,yubikey,backup"
    echo "saved as document: $key_name"
  fi

  echo "load key onto YubiKey PIV slot 9a..."
  ykman piv keys import 9a "$tmp_key"

  echo "generate self-signed certificate..."
  ykman piv certificates generate -s "$key_name" 9a -

  # ⚠️ the RETURN trap above shreds it too, so this line is the ANNOUNCEMENT and
  #    the trap is the guarantee. `shred -u` is idempotent enough (an absent
  #    file is a no-op), and the trap is what covers the paths that never reach
  #    this line at all
  echo "delete local key..."
  shred -u "$tmp_key" 2>/dev/null

  echo ""
  echo "done. public key:"
  ssh-add -L

  echo ""
  echo "add this public key to GitHub, servers, etc."
  echo ""
  echo "each SSH auth now requires: PIN + touch"
  echo ""
  echo "to load same key onto another YubiKey:"
  echo "  set_sshkey_into_yubikey --from 'op://Private/$key_name'"
}

# if executed directly (not sourced), dispatch based on command name
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  case "$(basename "$0" .sh)" in
    get_sshkey_from_yubikey)
      get_sshkey_from_yubikey "$@"
      ;;
    set_sshkey_into_yubikey|util.yubikey.ssh)
      set_sshkey_into_yubikey "$@"
      ;;
    *)
      echo "unknown invocation: $(basename "$0")"
      echo "use: set_sshkey_into_yubikey or get_sshkey_from_yubikey"
      exit 1
      ;;
  esac
fi

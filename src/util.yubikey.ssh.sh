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

  local tmp_key="/tmp/yubikey-import-$$.pem"
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
    read -sp "enter new PIN (6-8 digits): " new_pin
    echo ""
    read -sp "confirm new PIN: " confirm_pin
    echo ""

    if [[ "$new_pin" != "$confirm_pin" ]]; then
      echo "error: PINs do not match"
      return 1
    fi

    if [[ ${#new_pin} -lt 6 ]] || [[ ${#new_pin} -gt 8 ]]; then
      echo "error: PIN must be 6-8 digits"
      return 1
    fi

    ykman piv access change-pin --pin 123456 --new-pin "$new_pin"
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

  echo "delete local key..."
  shred -u "$tmp_key"

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

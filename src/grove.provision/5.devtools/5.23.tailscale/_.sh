#!/usr/bin/env bash
######################################################################
# .what = tailscale on every machine — the client, its daemon, and the join
#         check
#
# .why
#   - `local@unix` joins here, as a member: the human's own login, by a url
#     he opens. shields-up, always: a laptop reaches out and is never reached in
#   - `cloud@*` gets tailscale installed and joined as `tag:camp` by its
#     provisioner, at machine build. this bundle makes NO TAILSCALE WRITE there: it
#     verifies the client, the daemon, and the join, and fails fast with the
#     provisioner named (`define.invariant.grove-tailscale-has-one-owner`)
#   - a joined node takes no second `up` (kb 1241: flags are not persisted)
#   - the argument: `.behavior/v2026_10_25.feat-tailscale-on-every-machine/`
#
# usage:
#   sudo -v && rhx grove.provision --what 5.23.tailscale --mode apply
######################################################################

# .what = the key file and the apt source, at the paths tailscale's own docs use
grove_provision_5_23_tailscale_keydst() { printf '/usr/share/keyrings/tailscale-archive-keyring.gpg'; }
grove_provision_5_23_tailscale_listdst() { printf '/etc/apt/sources.list.d/tailscale.list'; }

# .what = the pinned primary fingerprint of tailscale's package repository key
# .the pin, and where it came from — TIER 3: one read, one source
#   - keyserver.ubuntu.com index for info@tailscale.com, read 2026-10-26:
#     tailscale's package repository key, rsa4096, created 2020-02-25
#   - no second independent channel was read. the served `<codename>.noarmor.gpg`
#     is the artifact checked AGAINST this pin, so it corroborates naught
#   - the pin still binds: `web_verify_gpg_fingerprints` compares the served key on
#     every install, and a mismatch installs no byte
#     (`rule.require.verify-binary-downloads`). a second channel raises the tier
grove_provision_5_23_tailscale_fpr() { printf '2596A99EAAB33821893C0A79458CA832957F5868'; }

# .what = the ubuntu codename the repo path keys on
# .why UBUNTU_CODENAME and never ID — pop-os reports `ID=pop`, and tailscale
#   publishes no `pop` path; its ubuntu base is what the package was built for
grove_provision_5_23_tailscale_codename() {
  local c=""
  c="$(. /etc/os-release 2>/dev/null && printf '%s' "${UBUNTU_CODENAME:-}")"
  [[ -n "$c" ]] || return 1
  printf '%s' "$c"
}

# .what = the apt line this bundle writes, for THIS box's codename
# .why  = ONE renderer: the upsert writes this text and both phases compare it
#   whole, so a commented-out line (a release upgrade disables third-party
#   sources) or a stale codename reads as absent, never as "declared"
grove_provision_5_23_tailscale_list_line() {
  local c
  c="$(grove_provision_5_23_tailscale_codename)" || return 1
  printf 'deb [signed-by=%s] https://pkgs.tailscale.com/stable/ubuntu %s main' \
    "$(grove_provision_5_23_tailscale_keydst)" "$c"
}

# .what = whether the declared source is THIS bundle's: the exact line, and a
#         key file whose primaries are the pinned ones
# .why  = a key file present is no claim about which key it holds; apt trusts
#   every package against it, so a swapped anchor is every future install
grove_provision_5_23_tailscale_source_ok() {
  local want keydst
  keydst="$(grove_provision_5_23_tailscale_keydst)"
  want="$(grove_provision_5_23_tailscale_list_line)" || return 1
  [[ -s "$keydst" ]] || return 1
  grep -qxF "$want" "$(grove_provision_5_23_tailscale_listdst)" 2>/dev/null || return 1
  web_verify_gpg_fingerprints --file "$keydst" \
    --fpr "$(grove_provision_5_23_tailscale_fpr)" >/dev/null 2>&1
}

# .what = the tag every remote grove is joined as
grove_provision_5_23_tailscale_tag() { printf 'tag:camp'; }

# .what = the provisioner's step a grove off the tailnet is owed
# .why  = the join is theirs; a verify that finds none names who acts
grove_provision_5_23_tailscale_provisioner_say() {
  echo "      ⇒ a grove's join is its provisioner's (ahbode/infrastructure):"
  echo "          rhx tailscale.authkey.mint --grove <this grove> --mode apply"
  echo "        then the provision path's join, as root, with --advertise-tags=$(grove_provision_5_23_tailscale_tag)"
}

# .what = how a joined node that was taken down (`Stopped`) comes back
# .why  = `tailscale up` refuses a bare call once a non-default pref is set, and
#   names the flags it wants; a laptop here always carries `--shields-up`, so the
#   restore repeats it. a grove's node is its provisioner's, so a human `up` there
#   would rejoin it without its tag — the restore is theirs
grove_provision_5_23_tailscale_restore_say() {
  if [[ "${GROVE_ENV_SERVER:-}" == cloud@* ]]; then
    printf "its provisioner's join, as root, with --advertise-tags=%s" "$(grove_provision_5_23_tailscale_tag)"
    return 0
  fi
  printf 'sudo tailscale up --shields-up'
}

# .what = the line a human runs to converge this bundle, on any tier
# .why `sudo -v &&` leads: on a laptop it asks the password in the human's own
#   terminal (`gotcha.rhx-runs-a-skill-with-no-tty`); where sudo needs none, it
#   passes silently
grove_provision_5_23_tailscale_rerun() {
  printf 'sudo -v && rhx grove.provision --what 5.23.tailscale --mode apply'
}

# .what = `tailscale status --json`, or naught — the one read every phase asks
# .why bounded: a wedged daemon must not stall a whole run
#   (`rule.require.bounded-probes-in-verifies`)
grove_provision_5_23_tailscale_status() {
  timeout 10 tailscale status --json 2>/dev/null
}

# .what = the daemon's state — `Running`, `NeedsLogin`, `Stopped`, … — or `?`
# .why three-valued: a read that FAILED must never read as "not joined", or a
#   joined node with a busy socket would be sent a second `up`
grove_provision_5_23_tailscale_state() {
  local js
  js="$(grove_provision_5_23_tailscale_status)" || { printf '?'; return 0; }
  printf '%s' "$(printf '%s' "$js" | jq -r '.BackendState // "?"' 2>/dev/null || printf '?')"
}

# .what = whether this node refuses all inbound tailnet traffic — `up`, `down`, or `?`
# .why  = a laptop needs no inbound: shields-up keeps it one-way whatever the
#   tailnet's acl says, and whatever happens to listen on the laptop. three-valued,
#   so a read that FAILED never reads as either answer
grove_provision_5_23_tailscale_shields() {
  local js
  js="$(timeout 10 tailscale debug prefs 2>/dev/null)" || { printf '?'; return 0; }
  printf '%s' "$(printf '%s' "$js" | jq -r \
    'if .ShieldsUp == true then "up" elif .ShieldsUp == false then "down" else "?" end' \
    2>/dev/null || printf '?')"
}

grove_provision_5_23_tailscale() {
  bundle.upgrade 5.23.tailscale.provision.upsert
  bundle.upgrade 5.23.tailscale.provision.verify
  bundle.upgrade 5.23.tailscale.configure.upsert
  bundle.upgrade 5.23.tailscale.configure.verify
}

#!/usr/bin/env bash
# .what = install the aws cli v2 and the ssm session-manager plugin
# .ref  = https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
# .ref  = https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html
# .why
#   - neither goes through `pkg_install` — debian ships awscli v1, a
#     different tool, and aws publishes the ssm plugin as a bare .deb, in
#     no distro repo at all; the package boundary installs NAMES
#   - `apt-get install ./plugin.deb`, never `dpkg -i`, which leaves the
#     dependencies unmet and trips the NEXT install
#   - .refs = gotcha.5-6-aws-cli-two-readers.demo=v1-debian-package,
#     gotcha.5-6-aws-pins.demo=tier-evidence
#
# guarantee:
#   - both installs short-circuit when the binary already resolves

grove_provision_5_6_aws_provision_upsert() {
  pkg_assert_apt || return 1

  # 1. the cli — the question is whether aws on PATH is v2 AT THE DECLARED
  # VERSION, never merely "is there an aws"; `unknown` (no answer in 20s) is
  # treated as done, since installing over it would re-download 60MB per
  # slow box (.refs = gotcha.5-6-aws-cli-two-readers.demo=v1-debian-package)
  local cli_state; cli_state="$(grove_provision_5_6_aws_cli_state)"

  if [[ "$cli_state" == whole || "$cli_state" == unknown ]]; then
    echo "   • aws cli already at the declared version; skipped ($cli_state)"
  elif ! bundle.root.owns "the aws cli" "aws is '$cli_state' on this box"; then
    # the decline is its OWN branch, never `|| return 0` — a return would
    # skip section 2, a separate fact with its own read
    :
  else
    # the root guard sits in this branch, not at the function top, so a box
    # that already holds both halves spends no root

    # a PRIVATE temp dir — the installer runs under `sudo`, and a fixed
    # `/tmp/aws-cli-install` in a shared 1777 dir lets `sudo … install`
    # execute whichever seat won that name first
    local tmp_dir
    tmp_dir="$(web_tempdir aws-cli)" || return 1

    # the url names a VERSION, never always-latest — an always-latest url
    # forecloses verification, since it names no artifact to pin
    local awscli_version="$GROVE_UPGRADE_5_6_AWS_CLI_AT"
    local awscli_url="https://awscli.amazonaws.com/awscli-exe-linux-x86_64-${awscli_version}.zip"

    # `--within` is raised — this is the tree's LARGEST fetch at ~60MB
    if ! web_fetch "$awscli_url" \
      --into "$tmp_dir/awscliv2.zip" --within 1800; then
      echo "   ✋ could not fetch the aws cli installer" >&2
      echo "      ⇒ with no aws cli, no grove can be woken — git.grove.wake" >&2
      echo "        opens its tunnel through 'aws ssm start-session'" >&2
      rm -rf "$tmp_dir"
      return 1
    fi

    if ! web_fetch "${awscli_url}.sig" --into "$tmp_dir/awscliv2.sig"; then
      echo "   ✋ could not fetch the aws cli installer's signature" >&2
      echo "      ⇒ the zip is discarded UNOPENED. an unverifiable installer" >&2
      echo "        would run as root, having proven not one fact about its bytes" >&2
      rm -rf "$tmp_dir"
      return 1
    fi

    # a SIGNATURE here, not a sha256, since it verifies whatever aws signs
    # at any version; the key is TIER 1 (.refs = gotcha.5-6-aws-pins.demo=tier-evidence).
    # the key expires 2027-07-01, and a rotation fails this check LOUD
    if ! web_verify_gpg_signature \
      --file "$tmp_dir/awscliv2.zip" \
      --sig  "$tmp_dir/awscliv2.sig" \
      --key  "$GROVE_SRC/grove.provision/5.devtools/5.6.aws/aws-cli-team.pgp" \
      --fpr  FB5DB77FD5C118B80511ADA8A6310ACC4672475C; then
      echo "      ⇒ the aws cli is NOT installed. the next line would have run" >&2
      echo "        '$ sudo <unpacked>/install' — an unverified payload, as root" >&2
      rm -rf "$tmp_dir"
      return 1
    fi
    echo "   • aws cli ${awscli_version} verified against aws's signer key ✔"

    # extract only AFTER the signature holds — an unverified zip would
    # decide what root runs next (rule.require.verify-binary-downloads)
    if ! unzip -q "$tmp_dir/awscliv2.zip" -d "$tmp_dir"; then
      echo "   ✋ could not extract the aws cli installer" >&2
      echo "      ⇒ unzip may be absent; a fresh ubuntu image ships none" >&2
      rm -rf "$tmp_dir"
      return 1
    fi

    # `--update` is passed only when an aws is ALREADY here — without it
    # the installer refuses to overwrite an extant install
    local install_args=()
    [[ "$cli_state" == absent ]] || install_args+=(--update)

    if ! sudo "$tmp_dir/aws/install" "${install_args[@]}"; then
      echo "   ✋ the aws cli installer failed" >&2
      rm -rf "$tmp_dir"
      return 1
    fi
    rm -rf "$tmp_dir"

    # the install is RE-READ, since the installer writes /usr/local/bin/aws
    # and a box whose PATH a human ordered by hand may still shadow it —
    # this bundle did not create that state and may not undo it
    cli_state="$(grove_provision_5_6_aws_cli_state)"
    if [[ "$cli_state" == whole || "$cli_state" == unknown ]]; then
      echo "   • aws cli ${awscli_version} installed ($cli_state)"
    else
      echo "   ✋ the installer ran, and the aws on PATH is still '$cli_state'" >&2
      echo "      ⇒ v2 landed at /usr/local/bin/aws. another aws earlier on PATH" >&2
      echo "        shadows it — debian's 'awscli' package (v1) is the usual one" >&2
      echo "      read why: type -a aws ; echo \"\$PATH\"" >&2
      return 1
    fi
  fi

  # 2. the ssm plugin the cli execs
  if command -v session-manager-plugin >/dev/null 2>&1; then
    echo "   • ssm plugin already installed; skipped"
    return 0
  fi

  bundle.root.owns "the ssm plugin" "session-manager-plugin is absent" || return 0

  # the url names a VERSION where aws's own docs give only /latest/, and the
  # pin is what makes the signature below expressible
  # (.refs = gotcha.5-6-aws-pins.demo=tier-evidence)
  local ssm_version="1.2.835.0"
  local url="https://s3.amazonaws.com/session-manager-downloads/plugin/${ssm_version}/ubuntu_64bit/session-manager-plugin.deb"

  # a PRIVATE temp dir — a .deb's preinst/postinst run AS ROOT
  local tmp_dir
  tmp_dir="$(web_tempdir ssm-plugin)" || return 1
  local tmp_pkg="$tmp_dir/session-manager-plugin.deb"

  if ! web_fetch "$url" --into "$tmp_pkg"; then
    echo "   ✋ could not install the ssm plugin from $url" >&2
    echo "      ⇒ 'aws ssm start-session' then fails with 'SessionManagerPlugin" >&2
    echo "        is not found', so no grove tunnel can open" >&2
    rm -rf "$tmp_dir"
    return 1
  fi

  # the signature is TIER 2, a DIFFERENT key from the cli's
  # (.refs = gotcha.5-6-aws-pins.demo=tier-evidence)
  if ! web_fetch "${url}.sig" --into "$tmp_dir/plugin.sig"; then
    echo "   ✋ could not fetch the ssm plugin's signature" >&2
    echo "      ⇒ the .deb is discarded UNINSTALLED. a .deb's maintainer" >&2
    echo "        procedures run as ROOT, so an unverified package is not a" >&2
    echo "        lesser install — it is arbitrary root code" >&2
    rm -rf "$tmp_dir"
    return 1
  fi

  if ! web_verify_gpg_signature \
    --file "$tmp_pkg" \
    --sig  "$tmp_dir/plugin.sig" \
    --key  "$GROVE_SRC/grove.provision/5.devtools/5.6.aws/ssm-plugin-signer.pgp" \
    --fpr  7959637124CE093AD501D47A2C4D4AFF6F6757EE; then
    echo "      ⇒ the ssm plugin is NOT installed. that is the safe outcome —" >&2
    echo "        a box with no grove tunnel beats a box that ran an unverified" >&2
    echo "        package's preinst as root" >&2
    rm -rf "$tmp_dir"
    return 1
  fi
  echo "   • ssm plugin ${ssm_version} verified against aws's release key ✔"

  # apt may print "Download is performed unsandboxed as root" here —
  # EXPECTED, the cost of the 0700 dir above. do NOT widen it to silence it
  local rc=0
  pkg_apt apt-get install -y "$tmp_pkg" || rc=$?
  rm -rf "$tmp_dir"

  if (( rc != 0 )); then
    echo "   ✋ the ssm plugin package would not install (see the error above)" >&2
    return 1
  fi

  echo "   • ssm plugin installed ✔"
}

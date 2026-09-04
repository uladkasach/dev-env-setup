#!/usr/bin/env bash
# .what = the aws cli, and the ssm session-manager plugin it shells out to
# .why
#   - the plugin rides in THIS bundle: a human never invokes it, only the
#     cli, which fails "not found" when it is absent
#   - every grove here is REACHED through ssm, so a grove needs the cli to
#     reach the NEXT grove, a laptop the first
#   - configure names the `ambient` profile — without it a grove holds an
#     identity no consumer can address
#
# usage:
#   rhx grove.provision --what 5.6.aws --mode apply

# .what = the aws cli version this repo installs, declared ONCE
# .why the upsert and the state reader both compare against it; two
#   declarations of one fact are free to drift (rule.require.bundle-as-sole-declaration)
GROVE_UPGRADE_5_6_AWS_CLI_AT="2.36.23"

# .what = which of FOUR states is this box's `aws` in?
#   `..._cli_state` → whole | adrift | wrong | absent | unknown
# .why
#   - ONE reader, asked by BOTH halves — debian's v1 `awscli` answers
#     `command -v` but fails an `aws-cli/2.*` match, two readers would disagree
#   - the read is BOUNDED — the v2 cli unpacks a bundled python runtime
#     before its first byte, and this runs on every plan
#   - .refs = gotcha.5-6-aws-cli-two-readers.demo=v1-debian-package
#
# stdout: whole = declared version; adrift = other v2; wrong = v1;
#   absent = no aws on PATH; unknown = no answer within the bound
grove_provision_5_6_aws_cli_state() {
  command -v aws >/dev/null 2>&1 || { echo absent; return 0; }

  local ver
  ver="$(timeout -k 5 20 aws --version 2>&1 | head -1)"

  [[ -n "$ver" ]]             || { echo unknown; return 0; }
  [[ "$ver" == aws-cli/2.* ]] || { echo wrong; return 0; }

  # the banner reads `aws-cli/2.36.23 Python/… Linux/…`, matched with the
  # space after the version so `2.36.2` cannot read as `2.36.23`
  [[ "$ver" == "aws-cli/$GROVE_UPGRADE_5_6_AWS_CLI_AT "* ]] || { echo adrift; return 0; }

  echo whole
}

grove_provision_5_6_aws() {
  bundle.upgrade 5.6.aws.provision.upsert
  bundle.upgrade 5.6.aws.provision.verify
  bundle.upgrade 5.6.aws.configure.upsert
  bundle.upgrade 5.6.aws.configure.verify
}

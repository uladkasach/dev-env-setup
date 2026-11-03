#!/usr/bin/env bash
######################################################################
# .what = the `gh` binary, and a credential for it to hold
#
# .why  = the binary and the auth are separate phases
#   - provision lands the binary on every machine, headless ones too
#   - configure gives it a credential by whichever means the machine has
#   - only the auth needs a human; one function once conflated them, so a grove got neither
#   - identical on every machine (`rule.require.identical-bundle-composition`)
######################################################################

# .what = the vault this box's github token lives in: ec2 → aws.params, else os.secure
# .why  = the vault follows the platform (`rule.forbid.aws-params-off-ec2`); one
#   function, so the upsert's fix-text and the verify's never name two vaults
grove_provision_5_4_gh_keyrack_vault() {
  [[ "$GROVE_ENV_SERVER" == *@aws.ec2 ]] && { printf 'aws.params'; return 0; }
  printf 'os.secure'
}

grove_provision_5_4_gh() {
  bundle.upgrade 5.4.gh.provision.upsert
  bundle.upgrade 5.4.gh.provision.verify
  bundle.upgrade 5.4.gh.configure.upsert
  bundle.upgrade 5.4.gh.configure.verify
}

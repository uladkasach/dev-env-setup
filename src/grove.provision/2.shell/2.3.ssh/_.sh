#!/usr/bin/env bash
######################################################################
# .what = the ssh client and daemon, plus a keypair for this box's own identity
#
# .why the KEY is a configure phase and not a provision one
#   - the package either exists or does not
#   - a keypair is this box's declared IDENTITY, the shape it presents to a remote
#   - an apt miss and a refused key are repaired by different acts
#   - ⇒ they carry separate verdicts
#
# .why this bundle applies to a HEADLESS box most of all
#   - a grove IS reached over ssh
#   - the daemon is how the duct exists at all
#   - the client is how the grove reaches github and its peers
#
# .note = the human's own auth keys live on a yubikey, not in this bundle
#   - see `util.yubikey.ssh.sh` and `plan.grove-credentials.md`
#   - this bundle declares the BOX's own keypair
#   - that is the one an unattended clone or a box-to-box hop presents
#   - 📜 to merge the two is how a grove got asked for a hardware touch it cannot give
######################################################################

grove_provision_2_3_ssh() {
  bundle.upgrade 2.3.ssh.provision.upsert
  bundle.upgrade 2.3.ssh.provision.verify
  bundle.upgrade 2.3.ssh.configure.upsert
  bundle.upgrade 2.3.ssh.configure.verify
}

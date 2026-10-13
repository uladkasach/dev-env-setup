#!/usr/bin/env bash
######################################################################
# .what = yubikey-agent — an ssh-agent backed by the YubiKey's PIV applet
# .ref  = https://github.com/FiloSottile/yubikey-agent
#
# ⚠️ this bundle recovers DEAD CODE, the worst instance found
#   - yubikey-agent's install was a function no driver reached, so it ran nowhere
#   - `util.yubikey.ssh.sh` told a human to call that function FIRST, by hand
#
# 🛑 a phase may NEVER append an export to `2.7.aliases`'s `bash_aliases.sh`
#   - that writes machine → repo, where it must be repo → machine
#   - its path is a hardcoded main checkout, so a WORKTREE run edits main's file
#   - (`rule.require.repo-as-source-of-truth`)
#
# ⚠️ the agent is NOT a shell's default. SSH_AUTH_SOCK keeps the desktop agent,
#    which holds file keys; yubikey-agent refuses them, so as the default it made
#    every file-key connection ask for a passphrase. a host that wants the
#    YubiKey names this agent's socket per call (`2.7.aliases` states why)
#
# .it applies ONLY where a human is
#   - a YubiKey is a physical object a human touches to authorize
#   - ⇒ on a headless grove the agent guards a key nobody can ever tap
#
# usage:
#   rhx grove.provision --what 5.9.yubikey --mode apply
######################################################################

grove_provision_5_9_yubikey() {
  bundle.upgrade 5.9.yubikey.provision.upsert
  bundle.upgrade 5.9.yubikey.provision.verify
}

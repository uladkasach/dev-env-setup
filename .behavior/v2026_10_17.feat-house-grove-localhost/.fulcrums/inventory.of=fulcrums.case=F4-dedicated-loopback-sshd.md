# F4 — reach: a dedicated loopback sshd unit

## .the fork
- **A** unmask `ssh.service` on a host with house groves, loopback-only via a drop-in
- **B** a separate unit (`grove-house-sshd.service`) with its own config: `ListenAddress
  127.0.0.1`, its own port, `AllowUsers` the house seats only, `PasswordAuthentication no`
- **C** no sshd — reach the seat via `sudo -u` / `machinectl shell`

## .taken: B, and why at the time
- `2.3.ssh` masks `ssh.service` on every `local@*` box and its verify fails unless it stays
  masked — the 2026-09-03 redteam fix after a password port opened on the laptop
  (`gotcha.2-3-ssh.demo=tier-split-and-mask.md`). B leaves the mask intact
- A re-opens the exact unit the incident closed; one drop-in error re-exposes 0.0.0.0:22
- C hands the supervisor's uid a sudo path into the seat, which is the custody the seat split
  exists to withhold; and every `git.grove.*` verb already speaks ssh

## 🔴 .what B costs that the first draft did not see — found at `has-questioned-assumptions`

the draft assumed the laptop holds an `sshd` binary. it does not:
`2.3.ssh/provision.upsert.sh:31-35` installs `openssh-client` ONLY on every tier but `cloud@*`,
and its verify (`provision.verify.sh:86-89`) states *"this tier asks for openssh-client only; a
listener is the defect"*. so B owes three things on the host bundle, in this order:

1. **mask `ssh.service` AND `ssh.socket` BEFORE the package lands.** the server's postinst
   enables what it installs — the incident's own mechanism — and on recent ubuntu the server
   listens through socket activation, which `2.3.ssh` does not mask today. debian accepts a mask
   on a unit not yet present, so the order is safe
2. **install `openssh-server`** for its binary only
3. **run `grove-house-sshd.service`** with `-f` pointed at its own config; `/etc/ssh/sshd_config`
   is never read by it and never edited

and `2.3.ssh`'s verify widens, not loosens: on `local@*`, the daemon binary is permitted ONLY
while a house grove is declared, and the one permitted listener is the house unit on
`127.0.0.1`. `ss -tln` with any `:22`, or any non-loopback bind, stays ✋.

## .rework
clean — the unit and the mask are new; the verify gains a branch.

## .confidence 75% — lowered from 80%
- whether this box's `openssh-server` ships an enabled `ssh.socket` is **unmeasured** here;
  the mask is owed either way, so the order above does not rest on the answer
- `2.3.ssh` and the house bundle now both speak about `openssh-server`. the package belongs to
  the house bundle; `2.3.ssh` must never remove it. two bundles, one package, a written owner —
  a peer read is owed at the blueprint (`rule.forbid.two-writers-on-one-artifact`)

## .where
case=1 `[t0]` `[t3]` and stdout; case=3 `[t3]` `[t4]`; inventory row 44.

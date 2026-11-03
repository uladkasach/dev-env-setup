# S004 — the provisioner joins the tailnet

## .said

> so if infra always boostraps the groeve into the tailnet, we can just add that as a prereq and exclude that behavior from this repo right? we can just declare that prereq?

> ahh, so we still need this behavior in here? so in that case, should we tlel them to apply that onto the ec2 grove too? (since they're the provisioner of the groves machines themselves)

> ok give me the handoff. and enbrief this boundary too plz

## .settled

a cloud grove's tailnet join belongs to the machine's provisioner, on every platform. this repo
installs, enables, and verifies; it reads no key and runs no join on a cloud grove. the laptop's
member join stays here.

## .landed

- `handoff.infra.grove-tailnet-join.md`
- `.agent/repo=.this/role=any/briefs/grove/reach/rule.require.the-provisioner-joins-the-tailnet.md`

# rule.require.the-provisioner-joins-the-tailnet

## .what

**a cloud grove's tailnet join belongs to the repo that provisions its machine
(`ahbode/infrastructure`), never to a bundle here.**

| act | owner |
|---|---|
| mint the one-time `tag:camp` key | the provisioner (`rhx tailscale.authkey.mint`, admin keyrack) |
| deliver it to a root-only file, join, delete the file | the provisioner, at machine build |
| host firewall admits `tailscale0`; sshd binds every address | the provisioner |
| install tailscale on a grove, enable `tailscaled` | the provisioner, at machine build |
| install tailscale on a laptop, from the signed apt repo | `5.23.tailscale`, `local@unix` only |
| verify a grove has the client, the daemon, and the `tag:camp` join | `5.23.tailscale`, cloud tier — reads only |
| a laptop's member join (the human's sign-in url) | `5.23.tailscale`, `local@unix` only |
| a laptop's shields-up — it refuses all inbound tailnet traffic | `5.23.tailscale`, `local@unix` only |

⇒ on a cloud grove `5.23.tailscale` makes no tailscale write: no install, no key read, no `tailscale up`. a
grove without the client, the daemon, or the join is a `✋ ConstraintError` that names the
provisioner as the owner of the fix (`define.invariant.grove-tailscale-has-one-owner`).

## .why

- **the key lives with the provisioner.** it is minted per grove into the admin keyrack and
  never enters the ehmpath keyrack. a grove bundle could reach it only through a second
  hand-off, and a second hand-off is a second name: this repo once read
  `ahbode.camp.TAILSCALE_AUTH_KEY` from the grove's own rack while the provisioner wrote
  `GROVE_TAILSCALE_AUTHKEY` to the admin rack. neither read the other's
- **the join is a once-per-machine root act.** a bundle converges as camper, on every apply.
  the provisioner already runs once, as root, at build — so a rebuilt grove comes up joined
- **one owner per credential path.** mint, delivery, and join on one side leaves no seam for
  the key to drift across

## .the boundary test

> **does this step need the admin keyrack, or root, once per machine?**

- yes → the provisioner's. hand it off, and verify it here
- no → a bundle here may own it, and converge it on every apply

## .enforcement

- a bundle here that reads a tailnet auth key for a cloud grove = **blocker**
- a bundle here that runs `tailscale up` on a cloud grove = **blocker**
- a bundle here that installs tailscale or starts `tailscaled` on a cloud grove = **blocker**
- a cloud-grove verify that passes with no tailnet address, or with an untagged node = **blocker**

## .see also

- `handoff.infra.grove-tailnet-join.md` (this repo, route `v2026_10_25.feat-tailscale-on-every-machine`) — the ask that set the boundary
- `rule.forbid.aws-params-off-ec2` — the same shape: a vault's identity decides who may touch it
- `rule.require.seam-claims-have-an-owner` — a power one seat lacks goes to the seat that holds it

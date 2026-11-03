# define.invariant.grove-tailscale-has-one-owner

## .what

on a cloud grove, this repo makes no tailscale write. its provisioner (`ahbode/infrastructure`)
installs the client, starts the daemon, and joins the node; `5.23.tailscale` verifies all three and
fails fast where one is absent. the one write it may make there is `jq`, the verify's own parser,
where absent — no tailscale artifact.

## .kind

**nurture.** nature permits two writers; we chose one, because a second writer hides the first
one's failures.

## .invariant

```
GROVE_ENV_SERVER == cloud@*  ⟹  5.23.tailscale writes no tailscale artifact
                                 (apt source, key, package, tailscaled, `up`, `set`)
                                 ∧ (tailscale absent ∨ daemon down ∨ not joined ∨ tags ≠ tag:camp
                                    ⟹ ✋, with the provisioner named as owner of the fix)
```

| concern | `local@unix` | `cloud@*` |
|---|---|---|
| apt source + client | this repo | provisioner |
| `tailscaled` enabled + active | this repo | provisioner |
| join | this repo — member, human's sign-in | provisioner — `tag:camp`, one-time key |
| shields-up | this repo | — (the acl governs a grove) |
| verify | this repo | this repo |

## .why

- **a write here masks the provisioner's defect.** a grove built without tailscale is a build that
  failed. an install here turns that fault into a later, vaguer one ("not joined"), and the build
  stays broken for the next grove
- **two writers on one artifact** (`rule.forbid.two-writers-on-one-artifact`). the provisioner lays
  its own apt source and key; ours beside it can conflict in apt, and a later change to one is
  never seen by the other
- **one owner per credential path** — the join's key lives in the admin keyrack, which no grove
  holds (`rule.require.the-provisioner-joins-the-tailnet`)
- ⇒ a verify that only reads is the seam: this repo learns of every provisioner miss, and fixes none
  of them by accident

## .scope

- covers tailscale on a cloud grove only. a laptop still installs, joins, and shields here
- does not forbid a READ on a cloud grove — `tailscale status`, `systemctl is-active` are the verify
- does not decide what the provisioner installs from; its own source is no defect, so the cloud
  verify checks the client and daemon, never this repo's apt path

## .the litigation

the first shape had this bundle install on every tier and leave only the join to the provisioner,
for parity across tiers and so a grove built some other way still had a client. the counter: parity
of code is not parity of ownership, and the "built some other way" grove is exactly the defect a
verify exists to surface. a fail-fast names the owner; an install hides the miss. settled for
fail-fast.

## .the counter-argument

an install here is a safety net: a grove whose build skipped tailscale would still come up with a
client, one manual join away from reach. the net is real, and it still loses — it repairs the
symptom on one grove and leaves the provisioner's defect to recur on every grove after it.

## .what would overturn it

a grove class with no provisioner that can run as root at build — a box this repo alone sets up.
then the install has no other owner, and that tier declares its own row above.

## .enforcement

- a tailscale write (its apt source or key, the package, `tailscaled`, `tailscale up`/`set`) in
  `5.23.tailscale` reachable on `cloud@*` = **blocker**
- a cloud-tier verify that passes with tailscale absent, the daemon down, or the node unjoined = **blocker**
- a cloud-tier ✋ whose fix is a rerun of this bundle, not the provisioner's step = **blocker**
- clamp: `rhx play.run --play prove.cloud-tailscale-is-verify-only`

## .see also

- `rule.require.the-provisioner-joins-the-tailnet` — the ownership table, by act
- `rule.forbid.two-writers-on-one-artifact`
- `rule.forbid.failhide` — an install that hides a failed build is a failhide at the seam

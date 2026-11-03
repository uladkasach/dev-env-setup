# handoff: the provisioner joins every grove to the camp tailnet — ec2 too

for: `ahbode/infrastructure`
from: `uladkasach/dev-env-setup`, route `v2026_10_25.feat-tailscale-on-every-machine` (wish #174)
answers: your `handoff/tailnet-join.for-dev-env-setup.md` (route `v2026_10_20.feat-hetzner-cloud-grove`)

## .the ask

1. **the ec2 grove provision path installs tailscale, enables `tailscaled`, and joins the box**, as root, the way the hetzner bootstrap does:
   `tailscale up --auth-key=file:<root-only path> --hostname=<grove> --advertise-tags=tag:camp`,
   the key file removed on every exit path, the step skipped when `tailscale ip -4` already
   answers. prior art: the tailscale step in
   `provision/hetzner.infra/account=camp/genHetznerGroveBootstrapShell.ts`
2. **install, enable, and join the extant camp ec2 grove once**, as root, through ssm as admin
3. **declare the hetzner platform**: the hetzner bootstrap writes `hetzner.hetzbot` as the first
   line of `/etc/grove/platform`, root-owned, readable by all. dev-env-setup reads it to name the
   tier `cloud@hetzner.hetzbot`; without it, a hetzner grove's tree apply is refused by name,
   before any bundle runs. a bootstrap runs once, so **write it once, by hand, on the extant
   hetzner grove too**, the same way ask 2 covers the extant ec2 grove
4. **amend your handoff's `.who owns what`**: on a grove, the provisioner installs, enables,
   mints, delivers, and joins; dev-env-setup only verifies, and writes no tailscale artifact

## .why the join is yours

- **you hold the key.** `rhx tailscale.authkey.mint` writes `GROVE_TAILSCALE_AUTHKEY` to the
  admin keyrack, env `camp`, one-time, per grove. a grove bundle reaches it only by a second
  hand-off, and that hand-off is where the key drifts — dev-env-setup had already named it
  `ahbode.camp.TAILSCALE_AUTH_KEY` in the grove's own rack, against your "never the ehmpath
  keyrack"
- **it is a once-per-machine root act.** the bundle runs as camper, many times; the join runs
  as root, once. a provision step that runs once, as root, already exists on both platforms
- **a rebuilt grove comes up joined.** the join lives with the build, not with a later converge

## .what dev-env-setup does on a grove (`5.23.tailscale`)

| step | on a cloud grove | on a laptop |
|---|---|---|
| install from the signed apt repo | ✋ never — yours; any source you choose | ✔ |
| enable `tailscaled` | ✋ never — yours | ✔ |
| join | ✋ never — reads no key, runs no `tailscale up` | the human's own sign-in url, untagged member |
| verify | the client present, `tailscaled` active, the node joined with tags exactly `tag:camp`; else a `✋ ConstraintError` that names your step as the fix | signed in, shields up |

⇒ a grove of yours that comes up without tailscale fails our verify, loud, rather than gets
installed here — so a miss in your build surfaces at once, on the first grove it hits.

steps 4 and 5 of your table (host firewall admits `tailscale0`; sshd binds every address) stay
yours too: both are root, both are per box.

## .what stops until you land it

- the camp ec2 grove's `5.23.tailscale` verify fails, loud, until the box is joined. that is
  intended: a grove that claims tailnet reach and lacks it is the defect the verify exists for
- the hetzner grove passes once your declastruct apply retags it `tag:grove` → `tag:camp`

## .refs

- dev-env-setup#174 — tailscale on every machine
- dev-env-setup#172 — one tailnet reach for every cloud grove
- ahbode/infrastructure#70 — the camp ec2 grove over the tailnet

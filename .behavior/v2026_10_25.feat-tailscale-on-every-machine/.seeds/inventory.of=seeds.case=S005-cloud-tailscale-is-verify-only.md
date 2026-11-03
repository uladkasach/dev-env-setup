# S005 — a cloud grove's tailscale is verify-only here

## .said

> ok so what we expect is that the cloud sides get provisioned with tailscale at bootup and then our bundles just verify and failfast if unverified on cloud groves ?

> why wouldnt we failfast if a cloud grove doesnt have tailscale as we'd expect?

> that way we enforce the invariant of the separation of concenrs of tailscale between this repo and ahbdoe/nfra?

> yeah

> otherwise, we have a whole new world of defects that we'd hide

> itemize this invairant too so its never relitigated and can be enforced

## .settled

on a cloud grove, tailscale's install, its daemon, and its join all belong to the provisioner. this
repo makes no tailscale write there: it verifies, and fails fast with the provisioner named as the owner of
the fix. a write here would hide the provisioner's failures. supersedes S004's "this repo installs,
enables" on a cloud grove; the laptop is unchanged.

## .landed

- `src/grove.provision/5.devtools/5.23.tailscale/provision.upsert.sh` · `provision.verify.sh`
- `.agent/repo=.this/role=any/briefs/grove/reach/define.invariant.grove-tailscale-has-one-owner.md`
- `.play/permanent/prove.cloud-tailscale-is-verify-only.play.sh`

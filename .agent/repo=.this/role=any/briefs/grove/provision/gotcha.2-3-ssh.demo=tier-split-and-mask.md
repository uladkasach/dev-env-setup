# gotcha.2-3-ssh.demo=tier-split-and-mask

## .what

the dated measurement behind `2.3.ssh/provision.upsert.sh`'s tier-split package name and
its unit-mask step — why an unconditional `pkg_install ssh` is a security defect, and why
disable alone does not hold.

## m1 — one metapackage, no tier gate, sshd live on every laptop

measured 2026-09-03, redteam round 22, class 5. `ssh` on debian is a METAPACKAGE over
`openssh-client` + `openssh-server`. `openssh-server`'s maintainer scripts ENABLE AND
START `ssh.service` at install time — dh_installsystemd's default for a daemon package.
no line in this repo has to run `systemctl enable`; apt does it.

this file asked for the metapackage on every box with no tier gate. a laptop that did not
already hold `openssh-server` came out of one `grove.provision --mode apply` with sshd on
`0.0.0.0:22`, enabled at boot, under a stock `sshd_config` this repo never writes
(`PasswordAuthentication` at its compiled default of `yes`), and with no host firewall
declared anywhere in this tree — on every network that laptop then joins.

the neighbor verify's own header asserted the opposite at the time — *"a local laptop
deliberately keeps its daemon down"* — held by a comment, made true by no code, asked by
no reader: `rule.require.seam-claims-have-an-owner` unmet.
`gotcha.my-own-note-became-my-evidence`: the next reader inherits the sentence as the state
of the box.

## the fix has two parts, and neither alone repairs a laptop already stuck with the server

**the package name splits by tier** — `cloud@*` alone gets the `ssh` metapackage; every
other tier gets `openssh-client` only (no daemon, no unit, no port). a grove IS reached
over ssh. the duct is the one tier that needs the server.

**a disable alone does not hold** — it is a second write that races apt and re-fires on
every `apt upgrade` that reinstalls the server. so the phase also drives the unit to its
declared end state: it MASKS it, never merely disables it. `disable` is undone by the next
apt install that pulls `openssh-server` back — its postinst re-enables the unit; `mask`
points it at `/dev/null`, and apt cannot walk over that.

## why the unit step lives in the bundle, not the verify

the first repair cut left a laptop with a live daemon to a VERIFY that printed three
commands for a human to type — a fourth step, which `rule.require.one-command-provision`
forbids outright. the unit is machine state. its fix is a BUNDLE's job, never a verify's
(`rule.forbid.repair-plays`); the verify stays the reader that proves it.

## why the tier gate is the first line of step 2

a mask on a CLOUD grove kills sshd, which kills the duct, on a box with no console. step 2
runs on `local@*` only; the gate sits first rather than as a condition buried in the body.

## .see also

- `rule.require.narrowest-terminal-grant` — the "never ask for the server" principle
- `rule.require.seam-claims-have-an-owner` — the neighbor verify's unmet claim
- `gotcha.my-own-note-became-my-evidence` — the comment-as-evidence trap m1 hit
- `rule.require.one-command-provision` — why the fix moved from verify to bundle
- `rule.forbid.exemption-as-habit` — why there is no opt-out yet

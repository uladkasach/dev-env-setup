# demo: 5.8.docker — measurements behind the seat split and the roster reader

## .what

`5.8.docker` splits into provision (the box) and configure (the seat). two dated
measurements shaped that split and the roster reader beside it.

## grove-1 already held passwordless root on both seats

- 📜 measured on grove-1:

  ```
  $ sudo -n grep -rhE '^[^#]*NOPASSWD' /etc/sudoers /etc/sudoers.d/
    ubuntu ALL=(ALL) NOPASSWD:ALL
    camper ALL=(ALL) NOPASSWD:ALL
  ```

- a `!= local@*` decline against docker's root-equivalence would block a capability the
  seat already had, which is a gap with a security-shaped label rather than a guard
- 📜 svc-chat's 19 suites died at `ConstraintError: testdb not accessible` — the docker
  compose testdb no bundle had put there

## the camper seat has no sudo — traced 2026-08-10

- 📜

  ```
  whoami: camper       groups: camper
  sudo -n true         → refused
  getent group docker  → ground
  docker info          → permission denied
  ```

- a `docker` group grant on this seat would make it root-equivalent, which a decline
  cannot fix either — it would leave the seat with no containers at all
- ⇒ rootless is the third answer: the seat gets its own dockerd in its own namespace

## a box-ready check comes BEFORE the sudo assert — 2026-08-10

- ground had already converged the box. the camper still halted at
  `provision.upsert` with "sudo needs a password" — this ALSO skipped this
  bundle's `configure` pair, the half the camper needed and which asks no sudo
- ⇒ read what is already true before you assert the means to change it
  (`grove.pkg.sh` carries the same lesson one level down)

## docker's release key carries no tier-1 fingerprint — 2026-08-13

- docker publishes no fingerprint on any page or in any source repo. tier 1
  is unavailable for one of the most-followed vendors there is
- this author's laptop and `grove-ahbode-v20260811` both read the same value
  independently: `9DC858229FC7DD38854AE2D88D81803C0EBFCD88`
- ⇒ that is tier 2: the same value read at two independent points in time,
  stated as such so no later reader mistakes it for a sourced fingerprint
  (`gotcha.my-own-note-became-my-evidence`)

## uidmap was the ONLY gap docker's own installer named — 2026-08-10

- on the camper seat, `dockerd-rootless-setuptool.sh check` refused, and named
  ONE absent package: `apt-get install -y uidmap`
- `uidmap` ships the setuid `newuidmap`/`newgidmap` a rootless daemon needs;
  without it the rootless check refuses outright
- ⇒ it is a box-wide apt install, so ground drives it in `provision`; the
  per-seat half is the daemon itself, which lives in `configure`

## the roster read — exec-time group sets

- 📜 2026-08-12, `grove-ahbode-v20260811`, FIRST apply on a fresh box: the grant landed,
  `id -nG` said no, `provision.verify` reported the daemon unreachable, and a fresh
  login on that same box reached it cleanly — it cleared only on a SECOND apply
- `id -nG` prints the CURRENT PROCESS's group set, fixed at exec time; `usermod -aG`
  writes `/etc/group`. that write cannot reach a process already underway
- `getent group` reads the roster the upsert actually wrote, so a first apply can see
  its own work

## .see also

- `5.8.docker/_.sh` — the header these measurements back
- `rule.require.one-command-provision`
- `term=entry` — the same box/seat split, in a second costume

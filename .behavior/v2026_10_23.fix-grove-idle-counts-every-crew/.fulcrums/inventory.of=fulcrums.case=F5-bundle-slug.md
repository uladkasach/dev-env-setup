# F5 — the bundle slug is `1.system/1.12.hibernate`

## .the fork
- `1.system/1.12.hibernate` — a new system bundle
- `1.system/1.2.power/<child>` — under power, which owns *"never suspend, never hibernate"*

## .taken — 1.12.hibernate
`1.2.power` forbids the box's own systemd sleep; this is an aws-api stop the box calls on itself.
a child of power would sit under a parent whose `.what` says the opposite.

## .rework — clean
a rename before the first commit.

## .confidence — 85%

## .where
`src/grove.provision/1.system/`.

## .rework, taken at 5.1
`origin/main` took `1.12.firewall`, `1.13.exitnode`, and `1.14.updates` after the vision, so the
bundle lands as `1.system/1.15.hibernate`. the fork (a peer bundle, never a child of power) stands.

## .verdict
open — the slug moved to `1.15.hibernate`; the placement call is unchanged

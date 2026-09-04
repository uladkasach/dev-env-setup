# gotcha.1-6-3-earlyoom.demo=binary-vs-daemon-and-seat-privilege

## .what

the dated measurements behind `1.6.3.earlyoom/provision.upsert.sh`'s unconditional
`enable --now` and its unit-before-sudo read order.

## m1 — an early return on the binary check left a masked unit unprotected forever

presence of the `earlyoom` binary is not presence of an ACTIVE daemon. an early return on
`command -v earlyoom` left a masked unit unprotected forever while it reported "already
installed; skipped" the whole time. the package install is conditional; the enable is not —
`enable --now` converges harmlessly on an already-enabled unit
(`rule.require.idempotent-install-procedures`).

## m2 — an unconditional enable printed a false claim on the seat with no sudo

measured 2026-08-12, a grove's camper seat, which holds no sudo by design (`term=seat`). an
unconditional enable printed:

```
✋ could not enable earlyoom.service
   ⇒ the binary is on disk and no daemon watches memory
```

`ground` had already enabled the unit box-wide with this same bundle — the claim was false,
a defect of privilege dressed as one of state. the fix reads the unit's OWN state (enabled
+ active) before root is ever asked for. a seat that already holds a converged box
reports ✔ rather than a false ✋ (`bundle.root.declines`).

## .see also

- `rule.require.idempotent-install-procedures` — m1's fix
- `term=seat` — why the camper holds no sudo
- `1.6.3.earlyoom/_.sh` — why a grove needs this bundle most

# F18 — a damaged meter halts the boot with a ✋; it never defers

## .the fork

peer round i006 of 5.3 (r012, blocker 2) notes that the branch's prior head deferred a damaged org
meter inside a boot (🌙, rc=0), and that the S5 rework halts it (✋ ConstraintError, rc=1, on
configure.upsert, configure.verify and the public entry). F6's moot verdict covers the unset meter,
which the upsert now fixes; it does not cover a damaged one, which only a human can clear.

the options:

- **defer in the boot** — a damaged meter prints 🌙 and the boot passes
- **halt with a ✋ that names the human's steps** — read the file, clear it, apply, re-set each block

## .taken

halt. three reasons:

1. **a deferral passes a grove whose crews cannot commit.** the gate reads a damaged meter as a
   refusal for every org, so a boot that prints 🌙 and passes ships the exact defect this route
   exists to fix, under a green verdict (`rule.forbid.failhide`)
2. **the ✋ names the owner and the steps.** the message names the file, says the bundle writes no
   grant over it, and prints four numbered steps a human runs (F17). the halt is read as a stop
   that names what unblocks it, never as a silent bundle fault
3. **a fresh boot never meets it.** no meter exists before 5.26 writes one, and 5.26 writes only a
   whole file via a rename. a damaged meter arises only on an extant grove whose file another
   writer broke; a halt there is the honest verdict

## .rework

clean: a deferral is one `GROVE_BOOT_*` gate on the damaged branch of `configure.verify`, plus a
relay in the boot.

## .confidence

85%. the gap: the boot's own tally names no "human-owed" class, so its summary line counts the ✋
beside bundle defects; the ✋'s own text names the human. a claim class for that is F8's pr.

## .where

`src/grove.provision/5.devtools/5.26.commitorgs/configure.upsert.sh`, `configure.verify.sh`,
`_.sh` (`damaged_fix`).

## .verdict

open: disputed in 5.3 peer round i006 (r012), for the council.

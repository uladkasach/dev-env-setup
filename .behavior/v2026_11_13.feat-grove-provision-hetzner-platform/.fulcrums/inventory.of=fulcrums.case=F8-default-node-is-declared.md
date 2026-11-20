# F8 — the default node is the declared one

## .the fork
- **A (taken):** `fnm default` = the `.nvmrc` version (22.21.0) on every box
- **B:** `fnm default lts-latest`, capped at the newest major rhachet runs on (24)
- **C:** keep `lts-latest`, and wait on rhachet to drop `--experimental-transform-types`

## .why A
- lts-latest is v26 today, and node 26 refuses the flag rhachet's `bin/run.jit` passes, so a fresh box has no `rhx` that runs (measured on the hetzner ground seat: v22 runs `rhx keyrack`, v26 dies on the flag)
- C leaves every box provisioned from today broken until an upstream release lands
- B adds a second pin (the cap) that drifts beside `.nvmrc`; A reuses the one declaration the repo already holds

## .rework — clean
one function (`grove_node_version_default`) and one verify claim. to restore lts, return `lts-latest` from that function.

## .confidence — 70%
- the laptop's default moves 24 → 22 on its next apply. a repo with its own `.nvmrc` is unaffected (fnm's cd hook), but a bare shell sees 22
- upstream rhachet owes the real fix; this pin should lift once it lands

## .where
- `src/grove.provision/5.devtools/5.1.node/_.sh` — `grove_node_version_default`
- `src/grove.provision/5.devtools/5.1.node/provision.upsert.sh` · `provision.verify.sh`

## .verdict
open

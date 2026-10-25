# F7 — ❓ for the commander: what foreign writer does the boot gate prove the lock against?

🧭 **a blueprint question (this route has no 3.3.1 stone, so it was settled in execution). the best guess is retracted; the commander rules.**

- **the question**: the wish asks for proof that a write from outside dev-env-setup fails loud. after each swap, the bundle's boot gate runs a writer and fingerprints home (inode, mode, sha256). which writer?
- **options**:
  - **A. this repo's own `npm run prepare:rhachet`** (as built), in the checkout `GROVE_SRC` names, bounded at 300s. the real install step a sprout runs, and the only measured home writer. it rewrites the repo's own `settings.of.repo.json`, and its proof moves whenever `prepare:rhachet` changes
  - **B. a fixture writer**: a fixed shell procedure that tries an in-place write and a rename on home. stable, fast, no npm; proves the lock against a writer of our own invention
  - **C. no gate in the bundle**: the clamp play alone carries the proof; the apply trusts the lock
  - **D. A and B**: the real init for realism, the fixture for a stable floor
- **lean**: A. it proves the lock against the writer that actually wrote home. D if the commander wants a floor that survives a change to `prepare:rhachet`
- **rework**: clean — the gate is one function, called after the swap
- **confidence in the lean 75%, low because**: the brains bundle reaches into the repo's install surface, and a 300s npm run rides every apply
- **where**: `_grove_provision_5_3_brains_settings_boot_gate`
- **verdict**: open — for the commander

# F16 — the window closes by a full-bundle apply, not a settings-only one

- **the fork** (i009, r010 nitpick.1): every ✋ in the `off` window names
  `rhx grove.provision --what 5.3.brains --mode apply`. that runs `provision.upsert` first — each
  `web_pnpm install -g` converges on an installed package, but each still makes a network round
  (rhachet, declastruct, declastruct-aws, codex at its pin, the claude install, the candidate) —
  and only then the configure half that strips. at sprout cadence the friction decides whether
  anyone closes the window
- **options**:
  - **A. keep the full-bundle apply** (as built). one entrypoint, one slug, an idempotent converge;
    the cost is a slower apply
  - **B. split the settings half into its own child bundle** (say `5.3.1.claude-settings`), so
    `--what` targets it alone. the entrypoint stays the one door; the cost is a slug and layout
    change across `5.3.brains/`, the clamp, the briefs, and every fix-text that names the slug
  - **C. a phase selector on the entrypoint** (`--phase configure`). repo-wide: every bundle gains
    a mode no rule declares, and the bundle model has one operation at every depth by design
- **taken**: A, for this tree. B is the honest cure and fits the bundle model (a phase is a bundle
  too); C works against `rule.require.grove-provision-as-the-only-entrypoint`'s shape
- **rework**: dirty — B renames a slug that fix-texts, the clamp, and briefs all cite, so it is a
  change of its own, not a ride-along. caught as a dream:
  `.dream/2026_10_23.fix-5-3-brains-settings-half-as-its-own-bundle.dream.md`
- **confidence 75%, low because**: the reviewer is right that friction decides use, and the
  window's cadence (nearly every sprout) makes the cost weigh more than a rare apply would
- **where**: every `fix: rhx grove.provision --what 5.3.brains --mode apply` line in
  `configure.verify.sh`

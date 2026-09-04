# demo: 5.3.brains — the pin measurements

## .what

three dated measurements shaped the brain-pin policy in `5.3.brains/_.sh`.

## the publish-path measurement — redteam round 23, 2026-09-03

- the header once claimed *"the control is that the npm account is ours to guard"* —
  the npm account is not what a publish consults
- measured against the live repos:

  ```
  ehmpathy/rhachet .github/workflows/publish.yml
    on: push: tags: [v*]          ← a TAG PUSH publishes
    → .publish-npm.yml → npm publish, via npm OIDC trusted publish
    jobs.publish has NO `environment:` key
  repos/ehmpathy/rhachet/rulesets      → []
  repos/ehmpathy/rhachet/environments  → prod, protection_rules []
                                         (and the workflow never names it)
  declastruct: byte-for-byte the same shape
  ```

- so "who can publish this?" answers *whoever can push a tag*. the credential that
  can is `@all.camp.GITHUB_TOKEN` — a classic pat with `repo` scope, not per-repo
  scopable, held on every grove, under a posture that assumes a grove compromised
- the honest read: the risk is accepted, and the control that bounds it is UNBUILT
- two candidates, and the second is the one at cause:
  - a github environment with a required reviewer on the publish job (free, one config)
  - the per-org APP token with `--scope`, already phase 2 in
    `grove.auth.github.roadmap`, and the only one that closes the same hole in this
    repo too
- a pin is the plausible fix and the wrong one — it gates the repo on its own release
  cadence and holds against neither a human's `pnpm add -g rhachet` nor this repo's
  `node_modules`, which the claude hooks run from

## the codex pin — set from "latest", then read as drift

- the codex pin first read `0.151.0`, taken from `npm view` at the moment it was typed
- the verify then reddened against a box on `0.128.0` — the red was right about the
  wrong subject: no drift had happened, the PIN had jumped 23 minors
- a pin set to "latest at the moment I wrote it" blesses an unreviewed publish — the
  exact uptake a pin exists to stop, done by hand

## the claude verify — measured 2026-07-31

- `pnpm list -g` reported `2.1.87`; the live cli reported `2.1.220`
- claude's in-place updater rewrote `cli.js` and left the package metadata alone
- a check on the PACKAGE version reports ✔ on a drifted box; the verify asks the
  BINARY instead

## .see also

- `5.3.brains/_.sh` — the pin declarations these measurements justify
- `grove.auth.github.roadmap` — phase 2, the app-token fix
- `define.claude-code-config.md` — why claude is pinned below latest

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

## the hooks, bitten at the pin — 2.1.280, 2026-10-04

the pin's old reason was *"hooks are TRUNCATED beyond it"*, a conclusion whose measurement was lost
(the dream that chased it read: which hooks, at which version, observed how — no record answered).
so it was re-measured by a BITE, never by a load — the LAST hook of each list, in a FRESH process:

| list | the last hook | the bite | a fresh `claude -p` at 2.1.280 |
|---|---|---|---|
| `PreToolUse [Bash]`, 6 hooks | 4 `forbid-suspicious-shell-syntax`, 5 `forbid-stderr-redirect` | `echo bite 2>&1` | 🛑 BLOCKED by hook 4 |
| `PreToolUse [Write\|Edit]`, 3 hooks | 3 `forbid-terms.blocklist` | a write of "helpers" | 🛑 BLOCKED, `⛔ helpers` |

⇒ at 2.1.280 both lists run WHOLE. the claim is not reproduced at the pin, and beyond it is unmeasured.

🔴 **a LONG-LIVED session is not that evidence.** the same two bites, sent from a session that began
2026-10-01 12:07 on the same binary, both went THROUGH, and neither hook left a nudge record. that
session's `.claude/settings.json` was rewritten at 14:43 by a stash/rebase/unstash — the bytes equal
to HEAD, only the mtime moved — and from then the project hooks did not apply in it.
⇒ prove a hook from a FRESH process. a session that outlived a rewrite of its settings may run with
none, and reads exactly like one whose hooks pass.

## .see also

- `5.3.brains/_.sh` — the pin declarations these measurements justify
- `grove.auth.github.roadmap` — phase 2, the app-token fix
- `define.claude-code-config.md` — why claude is pinned below latest

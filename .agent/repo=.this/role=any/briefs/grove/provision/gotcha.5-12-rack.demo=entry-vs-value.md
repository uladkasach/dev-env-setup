# demo: 5.12.rack — every measurement behind the ENTRY-vs-VALUE split

## .what

`5.12.rack` writes host-manifest ENTRIES for two facts a grove already holds as VALUES.
each row below is a measurement that shaped one clause of its header.

## .a value in a central vault is not a readable credential

- 📜 2026-08-10: a grove's instance role read `@all.camp.GITHUB_TOKEN`'s ssm parameter
  directly — 41 bytes came back, with no keyrack involved at all
- 📜 every keyrack consumer still answered `absent 🫧`
- the value survived its old box's death, as `aws.params` promises
- the ENTRY did not — it lived in a `$HOME` that went with the disk
- see `term=entry` for the four-way split this proves

## the AWS_PROFILE pointer — traced twice

- 📜 traced on grove-1 2026-08-07 and this box 2026-08-10:

  ```
  IMDS                          ✔ role attached
  aws sts (bare)                ✔ answers
  aws configure export-creds    ✔ emits the AWS_* lines
  useKeyrack                    ✋ throws — AWS_PROFILE is unset
  ```

- 📜 all 19 of svc-chat's integration suites died on that last line
- valid ambient credentials sat one metadata call away the whole time

## the `test prep` mistake — a wrong pointer is worse than an absent one

- 📜 this function said `test prep` for one run on 2026-08-10
- 📜 with `ahbode.test.AWS_PROFILE = ambient`, the gate passed and the suite then failed
  22 times: `AccessDeniedException … not authorized to perform: lambda:InvokeFunction`
- the camp role acted DIRECTLY on a dev resource and was correctly refused — it never
  tried to assume, since the pointer said it was already home
- an absent entry says `AWS_PROFILE not set` and names the gap; a wrong one says
  `AccessDenied` and sends a reader to hunt an iam policy
- 📜 `handoff.infra.grove-account-reach.md` records a near-filed report against the
  wrong layer
- ⇒ `test`/`prep` now belong to `rhx aws.reach.set --env <env>`, which proves the hop
  with a live sts call before it reports success

## the declared-vs-set gap

- 📜 this box, 2026-08-10: `AWS_PROFILE may not be DECLARED for env=test`, one command
  after the profile body wrote successfully
- keyrack's cli refuses a named-org set unless the key is declared in scope — a
  declaration says "legal name here"; an entry says "here is its value on this seat"

## the git-root seam

- 📜 this box, 2026-08-10: a `set` outside a repo dies `Not inside a Git repository`,
  before it reaches a prompt, a vault, or a manifest
- a pushed `src/` has no `.git` by design — that is how a branch is proven on a grove
  before it merges — so this bundle cannot assume the checkout is a repo
- 📜 an earlier draft cloned `dev-env-setup` as the throwaway root and `rhx` died in
  CONFIG LOAD, since a bare clone has no `node_modules`
- an empty `git init` directory gives rhx no config to trip over; the durable fix
  belongs in rhachet (`rule.require.solve-at-cause`)

## the early-return skipped a second entry

- 📜 2026-08-10: an early `return 0` inside the "already wired" check skipped a second
  entry declared further down — the phase printed "no work" while the box was short one
  claim
- ⇒ a phase that wires N things sets a flag and falls through; it never `return`s for
  one of them alone

## the host manifest starts empty

- 📜 camper seat, 2026-08-10: `BadRequestError: host manifest not found`
- `keyrack init` alone writes `hosts: {}` — an empty index; a box can hold a manifest and
  a live ssm value and still answer `absent 🫧`

## a named org needs its own keyrack.yml

- 📜 this box: a `--org ahbode` set died with `✋ no keyrack.yml found` before it reached
  a prompt, a vault, or a manifest — `@all` needs no such file, a named org does
- `setKeyrackKeyHost.js:136` writes no `@all` key into a repo yml, so the throwaway git
  root gets a minimal `keyrack.yml` that names the org and its envs; the durable fix
  belongs upstream (`rule.require.solve-at-cause`)

## .see also

- `5.12.rack/_.sh` — the header these measurements back
- `term=entry` / `term=rack` — the vocabulary these prove
- `rule.require.reach-credentials-through-keyrack`
- `rule.forbid.repair-plays` — why this landed as a bundle, never a hand step

# demo: github-auth-two-paths — the mint mechanism and the org-selector gap

## .what

`define.github-auth-two-paths.md` states that keyrack mints app-installation tokens, and that a
per-org credential helper is blocked today. these are the dated measurements behind both claims.

## m1 — the mint mechanism, read from source, 2026-07-31 (rhachet@1.44.4)

- mechanism `EPHEMERAL_VIA_GITHUB_APP` stores a json blob that holds `appId`, `privateKey`, and
  `installationId` (`mechAdapterGithubApp.js`)
- mints via `@octokit/auth-app`'s `createAppAuth()` → `auth({ type: 'installation' })`
- cached with `expiresAt` at 55 minutes — github's 1h cap, less a 5-minute clock-drift buffer
- the cache is the per-owner daemon's in-memory Map, over a unix socket at
  `~/.rhachet/keyrack/daemon/{owner}.sock`, purged lazily on read — memory only, which is what
  keeps "no secret at rest" true
- the installation id is STORED, not looked up — resolved once at `keyrack set` time, so the
  org→installation translation is already per-key-entry
- read off the rack: `EHMPATHY_SEATURTLE_GITHUB_TOKEN` sat `EPHEMERAL_VIA_GITHUB_APP` on three
  orgs (whodis, whodisio, aether) and `PERMANENT_VIA_REPLICA` on four (aether-auctions, ahbode,
  ehmpathy, nheuron)
- the paired key `EHMPATH_BEAVER_GITHUB_TOKEN` is `EPHEMERAL_VIA_GITHUB_APP` on all five orgs it
  belongs to — ahbode, ehmpathy, and nheuron included — proof the app path already works on the
  orgs seaturtle has not migrated
- the four unmigrated orgs are blocked at read, measured 2026-08-05 against rhachet@1.45.1:
  `keyrack get --org ahbode --env prep --key EHMPATHY_SEATURTLE_GITHUB_TOKEN --unlock --value`
  answers `status: blocked 🚫 — detected github classic pat (ghp_*)`. the refusal is correct;
  `--allow-dangerous` silences it and leaves the risk where it was

⇒ the seaturtle migration is a repeat of a move beaver already made, not new ground — and the
block above is the operative reason to migrate, not hygiene.

## m2 — the org-selector gap, measured 2026-08-05 (rhachet@1.45.1)

- `keyrack get --org` accepts a literal org name only when it equals the checkout's own
  manifest org. two reads, same minute, on a repo whose manifest org is `ahbode`:
  `get --org ahbode` ✔ accepted — composed `ahbode.prep.…`, reached the pat firewall;
  `get --org whodis` ✋ `ConstraintError: org 'whodis' does not match manifest org 'ahbode'`
- no `--scope` flag exists at 1.45.1
- `@all.camp.GITHUB_TOKEN` (`rule.require.github-token-at-all-camp`) answered at 1.45.1 the same
  day — a real `@all` entry read back a value on stdout, against a control absent-key read of 0
  bytes

⇒ a literal org is `@this` spelled out, not a free selector — fatal to a PER-ORG credential
helper, since the helper runs from whatever repo git is on, never the repo it lives in. the
helper this repo built sidesteps the gap entirely: it names one slug that belongs to no org, and
that path was untested past this point, since no readable token had existed yet.

## .see also

- `define.github-auth-two-paths.md` — the mechanism these measurements back
- `rule.require.github-token-at-all-camp` — the slug that sidesteps the org-selector gap

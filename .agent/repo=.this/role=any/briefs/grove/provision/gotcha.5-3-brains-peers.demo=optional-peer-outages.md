# demo: 5.3.brains — three outages from rhachet's optional peers

## .what

`5.3.brains/provision.upsert.sh` installs rhachet's peers explicitly. three dated
measurements justify why they cannot be left optional.

## a bare `pnpm` stalled a duct — 2026-08-14

- against a silent registry a bare `pnpm` opened 5 connections and had not returned
  at 240s
- this bundle makes four such calls, so a dead registry would hold the duct
  (`prove.tool-defaults-are-bounded`, `src/grove.web.sh`)
- ⇒ every call here goes through `web_pnpm`, never a bare `pnpm`

## three outages in one day traced to absent optional peers — 2026-08-06

- a global `pnpm install -g rhachet` leaves its optional peers absent. each one
  fails FAR from where it is absent, with no sign it is an install problem:

  | peer | how it failed |
  |---|---|
  | `with-simple-cache` | `Cannot find module`, inside node's loader, so EVERY `rhx` dies before any subcommand runs |
  | `declastruct-aws` | only the `aws.params` VAULT errors, so one credential goes quiet while the cli looks fine — which reads as "git asked me for a password", eight hours after anyone touched it |

- the second shape reports no error until a caller wants that vault

## the chain needs its middle link too — grove-1

- `declastruct-aws` and `declastruct` are a CHAIN: rhachet → declastruct-aws →
  declastruct. pnpm hoists no link of it globally
- an install of the middle link alone moved the failure one file deeper, to
  `DeclaredAwsBudgetActionDao.ts:1:1`, `Cannot find module`
- ⇒ so the whole chain is named in one call; the fix at cause is upstream
  (`ehmpathy/rhachet#458`)

## .see also

- `5.3.brains/provision.upsert.sh` — the install line these measurements back
- `gotcha.5-3-brains-pins.demo=publish-path-and-drift` — the neighbor demo, the
  pin policy rather than the peer chain
- `rule.require.github-token-at-all-camp`

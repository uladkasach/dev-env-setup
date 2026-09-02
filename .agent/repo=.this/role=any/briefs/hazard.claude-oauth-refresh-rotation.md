# hazard: claude oauth refresh rotates the token — never refresh the global session

## .what

claude code's oauth **refresh_token** (`sk-ant-ort01-*`, ~108 chars) is **single-use with
rotation**: a POST of it to the token endpoint returns a fresh `access_token` AND a NEW
`refresh_token`, and **invalidates the old one server-side**.

## .why this is a hazard

on 2026-07-31 a probe read the refresh_token from the live `~/.claude/.credentials.json` and
refreshed it to test the usage path. it succeeded (HTTP 200, real usage data) — but that refresh
rotated the token server-side. the global claude session still held the now-dead old token, so its
next use returned 401 and the human was locked out and had to re-login + reboot.

## .the rule

- NEVER read or refresh the refresh_token out of the global `~/.claude/.credentials.json`. any
  refresh against it kills the live session.
- capture each subscription's refresh_token via an **isolated** browser login
  (`CLAUDE_CONFIG_DIR=<tempdir>`, a separate account), then store it in the keyrack. that token is
  independent of the global session, so a rotation of it is safe.
- each `usage` call rotates the stored token, so `usage` MUST write the new refresh_token back to
  the keyrack, or the next call fails.
- to test the refresh path live, always target an isolated `CLAUDE_CONFIG_DIR`, never the real one.

## .the proven mechanism (2026-07-31)

the long-lived setup-token (`sk-ant-oat01` from `claude setup-token`) is REJECTED on the usage
endpoint ("Invalid bearer token") since ~2026-02-20 — only a freshly-refreshed access_token works.

1. **refresh** — `POST https://platform.claude.com/v1/oauth/token` (NOT `console.anthropic.com`,
   which 404s/301s), body
   `{grant_type:"refresh_token", refresh_token, client_id:"9d1c250a-e61b-44d9-88ed-5944d1962f5e"}`,
   header `Content-Type: application/json`. → 200 with a short-lived `access_token`
   (`sk-ant-oat01`, ~108 chars) and a rotated `refresh_token`.
2. **usage** — `GET https://api.anthropic.com/api/oauth/usage` with
   `Authorization: Bearer <access_token>`, `anthropic-beta: oauth-2025-04-20`,
   `User-Agent: claude-code/<ver>`. → 200 with `five_hour` / `seven_day` / `seven_day_opus` /
   `limits` / `spend` windows.

## .what does NOT test the invalidation claim (a trap, walked into 2026-08-13)

a stored keyrack token that refreshes cleanly after weeks idle is **not** evidence that a
superseded token stays alive. every read writes the rotated token back, so the stored value is
always the *current* one — never a superseded one. that it works is exactly what invalidation
predicts, so the observation separates no hypothesis from the other.

on 2026-08-13 that logic was run backwards: two-week-old stored tokens refreshed with a 200, and
it was read as proof that rotation leaves the old value usable. it does not follow. a security
call (whether a leaked token still needs a revoke) was made on that unsound inference.

**to actually test it** you must hold a value you know was superseded — refresh token A into B,
then retry **A**. the 2026-07-31 lockout is precisely that experiment, run by accident: the live
session held the pre-rotation token and got a `401`. that remains the evidence, and it says the
old token dies.

> a token that works proves it was never replaced. only a token you KNOW was replaced can
> tell you what replacement does.

## .the brief predicted its own violation (2026-08-31)

the bullet below — "a mint whose rotated value is dropped strands the account" — was written
before it happened, and then happened anyway, to three accounts in one command.

the mechanism was a **jq parse error**. a new shared mint leaf built its reply node with
`{ok: (.x // "") != "", …}`; in jq's object-construction grammar a bare `!=` is a parse error
(it needs `((.x // "") != "")`). the parse ran AFTER the http call, so per account: the refresh
succeeded → the server rotated the token → the decode failed → **the rotated value was dropped**.
the keyrack kept the superseded copy, which is dead. the symptom appeared only on the next read.

three things turned one typo into three lost logins:

1. the jq carried `2>/dev/null`, so the parse error was printed and discarded
2. the first run of the new code swept ALL five live accounts at once
3. the first sweep's `refresh_unreadable ×3` was read as "a bug to fix", not as "an
   irreversible loss in progress — stop"

### the rule this earns

> code that rotates or overwrites a credential runs ONCE, against ONE expendable subject, with
> every error stream visible — before it is ever pointed at a real account. never a sweep,
> never with stderr muted.

a credential rotation is not ordinary code. ordinary code you repair by iteration; a rotation
you cannot un-rotate. the blast radius of the first run is the whole cost of the mistake.

**corollary:** never mute stderr on a decode that sits downstream of a successful mutation. the
error you silence there is the only signal that the mutation's result was lost.

## .implication for brains.auth.*

- `brains.auth.set` must capture the **refresh_token** from the isolated login's credentials file
  (not a `setup-token`), and store it in the keyrack.
- `brains.auth.usage` must, per account: read the refresh_token → refresh at
  `platform.claude.com` → write the rotated refresh_token back to the keyrack → hit the usage
  endpoint with the fresh access_token.
- **any path that mints an access token owns the write-back — even one that only wants the
  identity.** `brains.auth.set` mints purely to ask `/api/oauth/profile` which account the token
  belongs to, and that mint rotates the stored secret just the same. so it files the ROTATED
  token, never the one it captured. a mint whose rotated value is dropped strands the account
  with no live token anywhere, and the symptom appears only on the NEXT read.

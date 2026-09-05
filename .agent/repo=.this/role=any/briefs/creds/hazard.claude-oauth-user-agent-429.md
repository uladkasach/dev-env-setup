# hazard: claude oauth endpoints 429 on a wrong User-Agent (not a real rate limit)

## .what

the claude oauth endpoints (`platform.claude.com/v1/oauth/token` refresh, and
`api.anthropic.com/api/oauth/usage`) reject an unrecognized `User-Agent` — the request lands in
an **aggressively rate-limited path** that returns a persistent `429 rate_limit_error` and does
NOT clear with time. it is a request-shape rejection dressed as a rate limit, not a volume
throttle.

## .why this is a hazard

the failure masquerades as a rate limit, so every instinct is wrong:

- the body says `{"error":{"type":"rate_limit_error","message":"Rate limited. Please try again
  later."}}` — so you assume volume and "wait it out".
- it never clears (proven: identical `429` the next day after zero activity) — a real throttle
  resets in minutes-to-hours.
- a `429` rejects at the gate and never reads the token, so it is NOT the token — re-auth does
  not help, and the stored token is fine.

the true variable is the `User-Agent` header alone.

## .the proof (2026-08-02)

same account, same stored refresh token, same URL + `anthropic-beta` header + body — only the
UA differed:

| User-Agent | refresh result |
|------------|----------------|
| `claude-code/2.0.1` | **200** — real usage data returned |
| `claude-code/2.1.87` (from `claude --version`) | **429** — persistent across a full day |

a UA pinned to `2.0.1` unblocked the whole feature instantly.

## .the rule

- **pin a known-accepted `User-Agent`** for these endpoints; do NOT derive it from
  `claude --version`, which drifts to a value the endpoint may not accept.
- treat a `429 rate_limit_error` from these endpoints as **"suspect the UA first"**, not
  "wait out a throttle" — especially when it persists past a few minutes.
- the pinned value will eventually go stale (anthropic rotates accepted client versions), so
  keep it a single overridable constant (`BRAINS_AUTH_UA` env override), not a scattered
  literal.

## .in brains.auth.*

`_brains_auth_ua()` returns the pinned `_BRAINS_AUTH_UA_PINNED='claude-code/2.0.1'`, overridable
via `BRAINS_AUTH_UA`. when a future claude-code version is required, bump that one constant.

## .the debug lever that found it

the per-slug error nodes carry a `detail` field, and `BRAINS_AUTH_DEBUG=1` prints the raw
non-200 body (`🔎 <slug> refresh http_429: {…}`). that surfaced the `rate_limit_error` type —
which, paired with the day-later persistence, is what exonerated the token/volume theories and
isolated the UA.
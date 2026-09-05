# rule.require.security-paramount

## .what

security is paramount — the top priority. when a choice trades security for
convenience, ergonomics, or speed, security wins by default. surface the
tradeoff to the human; never silently pick the less secure path.

## .why

- this repo configures a personal machine that holds real credentials, ssh
  keys, and access to prod — a single leak has outsized cost
- convenience compounds quietly; a shortcut taken once becomes the default
  posture on every future machine that inherits this setup
- the secure default is cheap to keep and expensive to retrofit after exposure
- an exposed secret cannot be un-exposed — prevention is the only real control

## .the rule

when any change touches a security boundary, apply this order:

1. **most secure that still does the job** — prefer it, even at some friction
2. **if a tradeoff is unavoidable** — surface it to the human explicitly, name
   what is exposed and to whom, and let them choose
3. **never** downgrade a security posture silently or as a convenience default

| situation | wrong | right |
|-----------|-------|-------|
| feature needs a capability | grant broad access ("just make it work") | grant the narrowest capability that suffices |
| a read leaks extra data (e.g. env vars) | ship it, filter later | close the leak at the source; expose only what's needed |
| an opt-in security control exists | leave it off for ease | keep it on; opt out only per-case, deliberately |
| convenience vs exposure | pick convenience quietly | name the exposure, let the human decide |

## .solve at cause

guard the boundary structurally, not with a downstream filter. if a mechanism
exposes more than needed, prefer a narrower mechanism over a scrub of its
output — a filter can be bypassed; a capability that was never granted cannot.

see rule.require.solve-at-cause.md.

## .the test

before you implement, ask:

> "what does this expose, to whom, and is that the minimum the task needs?"

if the answer widens the attack surface, stop and find the narrower path or
surface the tradeoff.

## .enforcement

- silent security downgrade for convenience = blocker
- broad capability where a narrow one suffices = blocker
- unsurfaced security/convenience tradeoff = blocker

## .see also

- inventory.security-checks.md — the live ledger of checks adopted
- rule.require.solve-at-cause.md — guard at the source, not the symptom
- rule.require.verify-binary-downloads.md
- rule.require.repo-as-source-of-truth.md
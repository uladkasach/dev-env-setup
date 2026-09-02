# domain.term.choice.reason: reach

## .etymology

a **reach** is how you get hold of someone — the address at which a party is reachable. the
term is borrowed from the extant `rhx clone say @:<id> --what "…"` surface, where a reach names
the handle through which one party addresses another. this namespace inherits that sense: the
reach of a claude subscription is the email at which its account is addressed, and it is
therefore the name its keyrack key is cut at.

the word carries the whole design in one syllable: an account is not *called* something by us,
it is *reachable at* an address it already owns. the name is discovered, never assigned.

## .disputes

### dispute: sub / slug  —  raised 2026-08-31  —  status: RESOLVED (adopt `reach`)

- raised.by  = the implementation of `brains.auth.*`, against its own first design
- claim      = the original scheme was `--sub <slug>`: the human invents a short handle
               (`ehmpathy`, `ahbode`) and the key is filed under
               `BRAINS_AUTH__OF__CLAUDE_CODE_OAUTH_TOKEN__FOR__<slug>`. a slug is short, it
               reads well in a tree render, and it is what the wish's own prose used.
- counter    = a slug is a **second name for something that already has one**, and a second
               name can disagree with the first. it had to be typed correctly at store time,
               and a typo would silently file a subscription under a name no later read would
               ever look for — a keyrack miss that reads identically to "never stored".
               `GET /api/oauth/profile` already answers "who does this token belong to?" with
               an email, so the token states its own name. under `reach` that answer is derived
               fresh on every call rather than recorded, which means no join table sits between
               our name and theirs, so no middle record can go stale.
               the practical proof: `brains.auth.set` now takes **no argument** in the common
               case — it signs you in, asks the token who it is, and files it under the answer.
               a term that deletes an argument was carrying an invention.
- resolution = adopt `reach`; record `sub`, `slug`, `account-name`, and `handle` as forbidden
               synonyms. `--sub` survives as a **parse-level alias only**, with a deprecation
               notice on stderr, so an older invocation does not hard-error — it is not the
               term, and a bare slug (`--sub ehmpathy`) is now a keyrack miss because no key is
               filed under a bare slug any more. dispute closed.

### note on the surviving alias

`--sub` in the flag parser is NOT a live synonym. it is a sunset ramp: it emits
`deprecation.sub-says-so` on stderr (never stdout, so a `--json` consumer is untouched) and
resolves to the same value. removal is deferred on purpose — a sunset with no warn period is a
break — but no new contract may use it, and `rule.forbid.domain-term-synonyms` applies in full.

## .evidence

- **discovery** — the five-whys walk on "why does a subscription need a name at all?" bottomed
  out at "so a later read can find its token", which is a question the token itself answers.
  the layer above ("so a human can say which one") was mechanism, not motive.
- **shape** — a reach is validated as an email address (`_brains_auth_is_reach`). `@all` is the
  only non-email value any of the three commands accepts. a bare slug is refused at the
  boundary rather than allowed to become a silent miss downstream — clamped by the eight
  `reachshape.*` cases, one of which proved that `use --reach <bare-slug>` used to **stall**
  (exit 124) rather than refuse.
- **consequence for consumers** — rendered rows are keyed by email, so a `--json` reader takes
  `.["kai@ehmpathy.com"].five_hour.utilization`. this is a contract change the dispute
  deliberately accepted.
- **invariant it serves** — `hazard.claude-oauth-one-holder-per-token.md`. identity must be
  DERIVED from the live token on every run, never remembered, so a login made behind our back
  (a plain `claude /login`) is noticed. a slug is a memory; a reach is a read. the term choice
  is what makes the invariant expressible.

# domain.term.choice.reason: park

## .etymology

you **park** a vehicle you intend to drive again. the word carries three senses this domain
needs and no rejected synonym carries all three:

1. **the thing parked is still yours and still live.** a parked account is not filed away or
   retired — it is one `brains.auth.use` away from the road again.
2. **the act is deliberate and located.** you park somewhere specific, and you can go back to
   exactly that spot. the keyrack, cut at the account's reach, is the spot.
3. **it pairs with a real failure.** a car you could not park is a car left in the street.
   that failure has its own word here — **strand** — and the pair reads as one story:
   `_brains_auth_park_or_strand`.

`park` also names a state, not only an act: the namespace's whole model is **one ACTIVE account
(in `~/.claude/.credentials.json`) and N PARKED accounts (in the keyrack)**. that split is the
domain's central fact, and `park` is the word that makes it sayable.

## .disputes

### dispute: stash / save / store  —  raised 2026-08-31  —  status: RESOLVED (keep `park`)

- claim      = `stash` is the familiar git word for "set this aside, i will come back to it",
               and `save`/`store` are the plain words for a write to a durable home.
- counter    = each loses one of the three senses above.
               `stash` implies a scratch shelf whose contents may be dropped — but a parked
               token is an account's **only** live credential; to drop it is a browser re-auth
               (`hazard.claude-oauth-refresh-rotation.md`). git's `stash` is also a stack with
               no addressing, while a park is cut at exactly one reach.
               `save`/`store` are true but flat: they describe a write and say nothing about
               the account's **state** afterward, which is the whole point — the domain needs
               to distinguish the one ACTIVE account from the N PARKED ones, and a "stored"
               account is not a state anyone can reason about.
               `backup`/`archive` are worse still: both imply a redundant copy, and the parked
               token is the ONLY copy. that misread is exactly the mistake the
               `.credentials.json.bak` naming already invites once in this file, and a second
               invitation is one too many.
- resolution = keep `park`; record `stash`, `save`, `store`, `backup`, `archive` as forbidden
               synonyms. dispute closed.

## .evidence

- **the pair** — `park` and `strand` are complementary and shaped alike
  (`rule.prefer.symmetric-term-pairs`): a park that succeeds files the token; a park that fails
  **strands** the account, and `_brains_auth_bak_strands` refuses the next swap while a strand
  is unresolved rather than compound it.
- **the split is load-carrying, and it is ordered** — the park is deliberately two operations,
  `_brains_auth_park_read` (read out, write nowhere) and `_brains_auth_park_file` (file it), so
  the keyrack stays untouched until the new credentials are installed. **install-then-park**,
  never park-then-install, so one token never has two holders
  (`hazard.claude-oauth-one-holder-per-token.md`). a flat word like `save` would have hidden
  that ordering inside one verb; the `park_read` / `park_file` pair names it.
- **the state it defines** — every render in the namespace reads off active-vs-parked: the
  `← signed in` marker, the union of the live account into an `@all` sweep, and the refusal to
  mint against the active account. the term is what those three share.

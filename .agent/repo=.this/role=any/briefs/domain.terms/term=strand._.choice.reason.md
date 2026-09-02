# domain.term.choice.reason: strand

## .etymology

to **strand** is to leave someone ashore with no way back — the boat left, and they are still
there, intact and unreachable. every part of that image is load-carrying here:

1. **the account survives.** a stranded account is not deleted and not corrupt. its token
   simply has no holder we can reach. that distinction is what the recovery advice rests on.
2. **the cause is a departure, not a destruction.** the swap moved on and left the account
   behind. no one destroyed the token; the copy that could reach it stopped being there.
3. **rescue is possible but costly.** a stranded account comes back by a browser re-auth — a
   real cost, paid by a human, not a retry the code can perform.

`strand` is the declared pair of `park` (`rule.prefer.symmetric-term-pairs`), and the pair is
the whole story of a swap's failure path: `_brains_auth_park_or_strand` names both outcomes in
one function name, so a reader sees the fork before they read the body.

## .disputes

### dispute: orphan / lose / drop / leak  —  raised 2026-09-02  —  status: RESOLVED (keep `strand`)

- claim      = `orphan` is the familiar systems word for a resource with no owner, and
               `lose` / `drop` / `leak` each plainly describe a value that stopped being
               reachable.
- counter    = each is wrong in a direction that would mislead the human at the worst moment.
               `orphan` says the account has no PARENT — but it has one, and the parent knows
               exactly who it is; what it lacks is a reachable TOKEN. the word points the
               reader at ownership when the problem is reachability.
               `lose` and `drop` both imply carelessness and, worse, imply the value is simply
               gone — so a human reads them as "no move remains". a strand is recoverable, and
               the term must not talk them out of the recovery.
               `leak` is the worst of the four: it names a security failure (a secret escaped
               to somewhere it should not be), which is the OPPOSITE of what happened (a secret
               sits nowhere it can be used). in a credential namespace, that misread costs an
               incident response for a defect that is not one.
               `abandon` is closest in sense but carries intent — a strand is always accidental.
- resolution = keep `strand`; record `orphan`, `lose`, `drop`, `leak`, `abandon` as forbidden
               synonyms. dispute closed.

## .evidence

- **the fork it names** — `_brains_auth_park_or_strand` is the one function whose name states
  both branches. a swap that reaches it either files the prior account's token (park) or does
  not (strand), and there is no third outcome.
- **it is a STATE, not only an event** — `_brains_auth_bak_strands` refuses the next swap while
  a strand is unresolved, rather than compound it. that guard is only expressible because the
  word names a condition the machine can be IN, not just a moment that passed. a `.bak` that
  cannot be parsed counts as a strand, deliberately: we cannot prove it redundant, and the two
  mistakes are not symmetric — to call it redundant destroys a token we could not read, while
  to call it a strand costs one refusal and a rescue a human can complete by hand.
- **it is why the ordering exists** — install-then-park, never park-then-install, and the
  install-failure path refiles a rotated token (`_brains_auth_refile_rotated`) precisely so a
  failed swap cannot strand the target. the term names the outcome the whole ordering is built
  to avoid (`hazard.claude-oauth-refresh-rotation.md`).
- **it is clamped** — `swap.install-fails.strands.snap` pins the narrative a human reads when
  it happens, so the recovery advice cannot silently drift into one of the forbidden frames
  above.

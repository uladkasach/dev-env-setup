# demo: adopt-a-replacement-grove — stale entries and trust mismatches

## .what

`howto.adopt-a-replacement-grove.md` states the checks a rebuilt box requires. these are the
dated measurements that showed a correct registry entry is not the same claim as a trusted
endpoint, and that "dirty" is not the same claim as "unique".

## m1 — a rebuilt box, a correct entry, and ssh refused it anyway, 2026-08-15

- `git.grove.get` returned the exid that matched; `wake` printed `account: <acct> ✔ matches
  the registry`, replaced a stale tunnel, rewrote the alias, and reported `🌳 grove's awake!`
- the very next `git.grove.push` died on ssh's own `REMOTE HOST IDENTIFICATION HAS CHANGED`
  banner, naming a conflicting key at `~/.ssh/known_hosts` line 8
- ⇒ `wake` converges the ALIAS and does not converge the TRUST. those are two records about
  one box, and only one is a fact about the endpoint's identity. the free registry check
  answers *"does the entry name the right box?"* — a question that was never the one at
  fault here
- the ssh banner is the loudest text ssh emits; a reader who trusts it over the context
  reads a rebuild they just asked for as an attack

## m2 — 205 "dirty" paths were mostly push artifacts, not unique work, 2026-08-10

- `verify.grove-safe-to-wipe` named 205 dirty paths in the grove's own dev-env-setup
  checkout — the same checkout `git.grove.push` feeds, so most are byte copies of what the
  caller already holds
- "dirty" there means *"differs from the grove's git HEAD"*, which is exactly what a pushed
  copy is supposed to be
- ⇒ the audit answers *"is any file unique here?"* with *"some file is dirty here"*; only a
  content compare separates the two — hash every dirty path through the duct and diff
  against the caller's own copies. a hash that agrees is a push artifact, safe to lose; a
  hash that differs is the work to rescue

## .see also

- `howto.adopt-a-replacement-grove.md` — the procedure these measurements back
- `rule.require.security-paramount`, `rule.prefer.prevent-over-correct`

# domain.term.choice.reason: live

## .etymology

`live` was chosen for its *transience*. a live wire is live only while current flows; cut the
power and it is inert. that is exactly the property this term must carry — the state is real
right now and gone after a boot, which is precisely why it cannot be trusted as evidence.

the rejected words all fail the same way: each implies that this state is the authority.

| rejected | why it fails |
|----------|--------------|
| `actual` | implies it is the TRUTH, when it is the consequence. "declared vs actual" invites the reader to trust the wrong half |
| `current` | same fault, and doubly overloaded — electrical current, and `git`'s "current branch" |
| `effective` | implies it is what finally counts, which is backwards: a boot overrules it |
| `runtime` | a build-vs-runtime word borrowed from another domain; says when, not how long it lasts |
| `in-effect` | reads as authoritative, and hyphenated where the pair wants one word |
| `observed` | describes the READER, not the state. state is live whether or not anyone looks |

`live` is also one syllable and pairs in shape with `declared`, per
`rule.prefer.symmetric-term-pairs`.

## .why it may never carry a verdict

live state fails as evidence in both directions:

1. **it goes quiet exactly when it matters.** right after a boot or a resume, the live signal
   can be entirely absent while the declaration stands ready to re-arm the defect. a live
   check reports clean, and the next boot brings the problem back.
2. **a live fix does not hold.** `swapoff`, `kill`, `ip link down` all look like repairs and
   are not — the declaration reinstates them.

on grove-1, a freshly resumed box showed *no active swap at all* while `/etc/fstab` still
armed the bad swapfile. the live-state checker reported **SAFE** on a box that could not
hibernate. that is the whole case for this term, and for the rule that governs it.

## .the one legitimate use

report it, labelled. `verify.swap.hibernate-safe` prints:

```
  swap active right now (transient — informative, never the verdict)
```

the label is part of the term's contract: live state may inform a reader, and may help a
human diagnose, but the exit code must come from the declaration.

## .evidence

- discovery: a live-state checker returned SAFE on a known-poisoned box
- invariant: no exit code may be derived from live state where a declaration exists
- corollary: a `diagnose` playbook may read live state freely, because it asserts no verdict —
  which is why `diagnose.swap.hibernate` was split out from the `verify` play

## .disputes

none open.

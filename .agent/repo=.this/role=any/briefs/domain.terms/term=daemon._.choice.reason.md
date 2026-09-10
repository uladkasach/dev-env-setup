# domain.term.choice.reason: daemon

## .etymology

from maxwell's demon by way of MIT's Project MAC, where the word shifted to the greek
*daimōn* — an attendant spirit that acts without being asked. the sense that stuck in unix is
**a process that runs unattended, on behalf of somebody who does not watch**.

that is precisely the property this domain needs, and the reason `helper` and `worker` both
lose: each implies somebody who asked. a daemon here is spawned by a caller that has since
exited, so at the moment it costs the most there is nobody who asked at all.

⚠️ the word is adopted from unix **unchanged in sense and narrowed in scope**, which is the
same move `term=orphan` sense F makes. what this cluster adds is the property unix's own
daemons lack: a **derived key**.

## .why it was itemized late

`keyrack.daemon.prune` has been a declared operation since 2026-08-30, and its noun went
unitemized for over a week while `prune` (its verb) and `orphan` (its consequence) both got
clusters. that is a third distinct cause of lateness, beside the two `install`'s reason file
records:

| term | why it waited |
|---|---|
| `prune` | it did not — the destructive verb was itemized first, correctly |
| `orphan` | it did not — the consequence was visible in a `ps` |
| `daemon` | it read as **imported vocabulary**, so it looked out of scope |

⇒ the glossary's own scope rule is what excludes imported vocab: *"vocab imported from a
dependency (bhrain's `stone`, `guard`, `route`)"*. **unix is not a dependency**, and a word this
repo narrows is a word this repo owns. `orphan` had already set that precedent, and it went
unread for the neighbouring case.

> **a word imported unchanged needs no cluster. a word imported and NARROWED needs one, and the
> narrower sense is what the cluster is for.**

## .the measurement — the key is what leaks

`rhachet` derives the daemon socket from `sha256(realpath($HOME))`. so the find-or-create is
correct code with a caller-supplied key, and the caller is what breaks it:

```
jest integration run  →  HOME=/tmp/rhachet-test-$ts-$rand  →  a NEW hash  →  a NEW socket
                                                           →  find misses →  spawn
```

575 of these were found on a 76-day uptime. each is cheap in RSS (PSS ~714K) and expensive in
aggregate: collectively GBs of swap plus a share of 1.19G of page tables — which is what filled
zram and pushed the whole desktop into disk-swap thrash.

⚠️ **no per-process threshold could have caught it.** at 714K PSS each, every member is far
under any reasonable alarm; the cost lands on the SET (`term=class`), and the set has no name
because each member is `node` and each is reparented to init.

## 🛑 .the fix belongs in the ALLOCATOR, and the prune is a chore

this is `tmp.fixture`'s lesson, restated for the twin population — and the two are one leak seen
twice, because **a throwaway `$HOME` is a `tmp.fixture`, and a daemon keyed on it is what that
fixture leaks**:

| | the fixture | the daemon it mints |
|---|---|---|
| what leaks | a `/tmp` dir | a process keyed on that dir |
| what it costs | kernel slab (`SReclaimable`) | ANON memory (must swap) |
| who can see it | no process-level tool | no tally by parent or by name |
| the real fix | one allocator with a teardown | the same allocator |

⇒ so `1.6.4.keyrackd` is a **chore, never a fix**. it bounds the population; it does not stop
the mint. one allocator that reaps its fixture on exit closes both, and that is upstream work
(`rule.require.pitofsuccess` — a rule that must be remembered will be forgotten).

📜 measured 2026-09-07 → 09-08: the fixture population refilled at ~118/hour with no change to
the workload. the daemon population refilled at ~152/hour. a prune on a 15-minute timer keeps
both bounded and neither at zero, and that is the correct outcome for a chore.

## .disputes

none raised. the five forbidden synonyms were each weighed at authorship against the
derived-key property, and each fails it — `agent` most narrowly, since ssh-agent and gpg-agent
are also lazily spawned. what separates them is **the reap**: an agent is bound to a session and
dies with it, and a session is a scope the OS enforces. this daemon's scope is a hash of a
directory, which the OS enforces in no way at all.

## .the neighbours

- **`tmp.fixture`** — the twin leak, and its cause. a fixture used as `$HOME` mints one of these
- **`orphan`** (sense F) — what it becomes the instant its spawner exits
- **`class`** — why no per-member threshold sees the population
- **`prune`** — the verb that bounds it, and the reason the predicate is three-part
- **`leak`** — the growth test; this population is the case that taught the sample floor

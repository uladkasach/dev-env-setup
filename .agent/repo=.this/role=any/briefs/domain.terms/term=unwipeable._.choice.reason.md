# domain.term.choice.reason: unwipeable

## .etymology

built directly off `term=wipe` with the plain `un-…-able` shape, and that is the argument for it:
the property has no sense apart from the act. a resource is not unwipeable in the abstract — it
is unwipeable **with respect to a wipe that would otherwise match it**.

⚠️ this is why a standalone word (`sacred`, `immortal`, `protected`) reads worse however much
prettier it is. each of those claims a property of the resource; this one names a relation between
a resource and an act, and the relation is the whole content.

## .disputes

### dispute: pinned  —  raised 2026-09-06  —  status: RESOLVED (keep `unwipeable`)

- claim      = "pinned buffers" is short, idiomatic, and immediately legible — a pinned tab, a
               pinned message, a pinned pane. every reader knows it means "do not remove this".
- counter    = `pin` is **already spent** in this repo, on a concept with no relation to this one:
               the exact identity of a fetched artifact (`term=pin`, three shapes — version, hash,
               commit — across 7 bundles and `grove.web.sh`). that term exists to serve
               `rule.require.verify-binary-downloads` and the deterministic clause of
               `rule.require.one-command-provision`.
               to spend the word twice puts "the tmux tpm commit pin" and "the pinned minimap
               buffer" in one vocabulary, and a reader who greps `pin` gets two unrelated
               subsystems. that is `ubiqlang.ambiguous-from-overload` exactly.
- resolution = keep `unwipeable`; record `pinned`, `protected`, `immortal`, `sacred`, `keep` as
               forbidden synonyms. dispute closed.

## .evidence

### the property is about the OWNER, and that is what makes it unreadable from the resource

measured 2026-09-06. the cached buffer and a leaked minimap buffer are indistinguishable by every
property a predicate can read:

| | cached | leaked |
|---|---|---|
| filetype | `neominimap` | `neominimap` |
| buftype | `nofile` | `nofile` |
| modified | false | false |
| **rebuilt after delete** | **never** | on the next refresh |

only the last row separates them, and it is a fact about `neominimap`'s code, not about the
buffer. ⇒ **the exclusion must be a LIST, authored per owner.** no predicate can derive it, and a
smarter predicate is the wrong instinct.

### why `leaked` / `structural` lost, though they were the candidates

both were considered when the defect was diagnosed, and both were deliberately deferred rather
than paved (`progress.md`, round of 2026-09-06). the dop that shipped chose neither.

the reason: `leaked` and `structural` describe **what a resource is**, and the property that
decides is **what its owner does**. a resource can be structural to its plugin and still get
rebuilt; a resource can be a leak and still be cached. the axis those two named is correlated with
the real one and is not the real one.

⇒ the deferral was correct, and it resolved to a third word. **a term deferred for want of a
declaration is not a term postponed — it is a term whose right name was not yet visible.**

## 🛑 .the term is DECLARED and the contract is UNCLAMPED — stated plainly

the dop `get_buffers_unwipeable` ships, and the round that shipped it proved the *predicate* by a
probe that **re-implemented** the exclusion inline rather than call the function:

- the probe built its own `keep` table
- the shipped code builds one in `get_buffers_unwipeable()`

that is one set with two readers — `gotcha.a-check-that-cries-wolf-gets-silenced`, m.9 — and the
half that runs in anger is the half no arm touched. if the shipped `require` path is wrong or the
field is renamed upstream, the probe stays green and the box stays broken.

⚠️ two further gaps of the same round, recorded so a later reader does not mistake the evidence
for more than it is:

1. **`trip_breaker` itself never ran.** no arm crossed the 1.2GB threshold, so the ORDER claim —
   read the keep-set before the disable — is reasoned, never measured.
2. **the probe was discarded.** it lived under the gitignored `.play/temporary/` and was deleted,
   where `rule.forbid.repair-plays` exception 2 says a discrimination probe belongs **tracked and
   permanent**. so this contract re-proves itself on no box.

⇒ the owed clamp is `prove.breaker-spares-cached-buffers`: it must call the shipped function, and
it must drive a real trip.

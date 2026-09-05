# domain.term.choice.reason: drift

## .etymology

from the nautical sense: a vessel that holds its course and is carried aside by a current it
cannot feel. that is the concept exactly — **the loss is real, continuous, and imperceptible
from the deck.** a crew that asks "are we still afloat?" gets a yes every time they ask, right
up until landfall.

the word arrives in this repo already loaded, from `configuration drift` in the ops
literature, and this domain narrows it: there, drift is a machine that wanders from its
declaration. here that is one of two axes, and the *declaration-vs-declaration* axis (two
lists of one fact) turned out to be the more expensive of the two.

## .why the two axes stayed ONE term

the obvious split is `drift.declaration` and `drift.install`, on the grounds that they take
opposite repairs — deletion versus convergence. it was declined for three reasons:

1. **the DETECTION is identical.** both are found by a content compare and missed by an
   existence test. a traveler who learns the word learns one test that catches both, and a
   split would teach the test twice.
2. **the axes convert into each other.** the 2026-08-11 install drift existed *because* a
   push put a second copy of `src/` on the box beside the checkout — a declaration drift that
   presented as an install one. to name them apart would suggest a reader must pick, when the
   honest answer is usually "both, and the second caused the first".
3. **the repo already carries the split elsewhere.** `term=declared` and `term=live` name the
   two sides precisely, so `drift` between a declared and a live artifact is expressible with
   no new word. a sub-term would restate what the extant pair already says.

⇒ one term, two axes, named in the say file's table. the moment a reader needs to be precise,
they reach for `declared` / `live`, which exist.

## .disputes

### dispute: stale — raised 2026-08-11 — status: RESOLVED (keep both; they are distinct)
- raised.by  = mechanic
- claim      = `stale` is the plainer word and is already used across this repo's verify
               messages ("the STALE copy names a wrong slug"). one word would be leaner than
               two, and `drift` is the more abstract of the pair.
- counter    = they name different things. `stale` is an adjective on ONE side and presumes a
               verdict — that this side is the old one. `drift` is a noun on the RELATION and
               presumes none. the difference is load-bear because the machine is not always
               the side that loses: a human who edits `~/.bash_aliases` in place has drifted
               it from the checkout, and there the live copy holds the NEWER bytes. this repo
               settles that case by fiat rather than by recency
               (`rule.require.repo-as-source-of-truth`), and a verify that said "your live
               copy is stale" would assert a falsehood about the timestamps while it reached
               the correct verdict for the wrong reason. the shipped message says "DIFFERS
               from the checkout" precisely to avoid that claim.
- resolution = keep both. `drift` = the relation; `stale` = the side the declaration outranks.
               `stale` is recorded as a forbidden SYNONYM (it may not stand in for `drift`)
               while it stays a legitimate word in its own narrower sense.

### dispute: divergence — raised 2026-08-11 — status: RESOLVED (keep `drift`)
- raised.by  = mechanic
- claim      = `divergence` is more precise and less metaphorical
- counter    = it names the end state and drops the two properties that make this term worth
               a place: that the process is CONTINUOUS, and that it is UNFELT. a component can
               diverge loudly — a type error is a divergence. drift is the kind you find only
               when you go and look, which is why the say file's whole middle section is about
               what an existence test cannot see.
- resolution = keep `drift`; record `divergence` as a forbidden synonym.

## .evidence

### measurement 1 — install drift, `grove-ahbode-v20260810`, 2026-08-11

a `git.grove.push --from src` landed a new checkout and ran no phase. the ladder's rung 4
then reported 123 ✔ · 2 ✋ on the camper, where the prior run had been 125 ✔ · 0 ✋:

```
✋ the installed credential helper DIFFERS from the checkout
✋ ~/.bash_aliases DIFFERS from the checkout
```

both artifacts **existed and ran**. `git` authenticated; the aliases resolved. only a content
compare could see it, and two `configure.upsert` runs closed both.

⚠️ the instructive part is what the drift would have COST had the check been an existence
test. the helper's own message says it: *"it runs, so git authenticates — with whatever slug
the STALE copy names. a wrong slug reads as an empty rack, never as an out-of-date file."*
the observable symptom of that drift is `absent 🫧` from keyrack — a credential problem, on a
box whose credentials are perfect.

### measurement 2 — declaration drift, `src/bash_aliases.sh:315`

two lists of the same bundle set diverged; one had silently dropped `brains`. groves therefore
ran the robot brains with **no config at all**, and the file's own comment names the property
this term is built on: *"the drift is quiet by construction."*

the repair was not to reconcile the lists. it was to **delete one** — the directory became the
inventory, so no list is left to drift. that asymmetry (declaration drift is fixed by removal,
install drift by convergence) is the only place the two axes come apart, and it is recorded in
the say file's table.

### the counter-example — a drift check with two writers, `3.2.theme`

a drift check over `cosmic.gtk.desert.css` reported drift on every healthy box, because COSMIC
regenerates that destination from the imported `.ron` and stamps it `/* GENERATED BY COSMIC */`.

⇒ a drift check carries an unstated precondition: **exactly one writer owns the destination.**
where two do, every diff is noise, the check cries wolf, and a reader learns to ignore it
(`gotcha.a-check-that-cries-wolf-gets-silenced`, `rule.forbid.two-writers-on-one-artifact`).
this is the reason `cosmic.gtk.desert.css` is an unowned copy rather than an `asset`
(`term=asset._.choice._.md`).

## .see also
- `term=declared` / `term=live` — the two sides the install axis runs between
- `term=asset` — a file exactly one phase copies and one verify `cmp`s; drift is what that
  `cmp` exists to catch
- `term=claim` — a ✋ is how drift is REPORTED; drift is what the ✋ is about
- `rule.require.bundle-as-sole-declaration` — the deletion fix for the declaration axis
- `rule.require.repo-as-source-of-truth` — why the declaration wins regardless of recency

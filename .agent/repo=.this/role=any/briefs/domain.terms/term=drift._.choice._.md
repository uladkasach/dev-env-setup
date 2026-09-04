# domain.term: drift

term.chosen   = drift
term.kind     = noun (and verb — *two lists drift*)
term.synonyms.forbidden:
- divergence   (latinate and static; it names the STATE and loses the silence, which is
                the whole reason the word is load-bear here)
- skew         (clock jargon, and it implies a measurable offset; drift has no magnitude)
- out-of-sync  (`sync` is RETIRED in this domain — `term=git.repo.pull._.choice._.md`)
- rot          (implies decay by TIME alone; drift is always caused by a write somewhere)
- mismatch     (a mismatch is read at ONE moment; drift is the history that produced it)
- stale        (NOT a synonym — it names one SIDE; see `.stale is not drift`)

## .what
two things that must agree, no longer agreeing — **and no reader can tell.**

the third clause is the term. a difference a check reports is a `claim` (✋). drift is what
that claim is *about*, and its defining property is that it is **invisible to an existence
test**: the file is there, the alias runs, the binary resolves. everything answers, and one
of them answers from an older revision.

## .the two axes it runs on

| axis | what disagrees | measured |
|---|---|---|
| **declaration drift** | two homes of ONE fact — two lists, two parsers, two literals of an address | `bash_aliases.sh:315` — one of two bundle lists had silently dropped `brains`, so groves ran the robot brains with no config at all |
| **install drift** | the LIVE copy vs the DECLARED source | 2026-08-11 — a pushed `src/` left the installed helper and `~/.bash_aliases` an older revision than the checkout |

these are one concept on two axes, not two concepts. both are *"two things that must agree,
silently no longer agreeing"*, and both are caught the same way: **compare the content, never
the existence.**

⚠️ they differ in the FIX, and only there:

- declaration drift is repaired by **deletion** — remove the second home, so no list is left
  to drift (`rule.require.bundle-as-sole-declaration`, and the reason the bundle tree IS the
  inventory)
- install drift is repaired by **convergence** — re-run the upsert, which is what a
  `configure.upsert` exists to do

## .stale is not drift

`stale` names ONE side, and presumes a verdict on which side is right. `drift` names the
RELATION and presumes none.

that distinction earns its keep because the losing side is not always the machine. a human
who edits `~/.bash_aliases` directly has drifted it from the checkout — and there the *live*
copy holds the newer bytes. this repo answers that case by fiat, not by recency: the
declaration wins, always (`rule.require.repo-as-source-of-truth`), which is exactly why the
verify's message says *"DIFFERS from"* rather than *"is older than"*.

## ⚠️ .why an existence test cannot see it

this is the whole reason the concept is worth a word:

```sh
# 👎 passes forever on a box whose installed copy is a year old
[[ -x ~/.local/bin/git-credential-keyrack ]]

# 👍 the only test that can see drift
cmp -s "$src" "$dst"
```

measured 2026-08-11 on `grove-ahbode-v20260810`. a `src/` push installed no phases, so:

```
✋ the installed credential helper DIFFERS from the checkout
   ⇒ it runs, so git authenticates — with whatever slug the STALE
     copy names. a wrong slug reads as an empty rack, never as an
     out-of-date file
✋ ~/.bash_aliases DIFFERS from the checkout
   ⇒ the symptom is 'my edit had no effect', which a human blames on the edit
```

⚠️ read what each ⇒ says the drift COSTS. neither surfaces as "this file is old". one
surfaces as an empty credential rack, the other as an edit that did no work — and in both
cases the human debugs the wrong subject entirely. **drift never reports itself; it reports
as some other component's defect.**

## .the rule it yields

> a `*.verify` over an artifact this repo declares must compare CONTENT. an existence test
> is not a verify of an asset — it is a verify that something is there.

that is why config artifacts are **copied** rather than symlinked (`repo.overview.md`): a
symlink cannot drift, and so cannot be caught drifting — it simply follows in silence, which
hides which revision a box actually ran.

## .refs
- src/grove.provision/2.shell/2.2.git/configure.verify.sh        # install drift, measured 2026-08-11
- src/grove.provision/2.shell/2.7.aliases/configure.verify.sh    # the same, same run
- src/grove.provision/1.system/1.8.tmpfiles/provision.verify.sh  # `read the drift: diff $src $dst`
- src/grove.provision/3.cosmic/3.2.theme/configure.upsert.sh     # a drift check that CRIED WOLF — see below
- src/bash_aliases.sh                                           # declaration drift, the `brains` incident
- src/grove.for.sh / src/grove.env.sh / src/grove.pkg.sh     # "two homes drift", the deletion fix
- src/bundle.upgrade.sh                                         # derived in one place, so the two cannot drift

⚠️ `3.2.theme` is the counter-example worth reading: a drift check over
`cosmic.gtk.desert.css` reported drift on **every healthy box**, because COSMIC regenerates
that path from the imported `.ron`. a drift check needs one more precondition than it looks —
**no other writer may touch the destination** (`rule.forbid.two-writers-on-one-artifact`).
where two writers exist, the diff is noise, and a check that cries wolf gets silenced
(`gotcha.a-check-that-cries-wolf-gets-silenced`).

## .reason
see the ref-level cluster beside this choice:
- `term=drift._.choice.reason.md` — the etymology, why the two axes stayed one term rather
  than splitting, and the `stale` dispute

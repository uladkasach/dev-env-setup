# domain.term: floor

term.chosen   = floor
term.kind     = noun
term.synonyms.forbidden:
- minimum      (bare arithmetic. it names the NUMBER and says no word about what a shortfall
                means, which is the whole reason this concept is kept)
- threshold    (names a level crossed in either direction. a floor is one-sided by design — a
                set that grew is never its concern)
- sanity check (`check` is the forbidden synonym of `claim`'s act — `term=claim._.choice._.md`)
- guard        (bhrain's route vocabulary binds `guard` to a stone's validation file, and
                `term=gate` already refused it for that reason)
- assertion    (test-framework vocabulary. a floor runs in a play on every box, not in a suite)

## .what
a **gate** on the SIZE of a set a play discovered: it halts when the discovery returns fewer
subjects than the play knows to be declared.

```
✋ discovered only 1 flatpak app id(s); at least 4 are declared
```

a floor exists because an empty or short discovery prints exactly like a clean run — a loop
over zero rows reports zero failures (`rule.forbid.failhide`,
`gotcha.grepsafe-glob-goes-quiet`).

## .it is a KIND of gate, not a rival word
`gate` is the ROLE — a check whose answer decides whether later work runs — and a floor holds
that role (`term=gate._.choice._.md`). `floor` names WHICH gate: the one over a discovered
count. use `gate` for the role, `floor` for this member; neither replaces the other.

## 🛑 .a floor DETECTS and cannot ATTRIBUTE
the load-bear fact, and the reason the word is kept. a floor that fires leaves two candidate
causes and no way to rank them:

| the cause | the repair |
|---|---|
| the tree dropped a subject | none — the play is right, and should be re-floored |
| the play's reader went blind | fix the reader; the tree was well all along |

⇒ so a floor is **half a guard**. its partner is a `fixture` — a `direction 0` that hands the
reader one file per declared shape and demands the right verdict on each
(`term=fixture._.choice._.md`).

> **the floor detects; the fixture attributes.** a play that discovers its own subjects owes
> both, and neither substitutes for the other.

## .and it is blind to the OTHER way a set goes wrong
a floor watches only for a set too SMALL. a set too LARGE — a phantom subject taken out of
prose — reports **✔** and pads the very count a reader uses to judge coverage
(`term=bite._.choice.reason.md`, `.the set has TWO ways to be wrong`).

## 🛑 .a floor CALIBRATED on a blind reader ratifies the blindness
the sharpest limit, and the one that voids the promise above. a floor's number comes from the
reader's own first read — so where the reader was ALREADY blind to a whole shape of its
subject, the floor is set at the blind count and reports ✔ forever, on that count.

the set never shrank. **it was never that size.** so the question a floor answers — *did the
set shrink?* — is the wrong question, asked with total confidence.

measured 2026-08-14: `prove.see-alsos-point-somewhere` read 170 of 477 pointers, because its
tokenizer emitted backticked paths only while `template.domain-term.md` declares the bare
shape. a floor at 170 would have been green on every run, and its fixture could not help
either — every arm was written backticked, so it inherited the reader's blind spot verbatim
(`gotcha.a-check-that-cries-wolf-gets-silenced`, m.12).

⇒ so the trio has a **precondition**, not a fourth member: before a floor is set, ask in how
many forms the subject is written and which the reader matches. what answers it is a row
planted into the LIVE subject, in the form that subject actually uses — if the count does not
move, the reader cannot see that form, and every row written that way is unproven.

## .reason
see the ref-level cluster beside this choice:
- `term=floor._.choice.reason.md` — etymology, the rejected synonyms, and the measurement that
  earned the detect/attribute split

# domain.term.choice.reason: mask

## .etymology
from the photographic and stencil sense: a mask covers a region so an operation applied to the
whole passes over that region untouched. that is exactly the shape here — `gsub` is applied to
the whole line, and the masked columns are the ones it may not act on.

the word is chosen for what it does to the LATER operation rather than for what it does to the
bytes. the bytes change (a separator becomes `\001`); the point is that a cut no longer falls
there.

## .why not `escape`
`escape` is the first reach and it points the wrong way. to escape is to take a character shell
would ACT on and make it literal. here the character is already literal — it is inside quotes,
so shell will never act on it — and the operation exists to tell a naive READER what shell
already knows. `escape` would name a repair of the input; this is a repair of the reader.

## .why not `strip`
`strip` claims a removal, and a removal would be a defect. two consumers report a **column**:

```
   ✋ 5.devtools/5.1.node/provision.upsert.sh:438
```

and one reports the segment text itself. a mask that shortened the line would move every column
to its right, so the site a play names would not be the site a human opens.

⇒ the length invariant is load-bear, and `mask` is the only candidate word that implies it.

## .disputes
### dispute: neutralize — raised 2026-08-14 — status: RESOLVED (keep `mask`)
- raised.by  = the author of `_.shell-tokenize.lib.sh`
- claim      = the lib's own header says "neutralize a separator that sits inside a quoted
               string", so `neutralize` is the word already in use, and it is plainer
- counter    = that sentence is the header's DESCRIPTION of what the mask achieves, and it can
               remain so. if `neutralize` becomes the term, the header has no word left to
               explain the term with — it would read "neutralize neutralizes a separator". a
               term and the prose that glosses it may not be the same word
- resolution = keep `mask`; `neutralize` stays the ordinary verb the header glosses it with,
               and is a forbidden synonym of the term.

## .evidence

### measurement 1 — the cut that condemned an echo, 2026-08-14
`prove.offbox-reads-are-bounded` split at every `&&` with no mask. this line is prose:

```sh
echo "      read why: fnm use <version> && corepack install -g pnpm@$pnpm_want" >&2
```

the cut fell inside the quotes, the tail became a segment whose first word was `corepack`, and
the play condemned `5.1.node/provision.upsert.sh:438` as an unbounded registry call — with a
`fix:` that named a bound the call already carried. the repair is nine lines of awk, and it
moved direction 1 from one false ✋ to `✔ no phase reaches off this box unbounded`
(`gotcha.a-check-that-cries-wolf-gets-silenced`, m.8).

### measurement 2 — the SINGLE quote, and four copies that disagreed
`mask_quoted` existed four times before the lib did, and the copies had **already diverged**:
`prove.early-exit-readers-are-safe` tracked the single quote and the other three did not. so
this line —

```sh
apt-get update | grep -vE '^(Hit|Ign)'
```

— was ONE command to one reader and TWO to another, in the same repo, on the same day. each
looked correct read alone.

⇒ that is the m.9 shape at the level of an OPERATION rather than a play: one concept, four
declarations, free to drift with no signal. the lib is the single declaration, and the merged
mask tracks both quote kinds — which is strictly stronger than any of the four it replaced.

### measurement 3 — the apostrophe that would blind the rest of the line
the two toggles must be mutually exclusive, and the reason is a comment this repo actually
writes:

```sh
# the seats own PATH is what a program reads
```

with an ungated single-quote toggle, that apostrophe opens a string that never closes. every
separator to the end of the line is masked, so a real `| sudo tee` on that same line would be
invisible — a false ✔, from a comment.

⇒ the gate is what keeps the mask honest. it is the one branch in the operation whose absence
is silent in both directions, so an unguarded toggle is a **failhide** device wearing a
tokenizer's clothes.

### the boundary — `$(` is deliberately NOT masked
a command substitution begins a real command even inside a quote:

```sh
echo "the account is $(aws sts get-caller-identity --query Account --output text)"
```

so `depth` tracks it, and separators within it still cut. this is the single place the mask
declines to act on a character inside quotes, and it is correct: shell would act there too.

## .see also
- `term=segment._.choice._.md` — what the mask makes possible
- `term=prose._.choice._.md` — what the mask spares
- `gotcha.a-check-that-cries-wolf-gets-silenced` — m.8 (the unmasked cut) and m.9 (one set,
  two readers, free to disagree)

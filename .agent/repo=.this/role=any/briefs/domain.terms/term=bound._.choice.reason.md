# domain.term.choice.reason: bound

## .etymology
from `rule.require.bounded-probes-in-verifies`, which has spelled the concept `bounded` since
2026-07-30. the ADJECTIVE was in use across the repo for six weeks before the NOUN was
itemized — which is the ordinary way a term goes unrecorded: nobody has to define a word
they only ever use as a modifier.

it was itemized on 2026-08-13, the day the adjective was measured to mean two different
things at two call sites.

## .why NOT `timeout`, which is what everyone says
`timeout` is the obvious word and it fails on two counts, each with a live example in this
repo:

1. **it names one mechanism.** `curl --max-time 3` is a sound bound and involves no
   `timeout` binary. a rule spelled "wrap it in timeout" reads as a demand for the wrapper,
   so a correct call gets flagged and a reader learns the check lies.

2. **it cannot discriminate.** `--connect-timeout` and `--max-time` are both spelled
   *timeout*, and only one of them is a bound. a word that a defect and its fix share is a
   word that hides the defect.

⇒ `bound` carries the sense that matters — a LIMIT ON THE WHOLE — and leaves `timeout` free
to name the mechanism it actually is.

## .disputes

### dispute: `ConnectTimeout` counts as a bound — raised 2026-08-13 — status: RESOLVED (it does not)
- raised.by  = `5.10.repos/configure.upsert.sh`, in a comment
- claim      = *"`ConnectTimeout` caps a dead network at 5s rather than ssh's default
               minutes"* — and it cited `rule.require.bounded-probes-in-verifies` beside the
               claim, so it read as a rule already satisfied
- counter    = that rule's own enforcement says the opposite in those words: *"a
               `--connect-timeout` (or a bare `ConnectTimeout`) offered AS the bound =
               blocker; it bounds the benign case and leaves the stall unbounded."*
               ssh has no total-time option at all, so the total had to come from outside.
- resolution = `ConnectTimeout` is a partial cutoff, never a bound. the site now reads
               `timeout 20 ssh -o ConnectTimeout=5 …` — BOTH, since they cap different
               halves. `ConnectTimeout` is recorded as a forbidden synonym.

⚠️ **the instructive part is not the verdict, it is the shape.** the comment named the right
rule, quoted its subject correctly, and inverted its conclusion. a claim that cites a rule is
HARDER to catch than one that cites none, because the citation is what a reviewer checks for
— and once it is present the reviewer stops
(`gotcha.my-own-note-became-my-evidence`, `gotcha.a-check-that-cries-wolf-gets-silenced` m.6).

### dispute: every tool that touches a socket owes a wrapper — raised 2026-08-13 — status: RESOLVED (no)
- raised.by  = the first cut of `prove.offbox-reads-are-bounded`
- claim      = a call that leaves the process can wait forever, so each one owes a `timeout`
- counter    = it produced **41 rows**, and the boundary's own header disproved a third of
               them: `grove.web.sh` states that apt, flatpak, and pnpm each carry their own
               transport, retries, and bounds, and the rule's table gives `aws` a **60s**
               default. so the check condemned `aws` on the strength of what `curl` does.
- resolution = a tool is condemned only where its own default is **measured** to be
               unbounded. the set became `curl`, `git`/http, `ssh`, `tmux`, `docker` — 9 real
               sites — and the other 21 are reported and judged by nobody until somebody
               stalls a listener at them.

⚠️ and the counter-argument to the counter-argument was weighed and refused: *"wrap them all,
to be safe."* a wrapper is not free. a `timeout 60` around `pnpm install -g` fails a fresh box
on a slow link that would otherwise have converged — so a guessed bound trades a hazard nobody
has seen for a regression on the one run this repo cannot re-test.

⇒ **a bound is a number, and a number is a claim about how long the far end may honestly
take.** to invent one is to assert a fact nobody measured.

## .evidence
- the four-way table in `term=bound._.choice._.md` (`.what`) is read from
  `rule.require.bounded-probes-in-verifies`'s own tool table, not re-derived
- nine sites measured and repaired 2026-08-13, listed in that rule under `.measured`
- `prove.offbox-reads-are-bounded` direction 2 holds an arm per shape: a total bound, a
  partial one, a tool-supplied one, and a call that reaches nobody at all

# domain.term: engage

term.chosen   = engage
term.kind     = verb
term.synonyms.forbidden:
- bite        (names a CHECK's power to REFUSE; a guarantee holds no verdict to refuse with)
- work        (a guarantee that never engages still "works" by any ordinary read)
- fire        (says it ran, not that it did the work AND stood aside when it should)
- trigger     (same gap as fire, and already reads as an event)
- activate    (names a state change, not that the effect landed)
- kick in     (informal, and names only the engaged half of the pair)
- apply       (already the name of the write MODE — `--mode apply`)
- hold        (already the word for a subject that sits in its declared state)

## .what

a **guarantee** engages when it has been seen to do its work against a condition
deliberately created, and to stand aside against a condition known absent.

so `engage` is a claim about the GUARANTEE, never about the box. it is `bite`'s
counterpart, one axis over:

| | the subject | proven by |
|---|---|---|
| a check **bites** | its power to REFUSE | red on a real break, green on a real pass |
| a guarantee **engages** | its power to ACT | it works when the condition holds, and stands aside when it does not |

## .why a word of its own, beside `bite`

a check answers with a VERDICT, so both its directions are verdicts and `bite`
covers them. a guarantee answers with an EFFECT and returns no verdict at all —
`pkg_await_apt_lock` returns 0 whether it waited five minutes or zero seconds, on
purpose, because the caller is the check.

so `bite`'s test cannot be run against it. there is no red direction, and by
`bite`'s own invariant a `prove.*-bites` play with no red arm is misnamed.

## 🛑 .the third hazard, which `bite` has no counterpart for

a guarantee can be wrong in a way a check cannot:

| the guarantee… | costs |
|---|---|
| never engages | the defect it prevents returns, silently — `bite`'s false ✔, one axis over |
| engages when it should not | a **tax**: every run pays time it never owed, and no verdict is wrong, so no check reddens |

the second row is why `engage` demands BOTH arms. a wait that always waits is not
a false ✋ — it produces no verdict to be false — it is a levy nobody voted for and
nobody can see.

## .refs
- src/grove.pkg.sh                                              # `pkg_await_apt_lock`, the term's first subject
- .play/permanent/prove.apt-lock-wait-engages.play.sh            # the play that proves it, both arms
- .agent/repo=.this/role=any/briefs/domain.terms/term=bite._.choice._.md      # the counterpart
- .agent/repo=.this/role=any/briefs/domain.terms/term=guarantee._.choice._.md # what engages

## .reason
see the ref-level cluster beside this choice:
- `term=engage._.choice.reason.md` — etymology, the dispute against `bite`, evidence

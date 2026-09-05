# domain.term.choice.reason: bare

## .etymology

`bare` = uncovered. the cover here is the WRAPPER — the flag, the gate, the boundary, the
operand that supplies a guarantee the call cannot supply itself. so a bare call is one
stripped of what made it safe, and the word carries no judgment about whether the strip was
deliberate.

that neutrality is why it fits both poles. `--bare` is a choice; a `✋ bare sudo` row is a
defect; and `bare` describes the STATE in each, so the context supplies the polarity.

## .why it was itemized late — and what that cost

the word was in use across at least seven clamps and one declared flag before it was ever
paved (2026-08-15). it drew no attention precisely because it never drifted: every author
reached for the same word unprompted, so no synonym pair ever surfaced to force the question.

⇒ **a term can be load-bear and invisible at once.** the trigger for itemization is not
"somebody used a synonym" — by then the vocabulary has already split. it is "this word
carries a concept the clamps share", and that is visible only when the clamps are read
together, which is what this round did.

## .rejected synonyms

| word | why not |
|---|---|
| `raw` | already taken, and for a different concept — the tokenizer's `raw[i]` is text BEFORE the mask is applied, a fact about a READER's stage rather than about a call's guarantees. to overload it would blur a parse phase with a safety property (`rule.forbid.domain-term-ambiguity`) |
| `naked` | same sense, and it reads as a judgment. `bare` states a fact; `naked` editorializes, which is wrong at a `--bare` flag the caller chose on purpose |
| `plain` | it is what `git.grove.send`'s own comment says — *"plain ssh, no duct"* — and it names the TRANSPORT rather than the absence. plain ssh is still plain ssh when it is correct; a bare call is defined by what it lacks |
| `unguarded` | it is true of a bare sudo and false of `--bare`, which is guarded by a required `--why`. a word that fits one pole and not the other would force the split this term exists to prevent |
| `direct` | it says a call took the short path and says none of what the path skipped. `git.grove.send --bare` is direct AND bare; `env -C … rhx keyrack` is direct and NOT bare |

⚠️ `unwrapped` was weighed and left OFF the forbidden list, deliberately. the shared
tokenizer declares `unwrap()` as its own operation — the peel of a wrapper to reach the
command word — and that is a legitimate, distinct use about the READER. to forbid the word
would condemn a correct function name (`gotcha.a-check-that-cries-wolf-gets-silenced`, m.7:
a pattern that reaches a site where the correct value is different).

## .evidence

discovery — the clamps were read together, and every one names an absent wrapper with the
same adjective:

```
prove.timeouts-kill-what-they-cut   "a bare timeout sends TERM; only -k adds a KILL"
prove.sudo-is-gated-or-nonintera    "$n_bad ungated bare sudo call(s)"
prove.plays-name-what-they-join     "✔ no bare join in any play or skill"
prove.rack-reads-stand-in-a-root    emits `BARE` as a literal state in its tsv
_.shell-tokenize.lib.sh             "is it a bare apt write?"
git.grove.send.sh                   `--bare` — the declared flag
rule.forbid.bare-globs-in-dual-shell-files
```

seven subjects, seven different wrappers, one word — and no author coordinated it.

## .the invariant it carries

> a `bare` call is a DEFECT unless it names its trigger.

this is what binds the term to `rule.require.exemptions-name-their-trigger`. `--bare` without
`--why` is refused; `bare-timeout-on-purpose:` with no reason after the colon is flagged
rather than exempted, and `prove.timeouts-kill-what-they-cut` carries an arm (`j_marked_bare`)
that proves it. the term and the rule are the same claim, one as vocabulary and one as gate.

## .disputes

none raised.

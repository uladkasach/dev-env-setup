# domain.term.choice.reason: verdict

## .etymology

latin *vere dictum* — "truly said". in law a verdict is the judgment of the party who
**heard the evidence**, and it is void when returned by anyone else. that provenance is
the whole point here: the word carries WHO spoke, where every rejected candidate carries
only WHAT was spoken.

that distinction is the one this repo kept losing. `git.grove.send` returned a number,
the number was true, and it was the SEND's number — so a caller that read it as the
command's had a fact about the postman filed as a fact about the box.

## .why the rejected words are rejected

| word | why it fails |
|---|---|
| `result` | the likeliest reach, and the emptiest. it names the shape of what came back and is silent on whose it is — which is precisely the confusion the term exists to end |
| `status` | already spoken for, three times over: `systemctl status`, a pr check's status, a duct pane's status. to add a fourth sense is `rule.forbid.domain-term-ambiguity` by construction |
| `outcome` | reads as the state of an EPISODE — "the outcome of the apply". a verdict is narrower and sharper: one judgment, on one subject, by one party |
| `answer` | close, and it was the word in use for a week. it fails on its OPPOSITE: the opposite of an answer is silence, and the case that costs is not silence — it is a **confident wrong number**. "no verdict" names that; "no answer" does not |
| `code` | an exit code CARRIES a verdict. 97 is a code that carries the absence of one. to spell both `code` erases the sentence that makes 97 legible |
| `response` | belongs to the wire. an http response is a fact about a transaction, which is the report half of the pair |
| `report` | correct — for the OTHER half. it is the transport's word, and this cluster's job is to keep the two apart, not to merge them |

## .the measurement that made it load-bear — 2026-08-13

`--reply` had been added so a verdict could ride the duct
(`gotcha.the-duct-returns-the-send-not-the-answer`, RESOLVED). it returned the command's
own exit code, so its OWN faults had to borrow from that same range — and they took 1
and 2.

then two runs overlapped. a backgrounded `git.grove.provision test` still held the pane, so a
second run's probes were all refused:

| what happened | what the caller got |
|---|---|
| `test -f x` ran and judged false | 1 |
| the duct refused the send, so it never ran | 1 |

`git.grove.ready.verify` read the second row as the first and halted a healthy grove with

```
✋ seat '…' holds src/ but no package.json beside it
```

plus a push command for a file that was present the whole time, 610 bytes, listed on
that box one command later. a **false ✋**, and the corrosive kind
(`gotcha.a-check-that-cries-wolf-gets-silenced`).

⇒ the repair was one reserved code, and the sentence that justifies it is one line long:

> **97 means there is no verdict.**

## .why ONE code, and not a table

the first design sketched a code per fault — refused, quiet, elapsed, unreadable rc,
malformed args. it was rejected before it shipped:

- those five differ in **cause** and agree on the only fact a caller acts on
- a table must grow, and a caller written before the growth reads the new member as an
  ANSWER — which is the very defect this closes, reintroduced on a schedule

a single reserved code cannot rot that way. 0-2 are everyday, 126-127 are
cannot-execute and not-found, 128+n is a signal; 97 sits in the unused middle and is
**ours**.

## .why a reserved code, and not a marker in the command

the cheaper repair wraps the remote command:

```sh
{ cmd ; } && echo __TRUE__ || echo __FALSE__     # 👎 cannot be delivered
```

`--what` takes ONE step, and `git.grove.send` refuses any `;`, `&&`, or `||` in its raw
text — a control that exists because the pretooluse hooks read only the outer command.
to encode past that guard would defeat it.

⇒ and the knowledge was never the command's to carry. the SEND already knew — it checks
its own delivery. it simply had no way to SAY so (`rule.require.solve-at-cause`).

## .the caller's obligation, which the word makes stateable

```sh
out="$(rhx git.grove.send "$seat" --reply --what "$cmd")" || rc=$?
[[ "$rc" -eq 97 ]] && halt_naming_the_duct     # never judge the box
return "$rc"                                   # otherwise it IS the verdict
```

⚠️ `|| rc=$?`, never `|| true` — a `true` discards the very code this reads and leaves 1
indistinguishable from 97 again. that mistake was made in this refactor's first draft
and caught before it landed.

## .evidence

- discovery: the word was already the only way to say the sentence, and had appeared in
  `gotcha.the-duct-returns-the-send-not-the-answer` for days before it was itemized
- 2026-08-13: it became a **declared name** — `GROVE_SEND_NO_VERDICT=97` — which is the
  itemization rule's own trigger (`rule.require.domain-term-itemization`)
- invariant: `prove.duct-contention-faults` drives each helper through a true verdict, a
  false verdict, and a refusal, so the third state is observed rather than asserted

# domain.term: verdict

term.chosen   = verdict
term.kind     = noun
term.synonyms.forbidden:
- result      (names WHAT came back, and not WHOSE it is — the exact gap)
- status      (already taken: a systemd unit, a pr check, a duct pane each have one)
- outcome     (reads as the state of an EPISODE; a verdict is the subject's own judgment)
- answer      (correct in spirit, but its opposite is "silence" rather than "no verdict")
- code        (an exit code is the CARRIER of a verdict, never the verdict itself)
- response    (a transport's word — an http response is a fact about the wire)
- report      (what the TRANSPORT gives; the pairing this term exists to keep apart)

## .what

a **verdict** is the judgment a COMMAND passes on its own subject — the thing it was
asked to decide, spoken by the party that did the deciding.

so the subject of a verdict is always the command. a transport that says "delivered"
has produced a **report**, not a verdict, however truthful it is.

## .the pairing the word exists to keep apart

```
report   → a fact about the CARRIAGE: the text landed, the pane took it
verdict  → a fact about the SUBJECT:  the file is absent, the digest matched
```

a caller that reads a report where it wanted a verdict has learned that the postman
arrived, and taken it as the letter's contents.

## .no verdict is a THIRD state

this is the whole reason for a word:

| the command… | there is… |
|---|---|
| ran, and judged true | a verdict |
| ran, and judged false | a verdict |
| **never ran** | **no verdict** — and that is not a false one |

a transport whose faults borrow the command's own codes collapses row 3 into row 2,
so a refusal reads as a finding. `git.grove.send --reply` reserves **97** for exactly
this: *there is no verdict; halt, do not judge the box*
(`term=duct.reply._.choice._.md`).

## .refs
- .agent/repo=.this/role=any/skills/git.grove.send.sh          # GROVE_SEND_NO_VERDICT=97
- .agent/repo=.this/role=any/skills/git.grove.operations.sh        # _ask_at / _shell_at read 97
- .agent/repo=.this/role=any/skills/git.grove.ready.verify.sh      # its rungs judge verdicts
- .agent/repo=.this/role=any/briefs/grove/reach/gotcha.the-duct-returns-the-send-not-the-answer.md
- `rule.forbid.failhide` — a SHIPPED brief of the mechanic role, so it is named rather
  than pathed. this row gave a path under THIS repo's briefs dir, where no such file
  is or was (`gotcha.a-check-that-cries-wolf-gets-silenced`, m.10)

## .reason
see the ref-level cluster beside this choice:
- `term=verdict._.choice.reason.md` — etymology, why `result` and `status` were refused,
  and the 2026-08-13 halt that made the third state load-bear

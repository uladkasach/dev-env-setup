# domain.term.choice.reason: detail

## .etymology

plain english, and it already means this: a detail is the fine-grained part of an account
that a summary omits. no gloss is needed, and the pair `summary`/`detail` reads symmetric at
the call site (`rule.prefer.symmetric-term-pairs`).

the repo already had `summary` and no counterpart, so every writer reached for **"the log"**
— which is the ambiguity this term retires. "the log" names both artifacts, so a sentence
like *"read the log"* is true of the file that answers and equally true of the file that
cannot.

chosen over:

- **"the log"** — the incumbent, and the defect. it is ambiguous between the two artifacts,
  and `rule.forbid.domain-term-synonyms` exists to stop exactly this overload
- **`output`** — names the STREAM, not the grain. a summary is output too
- **`verbose`** — names a FLAG a caller might pass, so it describes how the detail is
  obtained rather than what it is. and the detail here needs no flag: the tool writes it
  either way

## .evidence

### the defect it names — measured 2026-09-01, `grove-ahbode-v20260811`

`git.grove.provision test` halted at rung 4 with 6 failures, and its fix-text read:

```
  sort the failures by their ERROR STRING first — it names the subject:
    tail -60 /home/vlad/.local/state/…/suite.log
```

that file held **57 lines and not one error string**. what it held instead:

```
   │  ├─ stdout: .log/…/2026-09-01T21-46-32Z.stdout.log   ← the detail's PATH
   │  ├─ tests: 25 passed, 6 failed                       ← the summary
```

⇒ the gate captured the summary with `> "$SUITE_LOG"` and the detail stayed on the box.
both halves were written by authors who were each correct alone — the fix-text names the
right SORT, the capture takes the right STREAM — and together they send a reader to a file
that cannot answer (`gotcha.a-check-that-cries-wolf-gets-silenced`, m.9).

### 🛑 the property that makes it worth a term

> **a green run needs no detail.**

so the gap is invisible until a suite reddens — which is the one moment the reader has no
other source. a check that only fails when it matters most is the shape
`rule.require.errors-name-the-fix` exists to catch, and it went unseen here for as long as
the gate had never gone red on a real failure.

### the repair

the gate now fetches the detail onto the FAILURE path only, and says so when it cannot:

```sh
SUITE_ERR_REMOTE="$(sed -n 's/.*stderr: \(\.log[^ ]*\)$/\1/p' "$SUITE_LOG" | tail -1)"
```

⚠️ the else-branch is load-bear. an unfetched detail with no note reads exactly like a suite
that printed no errors (`rule.forbid.failhide`), so the absence is stated rather than left
for a reader to discover.

## .see also

- `rule.require.errors-name-the-fix` — a fix-text must name a fix that can be followed
- `gotcha.a-check-that-cries-wolf-gets-silenced` — m.9, two readers over one subject

⚠️ **`summary` is NOT itemized, and this term does not pave it.** the first draft of this
file cited `term=summary` as "the pair this completes" — a dead pointer, written in the same
round that recorded a fix-text which named a fix that could not be followed. a glob caught it.

⇒ `summary` is ordinary english here and names no declared dobj/dop, so
`rule.require.domain-term-itemization` does not reach it. `detail` earns its cluster because
its ABSENCE was the defect: the repo had one half of a pair and reached for "the log" for the
other. one word settles that; two would be vocabulary for its own sake.

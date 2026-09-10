# domain.term: consumer

term.chosen   = consumer
term.kind     = noun
term.synonyms.forbidden:
- reader
- interpreter
- host
- runtime
- caller

## .what

a runtime that **reads a given file and must be able to parse it** — so a file is only safe once
every one of its consumers accepts it.

the word names a **relationship, not an object**. bash is a runtime always; it is a *consumer*
only of the files it reads. the set is per-file, and it is what decides how a file must be
checked.

two properties define it:

1. **it can reject** — a consumer interprets, so a file it cannot parse is a file that fails at
   its point of use. a tool that merely opens bytes is not a consumer
2. **the set is plural by default** — one file commonly has more than one, and the count is not
   readable from the filename

## ⚠️ .the hazard the word must carry

a file's **name advertises one consumer; its consumers are whoever sources it**. those come apart
silently:

```
src/bash_aliases.sh          ← the name says bash
src/zshrc.sh:119   source ~/.bash_aliases          ← zsh consumes it
src/zshrc.sh:124   export BASH_ENV=~/.bash_aliases ← bash consumes it
```

measured 2026-09-05: the file named for bash has **two** consumers. so `bash -n` answers *"does
bash parse it?"* while the human reads *"is it safe to source?"* — a `proxy`, and one whose
failure lands at login, when the shell that was never checked is the one that must start.

so the consumer set must be **named per file**, never inferred from the extension.

## .refs

**the contracts:**

- `.agent/repo=.this/role=any/skills/shell.test.syntax.sh` — `consumers_of()` derives the set;
  `DUAL_CONSUMED` names the files read by both shells; the report prints the set per file, so a
  pass never claims more than what was parsed
- `src/zshrc.sh` — the declaration the consumer set is derived from (lines 119, 124)

**the origin:**

- 2026-09-05 — a `sync` of `bash_aliases.sh` was about to land on a live machine with only a
  bash parse behind it. the file is read by zsh too, and a zsh-side parse error breaks terminal
  startup outright

## .the boundary

| word | what it implies | fits? |
|------|-----------------|-------|
| **consumer** | a runtime that reads this file and can reject it | ✅ carries the per-file relation and the plurality |
| `reader` | any process that opens the bytes | ✗ `cat` reads it and rejects none of it; a consumer interprets |
| `interpreter` | a parse-and-exec engine | ✗ names the mechanism, not the relation to a given file |
| `host` | the environment that owns it | ✗ the repo owns it (`rule.require.repo-as-source-of-truth`); a consumer only reads |
| `runtime` | the class of engine | ✗ bash is a runtime always; the point is which files it consumes |
| `caller` | invokes an operation | ✗ a caller invokes; a consumer sources — a different relation |

`runtime` loses on the sharpest point: it is a property of the engine, and the fact we need is a
property of the **pair** (file, engine). only `consumer` names the pair.

## .reason

see the ref-level file beside this choice:

- `term=consumer._.choice.reason.md` — etymology, the dual-consumed shell file in full, and why
  a filename is not a consumer set

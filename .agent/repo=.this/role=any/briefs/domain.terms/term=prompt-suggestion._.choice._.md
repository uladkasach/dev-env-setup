# domain.term: prompt suggestion

term.chosen   = prompt suggestion
term.kind     = noun
term.synonyms.forbidden:
- autocomplete
- ghost text
- tab-to-accept suggestion
- inline suggestion

## .what

the greyed-out text claude-code renders **inside its own prompt input box** — a proposed
continuation while you type, or a proposed follow-up prompt after a turn. `tab` accepts it.

## .refs

**the contract** (landed 2026-08-03):

- `src/grove.provision/5.devtools/5.3.brains/configure.upsert.sh` — the patch that merges
  `CLAUDE_CODE_ENABLE_PROMPT_SUGGESTION` into `~/.claude/settings.json`
- `src/grove.provision/5.devtools/5.3.brains/configure.verify.sh` — reads the value back,
  since a merged file can hold the key at the wrong value
- `.agent/repo=.this/role=any/briefs/desktop/system/howto.silence-claude-cli-nags.md` — the "prompt suggestions"
  section, which names the feature and its polarity trap

**the origin:**

- the concept entered this repo on 2026-08-02, from a behavior route that was never
  committed. 🛑 **do not cite that route by path** — no file of it has ever existed in the
  checkout, so a pointer at one reads like a lost record rather than a route simply not kept
- vendor contract: `CLAUDE_CODE_ENABLE_PROMPT_SUGGESTION` (claude-code ≥ 2.0.71)

## .the collision that makes this term load-bearing

**`autocomplete` is forbidden because it is ambiguous, not because it is wrong.** in a terminal it
names three distinct claude-code features:

| feature | keep or kill |
|---------|--------------|
| **prompt suggestion** (grey text in the input box) | the one we disable |
| `/`-command menu | **keep** |
| `@`-file path completion | **keep** |

to say "autocomplete" in a contract is to name all three. two of them must survive.

## .reason

see the ref-level file beside this choice:

- `term=prompt-suggestion._.choice.reason.md` — etymology, evidence, why each synonym is forbidden

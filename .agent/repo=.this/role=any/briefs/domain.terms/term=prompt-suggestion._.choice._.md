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

- `src/install_env.pt5.devtools.sh` → `configure_robot_brains` — the patch that writes
  `CLAUDE_CODE_ENABLE_PROMPT_SUGGESTION` into `~/.claude/settings.json`
- `.agent/repo=.this/role=any/briefs/howto.silence-claude-cli-nags.md` — the "prompt suggestions"
  section, which names the feature and its polarity trap

**the origin:**

- `.behavior/v2026_08_02.fix-claude-suggestion/0.wish.md` — where the concept entered this repo
- `.behavior/v2026_08_02.fix-claude-suggestion/1.vision.yield.md` — "their words vs our words"
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

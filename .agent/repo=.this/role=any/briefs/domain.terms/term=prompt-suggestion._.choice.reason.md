# domain.term.choice.reason: prompt suggestion

## .etymology

adopted from the vendor, deliberately, over the human's own word.

the human who raised it called it **"autocomplete"** (`0.wish.md`, verbatim: *"the claude
suggestions that are shown as autocomplete"*). claude-code calls it a **prompt suggestion** — the
env flag is `CLAUDE_CODE_ENABLE_PROMPT_SUGGESTION`, and the feature request that produced the
opt-out (anthropics/claude-code#13878) titles it *"tab-to-accept suggestions"*.

we take the vendor's word. that is a deliberate exception to the usual instinct to speak the
human's language, and it earns the exception on two counts:

1. **the human's word is overloaded in this exact domain.** `autocomplete` also names the
   `/`-command menu and `@`-file path completion — two features that must **survive** the change.
   one word across three features, two of which are off-limits, is the ambiguity trap
   `rule.forbid.domain-term-synonyms` exists to prevent.
2. **the vendor's word is the contract.** the knob we set is literally spelled
   `..._PROMPT_SUGGESTION`. a term that diverges from the string in the config file makes every
   future reader translate.

the human's word stays correct in **speech**. it is forbidden only in contracts.

## .why each synonym is forbidden

| synonym | why rejected |
|---------|--------------|
| `autocomplete` | ambiguous — names 3 features, 2 of which we must not touch. the whole reason this term exists |
| `ghost text` | names the **render form** (grey inline text), not the feature. an ide's inline completion is also ghost text; the word does not pick out this one |
| `tab-to-accept suggestion` | accurate but describes one **interaction** with it. also **incomplete** — the suggestion may render after a turn, when no tab press is queued |
| `inline suggestion` | generic ide vocabulary; collides with editor completion, which this repo also configures (nvim, codium) |

## .evidence

**the discovery move: five whys on the human's word.** *"eliminate the autocomplete"* → why is it
hard to find? → because a search for "autocomplete" surfaces the `/`-menu and `@`-completion →
why? → because three features share that word → why does that matter? → because two of them must
survive → **so the domain needs a word that picks out exactly one.** the ambiguity is not
incidental; it is the reason the fix was hard to locate, and it cost real search time in this
behavior.

**verified in the installed bundle** (claude-code 2.1.87):

- `process.env.CLAUDE_CODE_ENABLE_PROMPT_SUGGESTION` — present; the vendor's own name for the knob
- a distinct internal `promptSuggestion*` identifier — present; the in-app state the `/config`
  toggle drives

so the vendor uses this term at **both** layers, env and internal state. that consistency is what
makes it safe to adopt as canonical.

**citations:**

- anthropics/claude-code#13878 — the feature request for a config option to disable
  "tab-to-accept suggestions"; closed, *"fixed as of version 2.0.71"*
- anthropics/claude-code#57436 — duplicate of #13878; its title uses the ambiguous word
  ("input autocomplete/suggestions"), which is itself evidence of the collision
- anthropics/claude-code#14629 — *"Prompt suggestions appear despite being disabled in config"*;
  uses the canonical term

## .disputes

no dispute open.

`autocomplete` was **considered and rejected** rather than disputed — the human's word lost on
ambiguity grounds, recorded above. should a future traveler judge that this repo's readers are
better served by the human's word, open a dated dispute here rather than a quiet rename.

## .invariants

- a contract (flag name, brief title, skill arg, doc that names the feature) uses
  **prompt suggestion**
- a comment or human-readable sentence may say "autocomplete" when it aids the reader — and should
  then name which of the three features it means
- any text that disables this feature must state that `/`-menu and `@`-completion are unaffected;
  silence there re-opens the ambiguity this term was chosen to close

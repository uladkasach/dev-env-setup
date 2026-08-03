# progress — learn.domain.terms

## round of 2026-08-03 — `v2026_08_02.fix-claude-suggestion` ships

### what this round touched

the behavior moved from vision to **applied**:

- `src/install_env.pt5.devtools.sh` — `configure_robot_brains` now writes
  `CLAUDE_CODE_ENABLE_PROMPT_SUGGESTION` into `~/.claude/settings.json`
- applied live to the machine via the procedure
- `howto.silence-claude-cli-nags.md` — extended, retitled, and two extant errors corrected
- `1.vision.yield.md` — questions retriaged after the wisher's instruction

### ✅ the debt from last round is paid

last round's sentinel made a commitment:

> *"the moment the execution stone writes `CLAUDE_CODE_ENABLE_PROMPT_SUGGESTION` into
> `configure_robot_brains`, that is a contract, and the cluster is owed in that same round."*

that happened this round, and the cluster was already written last round — so the debt is settled
by an update rather than a scramble. `term=prompt-suggestion._.choice._.md` now carries **the
contract refs** (the `configure_robot_brains` patch, the brief section) above the origin refs.

the term is no longer a reading of a vendor's vocabulary. it names a live contract in this repo.

### the judgment this round settled — `nag` has a boundary

`nag` is an extant repo term (`howto.silence-claude-cli-nags`). this round tested its edge and
found the term does **not** stretch to cover a prompt suggestion.

**the distinction, now recorded in the brief itself:**

| | `nag` | prompt suggestion |
|--|-------|-------------------|
| when | at **startup**, before the session | **mid-session**, while you type |
| what | a banner that reports a state (update failed, connectors need auth) | a proposed continuation of your input |
| shelf | shell export (read pre-settings) | settings.json `env` (read post-settings) |

so the brief was retitled *"silence claude-code cli startup nags"* → *"silence claude-code cli
noise"*, with `nag` kept for the three startup banners and the fourth entry marked explicitly as
**not** a nag.

**this is a conform, not a drift.** `nag` keeps its extant, narrower sense; the brief's *title*
widened to hold both categories. no synonym was introduced — "noise" is the section's scope word,
not a competing term for `nag`. no dispute opened, because no contract uses "noise" as a name.

⚠️ **the watch-item for the next traveler:** if a fifth entry lands and someone reaches for "noise"
as a *contract* word (a flag, a skill arg, a function name), that is the moment to itemize it
properly or push back to `nag`. right now it is prose scope, and prose scope needs no cluster.

### terms conformed (extant, reused as-is)

| term | how reused |
|------|-----------|
| `configure_robot_brains` | extended its patch literal; did not fork a second config procedure |
| `sync.devenv.brains` | named as the apply path in the brief, per `rule.require.install-via-procedures` |
| `prompt suggestion` | used in the brief and the install comment — **the canonical word held**; "autocomplete" appears nowhere in the new contract |

that last row is the point of the whole glossary exercise: the term was settled two rounds ago, and
when the contract finally landed, the right word was already there and no rename was needed.

### what would have been wrong to capture

- **`polarity trap`** — a vivid phrase i used in the brief for the `ENABLE_*` vs `DISABLE_*`
  inversion. it is **explanatory prose**, not a domain concept this repo declares. to itemize it
  would be to mistake good writing for vocabulary
- **`spinner tips`** — still out of scope (Q2 still open with the wisher)
- **`plowthrough` / `hashbar` / `level`** — bhrain's guard vocabulary, imported; the dir's readme
  excludes dependency terms

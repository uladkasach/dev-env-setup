# domain.term: bare

term.chosen   = bare
term.kind     = adj
term.synonyms.forbidden:
- raw
- naked
- plain
- unguarded
- direct

## .what
a call written WITHOUT the wrapper its context requires. the wrapper differs per subject —
a duct, a `-k`, a decline-gate, an `env -C`, an operand — and the word is the same in each,
because the shape is: **the call runs, and the guarantee its neighbours rely on is absent.**

## 🛑 .one sense, two polarities — do NOT split it into two words

`bare` appears both as a DECLARED flag and as a DETECTED row, and they are the same concept
seen from either end:

| where | what it means | what it costs |
|---|---|---|
| `git.grove.send --bare` | the caller CHOSE to drop the duct | a `--why` that names the trigger |
| `✋ 25 bare rack read(s)` | a reader DETECTED an absent wrapper | a defect to repair |

the sense is identical — *without the wrapper*. what differs is whether the omission was
declared or detected. to spell the two halves differently would be a synonym pair for one
concept (`rule.forbid.domain-term-synonyms`), and it would hide that a flag and a row
describe one state.

⚠️ so a `bare` flag is legitimate ONLY where it carries its trigger. that is why `--bare`
demands a `--why` and `bare-timeout-on-purpose:` demands a reason after its colon — an
exemption with no named trigger is a magic word (`rule.forbid.exemption-as-habit`).

## .the wrapper, per subject
each clamp names a different absent wrapper, and every one reads `bare`:

| subject | the wrapper it lacks |
|---|---|
| a send | the duct |
| a `timeout` | `-k` — so it sends TERM and cannot KILL |
| a `sudo` in an upsert | a decline-gate, or `-n` |
| an apt write | `PKG_APT_ENV` |
| a `wait` | an operand — so it joins every child |
| a keyrack read | `env -C "$gitroot"` |
| a glob in a dual-shell file | a `nullglob` guard |

## .why it is bare, not `call.bare`
the word spans every subject above with no shift in sense, so it belongs to no one of
them — the same allowance `declared` / `live` take (`term=declared`). a prefix would
multiply one concept into seven synonyms, and the pattern the clamps share is precisely
what makes the word worth a record.

## .refs
where the term is declared / used:
- .agent/repo=.this/role=any/skills/git.grove.send.sh          # `--bare`, the declared flag
- .agent/repo=.this/role=any/briefs/shell/rule.forbid.bare-globs-in-dual-shell-files.md

## .reason
see the ref-level cluster beside this choice:
- `term=bare._.choice.reason.md` — etymology, rejected synonyms, why the flag and the
  row share one word

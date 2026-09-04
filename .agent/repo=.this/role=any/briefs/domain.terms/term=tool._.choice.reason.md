# domain.term.choice.reason: tool

## .etymology

plain english, and deliberately so. a tool is a thing a person picks up, uses, and puts down —
the agency sits with the human, which is the whole distinction this term carries. every rejected
alternative lost that: `checker` and `linter` name what the artifact DOES, and the doing is
identical whether a human or a pipeline invoked it.

⚠️ `tool` is a generic word, and on its own it would be too vague to itemize. what earns it a
cluster is the **pair**: `gate` / `tool` is a two-word set where each is defined against the
other (`rule.prefer.symmetric-term-pairs`). the precision lives in the opposition, not in either
word alone.

## .the collision it had to survive — `toolkit`

`toolkit` was itemized first, and it names a **set of installed packages** that carry no config
of their own (`jq`, `tree`, `unzip`), held as the bundle `2.1.toolkit`.

so the repo already holds a `tool*` word, and the two senses are genuinely distinct:

| | `toolkit` | `tool` |
|---|---|---|
| what it is | a set of packages | one artifact's ROLE |
| the verb it takes | you INSTALL it | you RUN it |
| the test it passes | *"could this be installed?"* | *"who types this — the repo, or me?"* |

⇒ a member of the `2.1.toolkit` bundle may or may not be a `tool` in this sense, and the two
facts are independent. `jq` is in the toolkit and is a tool; `unzip` is in the toolkit, gates no
work and checks no claim, so it is neither.

⚠️ this is the one real hazard in the choice, and it is why the say-level file names `toolkit`
as its FIRST forbidden synonym rather than burying it. a reader who meets `tool` and recalls
`2.1.toolkit` will assume a relation that does not exist.

## .disputes

### dispute: `git.repo.test --what shell` — raised 2026-08-31 — status: RESOLVED (it is a tool, not a gate)

- raised.by  = the robot, as a best guess
- claim      = `shell.syntax.verify` reads files off a disk and drives no live surface, so it is
               the same shape as `git.repo.test --what types|format|lint` — a repo gate. it
               should ship as `--what shell` and inherit that family's `--scope` / `--mode`
               ergonomics.
- counter    = the human: *"defo not a `--what shell`, its just a compiler or linter. but a
               valid skill for the mechanic to check their work with."*

               the argument reasoned from the SUBJECT (what it reads) and said no word about
               the CALLER. `tsc` reads files and reports errors exactly as a lint gate does,
               and it is nobody's gate — a human runs it mid-edit and a red means *carry on*.
- resolution = it is a **tool**. the term is itemized, `gate` is recorded as its counterpart,
               and the naming rule it yielded is
               `rule.require.name-a-skill-by-who-invokes-it`. `linter` lands as a forbidden
               synonym — legitimate in the human's COMMENT above, which describes the artifact
               from another angle, and forbidden in a contract
               (`rule.forbid.domain-term-synonyms`).

## .evidence

- **discovery**: a fulcrum met at a real naming decision, overruled by the domain expert. the
  overrule is the evidence — the robot's case was internally sound and pointed at the wrong axis,
  which is what proves the axis worth a term.
- **the cost of the wrong choice**: a tool shipped as a flag on a gate is reachable ONLY through
  the command that runs it at you, at the gate's cadence. that is a real ergonomic loss, and it
  is why the naming rule grades it a blocker rather than a nitpick.
- **invariants**:
  - a tool's verdict skips no later work. the moment work is skipped on it, it occupies gate
    position and `gate` is the word (`term=gate._.choice._.md`).
  - one artifact may be both, and then it takes **two names** — the tool keeps its own verb and
    the gate calls it. it may never be collapsed into one flag on the gate.

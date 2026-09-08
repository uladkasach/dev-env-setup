# rule.require.crystallize-behaviors

## .what

every behavior this repo delivers to the human must be crystallized into a
**behavior inventory** — a durable, per-case ledger of what the config actually
does, including what it deliberately does **not** do.

one file per case:

```
.agent/repo=.this/role=any/briefs/$cluster/inventory.of=behaviors.via=$surface.case=$slug.md
```

- `$surface` = the thing the human touches — `nvim`, `kitty`, `tmux`, `shell`,
  `firefox`, `machine`
- `$slug` = the behavior case — `diff-boundary-nav`, `copy-forward`, `half-page-scroll`
- `$cluster` = the brief cluster that owns that surface, per `briefs/.readme.md`:

| `$surface` | `$cluster` |
|---|---|
| `nvim` | `desktop/nvim/` |
| `kitty`, `tmux` | `desktop/term/` |
| `firefox`, `machine` | `desktop/system/` |
| `shell` | `shell/` |

⚠️ the `via=$surface` segment stays in the FILENAME even though the cluster already
implies it. a brief is cited by NAME, and a name that carries its own surface survives a
move; one that leans on its directory does not (`briefs/.readme.md`, "a move is a
READER-SCOPE event").

## .why

this repo's value is not its code — it is the **behaviors** the code produces.
a keybind, an alias, a rewrite rule: each is a promise about what happens when
the human presses a key. those promises live today only in the config that
implements them, so:

- **they cannot be read** — the human must reverse-engineer `init.lua` to learn
  what `ctrl+d j` does, or ask a robot to re-derive it every session
- **they cannot be tested** — a promise nobody wrote down is a promise no test
  guards; a refactor silently drops it
- **the negative space is invisible** — "j j j does not repeat" is a real,
  load-bearing fact about the design. it appears in no file, so it is
  rediscovered by surprise, every time
- **the same question gets asked twice** — a behavior explained in a chat is a
  behavior lost when the chat closes

a brief explains *why a mechanism works the way it does*. an inventory declares
*what the human can expect*. we have the first and lack the second.

## .what counts as a behavior

anything the human can trigger and observe:

| kind | example |
|------|---------|
| a keybind | `ctrl+d j` → next diff boundary |
| a chord | `ctrl+d ctrl+j` → same, with ctrl held |
| an alias | `sync.devenv` → apply every config |
| a rewrite | kitty turns `ctrl+j` into `shift+enter` |
| a default | nvim opens with the minimap on |
| an absence | `j` alone after the chord does **not** repeat it |

that last row is not optional. **an inventory that records only what works is
half an inventory** — the boundaries of a behavior are as load-bearing as its
body.

## .the shape

each case file carries:

1. **`.what`** — one line: the behavior this case covers
2. **`.behaviors`** — a table of `given / when / then`, one row per observable
   outcome. the `when` is the exact keys or command; the `then` is what the
   human sees
3. **`.boundaries`** — what it deliberately does NOT do, and why. the negative
   space, stated on purpose
4. **`.lives in`** — the file:line that implements it, so a reader can jump
5. **`.see also`** — the briefs that explain the *why* behind the mechanism

the inventory is the **contract**; the briefs are the **rationale**. keep them
apart — an inventory that drifts into mechanism explanation stops being scannable.

## .when to crystallize

- **on discovery** — the moment a behavior is explained to a human (in chat, in
  a review, in a diagnosis), it has proven it needs a home. write it down before
  the context fades
- **on change** — a keybind added, moved, or removed updates its case file in
  the same commit as the config change
- **on surprise** — if the behavior did not match expectation, the gap between
  the two goes in `.boundaries`

## .the test

ask: *"could a human learn to use this without a read of `init.lua` and without
asking?"*

- yes → the inventory holds
- no → crystallize it

## .enforcement

- a keybind / alias / rewrite added with no inventory row = **blocker**
- a behavior explained to a human in conversation but not crystallized = **blocker**
- an inventory that records the happy path but omits a known boundary = **blocker**
- a config change that alters a behavior without an update to its case file = **blocker**

## .see also

- `inventory.security-checks.md` — the extant inventory this generalizes from
- `rule.require.repo-as-source-of-truth.md` — the repo declares the config;
  this rule makes it declare the *behavior* too
- `rule.always.externalize.lessons.into_briefs.md` (bhrain/learner) — briefs
  crystallize lessons; inventories crystallize promises

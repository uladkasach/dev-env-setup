# claude-code's declared config keys — what each buys, and why it sits where it does

## .what

the why behind every key `5.3.brains/configure.upsert.sh` declares. the phase cites each section by its `##` title, so the phase stays an outline (`prove.headers-carry-their-weight`).

## the two files, and which one owns a key

| file | holds |
|---|---|
| `~/.claude/settings.json` | declared settings — env, permissions, model, hooks |
| `~/.claude.json` | global config — the `/config` panel's toggles |
| `~/.claude/keybindings.json` | keymaps — a third file, which owns one declared chord (see `the send-now chord`) |

the first two are not interchangeable, and a wrong pick fails silent. `settings.json` validates against a zod schema that accepts and stores an unknown key, then no caller reads it. a grep-based verify reports ✔ forever. settle which file claude reads a key from before you add it.

## `verbose` lives in settings.json

- `yo(key, default)` reads every settings source first; it falls back to the global config only for keys in `nSe` (2.1.280).
- claude drops a global-config value equal to its default on every save (`Ls(config, (v, k) => S(v) !== S(Rx[k]))`, `Rx.verbose = false`). measured: `verbose: false` written, verified, read absent seconds later.
- the settings file is never filtered against `Rx`, so `false` there survives every save and outranks a stale `true` in a lower source.

## `diffSidebarOpen` — why the global config half exists

- the fullscreen tui auto-opens its diff panel on a wide terminal while this key is absent (`SWn()`). only an explicit `false` keeps it shut; `/diff` still opens it on demand.
- claude reads it straight off the global config (`ie()`), never through `yo`, so no settings file reaches it.
- it has no claude default, so a declared `false` survives claude's saves. a global-config key must have no default, or the next save drops it — the reason `verbose` lives in settings.

## one home for every brain knob

this patch is the sole home of every brain knob (`rule.require.brain-config-has-one-home`); no peer bundle declares one.

- the shelf test is the read site. `zd()` assigns the `env` block into `process.env` unfiltered at startup, so any flag read after that is reachable from here.
- a flag with no read site is dead: delete it, never rehome it. the one exception is a flag declared ahead of a pin bump, marked as such in its row.
- a "read too late" claim with no cited read site is a guess. two such guesses about the installer nag once split one knob across three bundles (.refs m4).

## the env flags

| flag | effect | read at |
|---|---|---|
| `DISABLE_AUTOUPDATER` | the one update kill-switch, cli and plugins (`ED6()`) | `j96()` |
| `DISABLE_INSTALLATION_CHECKS` | the npm→native migration nag (#23683) | `$w6()`, `kFz()` |
| `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` | auto-compact at 50%, not ~83%; cuts input-tokens-per-minute spikes | `et6()` |
| `CLAUDE_CODE_SUBAGENT_MODEL` | subagents on `claude-sonnet-5-5[1m]`, never the session's opus | `Ik6()` |
| `CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS` | idle compaction fires past 450k tokens, not its 200k default | none in 2.1.280; idle compaction ships in 2.1.299. declared ahead of the pin bump |

the subagent tool is allowed (see `subagents are allowed`), so the subagent model is live.

.refs = `gotcha.5-3-brains.demo=one-home-consolidation` — the three-bundle split, the silent model drift, what `gk6` gates, the reap, why `DISABLE_UPDATES` is no knob (m7)

## two env flags adopted, not chosen

| flag | the verify's claim |
|---|---|
| `CLAUDE_CODE_DISABLE_COMMAND_INJECTION_CHECK` | the command injection check, off |
| `CLAUDE_CODE_ENABLE_TODO_TOOLS` | the todo and task tools, on |

both sat on the live box and were adopted to keep a fresh box like it (see `keys adopted from the live file`). neither row cites a read site, so neither has passed the shelf test in `one home for every brain knob`. 📌 the read site of each is owed at the next pin bump; a flag found with none is deleted, per that section.

## the send-now chord

`~/.claude/keybindings.json` carries one declared bind: a `Chat` block sets `ctrl+x ctrl+s` to `null`, which unbinds claude's send-now chord.

- claude merges every `Chat` block, so the verify reads it unbound only where each block that names the chord sets it `null` — one null beside a second bind still leaves it bound.
- the apply merges the one block in and keeps every other keymap. it refuses a `.bindings` that is present and not a list, rather than drop a human's own keymaps; an absent `.bindings` it creates.

## `disableClaudeAiConnectors`

stops the claude.ai connector auto-fetch, which silences "N claude.ai connector needs auth · /mcp" (2.1.182+).

## `CLAUDE_CODE_ENABLE_PROMPT_SUGGESTION`

turns off the prompt suggestion — the grey ghost text in the input box (opt-out since 2.0.71, anthropics/claude-code#13878). the `/`-command menu and `@`-file completion are separate and unaffected. the term is `prompt suggestion`, never "autocomplete", which names all three (`term=prompt-suggestion`).

## the model, declared twice

the cli picks a model from three places, in order (`Ih()`, 2.1.87):

1. the session override — `/model` or `--model`
2. `env.ANTHROPIC_MODEL`
3. `.model`

- `ANTHROPIC_MODEL` outranks `.model`, so a box with only `.model` runs whatever a stale env var says.
- the `/model` panel reads and writes `.model`, so a box with only the env var shows a panel that disagrees with its run.
- so both are declared, at one value. rung 1 still wins: this sets the default, never a cap.
- `zd()` applies the env block into `process.env` before the model is picked, unfiltered. `gk6` gates a trust prompt, never permission (.refs m3, `define.claude-code-config`). so the value reaches every caller — tui, `claude -p`, sdk, the `claude` shell function, the `claude.latest` shim — with no rc export.

## `effortLevel`

`medium` is the default effort level.

- the settings zod schema names it (`enum(["low","medium","high"])`), so it is not an inert key.
- absent means `auto`, which the cli picks per model — a default nobody chose, free to move on a version bump. `medium` is the cli's own recommended rung in `/effort`.
- `CLAUDE_CODE_EFFORT_LEVEL` overrules it for a whole session, and the cli says so. this repo exports it nowhere, so an override on a box comes from a caller outside the repo.
- `modelSettings.<model>.effortLevel` overrules it for that one model, and would shadow the default with no sign. so the verify claims that no per-model block sets it, and the reap retires the one the repo once declared.

## `permissions.defaultMode=auto`

every session starts in auto mode, where the `PermissionRequest` hook decides a suspicious-classified prompt per segment rather than lift it to the human. shift+tab still cycles modes.

`auto` is an internal mode. the cli's tip text for an invalid value lists only the four external modes; the validator accepts those plus `dontAsk` and `auto`. a reader who checks the error message instead of the enum wrongly concludes `auto` is invalid.

## keys adopted from the live file

`permissions.defaultMode` and `.model` were adopted from the live file, not chosen here.

- measured 2026-09-23: the live file read `auto` and `claude-opus-5-5` where the patch declared `acceptEdits` and `claude-opus-5`. the next apply would have reverted a human's deliberate choice, so the repo took the live value (`rule.require.repo-as-source-of-truth`). the model has since moved, by a declared change, to `claude-opus-5-5[1m]` — the same model at its 1M-context window — at both rungs of `the model, declared twice`.
- the merge preserves an undeclared key on the box it sits on, and a fresh box never gets it. `skipAutoPermissionPrompt`, `tui`, and `env.CLAUDE_CODE_DISABLE_COMMAND_INJECTION_CHECK` sat that way until adopted 2026-09-25.
- no verify can see that gap: a verify reads only declared rows. when you touch this patch, diff the live keys against the declared set.

## `cleanupPeriodDays`

claude deletes a session transcript N days after its last activity. N defaults to 30 whether or not the key is present, so an absent key is a 30-day prune nobody stated.

- every `/resume`, post-compaction re-read, and archaeology run against a session dies on day 31.
- the loss is unrecoverable and unreported: a human learns of it from a `/resume` that finds none (`rule.forbid.failhide`).
- 36500 days is a hundred years — "never" in the only unit the option takes. claude declares no sentinel for never.

## `feedbackDrafts`

`off` stops the queue of claude's own bug-report drafts (2.1.247+). when on, claude writes a draft to `~/.claude/feedback/drafts/` whenever it judges it erred, and shows a "Bug report drafted" card; `quiet` keeps the queue and hides the card.

- user or managed scope only; a project or local value is ignored.
- the env twin `CLAUDE_CODE_SEND_FEEDBACK=0` is not declared — the settings shelf is the one home.
- .ref = https://code.claude.com/docs/en/tools-reference (SendFeedback)

## subagents are allowed

- a subagent holds research in its own context, so the main one stays lean, and `/batch` can fan out across worktree agents.
- a bare `Agent` in `permissions.deny` removes the tool outright, so a leftover entry silently re-bans every session.
- so the patch declares no `deny`, and the reap strips a leftover `"Agent"` while it keeps every other deny.

## the lock — one declared value, and the apply is the file's one writer

`_GROVE_PROVISION_5_3_BRAINS_SETTINGS_LOCK` in `5.3.brains/_.sh` decides the mode every apply gives `~/.claude/settings.json`, and the verify judges the file against the same value:

| value | mode | a foreign write |
|---|---|---|
| `on` | 0400 | an open for write fails with `EACCES` |
| `off` | 0600 | it lands, and the next apply strips its role hooks |

- the locked mode is 0400, never 0444: the file keeps your `env`, which can hold a token, so the lock takes away the write bit and adds no read bit for another user. both modes are named once, as `..._SETTINGS_MODE_LOCKED` and `..._SETTINGS_MODE_OPEN`.
- the apply is the bit's one writer: it writes a tmp beside the file, gives the tmp the declared mode, and renames it over, so no instant holds the file at another mode. the verify reads the mode back and holds it to the exact declared value — a write bit under `on`, or a lost one under `off`, is a ✋ that names the fix. the boot gate that follows it writes naught — under `on`, an init the lock halts is reported with both fixes (move that checkout's pin, or set the value `off`), and the lock is kept.

🛑 **it ships `on`.** a repo pinned below the shielded rhachet (1.49.2, where `withBrainDirSettingsShield` first ships; absent at 1.49.1) runs an init that writes its hooks into home through the tree's arrow; against the lock that write fails and the repo's `prepare` exits 1. the cure is that repo's upgrade past 1.49.2, never an unlock — the commander settled it. `off` stays a declared value (mode 0600, a strip on every apply, a foreign write lands until the next one), and the clamp proves both values.

⚠️ under `off` no writer re-strips between applies: a pre-shield install after an apply re-adds its hooks, and they fire until the next apply. the plan's ✋ is the only detector.

🛑 the flip to `on` is the commander's, and it owes three things no check detects — the same list sits at the declaration in `_.sh`:

1. every repo that runs on the box pins rhachet 1.49.2 or later
2. a hermetic probe of claude against a read-only settings file, with one of claude's own settings writes under it (fulcrum F10)
3. a skill that unlocks, edits, and re-applies, so the hand `chmod u+w` row below retires (fulcrum F13)

the mode is matched exactly: under `off`, a 0644 or 0666 file is rewritten to 0600, and the verify ✋s it.

every key that is not a role hook stays, your own empties included: the reap of retired keys drops only a container it emptied itself (a `permissions.deny` that held `Agent` alone, a per-model block that held `effortLevel` alone). a `permissions.deny: []` or a `modelSettings.<model>: {}` you left is kept as found, as the role-hook strip keeps every empty you left (clamp arms 18a, 18c, 18d).

🛑 the boot gate is a deliberate tie to rhachet, a repo this one does not own, since a lock is proven only by the writer it guards against. under `on` it runs, in the checkout this apply executes from, the same `npm run prepare:rhachet` a sprout's install runs. the tie has three parts, each bounded:

| part | what it leans on | its bound |
|---|---|---|
| the probe | `node_modules/.bin/rhachet` is executable in that checkout | absent → 🌙 no subject, the gate runs naught |
| the run | the checkout's `prepare:rhachet` npm entry | 300s; a timeout is a ✋, the declared mode kept |
| the halt read | rhachet's init names `EACCES` and `.claude/settings.json` in its output | an unmatched failure is a ✋ "proves naught", never read as a pass |

each failure mode ends in a ✋ with the declared mode kept, so a change in rhachet's layout or its error text can stall the proof but never unlock the file. the gate writes naught to home, and under `off` it does not run (its init would be a writer).

either way the bundle backs the file up, strips role-authored hooks, merges the patch, and renames a candidate of the declared mode over it. the rows below hold under `on`; under `off` the `chmod` step is moot.

| you want to change… | the path |
|---|---|
| a declared key | edit the patch in `configure.upsert.sh`, then `rhx grove.provision --what 5.3.brains --mode apply` |
| a key the patch does not declare (your own hooks, an allow list) | `chmod u+w ~/.claude/settings.json`, edit, then apply — the apply keeps every undeclared key and re-locks. this hand step is the escape hatch until the unlock skill lands (owed before the flip to `on`, item 3 above) |
| a file jq cannot read | the apply refuses and names both remedies: repair by that same unlock, or move it aside and re-apply |

- a robot that meets `EACCES` on this file has met the lock, never a defect to route around. hand the human the unlock row above; never `chmod` it from an agent shell.
- the apply's backups sit beside the file as `settings.<utc stamp>.<pid>.bak.json`, reaped to the newest ten, after the gate. the reap matches only that stamp shape, so a `.bak.json` of your own beside it is never taken.
  - ⚠️ **the pre-strip original is reaped too.** an apply that changes the file mints a backup, and under `off` every re-add between applies earns one more — so about ten such applies later, the first backup (the home as it was before any strip) is gone. it held what the converge drops or overwrites: the role hooks, the empty `permissions.deny` / `modelSettings` containers, and **the commander's prior value for any declared key the patch replaced** — that last is the one loss that matters, and the first backup is its only record. to keep it, copy it to a name outside the stamp shape (say `settings.original.bak.json`) — the reap never takes that
- `configure.verify` claims both halves on every plan: no role-authored hook, and the mode the declaration wants — a read-only file under `off` is a ✋ too, since it breaks a pre-shield install.

## merge, never overwrite — and arrays are replaced

- a human also edits `settings.json`, by the unlock row in `the lock` — hooks, model, permissions. an overwrite destroys all of it, so the phase deep-merges with `jq '. * $patch'` and leaves every undeclared key as found.
- `jq '. * $patch'` merges objects and replaces arrays whole. so `deny` stays undeclared: a human's deny list survives every apply, and a retired entry leaves by name in the reap.

## an enrolled claude reads settings.json through a symlink chain

measured 2026-10-19, on the laptop:

```
<repo>/.claude                                    → .agent/.actors/actor.via.repo=ambient/brain/.claude
…/brain/.claude/settings.json                     → settings.of.grove.json
…/brain/.claude/settings.of.grove.json            → ~/.claude/settings.json
```

- an enrolled claude runs with `CLAUDE_CONFIG_DIR` at the actor dir, and that dir's `settings.json` resolves to this file, so the declared keys reach it.
- the same chain makes a repo's project settings and the global file one file. a repo-scoped hook init writes its relative-path hooks (`./node_modules/.bin/rhx …`, `bash .agent/…`) into `~/.claude/settings.json`, where they fail in every other cwd.
- so a strip never goes by a hook's SHAPE — a relative path is also how a human writes a hook. the phase strips by AUTHOR: a hook whose `author` begins `repo=` is role-authored, and it leaves home (see `the lock`). any other author is kept and named for a human, never stripped in silence.
- the writer itself is rhachet's to cure, in its link layout; the strip and the lock are the guard on this side.

## the reap

a merge only adds, so a retired key outlives its declaration. without the reap the box holds every key the repo ever declared, and no verify can see it — an undeclared key has no row to redden (`rule.require.brain-config-has-one-home`, shape 11).

- the reap names keys explicitly; it never reaps every undeclared key. the merge's preserve guarantee lets the repo adopt a human's hand-set value, and a blanket reap would invert that.
- a key enters the list only once proven dead — zero read sites in the pinned cli, and not a flag declared ahead of a pin bump (`one home for every brain knob`) — so a delete harms no caller. a live key that merely moved retires by a change of value.
- one `del`, never a loop that builds it: an empty list would render `del() | …`, a jq syntax error.
- the `Agent` strip removes one entry by name and keeps the other denies; a list it empties is dropped, not left `[]`.

.refs = `gotcha.5-3-brains.demo=one-home-consolidation`, m5

## where the global config lives

the phase resolves the path the way the cli does, because the cli takes two branches. a literal path would write a second file beside the real one, read by none, while the verify reported ✔ on the file it wrote. from `cli.js` (2.1.87):

```
aM = () => exists(join(c1(), ".config.json")) ? join(c1(), ".config.json")
                                              : join($CLAUDE_CONFIG_DIR || homedir(), ".claude.json")
c1 = () => $CLAUDE_CONFIG_DIR ?? join(homedir(), ".claude")
```

the phase ignores `CLAUDE_CONFIG_DIR`, where the cli honors it. an apply launched inside an enrolled claude inherits that session's `CLAUDE_CONFIG_DIR`. measured 2026-09-26: such an apply wrote `diffSidebarOpen` into an actor's `.claude.json`, reported [KEEP], and never examined `~/.claude.json`. a seat converges its own `$HOME`; the caller's env is never the subject.

## the global config holds the oauth session — two guards

claude's own writer refuses a write whose re-read config lacks the auth its cache holds (`saveConfigWithLock`, github #3117). the hazard is measured upstream, so the phase guards its write twice.

1. skip: the phase reads the value first and never opens a file that already holds it. every apply after the first touches none of it, which closes the race window.
2. atomic rename: the merge lands in a tmp beside the target and is `mv`d over. `mktemp` alone would land in /tmp, a tmpfs here, where a cross-device `mv` is a copy with a half-written window.

- what remains: a claude that holds the file in memory and writes it back after our rename drops our key. that is benign — the verify reddens and the next apply re-converges. the costly direction, a write of ours that drops its auth, needs claude to persist auth inside the millisecond between our read and rename, and guard 1 removes even that after the first apply.
- the file is ~750KB of a human's per-project state, so the phase merges one key and leaves the rest as found.
- the patch only adds `diffSidebarOpen` or turns `true` into the longer `false`, so the output never shrinks. a smaller result means jq dropped state, and the write is refused.

## .see also

- `5.3.brains/configure.upsert.sh`, `5.3.brains/configure.verify.sh`
- `gotcha.5-3-brains.demo=one-home-consolidation` — m1–m7, the measurements behind these keys
- `define.claude-code-config`, `howto.silence-claude-cli-nags`

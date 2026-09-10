# domain.term: prune

term.chosen   = prune
term.kind     = verb
term.synonyms.forbidden:
- clean
- cleanup
- purge
- uninstall
- nuke
- reset
- reap
- gc
- sweep

## .what

remove the **unwanted subset** of a set at its source, so the wanted whole survives intact.

a prune is **selective, source-level, and idempotent**. it names both halves of the act: what
goes, and what deliberately stays. a second run over an already-pruned population removes none.

the selectivity is the content. `prune_claude_code_shadows` removes every npm-global claude-code
copy and leaves the pinned pnpm copy untouched. `keyrack.daemon.prune` removes a daemon only when
**all** of its predicate holds — temp home **and** spawner dead **and** older than `--min-age` —
so a daemon in the real home is never touched.

## .refs

**the contracts:**

- `prune_claude_code_shadows` — landed 2026-08-25 (branch `casey/pin-claude-code-version`); now
  under the devtools bundle in `src/grove.provision/5.devtools/`
- `.agent/repo=.this/role=any/skills/keyrack.daemon.prune.sh` — carries `--mode plan|apply` and
  `--min-age`, and reports each skip reason by name
- `.agent/repo=.this/role=any/skills/tmp.fixture.prune.sh` — the verb reused for a third
  population (`tmp.fixture` dirs), with the same three-part shape: a match predicate, a live-use
  skip, and an age gate

**the origin:**

- the 641-daemon incident that first demanded a selective removal rather than a blanket kill
- 2026-08-30 — 191 daemons found, 139 pruned across two passes, 39 left alive on purpose

## .why this term carries weight

the operation it names is **dangerous when misread**. the naive fix
(`npm uninstall -g @anthropic-ai/claude-code`) removes the *wrong* copy, because this repo's `npm`
shell function routes to pnpm when the cwd has no `package-lock.json`.

so the verb must signal *"a subset goes, the rest is protected"*. `uninstall` and `purge` both read
as total removal and would sanction exactly the mistake the operation exists to prevent.

## .the boundary

**the forbidden words each promise the wrong scope, or name the wrong mechanism.**

| word | what it implies | fits? |
|------|-----------------|-------|
| **prune** | a predicate-selected subset; survivors are intended | ✅ |
| `purge` / `nuke` | all of it — no survivors | ✗ overstates, and sanctions the real mistake |
| `clean` / `cleanup` | unbounded, undefined predicate | ✗ names no contract |
| `uninstall` | remove the package | ✗ total, and the naive form removes the wrong copy |
| `reset` | return to an initial state | ✗ a prune has no baseline to return to |
| `reap` | wait() on a dead child — a precise unix sense | ✗ overloaded; these are ALIVE |
| `gc` | automatic, unreachability-driven | ✗ a different mechanism; no operator predicate |
| `sweep` | a pass over the whole set | ✗ names the traversal, not the selection |

`reap` deserves the sharpest line: unix already spends it on *wait() on a dead child*. the
daemons a prune removes are **alive** and orphaned, not dead-and-unwaited. to call their removal
a reap would overload a word the platform already owns (`term=orphan`, sense F).

## .the boundary against `del`

`del` (see `rule.require.get-set-gen-verbs`) names an **idempotent removal of a named resource** —
`delVpc` removes *the* vpc. `prune` names a **selective removal across a set** — the caller does not
name what goes; the operation decides by a rule.

`delClaudeCode` would mean "remove claude-code". `pruneClaudeCodeShadows` means "remove the copies
that shadow the pin". distinct concepts, distinct words.

## .the plan/apply pair

a prune is destructive, so the operation defaults to `--mode plan` and requires `--mode apply` to
act. the plan output names each skip reason, which is what makes the predicate auditable before it
runs (`rule.require.safe-by-default`).

## .reason

see the ref-level file beside this choice:

- `term=prune._.choice.reason.md` — etymology, the age-gate lesson, evidence

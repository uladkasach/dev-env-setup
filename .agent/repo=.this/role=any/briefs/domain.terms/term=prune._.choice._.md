# domain.term: prune

term.chosen   = prune
term.kind     = verb
term.synonyms.forbidden:
- clean
- purge
- uninstall
- nuke
- reset

## .what

remove the **unwanted subset** of a set at its source, so the wanted whole survives intact.

a prune is **selective and source-level**. it names both halves of the act: what goes, and what
deliberately stays. `prune_claude_code_shadows` removes every npm-global claude-code copy and
leaves the pinned pnpm copy untouched.

## .refs

**the contract** (landed 2026-08-25, branch `casey/pin-claude-code-version`):

- `src/install_env.pt5.devtools.sh` → `prune_claude_code_shadows` — the declared operation
- `.agent/repo=.this/role=any/skills/keyrack.daemon.prune.sh` — prior use of the same verb, same
  sense: drop the surplus daemons, keep the live one

## .why this term carries weight

the operation it names is **dangerous when misread**. the naive fix
(`npm uninstall -g @anthropic-ai/claude-code`) removes the *wrong* copy, because this repo's `npm`
shell function routes to pnpm when the cwd has no `package-lock.json`.

so the verb must signal *"a subset goes, the rest is protected"*. `uninstall` and `purge` both read
as total removal and would sanction exactly the mistake the operation exists to prevent.

## .the boundary against `del`

`del` (see `rule.require.get-set-gen-verbs`) names an **idempotent removal of a named resource** —
`delVpc` removes *the* vpc. `prune` names a **selective removal across a set** — the caller does not
name what goes; the operation decides by a rule.

`delClaudeCode` would mean "remove claude-code". `pruneClaudeCodeShadows` means "remove the copies
that shadow the pin". distinct concepts, distinct words.

## .reason

see the ref-level file beside this choice:

- `term=prune._.choice.reason.md` — etymology, disputes, evidence

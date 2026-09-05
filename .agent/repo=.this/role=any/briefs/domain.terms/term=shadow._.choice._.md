# domain.term: shadow

term.chosen   = shadow
term.kind     = noun
term.synonyms.forbidden:
- duplicate
- stale install
- rogue install
- version conflict
- orphan

## .what

a second install of a tool that **outranks the pinned one on PATH**, so the tool that runs is
not the one the repo chose — and no error is raised.

a shadow is defined by **precedence, not by count**. two installs that coexist while the pinned
one still wins are not a shadow; one install that wins over the pin is.

## .refs

**the contract** (landed 2026-08-25, branch `casey/pin-claude-code-version`; rehomed by the
`install_env.*` → `grove.provision` reorg, which deleted the files this block first named):

- `src/grove.provision/5.devtools/5.3.brains/provision.upsert.sh` →
  `_grove_provision_5_3_brains_prune_claude_shadows` — the operation named with it
- `src/grove.provision/5.devtools/5.3.brains/provision.upsert.sh` — the header that names the
  cause: *"can outrank the pinned pnpm copy on PATH, with no other check to notice the swap"*

**the origin:**

- `.agent/repo=.this/role=any/briefs/hazard.claude-shadowed-by-npm-global.md` — where the concept
  entered this repo; the brief's title uses the verb form (`shadowed-by`)

## .why this term carries weight

the hazard is **silence**, and the word has to carry that. a shadow raises no error, emits no
caution, and leaves the pin's own guards (`DISABLE_AUTOUPDATER`, `CLAUDE_CODE_SKIP_UPDATE_CHECK`)
perfectly effective — on the copy that no longer runs.

`duplicate` and `stale install` both describe a **filesystem** state, which is the harmless part.
the harm is a **PATH-order** state. only `shadow` names the eclipse.

## .reason

see the ref-level file beside this choice:

- `term=shadow._.choice.reason.md` — etymology, evidence, why each synonym is forbidden

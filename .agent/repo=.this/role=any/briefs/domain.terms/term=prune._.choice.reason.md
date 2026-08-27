# domain.term.choice.reason: prune

## .etymology

from the gardener's cut. to prune a tree is to remove select branches **so the tree lives better** —
never to fell it. the word carries its own guarantee: the trunk stays.

that guarantee is the entire reason the word was reached for. the operation removes claude-code
copies while it **protects** one specific claude-code copy. a verb that fails to carry "and the rest
survives" would misdescribe the act in the most dangerous direction.

the repo already spoke this word before this round — `keyrack.daemon.prune.sh` drops surplus daemons
and keeps the live one. so the term is **reused, not coined**, which is why it needed a cluster:
two declared operations now lean on it.

## .why each synonym is forbidden

| synonym | why rejected |
|---------|--------------|
| `uninstall` | names **total removal** of the package. it is also the literal name of the command that, run naively here, destroys the copy we protect. to adopt it as our verb would bless the exact error (`hazard.claude-shadowed-by-npm-global.md`) |
| `purge` | connotes removal **plus** config/state teardown, and connotes totality. a purge of claude-code would take the pin with it |
| `clean` | ambiguous per `rule.forbid.ambiguous-labels` — reads as either "remove old artifacts" or "produce a fresh state". it also names no subject: clean *what*, of *what* |
| `nuke` | totality plus bravado. it hides the selectivity that is the operation's whole safety property |
| `reset` | implies a return to a prior or default state. a prune targets a subset by rule and asserts no state afterward |

## .evidence

**the discovery move: name from the motive, not the mechanism.** the mechanism is
`npm uninstall -g` in a loop — so `uninstall_claude_code_everywhere` was the mechanism-shaped name
first reached for. five whys: why uninstall? → to drop the shadows → why? → so the pin resolves →
why does that need its own operation? → **because a blanket uninstall would take the pin too.** the
motive is *selective* removal. the mechanism word could not express that; the gardener's word could.

**the mechanism word is actively unsafe here.** `src/bash_aliases.sh` defines `npm` as a **function**
that routes to `pnpm` when the cwd has no `package-lock.json`. so a reader who trusts an
`uninstall`-named operation and reproduces it by hand from a normal directory removes the pnpm copy
and leaves the shadow in place. the operation dodges this: it invokes npm through absolute paths
(`"$nodedir/bin/node" "$nodedir/bin/npm"`) — and the verb warns the reader why that care is taken.

**precedent in-repo:** `keyrack.daemon.prune.sh` — same shape (drop the surplus across a set, keep
the one that matters), same word, landed earlier. consistency across the two is what
`rule.require.ubiqlang` asks for.

## .disputes

### dispute: del  —  raised 2026-08-25  —  status: RESOLVED (`prune` is a distinct concept)

- raised.by  = mechanic (self-raised against `rule.require.get-set-gen-verbs`)
- claim      = the sanctioned mutation triad is `set` / `gen` / `del`. `del` is the canonical verb
               for idempotent removal, so `prune` reads as a forbidden synonym of it, and the
               operation should be `del_claude_code_shadows`.
- counter    = `del` names removal of a **named resource** the caller identifies — `delVpc({ vpc })`
               removes *that* vpc. `prune` names removal of a **subset the operation itself
               selects** by rule, across a set whose members the caller never enumerates. the
               distinction decides the outcome here: `del_claude_code` would read as "remove
               claude-code", which is the precise misread that destroys the pin. per
               `howto.domain-term-disputes`, a word that names a genuinely distinct concept becomes
               a **new term**, not a synonym to rename away.
               secondary: this repo's shell vocabulary is already `install_*` / `configure_*` /
               `sync_*`, none of which sit in the triad — the triad governs typescript
               domain.operations, not this repo's shell procedures.
- resolution = keep `prune` as a distinct term; record `uninstall`, `purge`, `clean`, `nuke`,
               `reset` as its forbidden synonyms. `del` is **not** forbidden — it remains correct
               for named-resource removal. dispute closed.

## .invariants

- a prune is **selective** — an operation that removes a whole set is a `del` or an `uninstall`, and
  must not be named `prune`
- a prune acts **at the source**, never on a symptom — a PATH reorder or a shim is not a prune, since
  the next shell undoes it (`rule.require.solve-at-cause`)
- a `prune_*` operation must name **what survives**, in its `.why` or its output, so a reader who
  reproduces it by hand cannot mistake it for total removal
- a prune is **idempotent** — a second run with no members to drop reports so and exits clean, never
  errors (`rule.require.idempotent-operations`)

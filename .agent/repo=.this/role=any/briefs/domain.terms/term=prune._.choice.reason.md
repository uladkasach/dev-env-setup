# domain.term.choice.reason: prune

## .etymology

from the gardener's cut. to prune a tree is to remove select branches **so the tree lives better** —
never to fell it. the word carries its own guarantee: the trunk stays.

the metaphor carries three properties this domain needs, and no forbidden synonym carries all three:

1. **selective** — you cut some branches, never the tree
2. **judged** — each cut satisfies a predicate (dead, crossed, overgrown)
3. **repeatable** — you prune again next season; it is a habit, not a one-time event

that third property is what makes `prune` fit an **idempotent** operation. a purge happens once and
empties the set. a prune runs on a schedule and converges each time.

the first property is the entire reason the word was reached for. `prune_claude_code_shadows`
removes claude-code copies while it **protects** one specific claude-code copy. a verb that fails to
carry *"and the rest survives"* would misdescribe the act in the most dangerous direction.

⚠️ the repo already spoke this word before that round — `keyrack.daemon.prune` drops surplus daemons
and keeps the live one. so the term is **reused, not coined**, which is why it needed a cluster:
three declared operations now lean on it.

## .why each synonym is forbidden

| synonym | why rejected |
|---------|--------------|
| `uninstall` | names **total removal** of the package. it is also the literal name of the command that, run naively here, destroys the copy we protect. to adopt it as our verb would bless the exact error (`hazard.claude-shadowed-by-npm-global.md`) |
| `purge` | connotes removal **plus** config/state teardown, and connotes totality. a purge of claude-code would take the pin with it |
| `clean` / `cleanup` | ambiguous per `rule.forbid.ambiguous-labels` — reads as either "remove old artifacts" or "produce a fresh state". it also names no subject: clean *what*, of *what* |
| `nuke` | totality plus bravado. it hides the selectivity that is the operation's whole safety property |
| `reset` | implies a return to a prior or default state. a prune targets a subset by rule and asserts no state afterward |
| `reap` | unix already spends this word on *wait() for a dead child*. the daemons a prune removes are **alive** and orphaned, so the word would overload a sense the platform owns (`term=orphan`, sense F) |
| `gc` | automatic and unreachability-driven. a prune is operator-invoked and predicate-driven; the operator supplies the judgment a gc infers |
| `sweep` | names the **traversal** across the set, never the **selection** within it — which is the half that carries the safety |

## .evidence

**the discovery move: name from the motive, not the mechanism.** the mechanism is
`npm uninstall -g` in a loop — so `uninstall_claude_code_everywhere` was the mechanism-shaped name
first reached for. five whys: why uninstall? → to drop the shadows → why? → so the pin resolves →
why does that need its own operation? → **because a blanket uninstall would take the pin too.** the
motive is *selective* removal. the mechanism word could not express that; the gardener's word could.

**the mechanism word is actively unsafe here.** `bash_aliases.sh` defines `npm` as a **function**
that routes to `pnpm` when the cwd has no `package-lock.json`. so a reader who trusts an
`uninstall`-named operation and reproduces it by hand from a normal directory removes the pnpm copy
and leaves the shadow in place. the operation dodges this: it invokes npm through absolute paths
(`"$nodedir/bin/node" "$nodedir/bin/npm"`) — and the verb warns the reader why that care is taken.

**precedent in-repo:** `keyrack.daemon.prune` — same shape (drop the surplus across a set, keep the
one that matters), same word, landed earlier. `tmp.fixture.prune` reuses the shape a third time, on
a third population. consistency across all three is what `rule.require.ubiqlang` asks for.

## .the age-gate lesson — a predicate can be out-run

the 2026-08-30 incident taught a fact the word itself does not say: **a prune's predicate can be
calibrated for a leak rate that no longer holds.**

`keyrack.daemon.prune` defaults to `--min-age 60`. against 191 daemons it found only **17**
prunable, because **152 had spawned within the last hour** and the age gate skipped every one.
the operation was correct and its output was honest — it named the skip reason plainly
(`skip (younger than 60m): 152`) — but the default made it near-useless at that leak rate.

at `--min-age 10` the same predicate found **122**.

**the lesson:** an age gate is a *rate assumption*. when the leak outruns it, the prune reports
success while the population grows. read the skip counts, not merely the prune count — a large
`skip (younger than Nm)` is the tell that the gate is mis-tuned for the current rate.

**why a lower gate was safe:** age is the *weakest* of the three predicates. the real safety is
`temp home` **and** `spawner dead` — a daemon that satisfies both is already unreachable by any
live process. age is belt-and-braces against a race where a spawner sits mid-fork. ten minutes
clears that race by orders of magnitude.

### the measurement

| pass | `--min-age` | found | prunable | skipped young | outcome |
|------|-------------|-------|----------|---------------|---------|
| 1 | 60 (default) | 191 | 17 | 152 | 64MB — the gate out-run |
| 2 | 10 | 162 | 122 | 30 | 1,125MB reclaimed |
| verify | 10 | **39** | **0** | 30 | idempotent: none left to signal |

the third row is the proof of idempotency: a re-run over the pruned population signals none, and
the 9 real-home daemons plus 30 young ones survive **by design**. that is a prune, not a purge.

machine effect across the two passes: memory 21.1G → 17.5G, available 9.8G → 13.3G, and swap
turned over from growth to decline (17.4G → 15.9G) for the first time in the session.

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
- resolution = keep `prune` as a distinct term; record the eight words above as its forbidden
               synonyms. `del` is **not** forbidden — it remains correct for named-resource
               removal. dispute closed.

## .invariants

- a prune is **selective** — an operation that removes a whole set is a `del` or an `uninstall`, and
  must not be named `prune`
- a prune acts **at the source**, never on a symptom — a PATH reorder or a shim is not a prune, since
  the next shell undoes it (`rule.require.solve-at-cause`)
- a `prune_*` operation must name **what survives**, in its `.why` or its output, so a reader who
  reproduces it by hand cannot mistake it for total removal
- a prune is **idempotent** — a second run with no members to drop reports so and exits clean, never
  errors (`rule.require.idempotent-operations`)
- a prune is **destructive**, so it defaults to `--mode plan` and requires `--mode apply` to act
  (`rule.require.safe-by-default`)

## .the neighbours

- **`kill`** — signals one named process; carries no predicate and no selectivity. `prune` *uses*
  kill as its mechanism, but is not a synonym for it.
- **`del`** — the repo's canonical idempotent-delete verb for a **single named resource**
  (`delVpc`). `prune` acts on a *population* under a predicate. related, never interchangeable; the
  dated dispute above is the record.
- **`tmp.fixture`** — the third population the verb now serves, and the one whose own term file
  explains why an *owner* word (rather than a *location* word) is what makes the predicate safe.

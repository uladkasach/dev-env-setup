# domain.term: daemon

term.chosen   = daemon
term.kind     = noun
term.synonyms.forbidden:
- service      (systemd's word for a UNIT — a declaration a boot replays. a daemon here is
                declared by nobody and replayed by no boot; see `.the boundary`)
- worker       (implies a queue it draws from, and a pool that sizes it. this one is spawned
                one-per-caller and draws from no queue)
- background process (names WHERE it runs, never what keys it. a `&`-suffixed command is a
                background process and is not this)
- helper       (generic; says no word about lifetime, and this term is entirely about lifetime)
- agent        (taken by ssh-agent / gpg-agent, which are session-scoped and reaped at logout.
                the whole defect here is that this one is NOT)

## .what

a long-lived process a CLI spawns **lazily, on first need**, whose identity is derived from an
input rather than declared — so a caller with a new input mints a new one rather than finds the
extant one.

the keyrack daemon is the instance this repo has: `rhachet` derives its socket path from
`sha256(realpath($HOME))`, so **`$HOME` is the key**.

## 🛑 .why the derived key is the whole term

a classic unix daemon is **declared**: a unit file names it, a boot starts it, and there is one.
this one is **discovered**: a caller computes where its daemon ought to listen, looks, and
spawns if the socket is absent. find-or-create — a `gen`, in this repo's verbs.

that is fine while the key is stable. it is a leak the moment the key is per-run:

| the caller | its `$HOME` | what the find-or-create does |
|---|---|---|
| a human's shell | `/home/vlad` | finds the extant socket ✔ |
| a jest run | `/tmp/rhachet-test-<ts>-<rand>` | **misses, every time** — so it spawns |
| an `rhx` under a temp home | `/tmp/pii-brain-live-*` | **misses, every time** — so it spawns |

⇒ **an idempotent operation is only as idempotent as its key.** `gen` promises "find, or create";
a key that can never repeat turns that promise into "create", forever, with no error and no
signal (`rule.require.idempotent-operations`).

## ⚠️ .the second half — it outlives its spawner and is charged to no one

when the spawner exits, the daemon reparents to pid 1 (`term=orphan`, sense F). so:

- it is invisible to any tally by parent — its parent is init, along with every other orphan
- it is invisible to any tally by name — each is merely `node` (`term=class`)
- it holds ~55MB of **ANON** memory, the one kind that must swap rather than be reclaimed

measured 2026-08-30: 191 daemons live, 152 of them spawned inside one hour, the box 17.4G into
swap. an earlier incident reached 641.

⇒ so the population is bounded by a `prune` on a timer (`1.6.4.keyrackd`), and the prune's
predicate is written against the two facts above: **temp home AND spawner dead**.

## .the boundary

| word | what it implies | fits? |
|------|-----------------|-------|
| **daemon** | a long-lived process, spawned on need, keyed by an input | ✅ |
| `service` | a systemd unit — declared, and replayed by a boot | ✗ the exact inverse: this one is declared by nobody |
| `worker` | draws from a queue; a pool sizes it | ✗ one per caller, no queue |
| `background process` | it runs detached | ✗ names the placement, never the key |
| `helper` | it assists | ✗ silent on lifetime, which is the whole subject |
| `agent` | ssh-agent, gpg-agent | ✗ those are session-scoped and reaped at logout — the property this one lacks |

⚠️ `service` deserves the sharpest line, because `1.6.4.keyrackd` ships BOTH: a systemd
**service** (declared, replayed, one) whose whole job is to prune the **daemons** (undeclared,
unreplayed, many). one word for both would make that sentence unsayable.

## .refs

**the contracts:**

- `.agent/repo=.this/role=any/skills/keyrack.daemon.prune.sh` — the declared operation this
  term composes; its `.safety` block is the predicate
- `src/grove.provision/1.system/1.6.procs/1.6.4.keyrackd/` — the bundle that bounds the pool

**the origin:**

- 2026-08-30 — 191 daemons found on one box; 122 pruned at `--min-age 10`, 1,125MB reclaimed
- `hazard.idle-process-leak-crosses-the-swap-cliff.md` — the hazard the population creates

## .reason

see the ref-level file beside this choice:

- `term=daemon._.choice.reason.md` — etymology, why the fix belongs in the ALLOCATOR, and the
  twin-leak relation to `tmp.fixture`

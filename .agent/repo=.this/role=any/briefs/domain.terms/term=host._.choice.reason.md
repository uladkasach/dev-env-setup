# domain.term.choice.reason: host

## .etymology

latin *hospes* — one who receives a guest. the word carries an asymmetry that no other candidate
does: **the host provides the place, the guest provides the purpose.** a host who receives a
dozen guests has not thereby done a dozen deeds.

that asymmetry is the whole term. a tmux server holds six work sessions; it authored none of
their forks. `parent` describes the same pid and drops exactly the distinction that matters,
because parenthood is a fact about the fork tree and says no more about intent.

## .the case that pinned it

2026-09-05. the box was at load 24.66 on 12 cores with `stall cpu 45%` and 450 forks/sec. the
churn report named its top parent:

```
├─  57 spawns  pid=38244    tmux new-session -d -s rhachet-brains-anthropic_beav_feat-
└─ 🪄 the heaviest parent is where to cut:  pid=38244 tmux new-session -d -s ...
```

the advice was followed. six live work sessions died. the fork rate did not fall — the storm was
never in that process.

pid 38244 was the tmux **server**. this is the trap:

> `tmux new-session -d -s <x>` starts a server when none is live, and the process that ran the
> command *becomes* that server. the server keeps the client's cmdline for its whole life.

so `ps -o args=` reports a command that ran once, days of uptime ago, and reads like an ongoing
spawn. the process's own `comm` says `tmux`. **the cmdline described the birth; the comm
described the thing.**

## ⚠️ .containment and causation produce the same number

this is the durable lesson, and it generalizes past tmux:

> **a parent tally cannot distinguish "it forked this" from "this forked beneath it."** both
> increment the same counter. so the tally alone can never justify a kill.

the repo had already met this once, one layer down: pid 1 topped the same list, because every
orphan on the box reparents to init. that was fixed by an exclusion — `$2 != 1`. but the fix
treated init as a special case, when init is just the most extreme member of a **class**: every
host aggregates, and init aggregates most.

so the second instance was inevitable, and it arrived as tmux. the fix now names the class rather
than its loudest member.

## .why the classification reads comm, never cmdline

a host is identified by `ps -o comm=`, not `ps -o args=`, and the tmux case is why. `comm` is the
executable's name — what the process *is*. `args` is the argv it was launched with — what it was
*asked to do*, once, possibly long ago.

for a daemon those diverge permanently. any classifier that reads argv will read a daemon's birth
certificate and mistake it for a job description.

the cmdline is still printed, as a **label** — it is what a human recognizes. it is simply not
what the verdict is computed from. the value measured (comm) and the value shown (argv) are
different, so both appear (`rule.require.name-what-you-measured`).

## .why the fix removes the kill, not just the tmux

the narrow fix is to hold hosts out of the blame list. that was done. but the report also lost
its `kill` recommendation entirely, and that is the larger correction.

a fork rate cannot tell a busy workload from a runaway one — a compile, a test suite, and a
runaway loop all fork fast. so the report never had the evidence to justify a cut, on a host or a
spawner. it recommended one anyway, and the recommendation carried the authority of a measurement
it had not made.

the report now ends at the name, and hands the human a probe:

```
🪄 the heaviest spawner — read what it forks BEFORE you cut:
   ├─ pid=3367417 claude
   └─ 🪄 see its children:  ps --ppid 3367417 -o pid=,etimes=,args=
```

a `concern` owes a runnable fix. it does not owe an irreversible one.

## .the neighbours

- **`orphan`** — the same aggregation defect, one layer down. init tops a parent tally because
  every dead chain reparents to it; a host tops one because every live workload runs beneath it.
  `$2 != 1` was the special case; `host` is the class it belonged to.
- **`proxy`** — the parent form. spawn count proxied for agency, with the condition (this parent
  authored the forks) unstated. the tenth instance found in these tools.
- **`concern`** — the rule that a report owes a runnable `fix` is what made a `kill` seem owed.
  this case sharpens it: the fix must be runnable **and** justified by what was measured.
- **`class`** — a host and a class are both sets charged as one. the difference is what a human
  may do with the total: a class total is real cost to reduce; a host total is borrowed and must
  not be acted on.

## .disputes

### dispute: host (vs `consumer`'s forbid)  —  raised 2026-09-05  —  status: RESOLVED (both stand)
- raised.by  = the round that paved both terms, hours apart
- claim      = `consumer` forbids `host` as a synonym, so a contract must not use `host`
- counter    = the forbid is scoped to a concept, not to a word. `consumer` forbids `host` as a
               name for *a runtime that reads a file*. this term names *a process that contains
               processes* — different relata (file↔runtime vs process↔process), different
               relation (reads vs contains). per `howto.domain-term-disputes`, a word that names
               a genuinely distinct concept earns its own cluster rather than a rename.
- resolution = both stand. `consumer`'s forbid is unchanged and correct in its scope; `host` is
               itemized here as its own term. each `.what` names the other so a reader lands on
               the right one. dispute closed.

# domain.term.choice.reason: diagnose

## .etymology

greek *diagignōskein* — *dia-* (through, apart) + *gignōskein* (to know). to know a thing
**apart from** the others: to tell this cause from that one.

the *dia-* is the whole term. a `check` knows one thing (pass or fail). a `monitor` knows a
stream. a diagnose knows **which** — it separates the suspect from the crowd, and the act of
separation is what it owes back to the human.

medicine kept the word for exactly that shape: a doctor who lists symptoms has not diagnosed,
and a doctor who names a disease with no findings behind it has diagnosed **badly**. both
halves — the name and the findings — are load-bearing there too.

## .why the frequency audit found it, and not an incident

`configure`'s `.reason` prescribes a tell:

> **audit by frequency, not by friction.** grep the verb counts across declared operations; a
> high count with no cluster is a gap, whatever its incident record.

run on 2026-09-06, that audit ranked `diagnose` first among this repo's own skills — **6
declared operations**:

| operation | what it reads |
|---|---|
| `machine.diagnose.churn` | fork rate + the parent each churner came from |
| `machine.diagnose.class` | what one process class costs, and whether cost tracks age |
| `machine.diagnose.lag` | a full snapshot, for later analysis |
| `machine.usage.diagnose` | the machine's whole state, stall-first |
| `nvim.diagnose.runaway` | which nvim core is hot |
| `nvim.diagnose.watchdog` | whether the in-process breaker tripped, and when |

plus four `howto.diagnose-*` briefs. no other verb in this repo's skills comes close.

and unlike `configure`, this verb has an **incident record** — three of them (below). so the
lateness here is not the "most-used word is last defined" shape. it is worse: the word caused
harm three times, and the harm was read as three separate tool defects rather than one term
that had never been pinned down.

> **a term with a repeat incident and no cluster is not a slow discovery — it is a lesson
> that has been re-learned instead of recorded.**

## ⚠️ .the three wrong-remedy cases, in full

each is a **true measurement** wrapped in an **untrue license**. that is the shape the term
must now guard.

### 1. `kill -9 38244` — six tmux work sessions died

`machine.diagnose.churn` counted forks, then tallied their parents, then named the top tally
"the heaviest parent is where to cut."

the top tally was a tmux **server**. a tmux server is a `host` — it **contains** work rather
than performs it, so it out-tallies every real spawner by construction (`term=host`). the
count was correct. the license was not.

what it cost: six live sessions, and the fork rate did not move — because the tmux server was
never the source of the forks.

the fix that landed: classify each parent by `comm`, split `spawner` from `host`, and **delete
the kill from the concern entirely**. the concern now names a probe:

```
🪄 the heaviest spawner — read what it forks BEFORE you cut
🪄 see its children:  ps --ppid <pid> -o pid=,etimes=,args=
```

### 2. `kill -9 <9 orphans>` — six were healthy chrome zygotes

the orphan hunt tested a process's cwd with:

```sh
if [[ "$cwd" == *"(deleted)"* ]] || [[ ! -d "$cwd" ]]; then
```

two different questions joined by one `||`:

- `*"(deleted)"*` — **the kernel attests the unlink.** universal, and a real stray.
- `[[ ! -d "$cwd" ]]` — **this path is not visible to ME.** a fact about the observer's
  namespace and permissions, never about the process.

chrome hardens its sandbox by having zygotes `chdir` into `/proc/<crashpad-pid>/fdinfo`. when
that crashpad pid exits, the path stops being visible while every zygote stays healthy. so six
live processes were offered up for `kill -9` under a banner that claimed the kernel had
attested their deletion.

caught before the human ran it. the fix split the two clauses: attested strays are named for a
kill, `unseen` paths are reported apart and never offered (`term=unseen`).

### 3. `the heaviest parent is where to cut: pid=1`

three days earlier, the same rank-by-parent named **init**. that was patched as a special
case — `$2 != 1` — which read as a fix and was not one.

pid=1 is merely the most extreme `host`. a filter that excludes the extreme member of a class
leaves every other member in place, so the tmux server was already inevitable the moment that
patch shipped.

> **a special-case exclusion is a rule that has not yet been generalized.**

## .the rule the term now carries

> **a diagnose names a suspect and its evidence. it does not pass sentence.**
>
> where the evidence cannot distinguish a busy workload from a runaway one, the fix names a
> **probe**, never a kill.

this is not caution for its own sake. it follows from *when* a diagnose is read: the box is
slow, the deadline is close, and the `🪄` line will be pasted into a terminal unread. **a
diagnose is trusted in exactly the moments a human has no time to verify it** — so its
authority must be earned in the tool, not in the reader's judgment.

## .why each rejected synonym loses

| word | the miss |
|---|---|
| `check` | returns a boolean. a diagnose must say *which* thing, and *how it was known* |
| `inspect` | ends in a description. to name a suspect is the whole job, so a dump is a failed diagnose |
| `analyze` | names the computation, never the outcome. a human under load needs the verdict, not the method |
| `monitor` | continuous, by nature. a diagnose is one act, on demand — the continuous form is `watchdog` |
| `audit` | presumes a declared rubric to grade against. a diagnose has a machine, not a spec |

`inspect` is the closest miss, and it is **already in correct use elsewhere**:
`nvim.inspect.embed` reports what is there and accuses no one. that is not a defect — it marks
the real split the two words carry:

> **inspect ends in a description. diagnose ends in a `concern`.**

## .the neighbours

- **`concern`** — what a diagnose must produce. a `says` + a **required** `fix`. a diagnose
  that prints numbers and names no suspect has not diagnosed
- **`host`** — the term the tmux incident forced. a diagnose that ranks by parent will always
  find a host at the top
- **`unseen`** — the term the zygote incident forced. a diagnose reports the unseen; it never
  acts on it
- **`proxy`** — every one of the three cases is a proxy left unstated: "the top parent tally"
  substituted for "the cause of the forks"
- **`watchdog`** — the continuous sibling. it lives inside its subject and trips a breaker;
  a diagnose stands outside and reports
- **`rule.require.name-what-you-measured`** — the repo rule this term's third property enforces

## .disputes

no open dispute on the word itself.

⚠️ one adjacent dispute is open and is recorded where it belongs — in
`term=stall._.choice.reason.md`, on whether `machine.usage.diagnose` may keep `usage` in its
name while `usage` sits in `stall`'s forbidden-synonym list.

# domain.term.choice.reason: concern

## .etymology

`concern` descends from *concernere* — to sift, to distinguish, and later to *regard* or *matter
to*. modern english kept the second sense: a concern is a matter that **weighs on a party**. it is
not a free fact adrift; it belongs to someone who wants it resolved.

that possessive sense is exactly why the word was chosen. an `alert` fires whether or not anyone
hears it. a concern is raised **to** a reader, and a reader raised-to expects a next step. the
word therefore obliges the shape of the contract, which is the strongest reason to keep a term.

## .the deferral that was honored — the point of this record

on 2026-08-30 `concern` was **deliberately not** paved. the sentinel recorded why, and what would
end the deferral:

> **`concern`** — declared this round in `_machine_usage_diagnose_concerns` and its output
> header. it is arguably a contract word now. i defer it because its **shape is still
> unsettled**: the 8 concern checks were authored in one pass and their thresholds are untested
> against a second machine. to itemize a word whose concept may shift within a week would be to
> freeze a guess. **owed the moment the concern set stabilizes or a second caller reuses it.**

on 2026-08-31 the trigger fired. the bare strings became a **declared function**:

```bash
concern() {
  local severity="$1"
  local says="$2"
  local fix="$3"
  concerns+=("${severity}|${says}|${fix}")
}
```

that is a contract with named, required parameters and a defined record shape. the deferral's own
condition — *the concern set stabilizes* — was met, so the debt was paid in the round it came due,
not later.

**the lesson worth the record:** a deferral is only honest if it names its own trigger. this one
did, the trigger was checkable, and it was checked. a deferral with no stated trigger is not a
deferral — it is an omission that hopes to be forgotten.

## .why the fix is a required parameter, not an optional one

before the function existed, concerns were bare strings, and **3 of 4** named no remedy:

| the string as authored | what the reader could do with it |
|------------------------|----------------------------------|
| `🔥 psi cpu 14.36% — tasks wait on cpu` | know that it is bad; guess at the next move |
| `🌊 swap 11.7G in use — anon at 13.6G` | same |
| `💾 iowait 5% — disk is a bottleneck` | same |
| `🗑️ 3220 fixture dirs — run tmp.fixture.prune` | act |

only the fourth had a fix, and it had one by accident of how it was worded rather than by
contract. that is a `rule.require.errors-name-the-fix` **blocker**, and it survived a full
authorship round because the shape permitted it.

to make `fix` a positional required parameter removes the failure mode at the source
(`rule.require.pitofsuccess`): a concern with no remedy is now unwritable, rather than merely
discouraged. the word demanded that shape, and the shape now enforces the word.

## .the severity rank, and why it never prints

severity is the first field and is **stripped before render**. it exists solely to sort:

| rank | class | why it outranks the next |
|------|-------|--------------------------|
| 1 | a stall or a wedge | someone waits **now**, or work is already lost |
| 2 | a level near its limit | harm is imminent, not yet realized |
| 3 | a count that will become a level | a trend, cheap to reverse today |

the reason it stays hidden: a printed severity is a second field to read and rank, and the sort
already did that job. the reader's eye lands on line one, and line one is the move. to print the
rank would re-impose the cognitive load the rank exists to remove (hick's law).

the sort is `sort -s` (stable), so authored order survives within a rank — the sequence inside a
severity reads as deliberate rather than arbitrary.

## .disputes

none raised. `issue` was the alternative most reached for by habit, and it was rejected on the
overload test rather than on style: `radio.task.push` already writes github issues from this repo,
so the word is spoken for.

## .the neighbours

- **`hazard`** — a brief-level word for a *durable* danger (`hazard.big-tmp-costs-ram-not-disk`).
  a hazard is a permanent property of the system; a concern is a live threshold crossed right now.
  a hazard explains why a concern's threshold sits where it does.
- **`hunt`** — the detector pass that names individual suspects. a hunt finds *who*; a concern
  states *what is wrong and what to do*. the report runs the hunt between the two.
- **`stall`** — one of the observations a concern can carry, and the highest-severity one.

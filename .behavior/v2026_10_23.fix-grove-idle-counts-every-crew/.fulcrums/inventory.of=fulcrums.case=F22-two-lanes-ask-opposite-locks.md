# F22 — where two l3 lanes ask opposite locks, the remedy text wins over the original literal

## .the fork
- **keep the original literals** — the test-intent lane's ask: a lock, once written, never
  follows a source change
- **keep the cause-specific remedy text** — the blemish lane's ask: a fix line must name the
  remedy for the cause it reports, and "read the error above" is false where none is above

## .the three points
| point | test-intent lane asks | blemish lane asks | taken |
|---|---|---|---|
| `nocreds` fix line | `└─ fix: read the aws error above` | a remedy for absent creds | the remedy |
| `rmdirfails` fix line | `fix: read the error above` | "the error on the 💥 line" | the 💥 line |
| `budget` fixture | `READ_BUDGET=-1`, which locks the clamp (its i005 blocker) | `0`, since a negative reads as real | `-1` |

## .taken, and why
- each remedy line is what a commander runs. a fix that names a fault absent from the run
  (`ec2:StopInstances` on a NoCredentials refusal) sends them to the wrong place: behavioral
- `-1` stays: it is the only value that proves the clamp. `0` passes with the clamp deleted
- every other lock change in this round was satisfied for both lanes instead (`findkill`:
  `: find exited 137`; `unanswered`: `the 💥 in the last tick names why:`; `at=x` restored, the
  source fixed so a non-iso stamp ages to none)
- the lanes' budgets are spent, and no `.taken` satisfies both: a fulcrum, disputed

## .rework — clean
three assert strings and their snap lines.

## .confidence — 80%, and why it is not higher
the test-intent rule is real; its bar is a lock that drifted to fit the code. these drifted to fit
a peer's blocker, which is the owner's call this records.

## .where
`.play/permanent/prove.idle-check-act-reaches-ec2.play.sh` ·
`prove.hibernate-upsert-converges-a-drifted-box.play.sh` · `prove.idle-check-counts-every-crew.play.sh`

## .verdict
open — the driver's best guess, flagged for the council and in the PR

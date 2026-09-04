# domain.term.choice.reason: stop

## .etymology
the plain inverse of `wake`, and the word the extant infra skill already carried
(`git.grove.stop`), so it was CONFORMED rather than invented — an extant declaration reused
per `rule.require.domain-term-itemization`.

chosen over:
- `hibernate` / `halt` — each names ONE MODE of a stop, not the operation. this is the
  central judgment of the cluster; see the dispute below
- `sleep` — a grove sleeps by ITSELF when idle (its own hibernate timer). to name the
  deliberate act `sleep` would blur an act a human takes with a drift the box does unbidden
- `kill` — violence toward a process, and a stop is orderly (the duct is closed first, so no
  bound-but-mute port is left behind)
- `terminate` — aws's word for DESTROY. a stopped grove keeps its disk and every tree on it;
  a terminated one is gone. the collision is dangerous, so the word is forbidden outright

## .disputes

### dispute: hibernate  —  raised 2026-07-26  —  status: RESOLVED (mode, not operation)
- raised.by  = <traveler>
- claim      = a grove's normal down-state IS a hibernate (its box is tagged
               `hibernatable=true` and self-hibernates on idle), so `hibernate` names the
               real act more precisely than the generic `stop`.
- counter    = this round proved the two modes are NOT interchangeable, so neither can name
               the operation:
               1. **hibernate** suspends to disk; the next start RESUMES the saved RAM image.
                  every process wakes with the state it slept with — so the ssm agent keeps a
                  dead socket and rotated credentials, and may never re-register. the grove
                  then reads as up while it is unreachable.
               2. **halt** powers off; the next start is a COLD boot, so every service starts
                  clean and the agent re-registers unconditionally.
               a caller must be able to choose, and a caller who recovers a stuck box MUST
               choose halt — so the mode belongs in a flag (`--how`), while the operation
               keeps the mode-neutral word. to name the operation `hibernate` would make the
               recovery path unsayable.
- resolution = keep `stop` as the operation; `--how hibernate|halt` carries the mode.
               `hibernate` and `halt` are forbidden as the operation's name, and remain the
               correct words for the modes themselves.

## .evidence
- the modes have OPPOSITE outcomes for reachability, proven on one box within minutes
  (2026-07-26):
  - hibernate → resume: box up, ssm agent absent, no duct could relay
  - halt → cold boot: box up, ssm `Online`, duct relayed on the first try
- the recovery narrative needs three steps, and each is a `stop` or a `wake` — never a
  `hibernate`: resume the hibernated box (wake), truly power it off (stop --how halt), then
  wake it cold. a vocabulary that lacked the mode-neutral verb could not express this
- the pair is symmetric with `wake` (`rule.prefer.symmetric-term-pairs`): wake drives up the
  same four resources stop drives down, and both are idempotent
- `--prune orphans` rides on `stop` for the same reason: to sweep ssm sessions whose box is
  gone is a down-ward act on the reach path, not a distinct domain operation

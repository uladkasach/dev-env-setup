# domain.term.choice.reason: wake

## .etymology
the grove metaphor's own word. a grove sleeps when idle and wakes when needed — the same
word a creature takes, for a machine the vocabulary already treats as one (`grove`, `tree`,
`forest`). it was reached for on the first dream of the skill and has never drifted.

chosen over:
- `start` — aws's api verb (`start-instances`), and its scope is one instance. a wake drives
  FOUR resources to a desired state (egress, box, duct, alias), so to borrow `start` would
  name the operation after one of its steps. it also imports amazon's vocabulary into a
  domain word (`def.domain-discovery`: the sdk is a map, not the territory)
- `boot` — a boot is a cold power-on. a wake may instead RESUME from a hibernate image, so
  `boot` would name one path and misname the other
- `resume` — the exact inverse error: it names the hibernate path only. a wake must cover
  both, so its name must be indifferent to the mechanism
- `provision` — held apart deliberately, and the boundary is already settled in
  `term=install`: provision stands up a MACHINE that does not exist; wake reaches one that
  already does

## .disputes

### dispute: home  —  raised 2026-07-24  —  status: RESOLVED (declared here 2026-07-26)
- raised.by  = <traveler>
- claim      = `wake` surfaced in round two as a grove-lifecycle verb and was DEFERRED three
               times (rounds 2, 3, 7) on one ground: its build home was the ghlitch/infra
               role package, so to itemize it in this repo's glossary would misplace it and
               pre-empt that package's own vocabulary.
- counter    = the defer held only while the word was declared elsewhere. this round
               declared a PORTABLE `git.grove.wake` **in this repo**, built on binaries the
               the tree itself installs (aws, session-manager-plugin, jq, ssh) rather than the
               infra repo's node_modules. so the word is now this repo's to own — and per
               the learner canon, a term the round DECLARES is not deferrable.
- resolution = itemize here. the eventual lift to ghlitch will carry the cluster with the
               skill; a term follows its declaration, and its declaration is now here.

### dispute: start  —  raised 2026-07-26  —  status: RESOLVED (keep `wake`)
- raised.by  = <traveler>
- claim      = the skill's core act is `aws ec2 start-instances`, so `start` names what it
               actually does, in the vendor's own words a reader can search for.
- counter    = it names one STEP, not the operation. a wake that only started the box would
               leave a grove unreachable — the NAT must be up for egress, the duct must
               relay, and the alias must exist before any duct can ride it. this round
               proved the gap is real, not theoretical: the box reached the aws `up` state
               while the grove stayed unreachable, because the ssm agent never re-registered.
               a name that promises `start` would have called that a success.
- resolution = keep `wake`; record `start` as a forbidden synonym. `start` stays correct for
               the aws call the skill makes internally — it is forbidden as the name of the
               grove-level operation.

## .evidence
- the wake drives four resources, in order, each idempotently: NAT → box → duct → alias. only
  the second is a `start`
- the reach path is the real contract: a private grove is reachable ONLY via ssm, so a woken
  box whose agent is de-registered is NOT awake in any sense a caller cares about. hence the
  skill gates on `Online` before it opens a duct
- narrative that settled it (2026-07-26): a hibernated grove was resumed. ec2 reported the
  box up within seconds — a `start` had plainly succeeded — yet no duct could relay for
  minutes, and the grove was unusable. the word `wake` is what makes that outcome legible as
  a FAILURE rather than a success
- symmetry: settled together with `stop` as a pair (`rule.prefer.symmetric-term-pairs`)

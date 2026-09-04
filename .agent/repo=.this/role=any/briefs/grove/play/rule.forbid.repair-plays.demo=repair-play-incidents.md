# demo: repair-plays — the incidents behind the forbid-writes rule

## .what

`rule.forbid.repair-plays.md` states the law in one line: a play may never write. these are
the dated measurements that earned each clause — a repair play built and caught, eight
deleted and re-homed, a promise that needed a structural fix, a rule conflict, and a false
existence claim inside the rule itself.

## m1 — a repair play was built and caught by a human, not the robot, 2026-08-10

- a fresh grove reported `no host manifest`; every credential read answered `absent 🫧`
- the robot wrote `repair.keyrack-host-manifest.play.sh`, then reached to grow
  `git.grove.send --set MODE=apply` so the play could write
- the human asked one question: *"why wouldn't it just be via grove.provision?"* — no answer
  existed
- the tell was on screen the whole time: a `MODE=plan` default and a `MODE=apply` branch — a
  plan/apply split is the bundle runtime's job, never a play's
- ⇒ the manifest is machine state; machine state is a bundle. the play was deleted, the
  transport change reverted, a bundle written instead

## m2 — the eight repair plays deleted 2026-08-10, and where each concern went

a robot that read the playbook dir learned "a repair play is normal here" from eight examples
that said so. a warning alone would not fix that — the plays had to go.

| deleted play | what it wrote | where it belongs |
|---|---|---|
| `repair.swap.hibernate-conflict` | `/etc/fstab`, `swapoff` | **`1.5.swap`** configure — its guard defers on new boxes but heals no old one; a verify is what heals |
| `repair.grove-rhachet-global` | a global rhachet reinstall | **`5.1.node`** provision |
| `repair.grove-pnpm-shim` | re-ran `5.1.node` configure + pnpm shims | **`5.1.node`** — its own header admitted it just re-runs the bundle: a pure forwarder, a second entrypoint by the letter of the rule |
| `repair.grove-keyrack-aws-peer` | `declastruct-aws` into the global root | **`5.6.aws`** provision |
| `repair.rootless-docker-preconditions` | four rootless-docker preconditions | **`5.8.docker`** provision |
| `repair.grove.devenv-checkout` | swapped a pushed copy for a clone | **`devenv.bootstrap.sh`** — a first-contact concern; its own header already said "a pushed src is NOT broken" |
| `repair.grove-root-strays` | deleted files a mis-aimed push scattered | **nowhere** — it cleaned up a MISTAKE, not a state. the durable fix is the guard in `git.grove.push` + `gotcha.grove-push-into-names-the-destination` |
| `repair.keyrack-drop-probe-keys` | `keyrack del` on a central vault | **nowhere** — it cleaned up litter a diagnose left. the durable fix: a diagnose must never write |

⇒ the last two rows share a cause: a different actor wrote when it should not have — a
mis-aimed push, a probe that stored a key it never took back. a repair play is what a codebase
grows when writes happen outside the inventory. remove the writes and repair plays lose their
reason to exist.

## m3 — condition 4 was a promise, not an enforcement, until 2026-08-30

- the rollback exception's fourth condition read *"DELETED when the bundle it served is
  proven"* — enforced by no check, only by whoever wrote the play, who had to recall it later
- the play family's own readme claimed 59 plays; the dir held more than twice that, almost
  entirely EXHIBITS — plays whose lesson had already landed in a brief, kept only because
  deletion was somebody's job to recall and nobody's job to enforce
- ⇒ the fix is structural, not another reminder: `rollback.*` now lives in the gitignored
  `.play/temporary/`. a play that is never committed cannot rot into an exhibit — the dir does
  what the old text asked a human to remember

## m4 — this rule forbade the one artifact a companion rule required, 2026-08-10 to 2026-08-11

- `rule.require.seam-claims-have-an-owner` requires a deliberate break: *"a seam check never
  exercised against a deliberate break = nitpick"*
- this rule, as first written, forbade the only artifact that can perform one — a
  discrimination probe
- the conflict stood for a day, with two probes live and cited the whole time, and surfaced
  only when a cull read the rule literally and moved to delete both
- ⇒ a rule that names one exemption where two exist does not prevent the second — it makes
  the second look like a violation to whoever reads carefully
  (`rule.require.exemptions-name-their-trigger`)

## m5 — the rule claimed two probes existed; neither did, measured 2026-09-02

- the rule read *"the two that live here"* — it named `prove.git-alias-seam` and
  `prove.keyrack-peer-probe-bites` as present
- measured three ways, all reach the same answer:
  ```
  Glob  **/prove.git-alias-seam*   → No files found
  git ls-files "*prove*"           → 8 files, every one a brief
  git log -- .agent/playbooks/     → EMPTY. no commit ever held that dir
  ```
- the last line settles it: they were staged, index-only additions, discarded before any
  commit — no delete removed them, no history holds a copy
- ⇒ a tracked rule asserted its own evidence in the present tense with no other proof —
  `gotcha.my-own-note-became-my-evidence`, at RULE scope, worse than the same defect in a
  brief because this rule's own enforcement graded their deletion a blocker
- the ARGUMENT for the exception stayed sound throughout; only the EXISTENCE claim beside it
  was false — the half no reader of a rule thinks to check
- current status: both probes remain owed, not yet written. `prove.keyrack-peer-probe-bites`
  writes destructively (`pnpm rm -g` a live peer) and must run only against a grove

## .see also

- `rule.forbid.repair-plays.md` — the rule these measurements back
- `rule.require.seam-claims-have-an-owner`, `rule.require.exemptions-name-their-trigger`
- `gotcha.my-own-note-became-my-evidence`

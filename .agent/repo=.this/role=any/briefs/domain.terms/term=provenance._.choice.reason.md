# domain.term.choice.reason: provenance

## .etymology

*provenance* is the art world's word for an object's chain of custody — where it came from, and
through whose hands. it is asked precisely when two objects look identical and their histories
differ. that is exactly the case here: a cloned src and a pushed src hold the same files, and
only their history tells you how to refresh one.

chosen over:

| candidate | why it loses |
|-----------|--------------|
| `source` | already names the `src/` dir in this repo. "the source of the source" is the overload `ubiqlang.ambiguous-from-overload` warns against |
| `origin` | git's own word for a remote. a pushed src has **no** origin, so the term would be undefined for exactly the case it must describe |
| `how` | a question word, not a property. "how = pushed" reads as a fragment; "provenance = pushed" reads as a fact about the src |
| `state` | says what a src IS now. provenance says where it CAME FROM, and that is what predicts the refresh path |

## .what settled it — a repair that destroyed work under test

`grove.bootstrap.sh` tested `[[ -d "$REPO_DIR/src" ]]` — "does it look like the repo?" a pushed
src passed that test, so bootstrap reported *"repo already present"*, its `git pull` failed for
want of a repo, and the else-branch announced:

> • left as-is (local commits or changes present)

that named a cause which **cannot exist** without the repo the check had just failed to find.

I then read that as a defect and wrote `a repair.grove.\*-checkout play` to "fix" it — which moved
the pushed branch aside and cloned main over it. main's driver predates the `--for` axis, so the
box went from a `--for`-aware driver to one that would install firefox, keyd, and cosmic
unconditionally on a headless machine. **the repair made the grove worse, and I reported only
the good half.**

the human corrected the model outright:

> no commits. the grove should know to expect that its repo might be pushed to it.

and `git.grove.push`'s own `.why` had said so all along:

> *a grove needs content that is not on main yet — a worktree's src/ … so a change can be
> validated on the grove BEFORE it is merged*

## .the lesson — a shape is not a verdict

the git-less src was never the defect. the defect was that **no tool named what it had found**,
so each one guessed, and one guess was destructive.

> a state you cannot name, you will misread. and a state you misread as broken, you will
> "fix" — which is how a repair destroys the work it was sent to protect.

the deeper form: I saw an unfamiliar shape and reached for a write before I asked what put it
there. that is the disposition `rule.require.solve-at-cause` warns against, and the reason
`diagnose` exists as a verb that asserts no verdict at all (`term=play.verify`).

📜 this paragraph read *"…a separate verb from `repair`"* until 2026-08-10. the play that
carried this measurement — `a repair.grove.\*-checkout play` — was deleted that day along with
the verb itself: a play may never write, and the concern belongs in `grove.bootstrap.sh`
(`rule.forbid.repair-plays`). the lesson is unchanged and in fact sharper — the whole class
of destructive "fix" this term was minted to prevent is now structurally unavailable to a play.

## .why the values are a closed pair

`cloned` and `pushed` exhaust the ways a src reaches a machine in this repo today: the bootstrap
clones, `grove.push` rsyncs. there is no third, so the pair is closed and a tool may branch on it
exhaustively.

a third value would need a third **arrival mechanism** — an image that bakes the src in, say.
that is the trigger which would reopen this term.

## .evidence

- `grove.bootstrap.sh` now prints `(provenance: cloned)` / `(provenance: pushed)` and takes a
  different path for each, where the pushed path exits 0
- `verify.grove.provision.applied` reports the provenance and judges the refresh path **against**
  it — a pushed src passes, because push is its correct refresh
- `diagnose.grove.repo-state` reports it and judges neither, per the diagnose contract
- the live grove now reads: `CLONED — head 318c27a … with 15 pushed/edited path(s) over it — a
  branch under test`, which is the hybrid the model had no word for before

## .disputes

none open.

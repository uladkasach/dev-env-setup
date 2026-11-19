# F14 — the live contract test is the grove ladder, run on a real grove

## .the fork

peer r2.b4, r3.b1 and r4.n5 (i001): every new play stubs ssh, aws, and rhx, so no
re-runnable test calls the real services.

- **A — the plays stay hermetic; the real-service test is `git.grove.provision test`, on a grove**
- **B — add live arms to the hermetic plays**

## .taken

A.

- this repo splits the two on purpose: a play is hermetic and runs on any box
  (`rule.require.hermetic-tests`); a change is proven on a grove
  (`rule.require.prove-changes-on-a-grove`). a live arm inside a play would decline on every
  box without a grove, and a decline is a skip by another name
- the re-runnable live test exists: `rhx git.grove.provision test <grove>` climbs
  `git.grove.ready.verify` and the gate's suite on a real grove — real `aws sts` (5.6.aws,
  5.13.reach hops), real ssm (5.12.rack reads the fleet token from `aws.params`), real ssh over
  the tailnet with a pinned key (trust.gen verified). it ran three times this stone (yield,
  "the whole deliverable, live"); each run is one command, not a manual sequence
- the live captures are the yield's evidence; a masked snap of a live run would pin the box's
  state (counts, versions, a fleet's throttles), which drifts with no defect behind it

## .the one gap this does not close

the tailnet FIRST CONTACT (`--trust tofu`) has run against stub ssh only. a real first contact
needs a box whose host key this laptop does not hold: a fresh grove. per
`rule.forbid.deferred-provision-defects`, that is the one legitimate halt.

⇒ the ask: when ahbode/infrastructure provisions the next hetzner grove, its first boot runs
`rhx git.grove.provision boot <grove> --mode apply --trust tofu`, and the capture lands in this
route's yield.

## .rework

clean — a live arm can be added later without a change to any contract.

## .confidence — 75%

## .where

every new play's stubs; `git.grove.provision.test.sh`.

## .verdict

open — disputed to the reviewers with this entry; the tofu capture awaits a fresh grove.

# F7 — the ci clamp splits into two plays

## .the fork
- **A** one play; the aws rung skips when no trust anchor is present
- **B** one play; ci holds a real cert + trust anchor (a ci secret)
- **C** two plays: `prove.house-grove-box-half` (ci) and `prove.grove-aws-identity-chain`
  (the human's box, any EC2 grove)

## .taken: C, and why at the time
- A is a conditional skip, which `philosophy.verification-strictness` and
  `rule.forbid.failhide` forbid: a green that did not check reads as a green that did
- B puts a live AWS credential into a public repo's ci, before #36 even exists
- C makes each play's subject explicit; neither ever skips. the ci summary names the split

## .rework
clean.

## .confidence 75% — why not higher
the wish says the house grove passes `prove.grove-aws-identity-chain` *with a clamp that runs
in CI*. a strict read wants the identity play itself in ci. C delivers the identity play on the
box and a ci clamp for every box fact; whether that satisfies the wish is the wisher's call.

## .where
case=5.

## .verdict — ruled 2026-10-18 by the director (seed S1): C holds
ci clamps the box-half pieces (users, loopback sshd); the identity play runs on the box. a ci
identity check would ride a runner's own trust, never the house grove's cert, so it proves naught
about the house path. the ci clamp covers the house-specific pieces, never a full converge.

## .risk: low
the ci clamp runs on a throwaway runner with a throwaway key it mints and shreds, and it holds no house cert or AWS trust by design: the identity play stays off ci. no real credential and no prod write.
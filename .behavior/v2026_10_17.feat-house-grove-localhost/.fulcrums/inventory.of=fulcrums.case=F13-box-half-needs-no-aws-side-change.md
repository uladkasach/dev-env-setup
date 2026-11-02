# F13 — Q1: does "no Roles Anywhere" mean the box half needs no AWS-side change?

## .the fork
- **A** yes — the box half (users, seats, loopback reach, env, the `credential_process` seam and
  its verify) builds and passes with no AWS-side change; `prove.grove-aws-identity-chain` passes
  once `ahbode/infrastructure#36` places a trust, by whatever mechanism it picks
- **B** no — the wish wants an unattended identity with no AWS-side change at all

## .taken: A, and why at the time
- off EC2 there is no unattended AWS identity without some trust on the AWS side, so B has no
  design that meets it
- the wish's own scope names `#36` as the AWS-side owner, so A holds both of its lines true
- the box seam is mechanism-agnostic (F6), so A commits to no CA or trust shape

## .rework
clean — the box half is unchanged by either answer; B would only cancel the identity play.

## .confidence 80% — why not higher
the wish says *"no Roles Anywhere"* in plain words; a reader could take it literally. **the
commander's to rule** (seed S2).

## .where
yield `.for the wisher to rule`; case=4 `[t5]`; case=5 `[t3]`.

## .risk: low
this tree writes no AWS-side trust and no credential; the call only says the box half waits on infra#36. the trust anchor #36 places is a credential and a prod write, and it is graded there, not here.
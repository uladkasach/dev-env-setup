# F4 — a hand-laid unfenced hop is refused, never adopted or deleted

## .the fork

`aws.reach.set` meets an unfenced `[profile X]` of the name it is about to write.

- **A — refuse the row.** ✋ with the line range and a one-time fix; no byte written; other rows proceed
- **B — adopt.** remove the unfenced section and write the fenced one
- **C — append** (today's behavior) — two sections, the last wins in silence

## .taken

A. C is a failhide. B deletes a human's config, which `5.6.aws` and `aws.reach.set` both refuse on principle (a human's sso profiles live in the same file). A costs one hand delete, once, on the one box that has hand-laid hops.

## .rework

clean — one branch in `aws.reach.set` before the write.

## .confidence — 75%, why low

A leaves a one-time hand step on the commander's box, which `rule.require.one-command-provision` frowns on. B with a byte-equal match (adopt only when the unfenced body equals the body we would write) would remove even that; weighed and left for execution, since a body that differs is the common case (a hand hop on hetzner likely names `source_profile = default`, the wish's shape, and ours names the endpoint — so they differ).

## .where

`.agent/repo=.this/role=any/skills/aws.reach.set.sh`, before section 6.

## .verdict

open.

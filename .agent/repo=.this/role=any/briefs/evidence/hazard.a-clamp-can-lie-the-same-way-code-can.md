# hazard: a clamp can lie the same way the code it guards can

## .what

a regression clamp is code, so it can carry the exact defect class it was written to catch. a
clamp that swallows the signal it came to read reports **green under a live defect**, or
**red for the wrong reason** — and both read as trustworthy from the outside.

so `rule.require.clamp-edge-cases` is not satisfied by "I saw it go red". it is satisfied by
**"I saw it go red for the reason I claimed"**.

## .why

a clamp is the one piece of code with no clamp above it. every other defect has a test that
would catch it; the test itself has only the author's attention. that asymmetry is why a
false clamp survives — it looks like protection, so no one revisits it.

three real instances from one round in this repo, all in probe setup rather than in assertions:

| the probe | what it did | what it reported |
|-----------|-------------|------------------|
| a pipefail clamp | ran the probe in a subshell that **inherited** `set -o pipefail` from the harness | green with the defect fully restored |
| an orphan-bootstrap clamp | captured with `>/dev/null 2>&1`, which aims stderr at the already-nulled stdout | *silent* about a leaf that spoke |
| a fixture clamp | truncated a shared file with the restore line placed **above** the block | a stray `jq: parse error` in an unrelated later case |

each was written carefully. each was wrong. all three were caught only by a deliberate
red-then-green dogfood.

## .the three failure shapes

1. **inherited state.** a subshell inherits `set -o` options, `trap`s, exported vars, and the
   cwd from the harness. a probe that means to run *without* an option must turn it off inside
   itself (`set +o pipefail`), not assume a clean slate.
2. **swallowed signal.** redirect order matters and reads backwards. `2>&1 >/dev/null` sends
   stderr to the capture; `>/dev/null 2>&1` sends **both** to the void. a probe that reads
   stderr must use the first.
3. **leaked fixture.** a probe that mutates shared state must restore it, and the restore must
   sit **after** the mutation in file order. a leak surfaces as a failure in an unrelated later
   case, which sends the next reader to search in the wrong place.

## .the test

for every clamp, run the loop and check **both** ends:

1. restore the defect → the clamp goes red
2. read the red **message** — does it name the cause you claimed, or a different one?
3. revert → the clamp goes green
4. run the **whole** suite green, not merely the new case — a leak only shows downstream

step 2 is the one that gets skipped, and it is the one that catches shapes 2 and 3.

## .the tell

a clamp you wrote and never saw fail is a guess. a clamp that went red with a message you did
not read is a guess with extra confidence.

## .enforcement

- a new clamp with no recorded red-then-green dogfood = **blocker**
- a clamp that went red for a reason other than the one its name claims = **blocker**
- a probe that mutates shared fixture state with no restore after it = **blocker**

## .see also

- `rule.require.clamp-edge-cases` (mechanic) — the rule this sharpens
- `rule.forbid.failhide` (code.test) — the parent class; a false clamp is a failhide in the
  one place a failhide is invisible
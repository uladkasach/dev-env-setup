# domain.term: signature

term.chosen   = signature
term.kind     = noun
term.synonyms.forbidden:
- fingerprint
- hash
- key
- class
- pattern
- dedup key

## .what

the **stable identity of a fault**, derived from its message with every digit collapsed to `#`.

```
"Invalid buffer id: 15968"  ─┐
                             ├─→  signature: "Invalid buffer id: #"
"Invalid buffer id: 15970"  ─┘
```

two errors share a signature when they are **the same defect seen twice**. that equivalence is the
unit the log dedups on and the rank counts by — without it, one stale-handle storm reads as
thousands of novel faults and the rank is worthless.

## .why not `hash` or `fingerprint`

both promise the wrong properties.

- **`hash`** implies opaque and one-way. a signature is neither — it stays **human-readable**, and
  it is printed verbatim as the rank's sample line. a reader must recognize the fault from it
- **`fingerprint`** implies uniqueness per instance — the opposite of the intent. a fingerprint
  distinguishes two individuals; a signature deliberately makes them **equal**

`key` and `dedup key` name the mechanical use and lose the sense (it identifies a *defect*, not a
map entry). `class` is a type-system word. `pattern` collides with the log reader's `--grep`.

## .the deliberate lossiness

a signature is **lossy on purpose**, and that is its one hazard: two genuinely different faults
that differ only in digits would collapse into one. accepted knowingly — over-collapse costs a
merged rank row, whereas under-collapse costs the rank its whole value.

the raw text is never lost: the full first-hit message is kept verbatim on the log line, so
`--tail` always recovers the exact error even when the rank shows the collapsed form.

## .refs

**the contract:**

- `src/init.lua` → `as_signature(msg)` — the derivation (`%d+` → `#`, whitespace squeezed, 240 cap)
- `src/init.lua` → `seen[sig]` — the per-signature `{ count, written, last, text }` record
- `.agent/repo=.this/role=any/skills/nvim.errors.review.sh` → the awk `sig` derivation — the reader
  re-derives the same collapse to group the rank

**the briefs:**

- `.agent/repo=.this/role=any/briefs/desktop/nvim/howto.review-nvim-errors.md` — "the rank groups by
  **signature**, not exact text"

## .reason

see the ref-level file beside this choice:

- `term=signature._.choice.reason.md` — etymology, evidence, the two-site hazard

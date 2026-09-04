# domain.term.choice.reason: pin

## .etymology

a pin fastens an object so it cannot shift. that is exactly the property: an
upstream url is a target that moves — `/latest/` moves on every release, a branch
tip moves on every merge — and a pin fastens one point of it to the source tree.

the word is already the industry's for this act ("pin a version", "pinned
dependency"), so it arrives with the sense a reader expects. `rule.forbid.surprises`
is served when the common word is adopted rather than a private one.

## .the rejected words, and why each loses something

| rejected | what it cannot say |
|---|---|
| `version` | a `sha256` is a pin and is no version. to spell the general by one specific hides the other two shapes, and the hash shape is the one that carries integrity |
| `hash` | the mirror error — `v3.5.0` in a url is a pin and is no hash |
| `lock` | pnpm and npm own it for a **generated** resolved-dependency set. a pin is **authored**. one word for a generated artifact and a hand-declared one is the overload `rule.forbid.domain-term-synonyms` exists to stop |
| `freeze` | implies a hold that later thaws. a pin has no thaw — it holds until a deliberate bump, and a stale pin aborts the install rather than lapse |
| `anchor` | this repo already uses "trust anchor" for a gpg key apt verifies against. two senses, one word, in the same paragraph |

## .the evidence — three shapes were found to be ONE concept, 2026-08-13

the sweep that produced this term started as two separate errands, and they kept
arriving at the same lines:

1. **determinism** — `rule.require.one-command-provision` demands the same disk
   yield the same result. five urls floated (`/latest/download/Hack.zip`, the
   awscli zip, the ssm `/latest/` path, `sh.rustup.rs`, `fnm.vercel.app/install`)
   and two clones took a branch tip.
2. **integrity** — `rule.require.verify-binary-downloads` demands a verify before
   extract. only three of seventeen fetch sites had one.

they are the same defect seen twice. a url that floats is a determinism defect
AND it makes a hash pin **inexpressible**, because there is no fixed artifact for
a hash to be about. so the version pin is a precondition of the hash pin, and a
fix that lands one without the other is half a fix.

⇒ that is what earned a single word. two words would have let a reader close one
half and believe the site handled.

## .the clause pair that settled `.the invariant`

`rule.require.verify-binary-downloads` held two clauses that cannot both hold:

- *"no signature available is not an excuse to skip the sha256 pin"*
- *"never hardcode a hash you computed from an unverified download"*

for an artifact whose upstream publishes neither a signature nor a checksum, the
only hash anyone could write is the forbidden one. the rule demanded a pin and
forbade the only pin available.

the resolution is the invariant on the say file: **a pin is sourced, never
computed** — and where no source exists, the fix is to change the ACQUISITION
PATH (an apt repo, a commit sha, a versioned url with a server-side digest),
rather than invent a number.

⚠️ **why a self-computed hash is worse than an open gap.** it is a CHANGE
DETECTOR: it proves the bytes match the day somebody last looked, and says not
one word about whether they were ever the published bytes. and it is
indistinguishable from a sourced pin in review — 64 hex characters either way —
so it converts a gap a reader would notice into one that reads as closed. that is
`gotcha.a-check-that-cries-wolf-gets-silenced` inverted: rather than a check that
lies red, a check that lies green.

## .why a COMMIT is a pin of both shapes at once

git addresses every object by the hash of its content and verifies that hash on
checkout. so a commit sha fixes WHICH code and proves it is that code, with no
second `sha256sum` step — the transport supplies the guarantee.

this is why `git_clone` makes `--at` **mandatory** rather than optional. a curl
url either names a version or it visibly does not; a clone url NEVER names one,
so an unpinned clone is a defect that leaves no trace in the diff. a pit of
success cannot have that as its default (`rule.require.safe-by-default`).

## .disputes

none raised.

## .see also

- `term=declared._.choice._.md` — the general property; a pin is one declared
  value with an integrity role, not a synonym for the state
- `term=provenance._.choice._.md` — a neighbour that is NOT this: it names how a
  tree src arrived (`cloned` | `pushed`), a closed pair about this repo's own
  checkout rather than about a fetched artifact
- `term=drift._.choice._.md` — what a pin exists to prevent

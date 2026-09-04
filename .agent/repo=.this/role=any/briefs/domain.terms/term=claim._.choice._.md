# domain.term: claim

term.chosen   = claim
term.kind     = noun
term.synonyms.forbidden:
- check        (names the ACT that tests; a claim is the assertion under test — see `.reason`)
- assertion    (test-framework vocabulary; a claim is about the MACHINE, not about a test run)
- guarantee    (already means the invariant a FILE holds, in every `guarantee:` header block)
- promise      (implies a future; a claim is about the machine's state right now)
- expectation  (locates the belief in the reader, where a claim is a property of the machine)

## .what
one assertion about this machine that a bundle leaf is accountable for — and that its `verify`
either proves, or declines to prove.

> *"the pinned kitty runs"*, *"a lookup of `xterm-kitty` succeeds"*, *"kitty is the SELECTED
> x-terminal-emulator"* — each is one claim.

a claim is the **unit the roll counts**. that is the whole reason the word is load-bear:

| node | claims it makes |
|---|---|
| **leaf** | every one. its four phases exist to assert and prove them |
| **composite** | none. it dispatches; its subbundles are accountable |

so `ran: 1` on a headless box means *one claim converged*, never *one node was visited*.

## .why it needs a word at all
because `exit 0` is not a claim, and the gap between them is every defect the verify axis exists
to catch. an exit code says commands returned 0. a claim says the machine now matches what was
declared. the four outcomes are all readings of a claim's status:

| exit | the claim is… |
|---|---|
| `0` | asserted and PROVEN |
| `1` | asserted and REFUTED |
| `3` | asserted, and UNPROVABLE from this run (debt we owe) |
| `4` | not made here at all — inapplicable (debt we do NOT owe) |
| `5` | not this node's to make — a composite dispatched |

without the word, `3`, `4`, and `5` all collapse into `0` and read as coverage forever
(`rule.forbid.failhide`).

## ⚠️ .a claim is a LINE SHAPE, not a glyph — three kinds wear `✋`

any reader that counts claims must know that only the first of these is one:

| the line | it is |
|---|---|
| `✋ gh is present but unauthed` | a **claim** — a phase found a fact |
| `✋ grove.provision finished with failures` | a **summary** — the runner's own total |
| `…its ✋ names the exact 'rhx keyrack set' …` | **prose** — a fix-text that cites the glyph |

⇒ the discriminator is POSITION: a claim's glyph OPENS its line. anchor first
(`^[[:space:]]*✋`), then drop the summary by name. three files have made this miscount;
the `.reason` records why a word list is the wrong repair for the third kind.

## .refs
- .agent/repo=.this/role=any/briefs/grove/provision/rule.require.upgrade-entries-verify-themselves.md  # a leaf owes a claim, and must prove it
- .agent/repo=.this/role=any/briefs/grove/provision/rule.require.grove-provision-bundles.md             # only leaves claim; exit 5 keeps the count honest
- src/bundle.upgrade.sh                                                          # `bundle_roll` tallies claims, not nodes
- .agent/repo=.this/role=any/skills/git.grove.operations.sh                          # `_count_claims` — the anchored reader
- src/grove.provision/4.terminal/4.3.kitty/4.3.2.emulator/provision.verify.sh              # three claims, each named and separately reported
- src/grove.provision/4.terminal/4.3.kitty/4.3.1.terminfo/configure.verify.sh              # a claim this run has no authority to prove → exit 3

## .the counterpart
`decline` (`🌙`) — itemized 2026-08-10. a phase that cannot ask its question does not make a
weak claim; it makes **no claim**, and says why. see `term=decline._.choice._.md`.

⚠️ that cluster was born from a `2.2.git` ✋ re-marked as an order fact, and **the re-mark was
retracted on 2026-08-12**: an order fact is a defect of order, cured by a MOVE of the phase,
never by a 🌙. so the `✋` there was closer to right than the `🌙` that replaced it — and the
real answer was neither glyph. read the retraction before you convert any ✋ into a 🌙.

## .reason
see the ref-level cluster beside this choice:
- `term=claim._.choice.reason.md` — etymology, why `check` and `guarantee` are forbidden, and the
  dated evidence that a run which tallies NODES reads as coverage it never earned

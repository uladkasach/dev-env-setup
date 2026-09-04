# domain.term.choice.reason: rack

## .etymology

`keyrack` is **rhachet's** word, not this repo's — it names the tool and the command
(`rhx keyrack get`). imported vocab does not get itemized here
(`rule.require.domain-term-itemization`).

what IS this repo's is the **short form**, and the boundary it draws. `rack` names what sits
on a box for a `keyrack get` to read. the metaphor is already in the tool's own name: a rack
is a frame that HOLDS keys — so the frame is the noun, and `keyrack` stays the tool that
mounts and reads it.

the word earns its place because it makes one sentence sayable that was not:

> the box has keyrack, and the box has no rack.

with one word for both, that sentence is a contradiction. with two, it is a diagnosis.

## .the two measurements that forced the split

### 2026-07-31 — the roadmap's ⚠️

`grove.auth.github.roadmap.md` was drafted on the assumption that `5.3.brains` gives a grove
all keyrack needs. one `ls` disproved it:

```
$ which rhx
/home/camper/.local/share/pnpm/rhx     ✔
$ ls -la ~/.rhachet
No such file or directory              ✋
```

the brief gained a section titled *"the binary is not the storage"* — but it had no NOUN for
the storage, so the section had to describe it in a phrase every time. a concept described
only in phrases is a concept with no term.

### 2026-08-02 — the skill that reported the wrong defect

`git.grove.auth.github.set` probed with `ssh host 'command -v rhx'` and, on a miss, halted:

```
✋ rhx is not on the grove's PATH, so it has no keyrack to fill
  fix: rhx grove.provision --what 5.3.brains --mode apply
```

**both halves were wrong.** the probe missed because a bare `ssh host 'cmd'` sources no rc
file (the grove keeps its pnpm dir on PATH via `~/.profile`, which only a login shell reads),
and the fix named a bundle that had already run. the sentence conflated command with storage,
so it could not have named the true owed step — a `keyrack init`.

with the term in hand, the skill now carries the two facts as two checks:

```
├─ rhx  present
├─ rack does NOT answer for GITHUB_TOKEN — a human is owed
├─ ⚠️ the box has NO rack yet (~/.rhachet/keyrack is absent)
```

three lines, three distinct facts, three different repairs. that is what the word bought.

## .disputes

### dispute: keyrack — raised 2026-08-02 — status: RESOLVED (keep `rack` for the storage)
- raised.by  = mechanic
- claim      = `keyrack` is the word rhachet uses and a human already types; a second word
               for the same subject invites drift, which `rule.forbid.domain-term-synonyms`
               exists to prevent
- counter    = they are not the same subject. `keyrack` names a COMMAND and the binary that
               carries it; the storage it reads is a separate artifact with a separate owner
               and a separate failure mode. one is installed by `5.3.brains`, the other by a
               human who runs `keyrack init`. the 2026-08-02 halt is the cost of one word for
               two concepts: it named the wrong bundle as the fix. this is the same shape as
               the `guard`/`marker` split (`term=marker`) — the act and the artifact it acts
               on are two terms, not one
- resolution = keep `rack` for the STORAGE; `keyrack` stays canonical for the command and is
               recorded as a forbidden synonym **in the storage's slot only**. `rhx keyrack
               get` remains correct and required. dispute closed.

### dispute: vault — raised 2026-08-02 — status: RESOLVED (keep `rack`)
- raised.by  = mechanic
- claim      = "vault" is the plainer english for a place secrets are kept
- counter    = keyrack has already spent the word: `--vault os.secure`, `--vault aws.params`
               name ONE backend each, and a rack holds several. to reuse `vault` for the whole
               would nest the word on itself — the same defect that kept `package` out of
               `term=bundle`'s slot
- resolution = keep `rack`; `vault` is forbidden in this slot and stays canonical for a
               keyrack backend. dispute closed.

## .evidence

- **discovery** — two field measurements on grove-1, quoted above, a day apart. neither was
  predicted; both were found by an `ls` after a claim was made without one
  (`rule.require.trust-but-verify`)
- **the boundary it draws** — the command is `5.3.brains`'s claim; the rack is a human's.
  a bundle can converge the first and can not converge the second, which is exactly why
  `5.4.gh` HALTS rather than repairs
- **the contract it appears in** — `5.4.gh`'s halt text, read by a human at the moment of
  least context. `rule.forbid.domain-term-synonyms` counts error text as a published
  interface, so the word there is a contract, not prose

## .see also
- `term=bin._.choice._.md` — the adjacent what-is-installed noun
- `term=marker._.choice._.md` — the same act-vs-artifact split, one domain over
- `grove.auth.github.roadmap.md` — where the binary/storage table lives

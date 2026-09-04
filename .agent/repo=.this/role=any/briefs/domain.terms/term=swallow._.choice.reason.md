# domain.term.choice.reason: swallow

## .etymology

`swallow` = taken in and gone, by what was only meant to carry it. the word holds
three facts at once, which is why four authors reached for it with no coordination:
there IS a consumer, the consumer sat in the MIDDLE, and the far end gets no signal
that a byte was consumed.

that last clause is what `lose` and `drop` cannot say. a dropped packet is missed at
the far end; a swallowed one is not missed, because the far end holds an empty string
that reads like an answer.

## 🛑 .the discovery — the repo had already drawn the line, in one sentence

nobody designed the pair. it surfaced on 2026-08-25, in a line that needed both words
in one breath (`rule.require.grove-provision-as-the-only-entrypoint.md:131`):

> the question is **swallowed on the way out** while the read still **waits on the way in**

one channel, two directions. an author who wrote about a single prompt on a single
duct reached for two verbs and used each correctly, because the two acts are opposite:

| direction | who consumes | the word |
|---|---|---|
| outbound | the CHANNEL (a pipe, a redirect, a `$( )`) | swallow |
| inbound | a RECEIVER that waits (a prompt, a live job's stdin) | eat |

⇒ so the synonym question settles as a **split, not a forbid**. `rule.prefer.symmetric-term-pairs`
asks for exactly this shape, and the corpus already held it.

## ⚠️ .why one round paves BOTH halves

the cheap move paves `swallow` (the word this round used) and leaves `eat` for later.
that is worse than a pave of neither:

> a paved term beside an unpaved near-neighbor does not read as *two concepts, one
> itemized*. it reads as **a canonical word and a synonym to conform away.**

so the next author, who obeys `rule.forbid.domain-term-synonyms` exactly as written,
renames every `eat` to `swallow` and destroys a distinction the repo already made — in
full obedience to the rules. a half-paved pair is a trap dressed as guidance.

## .the drift this round settles — 2 sites of 10

8 of `eat`'s 10 sites use it correctly (a prompt or a live job consumes a later
command). two use it for a CHANNEL, which is `swallow`'s half:

```
prove.bundle-pad-via-pipe.play.sh:25            "a pipeline eats an exit code"
prove.timeouts-kill-what-they-cut.play.sh:430   "its call all eaten"   ← a sed cut
```

both are comments, and `rule.forbid.domain-term-synonyms` governs CONTRACTS, so
neither violates it today. they are **clean-when-disturbed**. they stand here so the
next author who touches those lines knows which way to move them, and so no reader
takes them as counter-evidence to the split above.

## ⚠️ .the uses that do NOT go silent — recorded, not smoothed over

three sites use `swallow` where the result is **loud**:

```
git.grove.send.sh:377                         a fresh pane swallowed the first character (setsid → etsid)
prove.see-alsos-point-somewhere.play.sh:108   one `.see also` would swallow the rest of the file
prove.see-alsos-point-somewhere.play.sh:497   a reader would swallow a forbidden-synonym row
```

each is still a channel that consumes a signal in transit, so the **mechanism** clause
stands. but the residue is a `command not found` or a false ✋, which a reader cannot
miss. silence is a frequent PROPERTY of a swallow, never part of its definition.

⇒ the definition: *consumed in transit by the carrier*. the silence is what makes it
expensive, and why `rule.forbid.failhide` cares. a term defined by its worst outcome
would read these three sites as misuse, and they are not
(`gotcha.a-check-that-cries-wolf-gets-silenced`, m.12 — do not claim a set is cleaner
than it is).

## 🛑 .the first LIVE bite — 2026-08-25, minutes after the pave

the pave landed in the morning. that afternoon, a routine `git.grove.wake` answered:

```
🌳 git.grove.wake grove-ahbode-v20260811 --mode plan
   └─ 💥 no AWS_PROFILE in the keyrack for env=camp
```

**the rack held it the whole time.** the camp session had merely lapsed — 55 minutes
past its window. one `rhx keyrack unlock --owner ehmpath --env camp`, and the same
command answered in full: account matched the registry, nat up, box wakeable.

`git.grove.wake.sh:159` produced it, and it is one of five:

```sh
AWS_PROFILE=$(rhx keyrack get --owner ehmpath --env "$ENV" --key AWS_PROFILE --value 2>/dev/null || echo "")
```

the `2>/dev/null` swallows the stderr, so **four states collapse into one empty
string** — no entry, a lapsed session, an unreadable vault, no host manifest — and the
message names the first of the four.

### .why this bite is the expensive kind, and not merely a wrong sentence

a human who reads *"no AWS_PROFILE in the keyrack"* reaches for `keyrack set`. and
`set` **overwrites**: `setKeyrackKeyHost` acquires a secret and writes it. so a `set`
run to repair a message about an absence destroys the live value that message was
wrong about. worse, a `set` fed a closed stdin stores an **empty** value and still
prints `✔ set` (`rule.require.github-token-at-all-camp`).

⇒ so the swallowed byte does not merely mislead. it names a **destructive** repair,
against a healthy credential.

### .the same command showed BOTH states, side by side

the `unlock` that cleared it printed one rack with two very different rows:

```
AWS_PROFILE      → live, expires in 55m
GITHUB_TOKEN     → absent 🫧
```

one is a lapsed session; the other is a genuinely unplaced credential. **the swallowed
read renders them identical**, so a caller cannot tell the row to wait out from the row
to go place.

### .the repair, and the two that are wrong

| repair | verdict |
|---|---|
| keep the stderr, branch on it, name the true cause | ✔ the swallow is the defect, so close the carrier |
| pass an explicit `--org` | ✋ a **regression** — the cwd is an axis of the credential address, not noise (`aws.reach.set.sh:32`) |
| wrap the call in `env -C "$gitroot"` | ✋ same defect, one layer out — it answers for one org from inside another |

⇒ the second row earns its own note: this very session proposed it, and a human refused
it and pointed at a comment the repo already carried. a swallow's repair is always at
the CARRIER; a reach for the ADDRESS instead turns a silent read into a wrong answer
(`term=eat._.choice.reason.md`, on how the two halves take opposite repairs).

## ⚠️ .the near-miss — `5.4.gh` looks like the repair and is NOT it

on the fresh grove of 2026-08-25, `5.4.gh.configure.upsert` printed the message the
five sites cannot:

```
✋ the rack HELD a github token and github refused it
   ⇒ this is not an absent credential — it is a rejected one, so a
     'keyrack set' would repair no part of it
```

the obvious read is *"there — that bundle keeps its stderr, so copy it."* **it does
not.** line 213 still ends `--value 2>/dev/null`. the swallow is intact.

the bundle did two separate acts, and neither is the one a reader would guess:

| act | what it bought |
|---|---|
| `env -C "$gitroot"` on the read | removes **one** of the four collapsed states — a cwd whose manifest throws |
| a SECOND probe (`gh auth login --with-token`) | tells *held-but-rejected* from *absent*, downstream of the swallow |

so the discrimination comes from a later, independent read — never from the byte the
`2>/dev/null` ate. the other three states (a lapsed session, an unreadable vault, no
host manifest) still arrive as one empty string.

⇒ **a downstream probe can rescue a swallow only where a downstream probe exists.**
`gh auth login` is such a probe; `git.grove.wake` has none — its next act is the very
operation the credential was for.

### 🛑 .and its `env -C` is the fix that is CORRECT here and a REGRESSION there

this is the part worth the whole entry. the same repair, applied to the five sites, is
a defect — and one property of the slug discriminates:

| site | slug | does the org axis carry weight? | `env -C "$gitroot"` |
|---|---|---|---|
| `5.4.gh` | `@all.camp.GITHUB_TOKEN` | **no** — machine-wide, needs no manifest | ✔ correct |
| the 5 grove skills | `@this.<env>.AWS_PROFILE` | **yes** — the cwd's org picks the aws account | ✋ regression |

for an `@all` key the cwd is genuinely noise, so a fixed root is a strict improvement.
for a `@this` key the cwd is an **axis of the address** (`aws.reach.set.sh:32` —
*"a repo in a different org gets its own by virtue of its org"*), so a fixed root
answers for one org from inside another.

⇒ so *"copy what 5.4.gh does"* is a plausible, specific, wrong prescription — the shape
`gotcha.a-check-that-cries-wolf-gets-silenced` m.7 warns of, reached from the author's
side. read the SLUG before you copy the repair.

### .what the five sites are owed

not `env -C`, and not a second probe they have no room for. **keep the stderr**, and let
the message name which of the four it was. the bundle's own 📜 block says the sentence
out loud, one file away:

> `2>/dev/null` turns that throw into an empty string, so the branch below reads it as
> "no credential" … on a box whose rack is perfectly healthy (`rule.forbid.failhide`)
> — `5.4.gh/configure.upsert.sh:195`

so the repo **named this exact swallow, in prose, and repaired its cause rather than its
carrier** — the right call for that slug, and it left the carrier open for every other
caller.

## .why `hide` lost, though `failhide` is the neighbor rule

`failhide` names an OUTCOME: a fault that reads as a pass. `swallow` names the
MECHANISM behind it. they sit one layer apart, and each layer needs its own word,
because the repairs differ:

| layer | question it answers | repair |
|---|---|---|
| failhide | did a fault read as a pass? | make the fault reach a verdict |
| swallow | what consumed the signal? | name the carrier, and close it |

a review that can only say "failhide" points at the symptom. a review that can say
"the `$( )` swallowed the exit" points at the line to change
(`rule.require.solve-at-cause`).

## .evidence

16 files, four authors, no coordination — and the word survives four unrelated
subjects: an ssh stderr, a shell arg parser, a tmux byte, and a markdown section
reader. a word that survives four subjects with no gloss is a term, not a turn of
phrase.

⚠️ **and this round is itself the evidence.** round 53's status report said *"the 5
swallow sites"* to a human, unglossed, as settled vocabulary — out of a glossary that
held no such entry. a word used as canon while absent from the canon is exactly what
`rule.require.domain-term-itemization` exists to catch. it caught itself here.

## .disputes

none raised.

## .see also

- `term=eat._.choice._.md` — the inbound half of the pair
- `rule.forbid.failhide` (mechanic) — the outcome this mechanism produces
- `rule.prefer.symmetric-term-pairs` — the shape the split takes
- `gotcha.a-check-that-cries-wolf-gets-silenced` — m.12, on not a claim of a clean set

# domain.term: measurement

term.chosen   = measurement
term.kind     = noun
term.synonyms.forbidden:
- history      (names the TIME-ORDER, which is the one property a measurement does not need.
                git holds the history; a measurement holds what the world answered)
- note         (says no word about who the subject is, so it invites the changelog to wear
                the same term and survive a cull)
- log          (a log is append-only by construction — the exact shape
                `rule.forbid.chronological-accretion` forbids in prose)
- postmortem   (implies an incident and a review; a measurement is often one command's answer
                on a healthy box)
- changelog    (its FOIL, not its synonym — see below. to spell one `measurement` is how a
                changelog survives every sweep)

## .what

a dated record of **what the world answered** — a command's output, a box's state, a count
read off the tree. it is the one kind of `📜` this repo keeps.

## 🛑 .the test — read its SUBJECT, never its date

both a measurement and a changelog are dated, both wear `📜`, and both read as diligence. the
one question that splits them:

| the `📜` says | its subject | verdict |
|---|---|---|
| *"this check read `local` and missed the pin"* | the WORLD | a **measurement** — it stays |
| *"an X play stood here until the cull took it"* | MY EDIT | a **changelog** — it goes |

⇒ a date proves neither. `until 2026-08-30` sits happily in both.

## .the foil — `changelog`

`changelog` is a real and useful word, and it names a real artifact (`git log`). it is
forbidden only as a name for THIS concept, and this file names it so a reader can tell the
pair apart rather than collapse them.

`rule.require.briefs-obey-the-prose-rules` carries the enforcement: a measurement deleted as
"accretion" is a blocker, and a changelog kept as a measurement is a blocker.

## ⚠️ .the shape that hides a changelog inside a measurement

the costly case is neither pure. a block leads with *"this section read X until DATE"* and
then states a genuine finding. the archaeology is the changelog half; the finding is the
measurement half.

⇒ **lead with the rule, then cite the measurement under it.** the finding survives, and the
sentence a reader would ACT on is the current truth rather than a diff against a draft they
never saw.

```md
👎 📜 this section prescribed X until 2026-08-02, and that half was wrong. the swap …
👍 🛑 never do X — it reads absent forever. 📜 measured: the swap propagated into two skills
```

## .refs

- `rule.require.briefs-obey-the-prose-rules` — the three carve-outs, and the enforcement
- `rule.forbid.chronological-accretion` (mechanic) — the rule the foil violates
- `define.cry-wolf-measurements` — fourteen of them, cited by number from across the tree
- `term=exhibit._.choice._.md` — the near neighbour: an artifact kept past the argument it made

## .reason

see the ref-level cluster beside this choice:
- `term=measurement._.choice.reason.md` — etymology, the rejected synonyms, and the audit that
  settled the pair

# domain.term.choice.reason: audio.record.purpose

## .etymology

coined here, and it is one of the few words in this family the box did not supply.
`pw-record` knows a target and a filename and no grouping at all, so the concept is
entirely ours: **a set of takes that belong together, named before the first one exists.**

⇒ the word was chosen for what it asks. `--purpose` reads as *what is this FOR*, and the
answer a human gives to that question groups an archive better than any answer they would
give to *what is this called*.

## .the term was owed by a USE, not by an argument

📜 **2026-09-07.** the human asked:

> *"sweet. now how do i record for purpose babushka olga?"*

⇒ the word was already in the flag, in the state file, and in four skills — and it had
never been itemized. the ask made three decisions at once that no file recorded:

1. that a purpose is **dot-separated, most general first** (`stories.babushka.$name`)
2. that a purpose is **reused across occasions**, never one per take
3. that a purpose is the **dox seam** — real in the command, placeholder in the repo

⚠️ and the third was decided under time pressure, in a reply to a human about to sit down
with their grandmother. that is precisely when a dox rule is most apt to be forgotten,
which is why it is written down now rather than left to the next author's care.

## 🛑 .why `session` was the wrong word that felt right

it is the word a human reaches for, and pulse already uses it, and it is wrong for a reason
that only shows up later:

| | groups | so a year of takes is |
|---|---|---|
| `session` | one occasion | **many** sets, one per afternoon |
| `purpose` | one intent | **one** set, ordered by time |

⇒ an archive of a person's stories is a single set that grows for years. to key it on the
occasion would scatter it across dozens of dirs, each named for a date nobody remembers,
and the question *"where are grandma's recordings"* would have dozens of answers.

⇒ the timestamp already carries the occasion. it is in the filename, it sorts, and it needs
no dir of its own — so `session` would have bought a second grouper the archive already had.

## .the four roles, and why one word carries all of them

a purpose is the dir, the filename prefix, the remembered value, and the list key. that is
unusual density for one flag, and it is deliberate: **each role is the same question asked
at a different moment.**

- at capture: *where do these belong?*
- at rest: *what is this file?*
- at the next run: *what were we at?*
- at a read: *show me that set*

⇒ one word answers all four because they are one fact. to split them would let a take's dir
and its filename disagree, which is the drift a single source of truth prevents.

## .disputes

### dispute: subject — raised 2026-09-07 — status: RESOLVED (keep `purpose`)
- raised.by  = the mechanic
- claim      = the archive's real key is a PERSON, and `subject` says that plainly.
               `stories.babushka.<name>` is mostly person already, so the term should admit
               it rather than dress a person as an intent
- counter    = it is true of this archive and false of the concept. a purpose can be a
               person's stories, and it can equally be *"the house before we sell it"* or
               *"grandpa's workshop, described"* — neither of which has a subject who is a
               person. and `subject` would make the `demo` value ungrammatical: a demo has
               no subject at all
- resolution = keep `purpose`. it is the wider word, and the wider word is right when the
               narrower one happens to fit today's only instance
               (`rule.require.enumerate-before-you-name` — one instance cannot pick a word)

### dispute: a flat purpose, with no dots — raised 2026-09-07 — status: RESOLVED (keep dots)
- raised.by  = the mechanic
- claim      = `babushka-olga` is shorter, needs no convention to be explained, and a dir
               name with dots looks like a filename with an extension
- counter    = the dots ARE the convention, and they buy what a flat name cannot: a `<TAB>`
               on `stories.` reaches every story archive, and a sort groups them together.
               the same shape already governs this repo's skills (`audio.record.*`), so a
               flat purpose would be a second convention inside one family
- resolution = keep the dots. ⚠️ and the shape is a GUIDE rather than a check — no code
               enforces it, so it holds only while it is written down. that is what this
               file is for

## .see also
- `term=audio.record.take._.choice._.md` — one take; a purpose names the set of them
- `term=audio.record._.choice._.md` — the act; a purpose is a property of a set of its results
- `rule.forbid.dox-in-public-repo` — the rule the value shape exists to satisfy
- `rule.require.enumerate-before-you-name` — what settled the `subject` dispute

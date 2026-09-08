# domain.term: audio.record.purpose

term.chosen   = purpose
term.kind     = noun
term.boundary = audio.record
term.synonyms.forbidden:
- session     # names one occasion; a purpose spans every occasion with one person
- project     # implies a deliverable and an end; these takes end when a life does
- subject     # names WHO is recorded; a purpose names WHY, and the two differ
- name        # too broad, and it invites a bare person's name — see the dox note
- label       # names a tag applied after; a purpose is chosen BEFORE the first take
- tag         # implies many per take; a take has exactly one purpose

## .what

what a set of takes is FOR — chosen once, before the first take, and reused by every take
that belongs with it.

## .the four roles this one word plays

| role | where |
|---|---|
| the **dir** takes land in | `$into/$purpose/` |
| the **filename** prefix | `$purpose.$stamp.wav` + `.json` |
| the **remembered** half of the pair | `AUDIO_LAST_PURPOSE` in `last.env` |
| the **set** a reader lists | `audio.record.list --purpose <x>` |

⇒ so a purpose is not a comment on a take. it is the **key that groups an archive**, and
the one word a human types to reach a set of them again.

## 🛑 .the value shape — `$what.$who.$name`

```
stories.babushka.$name       # the archive this family exists for
demo                         # RESERVED — see below
```

**dot-separated, most general first**, so the set sorts by kind and then by person. it is
the same shape this repo's skills use (`audio.record.start`), and for the same reason: a
shared prefix groups a family under one glance and one `<TAB>`.

## ⚠️ .`demo` is RESERVED, and it changes where a take lands

`--purpose demo` defaults `--into` to this repo's cache dir and **writes no memory**. that
second half is load-bear: to remember a demo would re-point every later take at a cache
dir, which is the defect the scratch guard exists to catch, re-introduced through the
demo's own convenience.

⇒ so `demo` is the one purpose whose name carries behavior. do not open a real archive
under a name that begins with it.

## 🛑 .a purpose CARRIES DOX, and this repo is public

`stories.babushka.<name>` names a real person. it is correct in the command a human types,
in `~/.local/state/audio.record/last.env`, and in the dir on disk — and it is **forbidden
in this repo** (`rule.forbid.dox-in-public-repo`).

⇒ every brief, comment, and help string here writes the placeholder:

```
stories.babushka.$name
```

⚠️ the trap is that a purpose is the most quotable part of the command. it is short, it is
the vivid half of the example, and it reads as illustration rather than as an identifier —
which is exactly how a real name reaches a public repo.

## .refs
- `.agent/repo=.this/role=any/skills/audio.record.start.sh`       # takes it, makes the dir
- `.agent/repo=.this/role=any/skills/audio.record.list.sh`        # reads a set back by it
- `.agent/repo=.this/role=any/skills/audio.listen.sh`             # finds the newest of a set
- `.agent/repo=.this/role=any/skills/audio.record.operations.sh`  # `AUDIO_RECORD_DEMO_PURPOSE`

## .reason
see the ref-level cluster beside this choice:
- `term=audio.record.purpose._.choice.reason.md` — the etymology, the shape, and the disputes

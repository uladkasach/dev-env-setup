# domain.term: rack

term.chosen   = rack
term.kind     = noun
term.synonyms.forbidden:
- keyrack      (names the COMMAND `rhx keyrack`, and the binary that carries it. a box can
                hold the command and hold no rack — that is the measured case this term
                exists to keep sayable; see the `.reason`)
- vault        (taken by keyrack itself: `--vault os.secure` names ONE storage backend, where
                a rack is the whole of what a box holds)
- store        (generic; says no word about whose, or about the manifest that indexes it)
- credentials  (names the CONTENTS, not what holds them)
- secrets      (same, and it invites `secret` as a verb, which is not one)
- manifest     (a PART of a rack — `keyrack.host.age` — never the whole)

## .what
the credential STORAGE a box holds: `~/.rhachet/keyrack/` — its host manifest, its
recipients, and the vault files a `keyrack get` reads.

## ⚠️ the rack is not the binary — that split is the whole point of the word

measured on grove-1, 2026-07-31 and again 2026-08-02:

```
$ which rhx
/home/camper/.local/share/pnpm/rhx     ← the COMMAND is there ✔

$ ls -la ~/.rhachet
ls: cannot access '/home/camper/.rhachet': No such file or directory   ← the RACK is not
```

so a grove can RUN keyrack and have no rack to read. the two facts have different owners:

| | what it is | who puts it there |
|---|---|---|
| the **command** | `rhx keyrack …` | `5.3.brains`, via rhachet — on every box that gets the brains |
| the **rack** | `~/.rhachet/keyrack/` | `keyrack init` + a manifest that reaches the box — **a human's step** |

a sentence that says "keyrack" for both cannot state that gap, and a check that conflates
them reports the wrong defect. `git.grove.auth.github.set` halted with *"5.3.brains never ran"*
about a box where `5.3.brains` ran fine, precisely because its probe asked about the command
and spoke about the storage.

## .where the word is a CONTRACT

`5.4.gh`'s halt text is read by a human at the moment they are least able to guess, so the
word there is load-bear:

```
✋ gh is unauthed, and the rack holds no 'EHMPATHY_SEATURTLE_GITHUB_TOKEN' to give it
```

*"keyrack holds no EHMPATHY_SEATURTLE_GITHUB_TOKEN"* would read as "the tool is broken".
*"the rack holds none"* reads as "the storage is empty", which is the true and actionable
fact.

## .the split has a THIRD member: the DECLARATION

the storage/command pair is not the whole picture, and 2026-08-02 found the absent piece
the hard way. a `keyrack.yml` is the **declaration** — the list of which keys exist, per
env. the rack is where their values sit. keyrack is what reads both.

a key absent from every declaration can still be `set`: keyrack prints `✔ set`, and every
later get answers `status: absent 🫧`. so a set alone proves no read, and a swap can look
finished while it is empty forever.

| | holds | example |
|---|---|---|
| **declaration** | which keys exist | `.agent/**/keyrack.yml` → `env.prep: [EHMPATHY_SEATURTLE_GITHUB_TOKEN]` |
| **rack** | their values | `~/.rhachet/keyrack/keyrack.host.ehmpath.age` |
| **keyrack** | the command | `rhx keyrack get\|set\|list` |

`5.4.gh` addressed an undeclared key for as long as it existed, and would have reported an
empty rack on a box whose rack was fine.

## .refs
- src/grove.provision/5.devtools/5.4.gh/configure.upsert.sh   # reads the rack; halts when it is empty
- src/grove.provision/5.devtools/5.4.gh/configure.verify.sh
- .agent/keyrack.yml                                         # the DECLARATION, and its root org
- .agent/repo=ehmpathy/role=mechanic/keyrack.yml             # where the github token is declared
- .agent/repo=.this/role=any/skills/git.grove.auth.github.set.sh # inits a rack, then sets one slug
- .agent/repo=.this/role=any/briefs/creds/grove.auth.github.roadmap.md   # ⚠️ the binary is not the storage
- .agent/repo=.this/role=any/briefs/creds/plan.grove-credentials.md

## .reason
see the ref-level cluster beside this choice:
- `term=rack._.choice.reason.md` — etymology, the rejected alternatives, and the two
  measurements that forced the split

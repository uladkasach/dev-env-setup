# domain.term: configure

term.chosen   = configure
term.kind     = verb
term.synonyms.forbidden:
- setup
- init
- provision
- tune
- customize

## .what

to **write a tool's own settings into the form this machine wants** — the tool is already
present, and this changes how it behaves.

three properties define it, and all three separate it from its neighbours:

1. **the tool must already exist** — `configure` never fetches or installs. it presumes a binary
   and writes to the config surface that binary reads
2. **it writes the tool's native format** — a `user.js`, a `gsettings` key, a `keyd` conf. the
   format is the tool's, never ours
3. **idempotent** — a configure run twice leaves the same state as once

so the repo's three machine verbs form a chain, and each owns one link:

| verb | what it does | when it runs |
|------|--------------|--------------|
| `install` | provisions what was absent | once per machine |
| **`configure`** | writes settings into a tool that is present | when the desired behavior changes |
| `sync` | re-projects a repo file onto the machine | whenever the source moves |

## ⚠️ .the hazard the word must carry

**a configure writes a file; it does not change a live process.** every tool this repo configures
reads its config **once, at startup** — so a configure that returns success has changed the *next*
run, and left the live one untouched.

measured 2026-09-06: a firefox that held 8.9G across 39 content processes would have kept every
byte after its prefs were written, because those prefs are read at launch. the same shape hit nvim
three days earlier: an `init.lua` fix landed on disk while a live core kept the config it booted
with.

this is the `sync` hazard one layer on — a sync reports a copy rather than a delivery; a configure
reports a **write** rather than a **behavior**. so a configure's report must name the restart, and
`configure_firefox_prefs` ends with `restart firefox to apply` for exactly this reason.

## .refs

**the contracts:**

- `src/install_env.pt*.sh` — 27 `configure_*` operations (firefox, kitty, ptyxis, keyd, cosmic,
  git, tmux, codium, sysctl, …)
- `src/bash_aliases.sh` — several `sync.devenv.*` aliases source a module and call a
  `configure_*`. that is the layer order: a sync may *invoke* a configure; they are not one act
- `.agent/repo=.this/role=any/briefs/rule.require.install-via-procedures.md` — why a human is
  always told to run the procedure rather than a one-off command

**the origin:**

- long extant, itemized 2026-09-06 when `configure_firefox_prefs` gained three memory prefs. the
  verb composes more declared operations than any other in this repo and had no cluster, while
  both its neighbours (`install`, `sync`) had one

## .the boundary

| word | what it implies | fits? |
|------|-----------------|-------|
| **configure** | write a present tool's own settings | ✅ carries "already present" and "the tool's format" |
| `setup` | do whatever it takes to get ready | ✗ spans install AND configure; the vagueness is the defect |
| `init` | first-time bootstrap | ✗ implies once-ever; a configure re-runs whenever the desire changes |
| `provision` | make a resource exist | ✗ that is `install`; provision presumes absence |
| `tune` | adjust for performance | ✗ names one motive of many — a keybind is no performance work |
| `customize` | make it personal | ✗ names the taste rather than the act, and reads as optional |

`setup` loses hardest: it is the word most reached for by habit, and it collapses the
install/configure boundary that `rule.require.root-install-invocation` depends on — that rule can
check every `install_*` is dispatched precisely because the two verbs stay distinct.

## .reason

see the ref-level file beside this choice:

- `term=configure._.choice.reason.md` — etymology, the install/configure/sync chain in full, and
  why a write is not a behavior

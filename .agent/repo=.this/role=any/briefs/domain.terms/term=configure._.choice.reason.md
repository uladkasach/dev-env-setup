# domain.term.choice.reason: configure

## .etymology

latin *configurare* — *con-* (together) + *figurare* (to shape). to shape a thing's parts into a
chosen arrangement.

the etymology carries the exact constraint the term needs: **you can only shape what you already
have.** a sculptor configures marble; they do not configure a block they have not quarried. that
is the whole boundary against `install`, and it is in the word rather than imposed on it.

it also explains why the tool's own format is non-negotiable. to shape a thing is to work in *its*
material — a `user.js` for firefox, a `.conf` for keyd, a gsettings key for cosmic. a configure
that invented its own format would not be a shaping; it would be a new object beside the old one.

## .why it was itemized late

`configure` composes **27** declared operations in this repo — more than any other verb, `install`
included. it was itemized on 2026-09-06, long after `sync` and well after the glossary began.

that lateness is itself the finding:

> **the most-used word is the last one anyone thinks to define.** a term earns a cluster by
> being *disputed*, and a word used everywhere is never disputed — its meaning feels settled
> precisely because nobody has had to argue it.

`sync` got its cluster the day it caused an incident. `host` got one the day its absence cost six
tmux sessions. `configure` caused no incident, so it waited — while quietly carrying more contract
surface than either.

the practical tell for a future traveler: **audit by frequency, not by friction.** grep the verb
counts across declared operations; a high count with no cluster is a gap, whatever its incident
record.

## .the chain, and why three verbs rather than one

a single word (`setup`) would cover all three acts, and the repo would be worse for it:

```
install    →  configure  →  sync
provisions    shapes what   re-projects a repo
what was      is present    file onto the machine
absent
```

each has a different **precondition**, a different **cadence**, and a different **failure**:

| | install | configure | sync |
|---|---|---|---|
| precondition | the tool is absent | the tool is present | the repo holds the truth |
| cadence | once per machine | when the desire changes | whenever the source moves |
| its failure | a fetch that half-completed | a write the live process never reads | a copy from the wrong source |

`rule.require.root-install-invocation` depends on the install/configure split: it checks that
every `install_*` is dispatched from `install_env._.sh`. a merged `setup_*` family would make that
rule uncheckable, because it could not tell a provision from a shaping.

so the three-way split is not taxonomy for its own sake. one rule already leans on it.

## ⚠️ .a write is not a behavior

this is the hazard the term must carry, and it is the repo's third instance of one shape.

every tool here reads its config **once, at startup**. so:

```
configure_firefox_prefs   →  "• firefox prefs configured"   →  the live firefox is unchanged
```

the message is true. the file is correct. and the 8.9G firefox that prompted the change keeps
every byte, because it read its prefs 87 hours ago.

the three instances, all within four days:

1. **`sync`** (09-03) — a copy reported success while it delivered the wrong file
2. **nvim** (09-05) — `init.lua` landed on disk; a live core kept its booted config, and the
   `--history` report asserted the fix was absent when it was merely unread
3. **`configure`** (09-06) — prefs written; the live browser unaffected

each is the same defect at a different altitude:

> **an operation that reports on its own step, rather than on the outcome the human wants, cannot
> fail visibly.** the copy happened. the write happened. the machine still behaves the old way.

the cure is uniform and cheap: **a configure's report names the restart.** the extant
`restart firefox to apply` line is not politeness — it is the only part of that message that
speaks to the outcome rather than the mechanism.

## .why `setup` is forbidden, in one line

it is the word a tired human reaches for, and it answers *none* of the three questions the chain
asks: is the tool present? whose format is written? what makes it take effect? a word that
collapses three preconditions into one is not a shorthand — it is a lost distinction.

## .the neighbours

- **`sync`** — the layer above. a `sync.devenv.*` alias may source a module and call a
  `configure_*`, so a sync sometimes *invokes* a configure. they stay distinct because their
  sources differ: a sync's truth is a repo file, a configure's truth is the function body.
- **`install`** — the layer below, and the sharpest boundary. install presumes absence; configure
  presumes presence.
- **`proxy`** — the write-vs-behavior hazard is a proxy: "the file was written" substituted for
  "the tool behaves this way", with the condition (a restart since the write) unstated.
- **`class`** — the firefox case that prompted this itemization was found through a class read,
  and it is the second hazard that term now records: 39 content procs under a comm that does not
  say "firefox".

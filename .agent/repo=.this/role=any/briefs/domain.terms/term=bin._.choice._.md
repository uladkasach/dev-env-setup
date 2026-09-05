# domain.term: bin

term.chosen   = bin
term.kind     = noun
term.synonyms.forbidden:
- binary       (the full word, and its two peer ops are `bundle.fn.of` / `bundle.num.of` — a
                three-letter noun is the shape this cluster already has)
- which        (the unix tool that HAS the defect this term exists to route around; to borrow its
                name would advertise the very behavior we refuse — see `.reason`)
- command      (what `command -v` returns, which is the wrong answer: a function is a command)
- path         (says WHERE, not WHAT, and `$PATH` already means something else in every file here)
- exe          (windows vocabulary; this repo's invariant is debian)
- executable   (true of a shell function too, so it does not draw the line this term draws)

## .what
the file on `$PATH` that a name resolves to — read with every shell FUNCTION and alias of that
name deliberately unset.

> `bundle.bin.of usql` → `/home/camper/.local/bin/usql`, or the empty string
> `bundle.bin.of nvim` → `/usr/local/bin/nvim`, never the literal string `nvim`

a **bin** is what the BOX holds. it is explicitly not what the shell would run, because those two
differ on every box that sources `src/bash_aliases.sh`.

## .why the word is load-bear

| | answers with | sees a function as |
|---|---|---|
| **bin** | an absolute path, or empty | invisible |
| `command -v` | the bare NAME, exit 0 | a hit |
| `which` | varies by shell; zsh reports the function body | a hit |

the distinction is not academic. measured 2026-07-30: `5.11.usql.provision.verify` asked
`command -v usql`, was told yes by the `usql` shell function in `bash_aliases.sh`, and reported
*"usql is on PATH at the WRONG version"* on a box where `usql --version` exited **127, command
not found**. it named the wrong defect, and so offered the wrong fix.

so a verify's whole job — report what the BOX holds — needs a word for what it must read,
distinct from what a shell would run. that word is `bin`.

## .the operations it composes

**two** readers, and the split between them is the term's sharpest edge:

| operation | asks | use it when |
|---|---|---|
| `bundle.bin.of <name>` | *will a shell born now FIND this?* | the question really is about `$PATH` |
| `bundle.bin.at <name>` | *does the BOX hold this?* | a verify judges its own bundle's work |

both are declared in `src/bundle.upgrade.sh`, because a per-site `unset -f` was measured twice
to be forgettable. `bundle.bin.at` asks the declared install dir (`~/.local/bin/<name>`) first
and falls back to `bundle.bin.of`.

they follow the extant shape of their peers: `bundle.fn.of` maps a slug to its shell function,
`bundle.num.of` maps a slug to its numeric path.

### ⚠️ .why `.of` alone was not enough — 2026-08-12

`bundle.bin.of` reads the RUNNING process's `$PATH`, and a process inherits that at exec time.
so an upsert that writes `~/.local/bin/usql` changes the BOX, and the verify two lines later —
same process, same inherited `$PATH` — still cannot see it:

```
   • usql 0.19.14 installed → /home/camper/.local/bin/usql
   ✋ usql is absent from PATH
```

both lines are true and the pair is absurd. **7 of one apply's 11 claims had this one cause**,
and each read as a real defect, so a second apply looked like the cure. it is not: the bar is
one apply (`rule.require.one-command-provision`), and the verify simply asked the wrong subject.

⇒ **a verify judges the BOX, so it wants `bundle.bin.at`.** reach for `bundle.bin.of` only
where the question genuinely is *"will a future shell find this"* — a PATH claim, not a
presence claim.

## .refs
- src/bundle.upgrade.sh                                                       # both declarations
- src/grove.provision/4.terminal/4.5.nvim/provision.verify.sh                  # the first defect
- src/grove.provision/4.terminal/4.5.nvim/configure.verify.sh                  # the missed second
- src/grove.provision/5.devtools/5.11.usql/provision.verify.sh                 # the third
- src/grove.provision/5.devtools/5.1.node/provision.verify.sh                  # fnm + pnpm
- src/grove.provision/5.devtools/5.14.treesitter/provision.verify.sh           # `.at`, then a RUN
- .agent/repo=.this/role=any/briefs/shell/gotcha.command-v-answers-a-function.md    # the full lesson

## .reason
see the ref-level cluster beside this choice:
- `term=bin._.choice.reason.md` — why `which` was declined despite it naming the same idea, the
  dated evidence from the usql misdiagnosis, and why this earns a word rather than a comment

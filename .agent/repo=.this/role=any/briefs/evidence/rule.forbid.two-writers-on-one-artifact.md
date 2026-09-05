# rule.forbid.two-writers-on-one-artifact

## .what

an artifact on the box has **one** writer-kind, never two:

| kind | how it writes | what its verify may demand |
|---|---|---|
| **byte-owner** | `cp` / `cat >` — the whole file | exact equality with the checkout |
| **appender** | `>>`, findserted by a marker | its own marker is present |

a file may have **one byte-owner**, or **any number of marker-appenders**. it may
never have both. an append into a file some other bundle byte-owns is a blocker.

## .why

a byte-owner's verify is a `cmp -s` against the checkout — that is the whole point
of it, because a stale rc is invisible to a file test (it exists, it works, it is
simply an older revision). an appender writes bytes the checkout does not hold, so
after the appender runs the owner's verify can **never** pass again.

and it does not settle. the owner's next apply overwrites the file, which deletes
the appender's block; the appender's next run re-adds it. the two bundles overwrite
each other on every pass, forever.

## .the measurement — grove-1, 2026-07-31

`2.5.zsh` byte-owns `~/.zshrc`. `4.3.1.terminfo` appended its erase block to it.
after a full-tree run:

```
$ rhx grove.provision --what 2.5.zsh --mode plan
   ✋ ~/.zshrc DIFFERS from the checkout
```

permanent. apply it, and terminfo re-appended on the next pass.

### ⚠️ the part that makes this worse than a plain conflict

**terminfo never went red.** its verify accepts the marker in *either* `~/.bashrc`
or `~/.zshrc`, and `~/.bashrc` still carried it. so:

- the bundle that **caused** the defect reported ✔
- the bundle that was **broken by** it reported ✋
- the red line named the innocent bundle

a human who reads that page repairs `2.5.zsh`, watches it come back, and concludes
`2.5.zsh` is flaky. this is how a true ✋ decays into a silenced check
(`gotcha.a-check-that-cries-wolf-gets-silenced`) — the verdict was honest, and it
pointed at the wrong bundle.

## .how a shared concern reaches a byte-owned file

put the line **in the checkout**, so the byte-owner ships it. that is already how
every other concern reaches `~/.zshrc` — starship's init, fzf's bindings and fnm's
hook all sit inside `src/zshrc.sh` and are delivered by `2.5.zsh`. terminfo was the
one bundle that wrote the file directly, and it was the one bundle with the defect.

the appender keeps whatever files no bundle byte-owns (`~/.bashrc`, `~/.profile`),
and its verify keeps its own marker — so the concern is still **proven by the bundle
whose concern it is**, which is what `rule.require.seam-claims-have-an-owner` asks.

> a verify asks "is the declaration on disk?", never "did I write it?". a check
> keyed on authorship goes red on the healthy shared case.

## .the audit, as of 2026-07-31

the whole tree holds five appends. none targets a byte-owned file:

| file | byte-owner | appenders |
|---|---|---|
| `~/.zshrc` | `2.5.zsh` | none ✔ |
| `~/.bashrc` | none | `4.3.1.terminfo` ✔ |
| `~/.profile` | none | `1.1.keybinds`, `1.2.power`, `5.1.node` — distinct markers ✔ |
| `~/.bash_profile` | none | `2.5.zsh` ✔ |

two appenders on one file is **fine** — distinct markers coexist, and each findserts
its own block. it is the byte-owner beside an appender that cannot settle.

> ⚠️ this table counted FOUR appends and named two writers on `~/.profile` until
> 2026-07-31. `1.2.power` was the third, and it was invisible here because it is
> gated on `command -v system76-power`, so it appends on a pop-os laptop and
> declines everywhere else — the grove where the audit ran among them. **an audit
> run on one box counts the appends that box takes, not the appends the tree
> declares.** the roll to trust is the source, not a run.

## .the marker must be a SLUG, never the code

a findsert is only idempotent while its guard can still match. two of the three
`~/.profile` appenders grepped a fragment of the very command they wrote:

```sh
grep -qF '(keynav && echo "keynav started"' ~/.profile   # 1.1.keybinds, until 2026-07-31
grep -qF 'system76-power profile battery'   ~/.profile   # 1.2.power,    until 2026-07-31
```

that couples the guard to the COMMAND. reword the message, add a redirect, swap an
`&&` — and the guard can never match a healthy file again, so every run appends
another copy. the append was never idempotent; only the guard made it so.

a `# devenv: <slug>` marker is coupled to the CLAIM, which does not move:

```sh
local marker="# devenv: keynav autostart at login"
grep -qF "$marker" "$profile"
```

⚠️ **a marker rename is itself an append hazard.** a box provisioned before the
rename holds the pre-marker block, and a guard that looks only for the new marker
finds none and appends a second copy — the repair breaks idempotence once, on
every extant box. so a rename carries a legacy grep beside the new one, dropped
only when no box predates the marker.

## .the test

before you add a write to a file in `$HOME`, ask:

> **does another bundle `cp` this file, or `cat >` it whole?**

- yes → do not append. put your line in the checkout that bundle ships
- no → append, findserted by a marker that carries your slug

## .why the per-bundle proof cannot catch this

`prove.bundles.plan-apply-apply` runs each bundle with `--what <slug>` ALONE, so it
never sees two bundles meet. `2.5.zsh` in isolation converges its rc perfectly. the
defect exists only in the sequence a real run performs.

two checks cover it, at two grains:

| play | asks | scope |
|---|---|---|
| `prove.rc-ownership` | owner applies, neighbor applies, owner is **re-planned** | the ONE measured pair — a regression test |
| `prove.tree.fixed-point` | full apply, then full plan — does any bundle complain? | **every** bundle, no list at all |

the second is the one that catches the NEXT instance. it names no bundle and no
file: it drives the tree, asks the tree, and any slug that claims about state the
tree itself just left is the defect — whatever mechanism produced it. that is what
keeps this rule enforced without a roster to maintain
(`rule.require.bundle-as-sole-declaration`).

⚠️ the audit table above is a **snapshot, not a register**. do not treat it as the
list to append to — a list that must be hand-updated is the defect this repo kills
repeatedly, and it would go stale on the first bundle added by someone who did not
read this file. it is here to show the shape, and `prove.tree.fixed-point` is what
actually holds the line.

## .enforcement

- an append into a file another bundle byte-owns = **blocker**
- a byte-owner added for a file that already has marker-appenders = **blocker**
- an append with no marker (so a re-run doubles it) = **blocker**
- a bundle that claims under `--mode plan` after a full-tree apply, and is not a
  credential claim = **blocker** — that is `prove.tree.fixed-point`'s whole verdict

## .see also

- `rule.require.seam-claims-have-an-owner` — each claim is owned by the bundle that
  can make it; this rule is what keeps two owners off one artifact
- `rule.require.judge-declared-state-not-live-state` — why the byte-owner diffs
  against the checkout rather than tests the file
- `gotcha.a-check-that-cries-wolf-gets-silenced` — why a red line on the innocent
  bundle is the costly shape

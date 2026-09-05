# domain.term: bundle

term.chosen   = bundle
term.kind     = noun
term.synonyms.forbidden:
- entry        (names a POSITION in a list; incidental, and misnamed the moment the list is renamed)
- step         (names one ACT, where a bundle is the THING acted on. it also carried `install`'s
                sense, which `upgrade` replaced — see the disputes in the `.reason`)
- stepfn       (names the absence of a bundle, which is work not done rather than a concept)
- module       (generic; says no word about what it composites, and collides with node's sense)
- unit         (taken by systemd, and this repo installs systemd units)
- package      (taken by apt; a bundle CONTAINS packages, so the word would nest on itself)
- component    (generic; names a part, where a bundle is a whole made of parts)
- recipe       (implies a one-time make; a bundle is re-driven, per `grove.provision`)

## .what
a named composite of the packages and configs one concern needs, held as a directory under
`src/grove.provision/`. the DIRECTORY TREE is the inventory — no list of bundles exists anywhere
else, so a bundle cannot be declared and undriven.

a bundle is a **node in a tree**, and only ONE kind exists. `bundle.upgrade <slug>` looks up the
function the slug names and calls it. a body may do either, and the runtime does not care which:

- **dispatch** — call `bundle.upgrade <child>` for each part it composes
- **do the work** — the packages, the copies, the checks

so a PHASE is a bundle too (`2.8.tmux.configure.upsert` is a slug like any other), and the tree is
turtles all the way down.

> ⛔ **no composite/leaf split exists.** a prior runtime declared `bundle_composite` /
> `bundle_leaf`, an exit code 5, and a rule about which kind may read the environment — all to keep
> a COUNT honest. the count was the defect: a parent scored `0` landed in `ran` beside its
> children, so `4.3.kitty` printed ✔ on a box whose only applicable child was skipped. both kinds,
> the tally, and the third exit code fell on 2026-07-30. see the `.reason`.

## .why `bundle`
> a bundle, because it is typically a composite of packages and configs.

`entry` names where a bundle sits. `bundle` names what it is. kitty is seven artifacts (a pinned
tarball, a gpg fingerprint check, a `kitty.conf`, a theme, an icon, an `update-alternatives`
registration, a terminfo entry) under one concern — and `entry` hid exactly that composite
nature.

## .as a subdomain
a bundle names a **subdomain**, and its subbundles are composed within it:

```
4.3.kitty/            the kitty subdomain
├─ 4.3.1.terminfo/    composed within it
└─ 4.3.2.emulator/    composed within it
```

so the tree is a domain decomposition, and the order number is the path through it — one convention
for nest and order, never two.

## ⚠️ the number is a DEPENDENCY claim, not a preference

because one convention carries both nest and order, a bundle's number asserts a checkable
fact: **each thing this bundle needs is already done.** `sort -V` over the filesystem is the
whole run order (`grove.provision._.sh`), so a number placed too early is a claim the box
cannot satisfy.

the test, which is the order half of `rule.require.bundle-names-name-their-subject`:

> what does this bundle DEPEND on, and does its number sit after it?

- **yes** → the number is honest
- **no** → the bundle fails on every box, and the failure reads as that bundle's defect
  rather than as the tree's

⚠️ a number inherited from a prior layout is the case to watch. `2.4.gh` sat in `2.shell`
because the old `install_env.pt2.shell.sh` treated shell tools as one lump — but gh's real
dependency is a CREDENTIAL, and the sole credential source is keyrack, which arrives with
`5.3.brains`. so the position asserted a dependency on the shell and hid the one that mattered.
**same defect as a mis-tagged `--for` value: a taxonomy that states a falsehood about the
machine.**

the tell is cheap to check: grep for the bundle's subject between its number and its first
consumer. every `gh` reference between `2.4` and `5.10.repos` proved to be a COMMENT, so the
binary sat unused for ~40 bundles while its auth phase failed on every grove run.

**moved on 2026-08-02 to `5.4.gh`**, directly after `5.3.brains` and before `5.10.repos`, its
only consumer. two lessons the move itself taught:

1. **a side effect can BLOCK a move.** `2.4.gh` installed `curl` — for its own release key
   alone — and twelve later bundles had quietly inherited it. so gh could not move until curl
   got an honest home in `2.1.toolkit`. **before you move a bundle, ask what it incidentally
   puts on the box**, not only what it declares.
2. **the freed slot came from a DUPLICATE, never a renumber.** `5.4.ripgrep` re-installed a
   package `2.1.toolkit` already carried on its essential list — a second home for one concern
   (`rule.require.bundle-as-sole-declaration`), and, 40 bundles late, one that could never have
   put `rg` on the box. its deletion freed exactly the number gh needed.

`2.4` stands as a GAP. a number is an ordinal dependency claim, never a census, so a close of
the gap would renumber four bundles no dependency asked to move.

## .refs
- .agent/repo=.this/role=any/briefs/grove/provision/rule.require.grove-provision-bundles.md
- .agent/repo=.this/role=any/briefs/grove/provision/rule.require.bundle-as-sole-declaration.md   # one home per concern
- .agent/repo=.this/role=any/briefs/grove/provision/rule.require.identical-bundle-composition.md # every box, same set
- .agent/repo=.this/role=any/briefs/grove/provision/rule.require.bundle-names-name-their-subject.md
- .agent/repo=.this/role=any/briefs/grove/provision/rule.require.bundle-slug-matches-its-path.md
- src/bundle.upgrade.sh                    # the runtime: `bundle.upgrade`, and no other verb
- src/grove.provision._.sh                  # THE entrypoint; it reads the tree as the inventory
- src/grove.provision/                      # the tree — the inventory itself
- src/grove.provision/2.shell/_.sh                    # a SECTION, which dispatches its children
- src/grove.provision/2.shell/2.8.tmux/_.sh           # a concern, which dispatches its phases
- src/grove.provision/2.shell/2.8.tmux/configure.upsert.sh   # a PHASE, which does the work
- src/grove.provision/4.terminal/4.3.kitty/_.sh       # a concern with subconcerns, not phases

## .reason
see the ref-level cluster beside this choice:
- `term=bundle._.choice.reason.md` — etymology, the `.app` precedent, the rejected alternatives,
  and why the composite/leaf split was deleted

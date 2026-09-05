# domain.term.choice.reason: bundle

## .etymology

a **bundle** is a set of parts carried together as one. the software sense this borrows is macOS's
`.app` bundle: a *directory* that composites a binary with its resources and its `Info.plist`, and
which the system treats as a single object.

that is precisely the shape here. a bundle is a directory; it composites a package with its configs;
the driver treats it as one member of the inventory. so the word arrives with the right intuition
already attached, which is the best case for a term — a reader who knows `.app` needs no gloss.

## .the argument that produced it

the word replaced `entry`, and the human closed it in one line:

> lets call them bundles — and they're bundles, because they're typically composites of packages
> and configs

the correction is substantive, not stylistic. **`entry` names a position in a container.** it says
where a member sits and never what it is, so:

- it carries zero information about the composite nature — which is the whole property the shape
  exists to make usable
- it is misnamed the instant the container is renamed. and the container HAS been renamed once
  already this month (`procedure` → `inventory`), so this was not hypothetical
- it invited the mistake of one-artifact-per-entry, which is how kitty ended up as **five**
  inventory lines (`install_kitty` + four `configure_kitty*`) for one concern

`bundle` fixes all three, because it names the composite rather than its slot.

## .the rejected alternatives, and why each fails

| candidate | why it fails |
|---|---|
| `entry` | position, not identity. see above |
| `step` | a step is ONE act. the repo already uses it for exactly that (`bundle`), and a bundle is a composite of steps. to reuse it would overload one word onto two levels of the tree |
| `package` | taken by apt, and a bundle CONTAINS packages. the word would nest on itself: "the kitty package installs the kitty package" |
| `unit` | taken by systemd, and this repo installs systemd units (`install_runaway_monitor`). a real collision, not a theoretical one |
| `module` | generic, and node's sense is a different concept entirely. says no word about what is composited |
| `component` | names a PART. a bundle is a whole made of parts, so the word points the wrong way |
| `recipe` | implies a one-time make. the repo settled on `upgrade` precisely because the act is re-driven, so `recipe` would fight a decided term |
| `composite` | accurate but colorless, and it is the *kind* of one node type rather than a name for all of them. a leaf bundle is not a composite, yet it is still a bundle |

## .why the composite / leaf split falls where it does

the human: *"turtles all the way down — it can use the same dispatch switch on substeps"*, then
*"tag gets passed all the way through each bundle; leafs decide whether to use them"*.

so a bundle is one word for two node kinds, and the split is drawn by **who reads the environment**:

| node | subbundles | phases | reads the env? |
|---|---|---|---|
| composite | yes | no | **no** — it propagates only |
| leaf | no | yes | **yes** — it decides whether it applies |

this is the load-bear part of the design, and it was got wrong once before it was got right. an
earlier draft had each composite FILTER its children (`step local 4.3.2.emulator`). that reads
naturally and it is wrong for the same reason a top-level split is wrong: it puts the applicability
claim one level ABOVE the code that knows it. kitty knows its terminfo entry works headless; the
driver does not, and neither does the kitty composite. only the terminfo leaf does.

> a bundle that reads the environment to gate a child has taken custody of a claim that belongs to
> the child.

## .the evidence — what the word's absence cost

the term is new (2026-07-29), so its evidence is the defect its absence permitted:

`install_kitty` carried `sudo apt install kitty-terminfo`, with a correct comment on why tmux and
ssh need the entry. but `install_kitty` was tagged `local`, and the machine that needs the entry is
the **remote** one. so the lesson was learned, written down, and unreachable by every grove.

on 2026-07-29 that surfaced as three complaints that each read as its own bug:

> *"why is tmux not usable?"* · *"lots of the core utils are broken"* · *"why are backspaces
> rendered as spaces?"*

one absent terminfo entry on grove-1, three symptoms, and no run reported a defect — because no run
was ever asked to check.

the `bundle` shape is what makes the repair expressible: kitty is ONE concern whose parts differ in
applicability, so it is one bundle with two subbundles that each decide. under the old `entry`
model the only expressible answers were "two entries" (which hides the relationship) or "one tag"
(which is the bug).

## .disputes

no dispute is open.

### dispute: leaf  —  raised 2026-07-31  —  status: RESOLVED (allowed in comments, forbidden in contracts)

- raised.by  = a traveler who had just added `BUNDLE_LEAF_BROKEN` to `bundle.upgrade.sh`
- claim      = `leaf` is the ordinary tree word for a bundle that does work rather than
               dispatch, and it was already in ~30 bundle comments before this round. it
               reads naturally and nobody had objected to it.
- counter    = it reads as a **KIND**, and a kind is exactly what was deleted on 2026-07-30.
               `grove.provision._.sh` states the model outright — *"there are NO node kinds.
               no leaf, no composite, no tag, no tally."* the deleted `bundle_composite` /
               `bundle_leaf` split, its third exit code, and its tally are what let
               `4.3.kitty` print ✔ on a box whose only applicable child was skipped.

               it is also **false** under the one-kind model: a phase IS a bundle, so
               `2.8.tmux` has four children and is not a leaf at all.
- resolution = split by WHERE the word appears, per `rule.forbid.domain-term-synonyms`:
               · a **comment** may say `leaf` — it names the concept from another angle
                 ("this leaf carries no decline"), and the ~30 extant uses stay
               · a **contract** — an identifier, a filename, a message — takes the canonical
                 word. `BUNDLE_LEAF_BROKEN` → `BUNDLE_BROKEN`, and the local it reads is
                 now `parent`, which is what it actually holds: the phase's parent bundle

               the traveler introduced this violation in the same round they found it. that
               is the value of the split: prose drifts harmlessly, while a runtime identifier
               teaches the next reader a model the runtime does not have.

`entry` was in live use in code and prose for roughly one hour on 2026-07-29 before the human
renamed it. it is recorded as a forbidden synonym rather than as a dispute, because it was never
argued FOR — it was a robot's placeholder, corrected on first read.

## .see also
- `rule.require.grove-provision-bundles` — the rule this term serves
- `rule.require.upgrade-entries-verify-themselves` — the leaf's four-phase contract
- `rule.require.conform-to-sdk-environment` — the shape of what propagates down the tree
- `term=grove.provision.inventory._.choice._.md` — the ROLL that names bundles. the two terms are
  deliberately distinct: the inventory is the list, a bundle is a member
- `term=bundle._.choice._.md` — the one-act term `step` keeps, and why `bundle` could
  not reuse it
- `define.why-seaturtles-love-software` (mechanic) — *"it's turtles all the way down"*

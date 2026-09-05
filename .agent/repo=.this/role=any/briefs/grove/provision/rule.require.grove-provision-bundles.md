# rule.require.grove-provision-bundles

> 📖 **new to bundles? read `define.grove-provision-bundles.md` first.** it explains how the
> framework works — the tree, the dispatch, the exit codes, a worked trace. this rule states what
> you must not do, and assumes you already hold that model.

> 🛑 **STALE MECHANISM, LIVE CLAIMS — read before you cite a name from this file.** every
> `bundle_composite`, `bundle_leaf`, `exit 4`, and `exit 5` below names a runtime that
> `src/bundle.upgrade.sh` has DELETED. its header states the current model: *"there are NO node
> kinds. no leaf, no composite, no tag, no tally"* — the tally was the defect, since a parent
> scored `0` landed in `ran` beside its children. the runtime is now one operation,
> `bundle.upgrade <slug>`, at every depth. the CLAIMS this rule makes still hold —
> **composites propagate, leaves decide**, applicability belongs to the node that knows it, and
> a subject that spans two applicabilities is ONE bundle. the SPELLINGS do not. read
> `src/bundle.upgrade.sh` for the mechanism, and this file for the claim.

## .what

every member of the **upgrade inventory** is a **bundle**: a named composite of the packages and
configs one concern needs, which lives under `src/grove.provision/` and dispatches its
**subbundles** through the same primitive the driver uses.

one primitive at every depth. turtles all the way down.

```
src/grove.provision/
  4.3.kitty/                      # a bundle — the kitty subdomain
    _.sh                          # dispatches its subbundles
    4.3.1.terminfo/               # a subbundle, composed WITHIN that subdomain
    │  _.sh
    │  provision.upsert.sh
    │  provision.verify.sh
    │  configure.upsert.sh
    │  configure.verify.sh
    4.3.2.emulator/               # a peer subbundle, applicable elsewhere
       _.sh
       ...
```

and two things travel down the whole tree, untouched by any composite:

| what | shape |
|---|---|
| the **environment** | an `Environment` dobj, per `rule.require.conform-to-sdk-environment` |
| the **mode** | `plan` or `apply` |

**composites propagate. leaves decide.**

## .why `bundle` and not `entry`

> a bundle, because it is typically a composite of packages and configs.

**`entry` names a position in a list.** that is incidental — it says where a thing sits, never what
it is. rename the list and every `entry` is misnamed.

**`bundle` names what it IS.** kitty is not one act: it is a pinned tarball, a gpg fingerprint
check, a `kitty.conf`, a theme, an icon, an `update-alternatives` registration, and a terminfo
entry. seven artifacts, one concern. the word `entry` hid exactly the composite nature that this
rule exists to make usable.

the near precedent is macOS's `.app` bundle — a directory that composites a binary with its
resources and its `Info.plist`. same sense, same reason.

## .why subbundles, composed within the subdomain

> turtles all the way down — the same dispatch, on substeps.

### 1. it keeps applicability knowledge where the knowledge lives

kitty needs a screen. **its terminfo entry does not** — and the machine that needs the terminfo
entry is the headless one. so one concern spans two applicabilities, and only kitty knows that.

| shape | where "terminfo works headless" is recorded |
|---|---|
| two top-level bundles, differently tagged | in the DRIVER, inferrable only by a reader who compares two numbers |
| **one bundle whose subbundles decide** | **inside the kitty subdomain, beside the code it governs** |

the first shape must explain itself across two file headers, and a reader who opens only one of
them cannot see the relation. the second needs no explanation: the subbundle's own predicate
*is* the statement.

### 2. it is `install_env.grove.sh`, one level down

that file existed because a second machine kind *felt* like it needed a second procedure; the cure
was one inventory, filtered. a bundle whose parts differ in applicability is that situation
recursed, so the cure recurses too: **one bundle, whose subbundles decide.** to split it into two
top-level bundles is to reach for the `install_env.grove.sh` answer at a smaller scale.

### 3. reuse of the dispatch is what keeps `--mode plan` honest

the load-bear engineering reason, not an aesthetic one. the dispatch already owns:

- the `--what` filter
- the not-applicable report (`⏭️ skipped`)
- the undeclared-function check
- the `ran` / `skipped` / `unverified` / `failed` tally

a bundle that hand-rolled its own gate would lose all four **inside** itself. a partly-applicable
bundle would report one outcome, every internal skip would be invisible, and `--mode plan` would
stop being a complete account of what a run will do — which is the sole property that makes it
worth a run.

> reuse the dispatch, and a skip at depth 3 prints exactly as a skip at depth 1.

## .composites propagate; leaves decide

> the environment travels all the way through each bundle; LEAVES decide whether to use it.

⚠️ **the shape that lures you, and why it is wrong.** it reads naturally to have each composite
FILTER its children — `bundle_composite local 4.3.2.emulator`. that puts the decision one level
ABOVE the code that knows it: the same defect as a top-level split, merely shallower. it looks
better *in the composite* precisely because it moves the fact away from where the fact lives.

the test that catches it is **"who knows this?"**, never "where does it read well?"

the correct division of labour:

| node | its job with the environment |
|---|---|
| **composite** | pass it down, unread and unmodified. it holds no opinion |
| **leaf** | read it, and decide whether this leaf applies here |

so a composite is genuinely dumb about applicability, and that is the point: a bundle that reads
the environment to gate a child has taken custody of a claim that belongs to the child.

### the decision is the leaf's; the REPORT is still the driver's

both halves matter, so a leaf that does not apply must say so in a way the driver can tally rather
than print itself. that is a distinct exit code — `define.grove-provision-bundles`, *the exit code
IS the verdict*, holds the full table.

two of the five carry this rule's claim: **`4` (inapplicable)** is not a failure and not debt, so
it is separate from `3` (unverified) — a claim we owe versus one we do not. **`5` (composite
dispatched)** exists so the roll counts CLAIMS rather than nodes; only a leaf makes a claim.

## .the order field is the tree path

the number is the **path**, borrowed whole from route stones — not decoration, and not a group
label:

```
4          the group        (terminal & editor)
4.3        a bundle         (kitty)
4.3.1      a subbundle      (terminfo)
4.3.2      a peer subbundle (emulator)     — 1 before 2 asserts a real dependency
4.3.2.a    peers            (no order between a and b; the alpha only names one)
4.3.2.b
```

so nest and number are **one convention**, not two to keep in sync. and the number makes a claim
you are accountable for:

- a **distinct number** asserts *"this must follow that"*
- an **equal number with alpha suffixes** asserts *"either order is fine"*

⚠️ **the trap:** to read a number off the `install_env.pt4.*` filename a bundle's code lives in, and
number the bundle `44`. that conflates a FILENAME PREFIX with an ORDER. the two are unrelated — a
bundle's phases may call functions from three different `ptN` files, and its position in the run is
a claim about dependency, not about where its code happens to sit.

## .the two kinds of node

| node | holds | driver | contract |
|---|---|---|---|
| **composite** | subbundles | `bundle_composite` | propagate env + mode; claim none of it (exit `5`), save any *emergent* claim |
| **leaf** | the four phases | `bundle_leaf` | `provision.{upsert,verify}` + `configure.{upsert,verify}`, per `rule.require.upgrade-entries-verify-themselves` |

the kind is **declared** by which driver the `_.sh` calls, never inferred from whether the dir
holds subdirs. a reader knows a node's kind from its first line of code.

### a composite's own verify is OPTIONAL, and only for emergent claims

by default a composite needs no verify: if every child verified, it holds. a composite adds one
**only** for a claim that spans its children and that no child can make alone.

kitty has exactly one: *`kitten @` can drive a live window*. that needs the emulator AND the conf
AND remote control — emergent, so it belongs to the composite. a composite verify that re-checks
what a child already checked is a second copy of one claim, and the second copy is what drifts.

## .mode travels too, and every phase must honor it

`plan` is not the driver's private concern. a leaf that ignores `mode` and writes anyway has broken
the one guarantee `--mode plan` offers, and it breaks it silently.

| mode | a phase must |
|---|---|
| `plan` | report what it WOULD do, and alter no state |
| `apply` | do it |

a `verify` is READ-ONLY in both modes, so it may run under `plan` — and it should, because "what
does this machine currently fail?" is the most useful thing a plan can tell you.

## .the shape of a composite `_.sh`

```sh
grove_provision_4_3_kitty() {
  # `bundle_composite` dispatches each subbundle through the SAME `step` the
  # driver uses — so --what, the skip report, and the roll all work at this
  # depth — and returns 5, which means "dispatched; the claims are my
  # children's". no env is read here: a composite holds no opinion on where
  # its children apply
  bundle_composite 4.3.1.terminfo 4.3.2.emulator
}
```

two absences are load-bear:

- **no tag.** `bundle_composite local 4.3.2.emulator` would have the composite decide for its
  child. the child decides.
- **no verdict of its own.** a body that ended in a bare `step` would return that step's code, so
  the parent would tally the composite as a claim. on a headless box `4.3.kitty` would then print
  a green ✔ while its only applicable leaf was skipped — which reads as *"kitty is fine here"*.

### exit 5 — a composite is reported, never counted

the roll counts **claims**, and a composite makes none. so `bundle_composite` returns `5` and
`step` reports it without a tally: a kitty dispatch on a headless box rolls `ran: 1`, not `2`.
the worked trace lives in `define.grove-provision-bundles`.

## .the hard-cut mandate

imposed as a **migration in waves** — the same terms as
`rule.require.upgrade-entries-verify-themselves`, which carries the full argument. the short
version: fix-forward exempted the untouched members, and the untouched members are exactly where a
silent miss survives.

| when | what you owe |
|---|---|
| you **add** a member | it is born a bundle. no exemption |
| you **touch** a member | convert it, then make your change |
| a **wave** reaches its section | every member in that section becomes a bundle |
| its parts differ in applicability | subbundles that decide; never two top-level bundles |

the end state has a number: **zero `stepfn` lines, and no `pt*.sh` files.** `stepfn` itself is
deleted when its last caller goes, because a driver kept for a shape nobody uses is a second way
to declare a step (`rule.require.bundle-as-sole-declaration`).

## .the test

1. **is it a composite of packages and configs?** — nearly always yes, so it is a bundle
2. **do its parts differ in where they apply?** — then it is ONE bundle with subbundles that
   decide, never two bundles
3. **does its dispatch reuse `step`?** — a hand-rolled gate has blinded `--mode plan` inside it
4. **does any composite read the environment?** — if so, it has taken a decision from its child
5. **does every phase honor `plan`?** — a phase that writes under `plan` has broken the guarantee

## .enforcement

- a **new** inventory member authored as a bare function = **blocker**
- a **touched** member left as a bare function = **blocker**
- a member left as a bare function after its section's wave = **blocker**
- a bundle split into two top-level bundles because its parts apply differently = **blocker**
  (it is `install_env.grove.sh` recursed)
- a **composite** that reads the environment to gate a subbundle = **blocker** (leaves decide)
- a bundle that gates subbundles with hand-rolled logic instead of `step` = **blocker** (it blinds
  `--mode plan` and drops the roll's counts at that depth)
- a leaf that returns `0` when it did not apply = **blocker** (it inflates `ran`; use `4`)
- a composite that returns `0` rather than `5` = **blocker** (it is tallied as a claim it never
  made, so a headless box prints ✔ on a bundle whose only applicable leaf was skipped)
- a phase that alters state under `--mode plan` = **blocker**
- a number that encodes a filename prefix or a group label rather than an order = **blocker**
- a composite verify that re-checks a claim a child owns = **blocker**

## .see also

- `rule.require.upgrade-entries-verify-themselves` — the LEAF contract: four phases, and the
  exit-3 unverified axis. this rule is its composite half
- `rule.require.bundle-as-sole-declaration` — WHERE a bundle's body lives (in the bundle, once)
  and what it may call out to. this rule shapes the tree; that one shapes each node's contents
- `rule.require.conform-to-sdk-environment` — the shape of the env dobj that travels down
- `rule.require.grove-provision-as-the-only-entrypoint` — one entrypoint, one inventory, every
  member idempotent. bundles are what that inventory holds
- `rule.require.every-function-has-a-driver` — every function needs a driver, and a bundle PHASE is
  one of the two forms it accepts
- `rule.require.input-context-pattern` (mechanic) — env + mode are injected **context**, never
  positional args. the propagation here is that pattern in bash
- `domain.terms/term=bundle._.choice._.md` — the term, its forbidden synonyms, the argument
- `domain.terms/term=grove.provision.inventory._.choice._.md` — the ROLL that names the bundles;
  the two terms stay distinct on purpose
- `define.why-seaturtles-love-software` (mechanic) — *"it's turtles all the way down"*, which this
  rule is a literal instance of

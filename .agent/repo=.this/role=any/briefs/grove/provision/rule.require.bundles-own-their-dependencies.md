# rule.require.bundles-own-their-dependencies

## .what

a bundle installs every tool it calls. it may not assume a tool is present because
another bundle installs it, and it may not settle for an error that points the reader at
another bundle.

the test: **can `--what <this-slug>` alone converge on a fresh box?**

- yes → the bundle owns its dependencies
- no → it is half a bundle

## .why

- the driver ACCEPTS any slug, so a human can drive any bundle alone. a bundle that only
  works after some other bundle ran is a slug the driver reports on and cannot deliver
- the number is a **tree path, not a dependency edge**. `1.system` runs before `6.apps`
  today because 1 sorts before 6 — no rule keeps that true, and no line declares it
- a dependency you do not install is a dependency you **assume**, and the assumption
  holds on the box you wrote it on and nowhere else. every such assumption is found by a
  DIFFERENT machine, later, at the worst time
- an error whose fix the box cannot execute is a dead end in the costume of a fix

## .the two shapes this rule forbids

### 👎 the silent assume

```sh
# the finders do float math on load average against a core count
[[ $(echo "$LOAD > $CORES" | bc) -eq 1 ]]   # needs `bc`, which debian minimal lacks
```

absent `bc`, every threshold evaluates false — so each finder RUNS, prints, exits 0, and
names no hog **under any load**. a failure that reads exactly like a pass.

### 👎 the pointer-shaped error

```sh
if ! command -v flatpak >/dev/null 2>&1; then
  echo "   ✋ flatpak is absent, so no flathub app can be installed" >&2
  echo "      fix: rhx grove.provision --what 1.system --mode apply" >&2
  return 1
fi
```

honest, and still wrong: `--what 6.1.flatpaks` cannot converge, and the reader is sent to
a section whose relevance is an accident of the numbers.

## .the shape it requires

```sh
if ! command -v flatpak >/dev/null 2>&1; then
  pkg_install flatpak || return 1
  echo "   • flatpak installed — this box shipped without it"
fi
```

`pkg_install` converges, so the cost on a box that already has the tool is one skipped
apt call (`rule.require.idempotent-install-procedures`). two bundles that both install a
tool is not duplication of WORK — it is two declarations of one true dependency, and each
is checkable where it is used.

## .the record — this rule was learned twice

| date | bundle | assumed | what it cost |
|---|---|---|---|
| — | `1.6.1.finders` | `bc` | every load threshold read false; the finders reported a healthy box under any load |
| 2026-07-30 | `1.3.1.firefox` | `flatpak` | `flatpak: command not found` on grove-1, and the bundle's own fix line named a `flatpak install` the box could not run either |
| 2026-07-30 | `6.1.flatpaks` | `flatpak` (via `1.3.1.firefox`) | `--what 6.1.flatpaks` alone could not converge |

the third is the interesting one: it was not a silent assume — it *reported* the absence
with a named fix. the rule still catches it, because the claim a slug makes is "drive me
and I converge", and it could not honor that alone.

## 🛑 .the test that decides — is the install ONE CALL, or a second home?

*"install every tool you call"* is too wide by a whole class — applied literally it condemns
`5.10.repos`, which is **correct as written** (measured 2026-08-14). so ask what the install
would COST here:

| the dependency is… | the right shape | why |
|---|---|---|
| a tool one `pkg_install` converges | **install it** | free when present, and the slug becomes drivable alone |
| a tool whose install needs an APT SOURCE + a pinned key another bundle declares | **name the owner** | to install it here is to give that source and that key a second home |
| a CREDENTIAL or state another bundle produces | **name the owner** | no install exists to do; the owner failed, and that is the fact to report |

⚠️ **rows 2 and 3 are not a loophole — they are narrower than they look.** the fix-text is
legitimate only when the named bundle runs EARLIER, so its absence means that bundle
FAILED. a fix that points FORWARD is a defect of order, and belongs to
`rule.require.one-command-provision`'s first shape, not here.

### the worked pair, both live today

```sh
# 👍 row 1 — jq is one call away, so 2.9.emoji installs it
if ! command -v jq >/dev/null 2>&1; then
  pkg_install jq || return 1
fi

# 👍 row 2 — gh needs github's apt source and pinned key, which 5.4.gh declares
if ! command -v gh >/dev/null 2>&1; then
  echo "   ✋ gh is absent — cannot list org repos" >&2
  echo "      ⇒ the binary is 5.4.gh's claim … its provision phase failed above" >&2
  return 1
fi
```

the second is not an assumption with no owner. it names one, it names the right one, and
it names one that already ran — which is the whole difference from the pointer-shaped error
below.

## .the one exception

a tool the whole run assumes at its boundary — `bash`, `apt-get`, `git` — belongs to the
BOOTSTRAP, not to a bundle. `grove.bootstrap.sh` asserts apt before it clones, and
`grove.pkg.sh` asserts it again at the package boundary. those are declared invariants
with one owner each, which is the opposite of an assumption with none.

⚠️ the exception covers the ASSERT, never the FIX-TEXT. `2.8.tmux` asserted `git` — blessed
by this exception — and still pointed its reader at `--what 2.2.git`, which is forbidden
regardless. it now installs, because git is also an ordinary apt package and row 1 applies.

## 📜 .the three the rule caught, 2026-08-14

| site | it said | why it was wrong | the repair |
|---|---|---|---|
| `2.9.emoji` | `fix: … --what 2.1.toolkit` | jq is one `pkg_install` away | installs jq |
| `5.3.brains` | `fix: … --what 2.shell` | same, and it pointed at a whole SECTION | see below |
| `2.8.tmux` | `fix: … --what 2.2.git` | git is one call away, and the assert was blessed while the pointer was not | installs git |

⚠️ **`5.3.brains` needed a different repair, and the difference is the PHASE.** the tool is
used by its `configure` phase, so the obvious fix was a `pkg_install` right there — and that
would have been the only such call in the tree. two reasons it is wrong:

- `provision` puts a tool on the box; `configure` points it at this repo's config
  (`repo.overview.md`). an install in configure blurs the split
- the provision VERIFY gates the configure phase, so an install below that gate is one the
  gate can never see (`rule.require.upgrade-entries-verify-themselves`)

⇒ so the install went into `provision.upsert`, and the configure phase keeps an assert whose
fix names **its own slug**. a self-referential fix is not a pointer: one apply of the named
bundle converges it.

⚠️ **`2.9.emoji` argued its case in a comment**, which is what made it durable: *"a second
`pkg_install` would be a second declaration, and on a seat with no root it would fail over a
package that is already present."* both halves are false — the rule answers the first
directly, and the second was measured false at `grove.pkg.sh:386-403`, where `pkg_install`
reads `pkg_present` and returns 0 **before** `pkg_assert_sudo` is reached.

⇒ a decline whose REASON is wrong reads as careful, so a reader agrees with it and moves on
(`term=decline._.choice.reason.md`). the argument is what kept the defect alive, not the code.

## .enforcement

- a bundle that calls a tool ONE `pkg_install` would converge, and does not install it =
  **blocker**
- an error that names a fix in another bundle where row 1 applies = **blocker**
- an error that names a fix in a bundle that runs LATER = **blocker** (an order defect;
  see `rule.require.one-command-provision`)
- a bundle whose `--what <slug>` alone cannot converge on a fresh box, where every
  dependency it lacks is row 1 = **blocker**
- ⚠️ a row-2 or row-3 pointer deleted as a "pointer-shaped error" = **blocker**. read the
  table above before a cull: `5.10.repos` names `5.4.gh` correctly, and to "fix" it would
  give github's apt source and pinned key a second home

## .see also

- `rule.require.idempotent-install-procedures` — what makes the duplicate declaration free
- `rule.require.bundle-as-sole-declaration` — the directory is the inventory; the number is a path
- `rule.require.errors-name-the-fix` (ergonomist) — a fix the box cannot run names no fix
- `rule.require.exemptions-name-their-trigger` — the decline shape, for what a box truly cannot hold

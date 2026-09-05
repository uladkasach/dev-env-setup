# define: `6.apps` is laptop-only AND opt-in — no box installs any of it unasked

## .what

`src/grove.provision/6.apps/` holds five bundles, which offer **seven apps**. two
independent gates stand between a run and an install, and a bundle must clear
**both**:

| gate | asks | scope |
|---|---|---|
| the **box** gate | can this box even run a GUI client? | per box class — a grove declines all five |
| the **opt-in** gate | did the human ask for this app? | per app — the default is none, on every box |

| bundle | apps it offers | on `cloud@aws.ec2` | on a laptop, unasked |
|---|---|---|---|
| `6.1.flatpaks` | `spotify` `datagrip` `slack` | 🌙 no screen to draw a GUI client on | 🌙 not opted in |
| `6.2.codium` | `codium` | 🌙 a grove edits through nvim over its duct (`4.5.nvim`) | 🌙 not opted in |
| `6.3.dropbox` | `dropbox` | 🌙 no screen, and no human to sign it in | 🌙 not opted in |
| `6.4.protonvpn` | `protonvpn` | 🌙 a grove reaches private hosts through its own duct | 🌙 not opted in |
| `6.5.onepassword` | `onepassword` (the app + `op`) | 🌙 a grove is handed scoped credentials instead | 🌙 not opted in |

```sh
grove.provision --mode apply                      # installs NO app in this section
grove.provision --include codium --mode apply     # opts one in
grove.provision --include codium,slack            # comma-joined, or repeat --include
```

⚠️ **the section still RUNS.** every bundle is visited and every phase reports; an
app nobody asked for prints a 🌙, which is a decline and never a claim. this
section is not skipped — it is **empty by default**.

## .why opt-in, and why it is the tree that says so

every other bundle in the tree converges a box toward a **fact**: a box needs a
shell, a git, a node. these five install a **preference**, and a human's taste is
not a fact about the machine. so the tree declares what is AVAILABLE and the
command declares what is WANTED.

⚠️ **a brief alone cannot declare this.** a note that calls a bundle "optional" while its
code installs unconditionally is false about the code it describes. the tree is the sole
declaration (`rule.require.bundle-as-sole-declaration`), so the gate lands there and this
file holds no second copy of the app list.

### where each half is declared

| fact | declared in | read by |
|---|---|---|
| which apps exist | each bundle's `_.sh`, via `GROVE_OPTIN_APPS+=(…)` | the entrypoint, to validate `--include` |
| which apps are wanted | `--include` on the command | `grove_optin`, in `src/bundle.upgrade.sh` |

⚠️ the offered set is **never listed in the parser**. a list beside `--include`
would be a second declaration of what the tree already holds, and it would go
stale the day an app is added — with no signal, since a name absent from it is
indistinguishable from a typo.

### 🛑 a typo is refused, and never silently installs none

```
✋ --include named no app this checkout offers: codum
   ⇒ every bundle would decline it, and the run would report done
     with only what a run carrying no --include installs
   the apps this checkout offers:
     codium
     datagrip
     …
```

that refusal is the whole reason the offered set is derived rather than assumed:
without it, `--include codum` declines every bundle, installs the same set a bare
run installs, and reports `🌲 done` — the human asked for an app, got none, and
was told the box converged (`rule.forbid.failhide`).

⚠️ it is checked **before** any bundle runs, unlike `--what`'s equivalent, which
cannot answer until the last bundle has been offered its slug
(`rule.prefer.prevent-over-correct`).

## .the one opt-out with a cost inside this repo

`6.5.onepassword` is the exception worth knowing: `src/backup_env.sh` and
`src/util.yubikey.ssh.sh` each call `op`. a box that opts out holds both files and
no `op` — the exact state that bundle was written to end.

that is a deliberate trade. neither is on the provision path and both are
human-run, so an absent `op` costs a human one `--include onepassword` at the
moment they reach for a credential — where an unasked-for GUI vault costs every
laptop an install it never wanted.

⚠️ one opt-in name covers **both** packages. they are installed separately, on
purpose (the app can be present while `op` is not), but that split is about
CONVERGENCE, not taste — a human who wants the vault wants its cli, and two names
would let a box ask for half a bundle.

## .what opt-in retired

`6.4.protonvpn` is the bundle that earns this the most. its download url answered
**404 for months** and no run could see it: a grove DECLINED the install and a
laptop SKIPPED it on an already-present binary, so both printed a clean result
about a path that could not work.

⇒ **an app a human never asked for is an app whose failure nobody reads.** it was
found the first time a play was pointed at the wire on its behalf
(`define.provision-defect-shapes`, `.the DARKEST corner`).

✔ that gap is CLOSED. `prove.apt-sources-serve` opens the `.deb` and reads proton's apt
index out of it. that play found **two more** defects in this bundle: `pkg_install
protonvpn` names a package proton does not serve, and the verify tested a binary that
belongs to a different package. ⚠️ opt-in closed neither — it spares a laptop an app nobody
asked for; a play is what proves the app would work if asked for.

## .why this brief exists

*"why does a grove install a music player / a vault / a vpn?"* gets asked repeatedly, and
the answer is always three words: **it does not.** the section NAME invites the question —
`6.apps` reads like a list of what a box gets, when it is a list of what a laptop MAY get.

⇒ **a section named for WHAT it holds invites a reader to assume WHO gets it.** the answer
is written down once for both box classes, proven for each, so the next reader spends no
time on it.

## .the measurements

`.refs = gotcha.6-apps.demo=optin-gate-measurements, m1-m2`

a grove visits all 14 phases and declines every one, zero packages. a bare laptop visits
all 5 bundles and declines every one until `--include` names it, each decline with its own
fix — so this brief carries no second copy of the app list.

## .why a grove does not want any of them

each decline states its own reason at the bundle, and they are three reasons, not one:

1. **no screen.** flatpaks, dropbox, protonvpn and codium are all GUI clients. a grove
   has no display, so the package would install and never draw.
2. **no human.** dropbox and 1password need a human to sign in or unlock by hand. a
   box with no human cannot complete either, so the install would leave an inert
   binary and a `✋` nobody can clear.
3. **a grove already has the capability, by a different route.** this is the one worth
   remembering, because it is why the absence costs no capability at all:

   | the laptop reaches it by | the grove reaches it by |
   |---|---|
   | codium, a GUI editor | nvim over its duct (`4.5.nvim`) |
   | protonvpn, to reach private hosts | its own duct (`rule.require.reach-a-grove-through-its-duct`) |
   | 1password, a vault a human unlocks | scoped credentials through keyrack (`plan.grove-credentials.md`) |

⚠️ so the decline is not a gap to close later. **a grove that installed these would be
worse**, not more complete: three more packages to keep current, a vault that can
never unlock, and a vpn that competes with the duct for the same routes.

## .the guard, and its one sharp edge

every decline site in the tree spells the test the same way:

```sh
[[ "$GROVE_ENV_SERVER" != local@* ]] || return 0
```

⚠️ the count below is a MAGNITUDE, and it is re-derivable — do not trust it, ask:

```sh
rhx grepsafe --pattern 'GROVE_ENV_SERVER" != local@\*' --path src/grove.provision
#    → 37 sites, 37 files   (measured 2026-08-14)
```

a count written into a brief is a second declaration of a fact the tree already holds,
so it decays with no signal (`repo.overview.md`, `.the shape`). this one is kept because
the ARGUMENT below turns on its size, not on its exactness — but the command is what
settles it.

that is correct **today** and only because the detected set is CLOSED at two —
`local@unix` and `cloud@aws.ec2` (`src/grove.env.sh`, `.the CLOSED SET`). `local@*`
therefore means exactly `local@unix`.

⚠️ **the tag is coarser than the fact.** these bundles depend on *a screen and a human*,
and `local@*` reads a tier prefix. a `local@cicd` runner would be local tier with
neither, so it would match `local@*` and NOT decline — and a CI job would try to
install a GUI vault.

that box is not detected, so this is latent rather than live. the closed set is the
guard. `grove.env.sh` already states the procedure for whoever adds a third platform
(*"write its probe, give it a rung, and MEASURE it"*), and **that** is the moment these
37 sites must move from `local@*` to `local@unix` — not before, or the diff is 37 files
for no behavior change.

## .what this does NOT say

- it does not say `6.apps` is dead code. on a laptop all five RUN — every phase is
  visited and reports — and each installs the moment its app is named.
- it does not say the section should be deleted. it is the only declaration of what a
  human's workstation MAY get, and `rule.require.bundle-as-sole-declaration` is why it
  lives in the tree rather than in a doc.
- ⚠️ it does not say opt-in makes these bundles exempt from anything. an OPTED-IN app
  must still converge in one non-interactive apply, and its verify must still hold. the
  gate changes WHEN a bundle installs, never HOW.
- ⚠️ it does not say a forgotten `--include` uninstalls. an app dropped from the flag is
  simply not upgraded — the opposite would make a forgotten flag destructive, which
  `rule.require.safe-by-default` forbids.
- it does not say a laptop-only bundle is exempt from `rule.require.one-command-provision`.
  a converged laptop must still converge in one non-interactive apply, and a bundle that
  reaches for `sudo` before it reads whether work remains breaks that on the laptop even
  though a grove never sees it.

## .see also

- `src/bundle.upgrade.sh` — `GROVE_OPTIN_APPS`, `grove_optin`, and why the offered
  set is built by the bundles rather than listed beside the parser
- `src/grove.env.sh` — the closed two-platform set, and how to add a third
- `repo.overview.md` — `$server = $tier@$platform`, and why the tag is coarse
- `plan.grove-credentials.md` — how a grove gets secrets with no vault
- `rule.require.reach-a-grove-through-its-duct` — why no vpn is owed
- `rule.require.bundle-as-sole-declaration` — why the tree is the inventory
- `gotcha.6-apps.demo=optin-gate-measurements` — the two runs behind `.the measurements`

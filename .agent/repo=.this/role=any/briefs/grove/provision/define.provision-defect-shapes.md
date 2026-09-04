# define.provision-defect-shapes

## .what

the ten shapes that break `rule.require.one-command-provision` — each in full, with the
measurement that found it and the repair that closed it.

that rule is booted at say level and states the bar, the four properties, the test, and a
one-line catalogue of every shape below. **this file is that catalogue's long form.** read a
shape here when you have hit it, or when you are about to write the kind of phase it names.

⚠️ the shapes are numbered in the order they were FOUND, and that order carries no rank
beyond the first: shape 1 is the most common cause of a second apply, and the nine after it
are unordered.

⚠️ **"this rule", anywhere below, names `rule.require.one-command-provision`.** every shape
here is one way to break it, so the pronoun has exactly one referent throughout this file.

## .see also

- `rule.require.one-command-provision` — the bar, the test, the catalogue, the enforcement
- `rule.forbid.deferred-provision-defects` — a defect against that bar may never be filed
- `gotcha.a-check-that-cries-wolf-gets-silenced` — the false-✋ half every clamp below guards

---

## 🛑 .the shape that produces most violations — a bundle numbered for its SUBJECT

by far the most common cause of a second apply is one defect with one signature:

> **a bundle is numbered for what it is ABOUT, while its real dependency is a tool or a
> credential that lands in a LATER section.**

the phase then cannot converge on a first apply, so it declines — truthfully — and tells the
human to apply again. the decline is what makes it survive: its REASON is correct, so a reader
agrees with it and moves on (`term=decline._.choice.reason.md`).

**four instances, all found the same way:**

| the bundle | numbered for | its real dependency | fixed |
|---|---|---|---|
| `2.4.gh` | the shell | a credential from `5.3.brains` | → `5.4.gh`, 2026-08-02 |
| `4.5.nvim`'s tree-sitter build | the editor | cargo, from `5.2.rust` | → `5.14.treesitter`, 2026-08-12 |
| `2.2.git`'s identity | git | a credential from `5.4.gh` | → `5.15.identity`, 2026-08-12 |
| `5.10.repos`' ssh-key decline | — | a key from `2.3.ssh`, which runs EARLIER | fix text corrected, 2026-08-12 |

⚠️ the last row is the **inverse**, and it is worth as much as the other three: the dependency
came earlier, so "apply it again" was not merely unhelpful — it could never work. a re-run
finds the same absence and prints the same line, forever.

⇒ **"apply it again" is a real fix ONLY where the dependency comes LATER.** where it comes
earlier, an absent artifact means that bundle did not converge, and the fix belongs to IT.

### ⚠️ .this shape is now CLAMPED statically — `prove.fix-texts-are-actionable`

the test below is a human's read, and it is also mechanical enough to check on every box: the
play walks the run order out of the DISPATCH, then demands that every cross-bundle fix name a
bundle which runs EARLIER, and it refuses both an absent slug and a forward fix.

⇒ measured 2026-08-13: **27 cross-bundle fix-texts, and every one points backward.**

🛑 **the order is read from the DISPATCH, never from the number**, and that is not a detail —
the tree dispatches by dependency, so the digits and the run order disagree freely
(`repo.overview.md`, `.the shape`, holds the worked example and both dispatch shapes). a
reader who sorts by number — or worse, lexically, where `5.14` precedes `5.2` — answers the
test below about an order no run takes. **the number is a stable identifier; the dispatch is
the order.**

⚠️ and the dispatch has TWO shapes: the ROOT has no `_.sh` at all (sections are globbed
from the filesystem and `sort -V`'d by `grove.provision._.sh`), while every depth below
dispatches explicitly in written order. a walk that knows only one shape reads an EMPTY
order and reports every reference as a ghost — which is what the play's own first run did
(`repo.overview.md` had claimed a root dispatcher that has never existed).

### .the test, for any decline you write or read

> **does this decline name another bundle? then: does that bundle run BEFORE or AFTER this one?**

| it runs… | then the decline is… |
|---|---|
| **after** | a defect of order. MOVE this phase to a bundle after it — never carry the decline |
| **before** | that bundle failed. name IT in the fix, and never suggest a re-apply of this one |

a bundle is a unit of **dependency**, not a unit of subject or of destination file. two
bundles may write one file when each owns a distinct key
(`rule.forbid.two-writers-on-one-artifact` binds one ARTIFACT to one writer — `user.email`
and `alias.tree` are distinct artifacts that merely share a container).

⚠️ and when a phase MOVES, re-read every decline it carries: a 🌙 that was correct in the old
bundle is often a ✋ in the new one, because the dependency that justified it now runs first.

## 🛑 .the SECOND shape — a box-wide write asked for by a seat that has no root

the other defect that costs an apply, and it is the seat's version of the first:

> **an upsert reaches root to set a BOX-WIDE fact, and asserts the privilege BEFORE it
> reads whether the fact already holds.**

on a two-seat grove the camper has no sudo, so the assert fails, the phase fails, and every
later phase of that bundle is skipped — over a fact `ground` already set, with the same
bundle, minutes earlier.

⚠️ the fix-text such a phase prints is always a hand step (*"run this from a terminal"*,
*"give the user NOPASSWD"*), so the defect arrives already dressed as this rule's violation.

### .the pattern that is already correct, and must be copied

`pkg_install` has had the right shape since 2026-08-10, and its header states it:

> *what is already true is read first (a free, sudo-free `dpkg` read), and the machinery to
> CHANGE the box is asserted only when there is a change left to make.*

so the order is fixed, and it is the whole fix:

| step | asks | needs root? |
|---|---|---|
| 1 | does the box-wide fact already hold? | never — every such fact has a read-only query |
| 2 | it holds → report `✔` and return | — |
| 3 | it does not, and this seat has no root → `🌙`, naming the seat that owns it | — |
| 4 | it does not, and this seat HAS root → set it | yes |

⇒ **a seat with no root READS a box-wide fact rather than sets it.** that satisfies
`rule.require.seam-claims-have-an-owner`, because the grant has an owner: the seat with
sudo, made to do it by the same bundle.

### .the test, for any `sudo` in an upsert

> **before this line asks for root, has it read whether the state it wants is already true?**

- yes → correct, whatever the seat
- no → it fails on every seat without root, over work that may be already done

⚠️ `pkg_install` and `pkg_apt` already satisfy this, so a package install is never the
instance. **a DIRECT `sudo` is** — `update-alternatives`, a write under `/etc`, a `systemctl`
enable, a `chsh`. those are the sites to read.

### .measured — five phases, one cause, 2026-08-12

a full `--mode apply` on the camper seat of `grove-ahbode-v20260811`:

```
✋ sudo needs a password…   ← 1.1.keybinds.provision.upsert
✋ sudo needs a password…   ← 1.4.sysctl.configure.upsert
✋ sudo needs a password…   ← 1.8.tmpfiles.provision.upsert
✋ could not enable earlyoom.service
✋ grove.provision finished with failures
```

plus `4.3.2.emulator.configure.upsert`, found the same day. every one asserted root before
any read; every one was already true, set by ground with the same bundle. after the reorder,
the same command on the same seat reports **zero ✋**, and each phase prints the fact it read:

```
• keyd + keynav installed, linked, and the daemon is up ✔
• both sysctl keys already declared and live ✔
• both units match this checkout, and the timer is enabled ✔
• earlyoom.service already enabled and active ✔
• default terminal: kitty (/usr/local/bin/kitty) — already selected box-wide ✔
```

⚠️ **the read must be of the FACT, never of a proxy for it.** `1.6.3.earlyoom`'s header
already condemned an early return on `command -v earlyoom` — a binary-presence test that
passes on a box whose unit was masked. so the read is `systemctl is-enabled` **and**
`is-active`: the daemon itself, which is stronger than the test the header rejected. a
reorder that reintroduces a presence test has traded one defect for the other.

⚠️ **and this evidence is one-directional.** on a converged box every read short-circuits, so
the runs above prove the SKIP path and exercise no WRITE path at all
(`gotcha.a-check-that-cries-wolf-gets-silenced` — a check proven in one direction is half
proven). only a first apply on a fresh box drives the writes, which is the same single
measurement this whole rule waits on.

#### ⚠️ .PART of that blind spot is now closed, statically

the decline branch carries three claims, and each needs different evidence:

| the claim | proven by |
|---|---|
| the decline's **reason** is true | a read, by a human — no grep reaches it (`term=decline._.choice.reason.md`) |
| the decline's **exit code** is 0 | `prove.root-declines-return-zero`, statically, on any box |
| no `sudo` below it can **prompt** | `prove.sudo-is-gated-or-nonintera`, statically, on any box |

the second is worth its own play because a wrong digit there is silent and expensive: the
runtime reads the phase's EXIT CODE, not its glyph. a decline that returns 1 fails the
phase, and the chain then stands down every later phase of that bundle — on the camper,
which is the seat that does the work. that is precisely what `1.1.keybinds` did before its
reorder, over four facts `ground` had already set with the same bundle.

⇒ measured 2026-08-13: **7 decline call sites, all return 0**, and the reader was seen to
refuse a deliberate `return 1`. so a branch that runs ONLY on a fresh box's camper seat is
proven without a fresh box.

the third clamps `.the SECOND shape` above: every bare `sudo` in every upsert must be
unreachable by a prompt. three shapes satisfy it, and the play accepts all three — a reader
that demanded only the first would report a false ✋ on bundles that already cannot prompt:

| shape | why a prompt is unreachable |
|---|---|
| decline-gated | `pkg_can_sudo` / `bundle.root.owns` ran first, so a seat with no root declined before privilege was asked for |
| `sudo -n` | non-interactive by construction — it fails rather than prompt |
| assert-gated | `pkg_assert_sudo` is `sudo -n true`, so either root is password-less or the phase returns 1 above the sudo |

⇒ measured 2026-08-14: **64 bare sudo call sites, 52 decline-gated and 12 assert-gated**,
with a nine-arm fixture that classifies each shape correctly and refuses an ungated one.

🛑 **that count read 51 on 2026-08-13, and the 13 it was short were not new code.** the
reader anchored on `^sudo`, so it saw only a sudo that OPENS its line — and the tree has
written root a second way, `printf … | sudo tee …`, for as long as it has had apt sources.
sites across ten bundles appeared in **no row that play ever printed**. every one turned out
gated, so the verdict was right and its evidence covered two thirds of its subject
(`gotcha.a-check-that-cries-wolf-gets-silenced`, m.12 / q11: *in how many forms is this
subject written, and which does the pattern match?*).

⇒ the cut is now a shared, quote-aware tokenizer — `_.shell-tokenize.lib.sh`, whose
header holds its callers and its arms.

⚠️ the 12 assert-gated sites are **safe-but-worse**, and the play says so rather than flags
them. an assert cannot wedge a box; it does fail the phase where a gate would 🌙 and name an
owner. all 12 sit in laptop-only bundles that return 0 for `!= local@*` above the assert, so
a grove reaches none — a legibility note here, not a violation of this rule.

⚠️ this narrows the corner; it does not close it. the WRITE path below each gate is still
exercised by no run this repo can make, and the decline's *reason* is still a human's read.

#### ⚠️ .the OTHER half of non-interactive: apt, which does not fail but WAITS

`sudo` is the prompt this repo watches for, and it is not the expensive one. apt does not
merely ask — it **draws a menu, holds the dpkg lock, and waits**. on a duct that menu sits
on the pane and eats every command sent afterward.

📜 measured 2026-08-06: `5.8.docker` called `sudo apt-get install -y docker-ce` directly.
the packages installed, needrestart drew its menu, and the box was wedged for **57
minutes** with no human able to see why. `PKG_APT_ENV` + `pkg_apt` are the repair.

⇒ that repair is a **guarantee**, not a check, and the two rot differently:

> a copy of a guarantee is worth more than a copy of a check, because a check that drifts
> **reports**, and a guarantee that drifts **hangs**
> (`rule.require.every-function-has-a-driver`)

📜 measured 2026-08-13, and it is that sentence in miniature: the root dispatch held a
HAND COPY of `PKG_APT_ENV` as its process-wide braces — and had drifted to **one of three
variables**, with `NEEDRESTART_MODE` (the one that costs the 57 minutes) among the two
absent. its own comment argued *"a per-call fix is a second list, and a second list
drifts"*, while BEING the second list that drifted. it now expands the array instead.

`prove.apt-is-never-interactive` is the clamp, and it is static — no network, no privilege,
same answer on every box. it declares its own five directions; the one worth a reader's
attention here is the last, because the other four are all satisfied by a repo whose
process-wide export was deleted:

⚠️ **a guarantee is proven where it is CONSUMED, never where it is declared.** the array
would still exist, still agree with the bootstrap, and every call site would still route
through the boundary — while the one case the braces exist FOR, a deb tool started by a
package's post-install hook, ran bare.

⚠️ **two declarations are correct here and may not be collapsed.** `grove.bootstrap.sh`
runs before the repo exists, so it cannot source the boundary — that is this repo's one
documented exemption. the answer to an unavoidable copy is to CLAMP it, never to pretend
it is not a copy.

### 🛑 what that blind spot hid for a day — measured 2026-08-13

the reorder above is correct and was, for a day, **unreachable**. `pkg_can_sudo` — the free
read every one of those gates draws its answer from — held this line:

```sh
[[ -t 0 ]] && return 0     # 👎 a tty says sudo can ASK, never that anyone will ANSWER
```

a duct is tmux, and a tmux pane has a tty. so on the camper the predicate said **yes**, and
every gate above would have fallen through to its root half, where `sudo` prompts onto the
pane and eats the next command sent down the duct.

⚠️ **two clean camper applies ran with this live**, and neither could see it: each upsert
read its fact first, found it true, and returned before privilege was consulted. so the
`zero ✋` above was true and proved a different claim than it appeared to.

what caught it was a direct probe, `prove.root-decline-bites`, on its first run:

```
├─ sudo: this seat holds none without a password
├─ bundle.root.owns → rc=0        ← waved through
```

⇒ **the lesson for this rule:** a converged box cannot test a gate whose whole job is to
decide what happens when a fact is ABSENT. where a fresh grove is out of reach, the next
best evidence is a probe that calls the gate directly — never another apply.

the full account, and the exemption-shaped defect behind it, live in
`rule.forbid.tty-as-a-proxy-for-a-human`.

## 🛑 .the THIRD shape — a phase that is DECLARED and never called

the two shapes above both END IN A LINE: a `🌙` a human reads, or a `✋` with a hand step.
this one ends in silence, and that makes it the hardest of the three to find.

> **a phase file whose bundle's `_.sh` omits its `bundle.upgrade` line is sourced,
> declared, and never called.**

no error. no glyph. the bundle prints its other phases, the run ends
`🌲 grove.provision done`, and the box is short one phase's work.

### .why the runtime cannot catch it

`grove.provision._.sh` sources `$BUNDLE_DIR/**/*.sh` — every file, at every depth — so the
function EXISTS. `bundle.upgrade` then resolves a slug to that function BY NAME
(`bundle.fn.of`), and a bundle's own `_.sh` is the only place that says which phases to ask
for. so the runtime's one loud check — *"undeclared; its bundle dir did not source"* —
fires for the OPPOSITE defect, and has no way to notice a declaration nobody asked for.

⚠️ **and a plan cannot see it either.** `--mode plan` reports what RAN. a phase that runs on
no box appears in no plan, so the survey a human reads to learn what a box lacks is exactly
the artifact that cannot report this.

### .why the two lists are BOTH correct, and must be clamped rather than collapsed

| list | declares |
|---|---|
| the filesystem | what a bundle HOLDS |
| the `_.sh` | the ORDER its phases run in |

neither can be deleted. order is not derivable from filenames — `6.apps` dispatches
6.1 → 6.3 → 6.4 → 6.5 → 6.2 on purpose — and a body has to live in a file. this is the
`PKG_APT_ENV` precedent one level up: **where a second declaration is CORRECT, clamp it**
(`rule.require.identical-bundle-composition`).

### ⚠️ .clamped statically — `prove.every-bundle-is-dispatched`

it is static — no fresh box, no privilege, no network. the play declares its own directions.

⇒ **ask the play for its counts.** they moved 190 → 195 in a day with no edit to this line: a
count written into a brief is a second declaration of a fact the tree already carries.

🛑 **one of its directions — a phase FN must sit in the file its suffix names — clamps a seam
THREE other plays rest on, and none of them can see.**
the runtime resolves a phase by FUNCTION NAME and sources every `*.sh` under the bundle dir,
so a phase body moved into `_.sh` would dispatch, run, and read as reached. but
`prove.sudo-is-gated-or-nonintera`, `prove.every-upsert-is-verified`, and
`prove.apt-is-never-interactive` all key on the **filename** — so all three would go blind to
that phase in one move, and an ungated `sudo` inside it would sit in no row any of them
prints.

⇒ measured 2026-08-14: **138 phase files, and every one declares its phase in the file the
suffix names.** the agreement was real and asserted by nobody — which is exactly when a
clamp is cheapest (m.12: a subject written in a form nobody's pattern matches produces no
row, and the counts never move).

⚠️ **the entrypoint classifier is derived, never listed.** a bundle file may declare
OPERATIONS under the same prefix — `grove_provision_2_8_tmux_plugin_root`, and 14 more in
`5.12.rack`. those are called by their own phases and owe no dispatch, so a reader that
demanded one for every `grove_provision_*` would report a false ✋ on every bundle that
factors its work. the two entrypoint shapes are read out of the tree: a name that equals
some directory's fn, or a name that ends in one of the four phase suffixes.

### ⚠️ .the SIBLING hole — a phase that is called and proves none of its claim

the play above asks whether a declared phase is ever CALLED. it says not one word about a
phase that was **never written**, and that is a second way to reach the same box:

> **an upsert reports whatever its LAST command returned.** a phase that copies a file, or
> installs a package that lands broken, or writes a unit it never enables, ends 0.

so an upsert half with no verify half is a claim with no reader. worse for this rule, a
provision verify is a GATE — `bundle.upgrade` records the bundle in `BUNDLE_BROKEN` on a
failure, so its absence means the CONFIGURE half runs unconditionally on a base nobody
checked (`rule.require.upgrade-entries-verify-themselves`, `term=gate._.choice._.md`).

`prove.every-upsert-is-verified` clamps it, statically: every upsert half must hold a verify
FILE, and that file must be DISPATCHED.

⇒ measured 2026-08-13: **67 upsert files, 67 verify files, 0 unpaired halves.**

⚠️ the rule is **one-directional** on purpose. a VERIFY with no upsert is legitimate — a
bundle may read a fact it does not set — so those are `·` rows, judged by nobody. *applied
is not proven; proven with no apply is simply a read.*

### ⚠️ .the THIRD of the family — a phase that runs and never returns

the two above are about a phase that does not run, or that runs unproven. this one is about
a phase that runs FOREVER, and for this rule's **non-interactive** clause it is the worst of
the three: a failure ends a run, and a hang holds the pane — which on a grove IS the duct, so
every command sent afterward queues behind it.

`prove.offbox-reads-are-bounded` clamps the roads off the box that `web_fetch` does not
cover — `tmux`, `docker`, `ssh`, and every other tool that asks a QUESTION rather than pulls
bytes. it is static, and it condemns a tool only where that tool's own default is MEASURED
to be unbounded (`rule.require.bounded-probes-in-verifies`).

⇒ measured 2026-08-13: **nine unbounded sites, all fixed** — and one of them carried a
comment that cited the very rule it violated.

⚠️ **21 further call sites were REPORTED and unjudged**, since `gh`, `aws`, `pnpm`, `npm`,
and `flatpak` each carry a bound of their own that this repo had not measured. that was an
honest gap, not a deferred defect — and a guessed `timeout` would have traded an unseen
hazard for a real regression on the one run a converged box can never re-test.

#### ✔ .the gap was CLOSED by measurement — 2026-08-14

`prove.tool-defaults-are-bounded` measured each tool against a silent listener: **four of six
(`npm`, `pnpm`, `corepack`, `flatpak`) can hold a duct past four minutes on a first apply.**
`src/grove.web.sh` grew a second boundary for them.

⇒ the CLAIM this shape needs is one line: **an unbounded call on the provision path hangs the
FIRST apply, and no converged box can re-test it.** the full transcript behind it — the six-row
table, the `corepack`/`cargo`/`fnm` invisibility, the bare-`wait` hang that held a duct for 40
minutes — is owned by `rule.require.bounded-probes-in-verifies`, the rule it was measured for.

## 🛑 .the FOURTH shape — a tool installed into a dir the LIVE process cannot see

the three shapes above are all about a phase that fails or declines. this one is about a
phase that **succeeds**, and about the phase two bundles later that cannot find what it
installed:

> **a bundle installs a binary into a dir that reaches PATH only through a SHELL RC.**

the rc is read by the NEXT shell. the run in progress already has its PATH, so the tool is
on disk, executable, current, and unnamed for every later phase of that same run. apply 2
starts a new shell, finds it, and converges — which is the two-applies signature exactly,
and the reason this shape belongs to this rule rather than to a PATH brief.

⚠️ **it is invisible to every static play in this repo.** the install succeeded, the verify
of the bundle that installed it passes, and the bundle that cannot see the tool reports a
truthful `✋ <tool> is absent`. no row anywhere says *"…and it is on this disk."*

### ✔ handled today, and deliberately — measured 2026-08-14

`5.1.node/provision.upsert.sh` exports into the **live process**, not only into the rc:

```sh
export PATH="$fnm_home:$HOME/.fnm:$PATH"                    # :162
export PNPM_HOME="$HOME/.local/share/pnpm"                  # :294
export PATH="$PNPM_HOME/bin:$PNPM_HOME:$PATH"               # :296
```

and its own comment names the reason: *"zshrc exports as PNPM_HOME, so this phase and an
interactive shell agree."* so `rhx` — installed by `5.3.brains` into `$PNPM_HOME/bin` — is
reachable by `5.12.rack`, `5.13.reach`, and `5.4.gh` later in the same run, all of which
assert it.

⇒ **`export` inside a phase function mutates the run's own shell**, which is what makes the
one-line fix work. an `echo … >> ~/.zshenv` alone does not.

### the test, for any bundle that puts a binary outside `/usr/bin`

> **will a phase LATER IN THIS RUN need it — and does this phase `export` the dir, or only
> write it to an rc?**

- exports it → the run can see it
- writes the rc only → apply 1 fails, apply 2 passes, and that is this rule broken

### 🛑 .the variant where the live-process fix is IMPOSSIBLE — move the CLAIM

`export` rescues a PATH because a shell variable is a property of the process. some grants
are not, and for those the same shape has **no mechanical repair at all**:

| the grant | reaches the process… | can a phase force it? |
|---|---|---|
| a dir on PATH | when the shell reads it | ✔ `export` |
| a **unix group** | at the next **login**, from the group db | ✋ never — `newgrp` forks a shell, and the run's own shell keeps the old set |

⚠️ **measured 2026-08-14, and it failed the first apply of every fresh box.**
`5.8.docker/provision.upsert` grants the ground seat the `docker` group; its
`configure.upsert` then ran two phases later, in that same shell, and printed:

```
🌙 this seat holds sudo, so the rootful daemon is its route
   ⇒ a group joins a process at LOGIN, so a session opened before the grant
     cannot reach the socket yet
   fix: open a new session, or for this one:  newgrp docker
```

and `configure.verify` — same shell — got `permission denied` from the socket and answered:

```
✋ this seat cannot reach a docker daemon
   fix: rhx grove.provision --what 5.8.docker --mode apply
```

three blockers in one branch: a **hand step** printed on the provision path; a **second
apply** named as the fix, which finds the same stale shell and prints the same line forever;
and a **✋ over a converged box** — the group was on disk the whole time.

⚠️ and on a grove the hand step is not merely unavailable, it is INERT. a duct pane is a
long-lived shell, so a `newgrp` typed into it reaches no later send either (`term=duct`).

⇒ **when a grant cannot be forced into the live process, RE-ASK the question under the
grant** rather than assert the grant and hope. `sg <group> -c '<cmd>'` enters the group for
one command, which is exactly *"would a fresh login reach this?"* — so the phase reaches a
proven `✔` instead of a hopeful one, and a daemon that is genuinely down still fails.

⚠️ the re-ask must be **gated on the roster**: `sg` asks for the GROUP PASSWORD when the
caller is in neither the live set nor the roster, and a prompt on a duct eats the next
command (`rule.forbid.tty-as-a-proxy-for-a-human`).

📜 **this bundle learned it twice, two days apart, and that is the durable lesson.**
`5.8.docker.provision.verify` took the `sg` repair on 2026-08-12; its two CONFIGURE phases
still judged the same grant by a direct socket read, and were found on 2026-08-14. a repair
applied to one phase of a bundle is not applied to the bundle — re-read every other phase
that asks the same question.

⇒ and when a second phase wants the gate, it must call the FIRST one's reader. the roster
question now lives once, in the bundle's `_.sh`, because three phases ask it — two readers
over one set drift with no signal (`gotcha.a-check-that-cries-wolf-gets-silenced`, m.9).

### the test, for any grant a phase makes to a seat

> **does this grant reach the run's own process, or only its next login?**

- reaches the process → assert the effect
- only the next login → **re-ask the real question under the grant**, gated so the re-ask
  cannot prompt. a `fix:` here is a hand step by another name, and a re-apply can never
  clear it

⚠️ **this class is caught by a READ, and no clamp in this repo can reach it.** the tell is a
`✋` whose fix is a re-apply of its own bundle, in a branch a re-apply cannot change — and
that is not statically decidable. a pattern wide enough to catch `newgrp docker` also
condemns *"attach an iam role to the instance"* and the 1password GUI toggle, which are
legitimate; a check whose red is a plausible, regressive fix is worse than no check at all
(`gotcha.a-check-that-cries-wolf-gets-silenced`, m.7).

## 🛑 .the FIFTH shape — a decline whose "yet" names a future ONE box class has

the FOURTH shape's variant is a fix made unreachable by TIMING — a group joins at the next
login, so a re-apply in the same shell can never clear it. this one is unreachable because
of the BOX, and its tell is a single word:

> **a decline that says "not X YET" is a claim about the FUTURE. if that future exists on
> one box class only, the decline is wrong on every other one.**

| the word | what it promises | when it is a lie |
|---|---|---|
| "no profile **yet**" | a profile will exist | on a box with no display to launch one into |
| "not on PATH **yet**" | a later shell will find it | never — a next shell always follows |
| "**still** owed a human click" | a human will click | on a box with no human |

⚠️ and the `fix:` such a decline prints is always a hand step, so it arrives already
dressed as this rule's violation.

### .measured — `1.3.1.firefox`, 2026-08-14

the bundle installs firefox's flatpak everywhere, deliberately and correctly — its `_.sh`
argues the case at length, and `4.3.1.terminfo` is its precedent. but its `configure`
phases then reached for the PROFILE, and a profile is born of a GUI launch:

```
🌙 no firefox profile yet at …
   ⇒ a fresh install creates no profile until firefox is STARTED once.
   fix: open firefox once, then re-drive:
     rhx grove.provision --what 1.3.browser --mode apply
```

three blockers in one branch, on every grove, forever:

1. **a hand step** — "open firefox once", on a box with no display and no hand
2. **a second apply**, named as the fix — and a re-apply finds the same absent profile and
   prints the same line
3. **owed work reported on a converged box** — the flatpak and the ctrl+N systemconfig
   channel are all this bundle can give a grove, and both had landed

⇒ and the same file's next section held four `browser <url>` launches whose whole product
is a permission prompt mozilla shows **on a screen**. the profile gate happened to return
first, so they were unreachable — which is exactly why that gate is the wrong place to
state their precondition (`rule.require.solve-at-cause`).

### .the repair: decline the HALF, never the bundle

the temptation is to decline the whole bundle off `local@unix`. that is the objection this
leaf's own header refutes at length, and it is wrong — the flatpak and the systemconfig
channel converge on a grove, and the headless box is the one that turned out to need
`4.3.1.terminfo`.

what declines is the half whose precondition is a human-driven GUI launch. the leaf already
had the precedent in its own header: *"the one part that genuinely needs a desktop is the
single `xdg-settings` line, so THAT line tolerates its own failure and says why."*

⚠️ **`local@unix`, never `local@*`** — `local@cicd` is a local tier with no screen and no
human, and this needs both (`repo.overview.md`).

### .the test, for any decline that carries a time word

> **"yet", "still", "not until" — name the event that ends the wait, then ask: can THIS box
> class ever produce it?**

- yes → owed work; the fix is real
- no → it is not "unmet yet", it **cannot be met**. say so, and print no fix

⚠️ and re-read the bundle's OTHER phases in the same edit. the verify here printed the
identical hand step, one file away, and would have survived a repair to the upsert alone —
which is what `5.8.docker` learned twice, two days apart.

## 🛑 .the SIXTH shape — an idempotency guard that tests PRESENCE where the claim is HEALTH

the five above are all about a phase that declines, fails, or never runs. this one is about a
phase that **skips**, cheerfully, forever:

> **an upsert's skip-guard tests that an artifact EXISTS. the artifact is written in more
> than one step. so a run cut partway leaves a PARTIAL artifact that passes the guard — and
> the upsert counts it done on every apply thereafter.**

the verify then finds the partial artifact, refutes it correctly, and its only honest fix is
a **hand step** — because the upsert genuinely cannot repair what it was told to skip.

### .measured — `5.10.repos`, 2026-08-14

one set, two readers, and they disagreed on exactly one input:

| half | the reader | its answer for a clone cut partway |
|---|---|---|
| `provision.upsert` | `[[ -d "$into/.git" ]]` | "already here, skip" |
| `provision.verify` | `[[ -r ".../.git/HEAD" ]]` | "half-cloned, refuse" |

a `git clone` writes the dir, then `.git/`, then `HEAD`. cut it between the second and the
third — ordinary on a fresh grove, ~600 clones over a thin link — and:

1. the upsert counts it `failed`, returns 1, and the phase chain skips the verify
2. the human re-applies. the guard sees `.git/` and counts the corpse **done** — forever
3. the verify refutes it and named `rm -rf <dir>`, which no grove has a hand to take

⚠️ **the file said so itself.** the verify's own line read *"the upsert's idempotency guard is
`[[ -d $into/.git ]]`, so it counts each one DONE and skips it on every future apply — an
apply will not repair this."* it named the CAUSE in the sentence directly above a fix that
named only the SYMPTOM (`rule.require.solve-at-cause`).

### 🛑 .the SECOND half of the shape — presence cannot see a VERSION either

the account above is about a PARTIAL artifact. the same guard has a second blind spot, and it
is the larger of the two, because it fires on a box that is perfectly healthy:

> **a presence guard cannot see a pin.** so a bundle may declare a version, argue at length
> that a version which floats breaks the deterministic clause — and then skip every box that
> already holds the tool. the pin governs the FIRST apply and no other.

⇒ bump it and no extant box moves. both halves report ✔ throughout, because neither reader
ever asked. that is the deterministic clause of this rule, defeated by the bundle's own guard.

### .measured — three bundles, one defect, 2026-08-14

| bundle | the upsert's guard | the verify's test | the input they disagreed on |
|---|---|---|---|
| `5.10.repos` | `[[ -d "$into/.git" ]]` | `[[ -r ".../.git/HEAD" ]]` | a clone cut partway |
| `2.8.tmux` | `[[ -d "$tpm_dir" ]]` | `[[ -x "$tpm_bin" ]]` | a killed clone, AND the pin |
| `5.6.aws` | `command -v aws` | `aws-cli/2.*` | debian's v1, AND the pin |

⚠️ **`5.6.aws` is the sharpest, because its fix-text was an infinite loop.** debian's `awscli`
package puts a v1 `aws` on PATH; it answers `command -v`, so the upsert printed
*"already installed; skipped"* and the verify answered `fix: … --what 5.6.aws --mode apply`.
that re-apply hits the same guard, skips again, and prints the same line — forever.

⚠️ and in ALL THREE the verify's own header **named the upsert's guard as the cause** and then
prescribed for the symptom (`rule.require.solve-at-cause`). that is not a coincidence: the
verify author is the one person who has looked hard at what the guard misses.

### .the repair, and why a PREDICATE was not enough

the set has **three** members in `5.10.repos` — `whole`, `half`, `absent` — so the shared
reader NAMES the member rather than answers a boolean. a first cut shipped `..._is_whole`, and
the clamp went red on the verify at once: that half must tell `absent` from `half`, which a
boolean cannot, so it had kept an inline `[[ -d …/.git ]]` and the two-readers defect survived
at half its old size. `2.8.tmux` and `5.6.aws` were written state-first because of it, at four
members each.

the upsert then acts on the state it can now see. for an artifact it OWNS, a broken or adrift
one is **moved aside** — never deleted — and re-fetched. a move is reversible, costs one
rename, and frees the path, which is all a clone needs. for a tool with its own installer, the
state chooses the flag: `5.6.aws` passes `--update` when an aws is already there.

### .the test, for any skip-guard you write

> **is the artifact this guard tests written in ONE step, or several — and does this bundle
> declare a VERSION for it?**

- one step, no pin (a symlink, a single `cp`, a `mkdir`) → presence IS health
- several steps (a clone, a tarball unpack, a multi-file copy, a unit plus its timer) →
  **presence is not health.** test the LAST byte written
- a declared pin, however few the steps → **presence cannot see it.** read the version
- either way → share that reader with the verify

⚠️ and the tell that it already went wrong: **a verify whose fix-text is a hand step, or a
re-apply of its own bundle, against an artifact its own upsert claims to own.** those two facts
sit together for exactly one reason — the upsert cannot see what the verify sees.

⇒ each instance is clamped by its own play — `prove.half-clone-is-repairable`,
`prove.tpm-pin-is-enforced` — and each drives the bundle's reader through every state on a real
fixture, with the pin read from the tree rather than re-typed.

⇒ and the CLASS is clamped by `prove.state-readers-are-shared`, which discovers every `*_state`
reader in every bundle's `_.sh` and demands both halves ask it. a hand-written list of the
three would go stale the day a fourth lands; a set read from the tree cannot
(`gotcha.a-check-that-cries-wolf-gets-silenced`, m.12).

## 🛑 .the SEVENTH shape — a VERIFY that reads state a LATER component writes

the six above are all about an UPSERT. this one is about the other half, and it is quieter
than any of them: the apply says `🌲 done`, the box is genuinely converged, and a claim the
tree makes about itself goes **unproven on every fresh box, forever**.

> **a verify reads state some OTHER component wrote. if that component runs after it, the
> claim cannot be observed on a first apply — and a converged box hides it, because on every
> later run the state is already there.**

two instances, one from-scratch run, 2026-08-14:

| # | the verify | it reads | the writer | when |
|---|---|---|---|---|
| 1 | `2.2.git/configure.verify` | `~/.bash_aliases` | `2.7.aliases` | LATER in the same run |
| 2 | `2.5.zsh/configure.verify` | `~/.zshenv` | `rustup-init`, via `5.2.rust` | LATER, and not even in this repo |

### .instance 1 — the note that was true of one half

`2.shell/_.sh` ordered `2.2 before 2.7` and argued the case in a comment:

> *"either order lands; git's aliases are read at call time, not at write time"*

**that is true of the UPSERT and says no word of the VERIFY.** `2.2.git`'s configure.verify
opens `~/.bash_aliases` to assert that each of the six compound git aliases names a defined
function — and `2.7.aliases` is the bundle that writes that file. so the read always preceded
the write, and the check declined with a 🌙 that blamed a bundle whose turn had not come.

⇒ **an "either order lands" note is a claim about the UPSERT. re-read it against the VERIFY
before you trust it** — the verify is the half that pins an order down, because it is the half
that reads what somebody else wrote.

⚠️ the repair is a DISPATCH reorder, not a renumber: `2.7` now runs before `2.2`, and the
number stays. the dispatch is the order; the number is a stable identifier.

### .instance 2 — and the writer was not in this repo at all

`5.2.rust` ran `rustup-init -y`, and rustup appends `. "$HOME/.cargo/env"` to `~/.zshenv` —
a file `2.5.zsh` owns by byte. the camper's first apply said `🌲 done`; the plan after it said
`✋ ~/.zshenv DIFFERS from the checkout`, and the red line named `2.5.zsh`, the innocent half.

that is `rule.forbid.two-writers-on-one-artifact`, and `prove.rc-ownership` exists to catch
exactly it — the same defect on `~/.zshrc` in july. it was green throughout, for two reasons:

1. its pair list was **hand-written and held one row** (m.12)
2. the neighbor was a **third-party binary**. no read of this tree can learn that `rustup-init`
   edits an rc file, so no discovery could have added the row either

⇒ **a NEIGHBOR list cannot be completed, on principle**, so the play names none. it discovers
the OWNERS from the tree — every bundle whose configure.verify holds a `cmp -s` — applies the
WHOLE TREE as the neighbor, and re-plans each owner. that covers every bundle and every
installer any bundle invokes, named or not.

### .the test, for any verify you write

> **does this verify read state some OTHER component wrote — and does that component run
> before it, every time, on a box that starts empty?**

- it writes what it reads → the order is its own business
- another BUNDLE writes it → that bundle must be dispatched earlier
- a third-party INSTALLER writes it → no order saves you; stop the write at its source, with
  the installer's own opt-out flag

⚠️ and the tell is a **🌙 on a fresh box that no later run reproduces.** a decline that clears
itself on the second apply is not benign: it means the claim was never checked on the box where
it mattered most.

⇒ clamped two ways: `prove.fix-texts-are-actionable` direction 5 refuses an absence attributed
to a bundle that runs later, and `prove.rc-ownership` refuses an owner whose file changed after
a whole-tree run.

## 🛑 .the EIGHTH shape — a test that keys on how the repo ARRIVED, not on what it HOLDS

the seven above are all about ORDER, PRIVILEGE, or DISPATCH. this one is about a test that
asks the wrong question, and it is the only shape so far that is **false on every grove and
true on every laptop** — so it cannot be found by any amount of work on a developer's box.

> **a check that keys on the SHAPE of a checkout — a `.git` directory, a remote, a branch —
> asks how the repo ARRIVED. the provision does not clone; it PUSHES. so the test is false
> for the whole population this rule creates, and true for the one that writes it.**

### .measured — the credential helper's repo ladder, 2026-08-15

`src/git-credential-keyrack.sh` picks a cwd to run `rhx keyrack get` from. its rung 2 says,
in its own header, exactly what it needs:

> *"THIS repo's checkout — it owns `.agent/keyrack.yml`, the one manifest that declares the
> key, so it is the only cwd guaranteed to load"*

and it tested `[[ -d "$HOME/git/more/dev-env-setup/.git" ]]`.

| how this repo lands on a box | `.git` | rung 2 fires? |
|---|---|---|
| `git clone` — a developer's laptop | a directory | ✔ |
| `git.grove.push --from . --into …` — **the provision** | ABSENT | ✋ |
| a git worktree — a developer's branch | a FILE | ✋ |

so on `grove-ahbode-v20260811`, built from scratch by this rule's own two-line procedure:

```
· rung 2  /home/camper/git/more/dev-env-setup
  ├─ shape:              pushed copy (NO .git)
  ├─ holds the manifest: YES   ← what the rung NEEDS
  └─ passes [[ -d .git ]]: no  ← what the rung TESTED
⇒ rung 4 (the cwd — correct only by luck) → …/git/ahbode/svc-chat
```

every private fetch fell to whatever clone the caller stood in. that clone's own
`.agent/keyrack.yml` extends a role manifest it does not vendor, so the read threw, the
helper declined, and **git's terminal prompt wedged the duct**:

```
camper@…:~$ { zsh -ic git -C $HOME/git/ahbode/svc-chat fetch origin main }
Username for 'https://github.com/ahbode/svc-chat.git':
```

⚠️ and note WHICH box could ever have found it. the author's laptop holds this repo as a
clone and as a worktree; both are wrong shapes, and one of them passes. only a box the
provision built holds the third.

### .the test, for any check that reads a checkout

> **what FACT does this test need, and is `.git` a proxy for it?**

- the fact is "does this hold file X" → test for file X
- the fact is genuinely "is this a clone" (a `git pull`, a `rev-parse`) → `.git` is correct
- unsure → ask which shape a GROVE has, and check the test against that one first

⇒ clamped by `prove.helper-finds-a-pushed-checkout`, which builds a `$HOME` in each of the
three shapes and reads back which rung fired. it was seen to go RED on the un-fixed ladder —
three directions, exactly the pushed, worktree, and cwd rows.

## 🛑 .the NINTH shape — a git that can ASK, on a box with nobody to answer

the `.SECOND shape` above covers `sudo`, and `.the OTHER half of non-interactive` covers apt.
git is a third, and it fails differently from both — so a reader who has internalised those
two will still walk into it.

| the ask | how it reaches the human | what suppresses it |
|---|---|---|
| `sudo` | reads `/dev/tty` | a decline-gate, or `sudo -n` |
| apt / needrestart | draws a menu on stdout | `PKG_APT_ENV` (`DEBIAN_FRONTEND`, `NEEDRESTART_MODE`) |
| **git credential** | opens `/dev/tty` **directly** | **`GIT_TERMINAL_PROMPT=0`, and that alone** |

🛑 **the lever that looks like a lever and is not:** `</dev/null`. git does not read stdin for
a credential — it opens `/dev/tty`. so a closed stdin, a pipe, or a `[[ -t 0 ]]` guard each
leave the ask fully reachable, and a tmux pane HAS a tty with no human behind it
(`rule.forbid.tty-as-a-proxy-for-a-human`).

⚠️ **and a git ask is the most expensive of the three**, because it never times out. `sudo`
fails, apt eventually can be killed — git waits forever, and on a duct it eats every command
sent after it. the box reads as *hung* rather than as *broken*, which is the one report a
human cannot act on.

### .measured — 2026-08-15, two sites, one shape

| site | had | needed |
|---|---|---|
| `5.10.repos/provision.upsert.sh` — `gh repo clone`, ~600× on a fresh grove | neither | both |
| `grove.bootstrap.sh` — `git pull --ff-only`, the re-bootstrap path | neither | both |

⚠️ the second is the instructive one: the **clone** 60 lines below it carried
`GIT_TERMINAL_PROMPT=0` AND a `timeout`, with a 25-line block that argues for each. the
**pull** carried neither. and `prove.wire-fetches-are-bounded` had already been widened to
sweep that exempt file BY NAME — it saw the clone, and had no question to put to a pull.

⇒ **a sweep widened to reach an exempt FILE still reads only the call somebody thought of.**
a guarantee is owed to every SIBLING call, not to the one that taught it.

### .the test, for any call that reaches github

> **can this call reach `/dev/tty`, on a box with no human?**

if it is `git clone|fetch|pull|push|ls-remote`, or a `gh` that shells out to one, the answer
is yes unless `GIT_TERMINAL_PROMPT=0` sits on the call itself.

⇒ clamped by `prove.git-never-prompts` — static, over the driven set (the bundle tree, the
shared runtime, and the bootstrap), with a fixture that refuses a stdin redirect as a guard
and spares a local `git config` and a `git clone` named inside an echo.

⚠️ `src/bash_aliases.sh` is deliberately OUT of that claim. those are aliases a human types,
and for a human a credential prompt is the correct affordance — a check that demanded the
guard there would ship a plausible regression.

## 🛑 .the DARKEST corner — a path that runs on ONE box class, rarely

the gates above are at least exercised on every apply, on the SKIP side. a worse class
exists, and it has **no ambient evidence at all**:

> **an install path that declines on one box class and short-circuits on the other.**

that path runs on exactly one kind of box, at exactly one moment — the FIRST apply on a
fresh machine of that class. every other run declines or skips, and each prints a clean
`🌙` or `•` about a route nobody touched.

### .measured 2026-08-13 — a url that was never once fetched

`6.4.protonvpn` downloaded from `https://protonvpn.com/download/<deb>`. that url answers
**404**, and had for as long as it can be traced:

| box | what happened | what it printed |
|---|---|---|
| a grove | declines — `local@unix` only | `🌙 declined — this is the DESKTOP client` |
| a laptop | short-circuits on an installed binary | `• protonvpn already installed; skipped` |

so the fetch line could not have succeeded on ANY box, on ANY run, and the tree reported
green throughout. it was found the first time a play was pointed at the wire on its behalf.

⚠️ and the repair was NOT a version bump, which is the reflex the symptom invites. a 22
from that fetch has two causes with opposite fixes — the version aged out, or the HOST
moved. the host had moved (`repo.protonvpn.com`), so a bump would have changed the one
part that was already right (`rule.require.solve-at-cause`).

### .the remedy: a play that reaches the SOURCE, on any box

such a path cannot be proven by an apply, because no apply runs it. it is proven by a
READ of what the path depends on — which needs no privilege, no fresh machine, and no
install:

| play | reaches | proves |
|---|---|---|
| `prove.apt-sources-serve` | every apt source the tree declares | Release + binary index + the package name each bundle installs |
| `prove.apt-packages-serve` | every name the tree hands `pkg_install` | the box's own sources offer a candidate for it, and a fabricated name is refused |
| `prove.sha256-pins-bite` | every pinned download | the url answers AND the pinned hash matches |
| `prove.apt-key-pins-bite` | every pinned repo key | the fingerprint matches upstream, and a wrong one is refused |
| `prove.gpg-signature-pins-bite` | every signed artifact | the signature verifies under the pinned key, and a foreign key is refused |
| `prove.flathub-apps-serve` | every flatpak app id the tree declares | the remote answers, each id is still served, and a fabricated id is refused |
| `prove.registry-packages-serve` | every npm spec, cargo crate, and codium extension the tree installs | the registry still serves each name AND each pinned version, and a fabricated name is refused |
| `prove.clone-pins-exist-upstream` | every `git_clone` the tree declares | the pinned commit still checks out, and an impossible sha is refused |

⚠️ the `reaches` column names a **set discovered from the tree**, deliberately, and holds
no count. a count there is a second declaration of a fact the tree already carries, and it
goes stale silently — which is exactly the defect the block below measures.

### 🛑 .the hole all seven of those share, and the one play that can see it

every play above discovers its subjects **by the presence of a check**:

| play | keyed on |
|---|---|
| `prove.sha256-pins-bite` | `web_verify_sha256 --file` |
| `prove.apt-key-pins-bite` | `--fpr <40 hex>` |
| `prove.gpg-signature-pins-bite` | a `.sig` fetch |

⇒ so a download with **no verification at all** is invisible to every one of them, **by
construction**. it cannot appear in a set keyed on the thing it lacks, and each play stays
green the day it lands.

⚠️ and a coverage arm does NOT close this. those arms compare a hand-written list against
a discovered set — and the discovered set has the identical hole. the only reader that can
see an unverified fetch is one keyed on the **fetch**.

that is `prove.every-fetch-is-verified`: **static**, it discovers every file that calls
`web_fetch` and demands each carry a check, and it proves its reader in both directions.

⚠️ its rows report the SHAPE of the check, not merely its presence. `4.3.2.emulator`
verifies with a **hand-rolled** `gpg --verify` rather than the shared boundary — so a row
that counted only boundary calls would raise a false alarm about a correct bundle. the
hand-rolled shape is still a second declaration of a check `web_verify_gpg_signature`
already performs, so a repair to the boundary never reaches it.

⚠️ each carries **control rows** — anchors a grove apply already exercises (gh, docker).
their agreement says the play's own PATH is sound, so a red row can be read as a fact
about a vendor rather than about this box's egress
(`gotcha.a-check-that-cries-wolf-gets-silenced`, `.the corollary`).

⚠️ and each reads its subject **out of the bundle**, never restated in the play. a copy
would be a second declaration of one fact, so a url bumped in the bundle could leave the
play to re-prove a route the tree no longer uses
(`rule.require.identical-bundle-composition`).

> 🛑 **a play that hardcodes its subject list is blind to whatever the tree grows next.**
> 📜 measured 2026-08-13: `prove.sha256-pins-bite` held **6** subjects while the tree held
> **8** — `2.6.starship` and `4.1.fonts` each carried a correct sha256 pin and appeared on
> no page the play ever printed. its count guard compared what LANDED against what was
> LISTED, so the two omitted subjects were absent from both sides and the comparison agreed
> with itself.
>
> ⚠️ **a count in a table is a CLAIM about coverage**, and it ages into a false one the
> moment a subject lands — with no signal at all, because the play it describes is green.
>
> ⇒ so no play above writes a count, and every one reads its SET from the tree. a count
> cannot go stale if no one writes one down (`rule.require.bundle-as-sole-declaration`,
> `rule.require.trust-but-verify`).
>
> ⚠️ two mechanisms do it, and they are not interchangeable — measured 2026-08-13 by a
> read of all six:
>
> | mechanism | plays | growth is caught… |
> |---|---|---|
> | **discovery drives the loop** — the discovered set IS the row list | sha256, apt-sources, apt-packages, flathub, registry-packages | automatically; a new subject gets a row the day it lands |
> | **coverage arm** — hand-written arms, compared against the discovered set | apt-key-pins, gpg-signature-pins, clone-pins | by the comparison; a new subject turns the play RED until an arm is added |
>
> the second is correct where each arm carries per-subject prose no discovery can derive.
> both refuse an empty read, which is the failure a bare loop cannot tell from a clean run
> (`gotcha.grepsafe-glob-goes-quiet`).

### ⚠️ .the two names that were proven on NO box class — and what the laptop run found

`prove.apt-packages-serve` reports three buckets:

| bucket | what it means |
|---|---|
| ✔ served | this box's own sources offer a candidate — proven here, now |
| ⊘ deferred | the bundle declares its own apt source; the OWNER is per-shape, and can be NOBODY |
| 🌙 unproven | the bundle DECLINES on this box class, so no row here reads its name |

measured 2026-08-13 on a grove, `cosmic-term` and `protonvpn` landed in the third bucket —
both `local@unix`-only, so only a laptop reaches either. the laptop run on 2026-08-14 moved
neither name to ✔. it found two READER defects first — a source-shape classifier blind to two
of the three shapes, and a ⊘ row that named an owner which owned no index — and then a live
defect in `6.4.protonvpn`: proton serves no package by that name.

⚠️ **the sharpest lesson was CREATED by the fix for that live defect.** the verify tested
`command -v protonvpn`; that binary is `proton-vpn-cli`'s, and the desktop client ships
`protonvpn-app`. so a corrected package name alone would install fine, run fine, and report
the app ABSENT — a false ✋ on a converged box, which is the direction that gets a check
silenced.

⇒ **a PACKAGE name and a BINARY name are two facts**, and a bundle that installs one and
tests the other has never proven the pair. read both off the vendor's own index; never assume
(`rule.require.trust-but-verify`).

⇒ and hold that claim apart from its neighbour: `prove.sha256-pins-bite` says the `.deb`'s
bytes are the pinned bytes, where this says the repo those bytes declare still serves the
package the bundle installs (`gotcha.a-check-that-cries-wolf-gets-silenced`, m.6).

✔ **the deferral audit prints `· none` as of 2026-08-14** — `prove.apt-sources-serve` reads
all three source shapes, so every ⊘ has a real owner. 🛑 the classifier is **declared ONCE**, in
a shared `_.apt-sources.lib.sh`, and both plays read it — a classifier inline in one play is
one set with two readers the moment a second play needs it, which is the m.9 shape.

⚠️ do NOT "fix" this corner with a skip-list of the two names. the bucket is DERIVED — the
play reads which bundles decline on this box class straight from the tree — so a third
laptop-only package joins bucket 3 the day it lands, with no edit to the play. a hand-written
list would go stale exactly as the counts above did.

⇒ the three source shapes and their exclusions are declared in `_.apt-sources.lib.sh` — read
them there, never from a copy. the reader defects behind this claim are m.4, m.6, m.7, and m.9
of `gotcha.a-check-that-cries-wolf-gets-silenced`.

### .the test, for any install path you write

> **which box class runs this line, and how often?**

- every box, every apply → the tree itself is the evidence
- one class, on a fresh machine only → **it has no evidence.** owe it a play that reaches
  its source, or it will rot silently and be found by a human on a new laptop

---

## ✔ .the run that MET the bar — 2026-08-30, in full

`rule.require.one-command-provision` states the claim: one command, one apply per seat, zero
claims, 31 passed. this is the whole account behind it — the one interjection, what that
interjection surfaced, and the local record that nearly discarded the measurement.

### ⚠️ the ONE interjection, and why it does not void the run

the gate halted at **its rung 0, `box`** with *"the grove did not wake"*. its own `fix:` named the cause
first, and the wake log agreed: `ahbode.camp.AWS_PROFILE — status: locked 🔒`. camp lapses
in ~55m and the run had cost longer than that.

so a `keyrack unlock` was typed, and then the gate alone was resumed with `--from 4`.

⇒ that is the exemption this rule already grants, and it earns a worked example: **the
unlock repaired THIS MACHINE's reach and changed no grove state.** the gap forbids a command
that CHANGES THE GROVE, and the gate's rung 0 went ✔ on the retry with the box untouched — which is
also the proof that the halt was never about the box.

⚠️ and it surfaced m.4 one layer out. `git.grove.provision test`'s own sign-off is per-rung and
correct. then `git.grove.provision` printed its own line underneath — *"the box provisioned and
did NOT pass the gate"* — so a **caller re-generalized over a set its callee had just been
careful not to.** the fix was to name no subject at all and point at the per-rung text
already on screen.

🛑 **never cite a rung number without the ladder it belongs to.** `git.grove.provision test`
numbers its rungs **0..4**; `git.grove.ready.verify` numbers its **1..5**; and only the gate's
rung 0 climbs the verify's. both are ladders, so both hold rungs (`term=rung._.choice.reason.md`,
`dispute: the AXIS`) — no noun tells the two number sets apart, so **the qualifier is the
discriminator**.

📜 measured 2026-08-30, within the hour of the repair above: a correction read *"rungs 0-3 can
halt on THIS machine … 4 and up are the box"*, which fuses the two ladders. the *"this machine"*
property belongs to the verify's 1-3, and the line pinned it to a 0-3 band that is the gate's.
a correction that reproduces the defect it records is m.10.

⚠️ **the durable lesson is not "count more carefully".** it is that **a caller cannot re-state
its callee's subject split without a COPY of that split**, and a copy drifts with no signal
(m.9). the callee's sign-off is already per-rung, already correct, and already on the screen —
so the caller states none.

⚠️ and when you cite this, **grep the component you blame.** a defect can be real while the
accused is wrong — m.4's quotation is memorable, so it is easy to charge the skill the
measurement was written about rather than the one that printed the line
(`gotcha.my-own-note-became-my-evidence`).

⚠️ **`git.grove.ready.verify` asks about the BOX and stops there.** the tree and the suite
belong to `git.grove.provision test`, the command that can act on them — so the ladder holds no
rung that clones a repo, installs deps, or writes against a live testdb. a ladder that grew
such a rung would put one claim in front of four readers, which is the m.9 shape this very
section names.

### 🛑 what nearly discarded it — a local record that outlived its subject

`git.grove.provision` kept a local per-seat record at
`$XDG_STATE_HOME/git.grove.provision/<name>/applied.<seat>`, so a re-run would say which applies
it had already driven. keyed on the grove **NAME** — and a name survives a rebuild, because
that is what a name is for. the plan against the fresh box reported:

```
├─ 2. ground
│  ⚠️ this skill already drove an apply on ground — 2026-08-30T07:05:47Z
```

about an instance terminated at `07:04:28`. **so the one from-scratch box this rule waits
for read as a second run**, and to act on that verdict would have thrown the measurement
away (`gotcha.a-check-that-cries-wolf-gets-silenced` — the false ✋ is the corrosive half).

⇒ the repair is at cause: the question is put to the **BOX**, which holds the only copy that
cannot outlive it — the apply's own `--detach --log` sits on that disk, and a rebuild takes
the disk with it. the local record is deleted, so one fact has one reader again.

⚠️ **and it is not a `marker`.** that word is taken here, for a fixed line appended into a
file this repo does not own so that an APPEND is idempotent (`term=marker`). this was a local
file that remembered a REMOTE fact — a different concept, and to spell it with the same word
is the overload `rule.forbid.domain-term-synonyms` forbids.

⚠️ **and the answer is THREE-valued, never two.** a duct that gives no verdict has said not
one word about the box (97 is the transport). the first cut folded that arm into "no prior
apply" — a false ✔ introduced by the fix for a false ✋, in the same edit.
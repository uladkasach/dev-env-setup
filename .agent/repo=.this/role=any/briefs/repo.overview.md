# dev-env-setup

## .what

personal dev-environment repo for debian-based linux (pop-os, ubuntu). it declares
what a **grove** should hold, and converges any grove toward that declaration.

## 🛑 .a GROVE spans BOTH kinds — the laptop is one, and this is load-bear

settled by the human 2026-08-30: *"local and cloud are two types of groves."*

| kind | `$GROVE_ENV_SERVER` | `--for` | reached by |
|---|---|---|---|
| **local** | `local@unix`, `local@cicd` | `local` | no transport — the shell is already on it |
| **cloud** | `cloud@aws.ec2` | `cloud` | a duct (`term=duct`) |

⚠️ they differ in **REACH**, never in nature. a laptop is a grove you stand on; a cloud
grove is one you speak to through a duct. every bundle is written for both, and one that
cannot serve a kind DECLINES inline beside its reason.

### 🛑 so a sentence about "a grove" that is true of ONE kind is a defect

📜 measured 2026-09-03, and it cost a live port. `2.3.ssh/_.sh` reads *"a grove IS reached
over ssh; this is its front door"* — **true of a cloud grove, and false of a laptop.** the
phase beneath it asked for the `ssh` metapackage on every kind, debian's `openssh-server`
postinst enabled the unit, and one apply put a password-authenticated port on the box that
holds the rack.

⇒ this line used to read *"a laptop **or** a cloud grove"*, which states the laptop is not
a grove — the opposite of what `term=grove` declares. one fact, two holders, and the
always-booted holder was the wrong one.

⇒ **when you write `grove` in a claim, name the KIND, or confirm the claim holds for both.**

## .the shape: a grove's state is a TREE OF BUNDLES

`src/grove.provision/` **is** the inventory. the directory tree is the list; there is
no second list anywhere (`rule.require.bundle-as-sole-declaration`). some bundles carry
phases; the rest only dispatch their children.

⚠️ **no count is written here, on purpose.** a count in a brief is a SECOND declaration
of a fact the tree already carries. it decays in silence — no check reddens the day a
bundle lands — so the always-booted map goes wrong and still reads as authoritative.

⇒ ask the tree. a `prove.every-bundle-is-dispatched` probe answers on any box, and
cannot go stale — it reads `src/grove.provision/` and reports:

```sh
#    ├─ bundle dirs:   …  (top level: …)
#    ├─ entrypoints:   …
#    ├─ dispatches:    …
#    └─ reached slugs: …
```

that is the same repair `rule.require.one-command-provision` already made to its own
table of plays: *"the counts are now GONE, and every play reads its SET from the tree."*

⚠️ there is **one kind** of bundle, not two. a bundle either dispatches its children or does
the work, and the runtime does not care which — so a PHASE is a bundle too, turtles all the
way down. 🛑 do not reintroduce a `leaf` / `composite` split: its tally let `4.3.kitty` print
✔ on a box whose only applicable child was skipped (`term=bundle._.choice._.md`).

each bundle that carries phases holds up to four, and may own any subset:

| phase | asks |
|---|---|
| `provision.upsert` | put the thing on the box |
| `provision.verify` | prove it is on the box |
| `configure.upsert` | point it at this repo's config |
| `configure.verify` | prove the config is live AND current |

ONE operation drives every depth: `bundle.upgrade <slug>`. a parent's `_.sh` just
dispatches to its children, so `2.shell` and `2.8.tmux` are driven the same way.

```
src/grove.provision/         # ⚠️ NO _.sh here — see below
  2.shell/
    _.sh                    # dispatches its children, in WRITTEN order
    2.8.tmux/
      _.sh                  # operations shared by this leaf's phases
      provision.upsert.sh
      provision.verify.sh
      configure.upsert.sh
      configure.verify.sh
```

🛑 **the ROOT is the one depth with no `_.sh`.** `src/grove.provision/_.sh` does not
exist and never has, so a tree walk that expects a dispatcher at every depth returns
an EMPTY order at the root — and then reports every reference below it as a ghost.

the two shapes are:

| depth | how children are ordered | declared in |
|---|---|---|
| **root** | the FILESYSTEM, `sort -V` | `grove.provision._.sh` — it globs `$BUNDLE_DIR/*/` and version-sorts |
| **below** | each `_.sh`, in WRITTEN order | its `bundle.upgrade <child>` lines |

⚠️ and the second row matters more than it looks: **the written order is often
NOT the numeric order, on purpose.**

```
5.devtools:  5.1 → 5.2 → 5.14 → 5.3 → 5.5 → 5.6 → 5.12 → 5.4 → 5.15 → …
6.apps:      6.1 → 6.3 → 6.4 → 6.5 → 6.2
```

`6.apps/_.sh` states its reason in a `.order` block: codium runs last because
its CONFIGURE phase drives the binary its own PROVISION puts down. so the
number is a stable **identifier**, and the dispatch is the **order** — never
reason about what runs before what from the digits.

⚠️ `sort -V` at the root is load-bear for the same reason: plain lexical order
puts `10.x` before `2.x`. `prove.fix-texts-are-actionable` holds a fixture arm
for each of these two traps.

## .the one entrypoint

```sh
rhx grove.provision                              # plan the whole tree
rhx grove.provision --what 2.8.tmux --mode apply # one bundle, applied
rhx grove.provision --for cloud                  # as a grove would see it
```

`--mode plan` is the default and is a **survey**: it short-circuits every `*.upsert`
but ALWAYS runs every `*.verify`, so a plan tells you what is already true.

from a shell, `grove.provision` is the same command (`src/bash_aliases.sh`).
`grove.provision.<part>` names are pure synonyms for `--what <slug>`, kept only so
`<TAB>` completes; they are deliberately not grown.

## .$server = $tier@$platform

`local@unix`, `local@cicd`, `cloud@aws.ec2`. a bundle that cannot run everywhere
DECLINES inline, with an early return, beside the reason it declines for:

```sh
# a gpu terminal needs a display; a cloud box has none
[[ "$GROVE_ENV_SERVER" == local@* ]] || return 0
```

🛑 **read the TIER the bundle depends on — `local@*` is too coarse to mean
"a human is here."** `local@cicd` is a local tier with no screen and no human, so
`local@unix` is the one tier with a human at a keyboard (`pkg_can_sudo` is the
worked example).

⚠️ there is no `grove_env_has_screen` / `grove_env_has_human` predicate to reach for, and
do not write one. **each name claims a fact its body cannot check** — `has_screen` read the
server string, so it answered YES on a `local@cicd` runner. a predicate whose name outruns
its body is worse than the bare tag it wraps. `src/grove.env.sh` carries the reason inline.

## .src/ — the runtime, plus what no single bundle owns

🛑 **a config artifact owned by exactly one bundle lives INSIDE that bundle's own
directory, never at the flat `src/` root.** `4.3.2.emulator/kitty.conf` set the
precedent; `tmux.conf`, `starship.toml`, `zshrc.sh`, `init.lua`, and a dozen others
followed it. each upsert/verify reads its payload via `$GROVE_SRC/grove.provision/<path
to its own dir>/<file>` — a `bundle_dir` local, not a bare `$GROVE_SRC/<filename>`.

⇒ so `src/` root now holds only the RUNTIME (owned by no single bundle — every bundle
calls into it) and the handful of artifacts that genuinely have no ONE bundle to
collocate into:

| file | role |
|---|---|
| `grove.provision._.sh` | the entrypoint; root of the bundle tree |
| `bundle.upgrade.sh` | the runtime — the one operation, at every depth |
| `grove.for.sh` / `grove.env.sh` / `grove.pkg.sh` | shared runtime: target, server detection, package installs |
| `grove.web.sh` | shared runtime: the ONE wire boundary. `web_fetch`, `web_verify_sha256`, `web_verify_gpg_signature`, `web_verify_gpg_fingerprints`, `git_clone`, and the bounded `web_npm` / `web_pnpm` / `web_corepack` / `web_flatpak`. sourced by the entrypoint at `grove.provision._.sh:263` |
| `machine/` | systemd units + scripts. copied by FIVE bundles: `1.6.1.finders`, `1.6.2.monitor`, `1.7.usage`, `1.8.tmpfiles`, `4.3.4.snapshot` — no ONE owner, so no ONE dir to collocate into |
| `cosmic.gtk.desert.css` | **nobody** — an orphan; see below |
| `util.yubikey.ssh.sh` | human-run: load an ssh key onto a yubikey |
| `backup_env.sh` | human-run: push untrackable secrets to 1password |

config artifacts are **copied** to `~/`, not symlinked — so a `configure.verify`
diffs the live file against the checkout to catch a stale copy.

**where the single-owner artifacts moved** — each now sits beside its bundle's own
phase files, so `rule.require.bundle-as-sole-declaration`'s ownership test (would
exactly ONE bundle break if this vanished?) is enforced by the DIRECTORY, not merely
by a grep:

| moved into | carries |
|---|---|
| `2.shell/2.2.git/` | `git-credential-keyrack.sh` |
| `2.shell/2.5.zsh/` | `zshrc.sh`, `zshenv.sh` |
| `2.shell/2.6.starship/` | `starship.toml` |
| `2.shell/2.7.aliases/` | `bash_aliases.sh`, `ductwork.sh`, `termwork.sh`, `brains.auth.sh` |
| `2.shell/2.8.tmux/` | `tmux.conf` |
| `2.shell/2.9.emoji/` | `emoji.zsh`, `emoji.test.zsh`, `emoji.index.build.sh` |
| `3.cosmic/3.2.theme/` | `cosmic.theme.ron` |
| `1.system/1.3.browser/1.3.1.firefox/` | `firefox/` (`autoconfig.js`, `firefox.cfg`) |
| `4.terminal/4.5.nvim/` | `init.lua`, `lazy-lock.json`, `imagemagick.policy.xml`, `nvim.md` (tracked symlink → `../../../../.agent/repo=.this/role=any/briefs/desktop/nvim/nvim.md`) |

> 🛑 **an omission is the one defect a table cannot signal.** a wrong row is disproved
> by a reader who follows it. an absent row is disproved by nobody, because no reader
> can follow a path that is not written down — so a map reads complete at exactly the
> moment it is least complete.
>
> ⇒ both tables are a **claim about a directory's contents**, and they decay with every
> file added or moved. re-derive them before you trust them, and treat any row you add as
> owed a measured owner (`rule.require.trust-but-verify`):
>
> ```sh
> rhx globsafe --pattern 'src/*'
> rhx globsafe --pattern 'src/grove.provision/**/*' --long
> ```

⚠️ `cosmic.gtk.desert.css` is read by NO phase, so it is not an asset — an asset is a file
exactly one bundle phase copies and one verify `cmp`s (`term=asset._.choice._.md`). this one
is a **copy with no owner**, which is exactly why it stayed at the flat `src/` root rather
than move: there is no single bundle dir that could claim it. never copy it over
`~/.config/gtk-4.0/cosmic/dark.css`: COSMIC REGENERATES that path from the imported `.ron`
and stamps it `/* GENERATED BY COSMIC */`, so the repo's copy never survives and a verify
that diffs the two reports drift on every healthy box. the `.ron` is the single source; the
css is the written record of the palette, a human's to retire. `3.2.theme/_.sh` says so at
the bundle.

> ⚠️ an OWNER column is the easiest cell in a table like this to assert without a check, and
> a table is where an unverified claim hides best. grep for the `cmp` before you write one
> (`rule.require.trust-but-verify`).

⚠️ the two `util`/`backup` files are human-run utilities, NOT bundles. a bundle
converges the machine; `backup_env.sh` reads the machine and writes OUT to
1password. same nouns, opposite direction. neither is bundle-owned config, so neither
moves.

## .other dirs

| dir | holds |
|---|---|
| `codium/` | the vscodium settings sync — see the breakdown below |
| `assets/` | ⚠️ `kitty-icon.png` — the ONE bundle-read file outside `src/`; see below |
| `.claude/` | `settings.json` — the hooks that gate every write in this repo |
| `.dream/` | dream captures, via `rhx catch.dream` |
| `.behavior/` | bound behavior routes |
| `guides/` | vim/nvim references, eol upgrade notes |
| `keeb/` | hhkb layout docs |
| `notes/`, `ideally/`, `backups/` | a human's scratch. read by no phase |

⚠️ **`assets/kitty-icon.png` is read from OUTSIDE `src/`.**
`4.3.2.emulator/configure.upsert.sh:644` reaches it as `$GROVE_SRC/../assets/`,
so it is a declared asset that a `git.grove.push --from src` does **not** carry
(`gotcha.grove-push-into-names-the-destination`).

that step carries **no `GROVE_ENV_SERVER` gate**, so it runs on every box class — a grove
included. the `🌙` at line 654 keeps it benign: an absent asset is reported and the bundle
continues, since an icon is a decoration and a `✋` would fail the whole bundle over one.

> ⚠️ **a brief that cites ANOTHER BRIEF for a fact about code has verified no part of it** —
> it has only moved the unverified claim (`gotcha.my-own-note-became-my-evidence`). grep the
> CODE.

⇒ the residue is a **`🌙` whose reason is wrong on a grove.** it reads *"no custom icon
asset"*, which says the checkout lacks a file; the truth is that the TRANSPORT cannot carry
one, since `--from src` sends `src/` and the asset sits beside it. a correct verdict with a
mis-scoped reason is `gotcha.a-check-that-cries-wolf-gets-silenced`, m.4.

### `codium/` — who owns what, since not all of it is bundle-owned

| path | owner | why |
|---|---|---|
| `sync.settings.yml` | `6.2.codium` | its configure phase copies it to the extension's globalStorage, and its verify diffs it |
| `profiles/main/data/*` | the **zokugun.sync-settings extension** | `sync.settings.yml` sets `repository: {type: file, path: …/codium}` + `profile: main`, so the extension itself writes these. a bundle must NOT manage them |
| `redundant.extensions.yml` | **nobody** — see below | |

⚠️ `redundant.extensions.yml` is unowned, unreferenced, and misnamed. it is a pasted terminal
capture, first line and all —

```
➜ codium --list-extensions --show-versions
aaron-bond.better-comments@3.0.2
…
```

— so it is not valid yaml, and its name says "extensions to avoid" while its content dumps
ALL installed ones. `profiles/main/data/extensions.yml` holds the real list as structured
`enabled:` / `disabled:` entries with uuids, maintained by the extension. superseded; left in
place as a record of a past extension set, the human's to discard.

`grove.bootstrap.sh` sits at the repo ROOT and is the single documented exemption
from the bundle rule: it runs *before* the repo exists, so it cannot be a step of
the run it starts. the readme drives it.

## .the loop

```sh
git.repo.pull    # remote → here
grove.provision      # repo → machine
```

split by direction on purpose: `grove.provision.*` is repo→machine, `git.repo.pull.*`
is remote→here. one word used to name both.

## .key patterns

- the filesystem is the inventory; a second list is the defect this repo kills
  repeatedly (`rule.require.identical-bundle-composition`)
- every bundle verifies itself — a driven step is not a proven one
- 1password holds what cannot be tracked (aws creds, vpn profiles)
- flatpak for sandboxed apps; keyd for system-wide key remaps
- a grove is reached through its duct, and **a duct is tmux** — so an interactive
  prompt sits on the pane and eats the next command sent down it. that is why
  headless leaves refuse to prompt and ask for a token instead

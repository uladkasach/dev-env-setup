# inventory.approved-divergences

## .what

a **divergence** is a tool, unit, or config present on one grove kind and absent from the
other. this file names the ones that are **settled and correct**, so a traveler who finds one
does not re-argue it — and gives the test that separates them from a **miss**.

```
a divergence is APPROVED  ⟺  a bundle DECLINES it, and the decline names a PHYSICAL subject
```

⚠️ `grove` spans both kinds (`repo.overview.md`). a laptop is `local@unix`; a cloud grove is
`cloud@aws.ec2`. every row below is one of the two short of what the other holds.

## .the approved set — measured 2026-09-13 over `~/.local/bin` on both kinds

| absent from | the tool | the bundle that declines it | the physical subject it names |
|---|---|---|---|
| cloud | `kitty_snap_lowbatt` | `4.3.4.snapshot` | kitty WINDOWS |
| cloud | `machine_resource_procs_monitor` | `1.6.2.monitor` | a notification bus (`notify-send`) |

⇒ both are correct. neither is owed to a cloud grove, and a traveler who adds one has added a
unit no process on that box can trigger.

## .the wider class — every `local@*` decline in the tree, by subject

the two rows above are instances of one shape. the whole set, walked 2026-09-13:

| the subject a decline names | the bundles |
|---|---|
| no screen or compositor | `6.1.flatpaks` `6.2.codium` `6.3.dropbox` `6.4.protonvpn` `6.5.onepassword` `3.1.term` `3.2.theme` `3.3.desktop` `4.1.fonts` `4.3.3.launcher` |
| no microphone | `1.9.audio` |
| no notification bus | `1.6.2.monitor` |
| no kitty windows | `4.3.4.snapshot` |
| no hand to tap a key | `5.9.yubikey` |
| no keystroke for zle to read | `2.9.emoji` |

**not one gates a devtool binary.** that is the property worth a guard: a decline is earned by
a fact about the HARDWARE, never by a judgment about what a box "probably needs".

⚠️ `5.4.gh` and `5.15.identity` gate only the interactive **prompt**, never the binary. the
binary reaches both kinds; the login does not. that is a third, correct shape — do not read
their `local@unix` test as a decline of the tool.

## 🛑 .the test — approved, or a miss?

> **what does the decline NAME, and can that subject exist on the other kind?**

- a screen, a mic, a bus, a hand, a window → **approved.** the box genuinely cannot use it
- a binary, a version, a config file → **a miss.** those exist on any box, so no decline is earned
- no decline at all, and the tool is still absent → **a miss.** the bundle simply never ran there

⇒ the second and third rows are what `yq` and `git-credential-keyrack` each turned out to be.

## ⚠️ .the two measured misses — kept so the shape stays recognizable

| the tool | how it read | what it was |
|---|---|---|
| `yq` | absent from a grove, so it looked like a desktop concern | **no bundle declared it at all.** a lint gate reached for a host tool, and every box sat one apt-divergence from silent breakage. the repair is `5.17.yq`, a pinned static binary |
| `git-credential-keyrack` | absent from a laptop's `~/.local/bin`, so it looked like a cloud-only credential path | **no gate exists.** `2.2.git/configure.upsert.sh` installs it unconditionally; the laptop had simply not had that bundle applied |

⇒ **both were absent, and neither was declined.** an absence with no decline behind it is the
signature of a miss, and it is the cheapest claim in this file to check.

## .the apt half — measured 2026-09-13, and it names no miss

`~/.local/bin` is one directory, so a miss of the `yq` shape could have sat in `/usr/bin` and
this file would not have named it. the apt manifests close that:

| the read | laptop | cloud |
|---|---|---|
| `apt-mark showmanual` | 400 | 134 |
| laptop-only rows | 361 | — |

of the 361, all but two are locale packs, `lib*`, or a desktop the cloud kind has no screen
for. the two that read as devtools are `age` and `chafa` — **declared by no bundle and invoked
by no line of this repo**, so neither is owed to a grove. a human's hand-install has no claim on
the other kind.

⇒ four tree-declared packages are genuinely absent on the cloud kind, and each is already an
approved row above: `fonts-firacode` (`4.1.fonts`), `pulseaudio-utils` (`1.9.audio`),
`yubikey-agent` (`5.9.yubikey`), `cosmic-term` (`3.1.term`).

### 🛑 the two false ✋ this walk produced — read the STORE, and read the SHELL

both would have been recorded as misses by a reader who trusted its first answer:

| the trap | what it printed | what was true |
|---|---|---|
| the **store** | 9 tree-declared packages absent from `apt-mark showmanual` — `git` `tmux` `vim` `gnupg` `bc` `ca-certificates` `software-properties-common` `fontconfig` `pipewire-bin` | all 9 **present**, auto-flagged rather than manual. the manual flag is one store; presence is another |
| the **shell** | `command -v yq` over a duct → no line | `$HOME/.local/bin/yq` is there, 14MB. a duct send reaches a shell that never read an rc |

⇒ the first is `gotcha.a-check-that-cries-wolf-gets-silenced` q13 verbatim, and the second is
`gotcha.a-tool-found-by-path-answers-only-a-human` rung 1. **a package absence and a PATH
absence render identically**, so a presence probe by absolute path is what settles either.

## 🛑 .the bound that remains

the walk reads **apt manifests plus `~/.local/bin`**. a tool that arrives by neither — a cargo
install, a pnpm global, a tarball into `/opt` — is invisible to it.

so read the table as a **lower bound on what is settled**, never as a census.

## .enforcement

- a divergence "fixed" by a copy onto the other kind, where a bundle declines it here =
  **blocker**; the decline names the reason and the copy discards it
- a tool absent from one kind with **no** decline behind it = **blocker**, and it is a miss —
  find the bundle that owes it, or write one
- a row added here with no bundle named = **blocker**; the bundle is what makes it checkable
- a decline that names a capability rather than a physical subject = **blocker**
  (`rule.forbid.tty-as-a-proxy-for-a-human` is this same defect one layer down)

## .see also

- `rule.forbid.divergence-without-a-physical-reason` — the rule this inventory records the
  settled cases of
- `rule.require.identical-bundle-composition` — why one declaration serves both kinds
- `rule.forbid.tty-as-a-proxy-for-a-human` — a capability used in place of a human's presence
- `define.6-apps-is-laptop-only` — the section-scale instance of the screen decline
- `rule.avoid.python-runtimes` — why `yq`'s repair is a static binary rather than the apt route
- `repo.overview.md` — the two grove kinds, and why a claim true of one is a defect

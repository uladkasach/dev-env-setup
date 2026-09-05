# rule.require.bundle-as-sole-declaration

> 📖 **new to bundles? read `define.grove-provision-bundles.md` first.** it explains the tree, the
> quartet, and the exit codes this rule leans on.

## .what

a bundle directory is the **sole declaration** of its concern. each part the concern needs to make
its claim lives under `src/grove.provision/<slug>/` — the packages, the config bodies, the
version pins, the verifies — and it lives there **once**.

two halves, and both are the rule:

1. **SOLE** — the concern is declared in exactly one place. never in a bundle *and* in a `pt*.sh`
   file, never in two bundles.
2. **SELF-CONTAINED** — a bundle calls out only to the **runtime primitives** (named below). it
   may not call a function that another concern owns.

settled by the human, 2026-07-29:

> yeah basically hard cut away into bundles exclusively. everything should now be in terms of
> `grove.provision --what $bundle` format

## .why

### the drift this closes

a concern spread across two files is a concern with two answers, and this repo has paid for that
shape four times:

| the two places | what drifted | when |
|---|---|---|
| `install_env._.sh` + `install_env.grove.sh` | a second list of steps | 2026-07-26 |
| `grove.provision` + `grove.provision.grove` | the second list had already dropped `brains`, so a grove ran the robot brains with no config | 2026-07-27 |
| a `step` inventory + a standalone slice suite | 8 of 11 members re-implemented the function a `step` line already drove | 2026-07-27 |
| `grove.env.sh` + `grove.for.sh` | two detections of one machine kind | 2026-07-29 |

⚠️ **the names in that table are the names those artifacts CARRIED, and a rename must not
touch them.** `install_env` and `grove.provision` are both superseded by `grove.provision`
(`term=grove.provision._.choice.reason.md`), so a sweep rewrites them into a row that reads as
a live word beside a dead one — and the account of what drifted is destroyed. measured
2026-08-31, on this row.

every one is the same defect: **two answers to one question, drifted apart**. a bundle with its
body in a `pt*.sh` file is that shape one more time — the phase says what to claim while the
function says what to do, and a change to one is free to miss the other.

### the reader cannot follow an ambient call

`4.3.2.emulator/provision.upsert.sh` used to call `install_kitty` with no declaration of where
that name comes from. it worked, but only because the driver sources all eleven `pt*.sh` files
into global scope BEFORE it glob-sources the bundles. four costs:

- a reader who opens the phase cannot find the code it runs
- the bundle is not self-contained, so it cannot be read, moved, or reviewed as one unit
- the source ORDER is now load-bear and undocumented — reorder two lines in the driver and a
  phase calls an undefined function
- it cannot survive a lift into `declastruct`, where a bundle must declare its own dependencies

### one flag, one subject

`grove.provision --what <slug>` is the whole surface. that only holds if the slug reaches the whole
of the concern: if half of kitty is `4.3.2.emulator` and half is `install_kitty`, then
`--what 4.3.2.emulator` names a subtree that does not contain its own work.

## .the boundary — what a bundle MAY call

the runtime families below, and no others. these are the framework's contract, owned by no
concern:

| family | the calls | where declared |
|---|---|---|
| **the dispatch** | `step`, `bundle_composite`, `bundle_leaf` | `src/bundle.upgrade.sh` |
| **the package boundary** | `pkg_install`, `pkg_refresh`, `pkg_present`, `pkg_assert_apt`, `pkg_can_sudo` | `src/grove.pkg.sh` |
| **the environment readers** | `grove_env_server_tier`, `grove_env_server_platform`, and `$GROVE_ENV_SERVER` itself | `src/grove.env.sh` |
| **the wire boundary** | `web_fetch`, `git_clone`, `web_tempdir`, `web_verify_sha256` | `src/grove.web.sh` |

every other call a phase makes must be declared inside the bundle's own directory.

### the ownership test

> if this function vanished, which bundles would break?

| answer | verdict |
|---|---|
| **every** bundle | a runtime primitive. call it |
| exactly **one** bundle | that bundle's body. it must LIVE in that bundle |
| **two or three** bundles | duplicate it into each, until there are three (`rule.prefer.wet-over-dry`); then lift it to the runtime and name it there |

the middle row is deliberate. a shared operation extracted at its second use is an abstraction
guessed from one example, and the wrong guess costs more than the duplication
(`rule.prefer.most-common-denominator` governs WHERE it lands once it is genuinely shared).

## .how — the move, never the copy

when a concern converts to a bundle, its body **moves**:

```sh
# 👎 forbidden — the body is copied; two answers, free to drift
# 4.3.2.emulator/provision.upsert.sh
grove_provision_4_3_2_emulator_provision_upsert() {
  install_kitty                 # still declared in install_env.pt4.terminal.sh
}
```

```sh
# 👍 required — the body LIVES here; install_kitty is deleted from pt4
# 4.3.2.emulator/provision.upsert.sh
grove_provision_4_3_2_emulator_provision_upsert() {
  local version="0.44.1"
  local sha256="..."
  # the pinned fetch, the fingerprint check, the symlink — all here
}
```

the test that the move is complete: **grep the old name.** if it still appears outside a dated
historical note, the body was copied, not moved.

## .the caveat — a `sudo` or a coreutil is not a concern

this rule governs calls to functions **this repo declares**. `sudo`, `curl`, `awk`, `tar`,
`update-alternatives` are the os, not a concern, and a phase calls them freely. the boundary is
about ownership inside this repo, not about self-sufficiency from the machine.

## .enforcement

- a bundle phase that calls a function declared outside its own directory, and outside the
  runtime families above = **blocker**
- a concern declared in BOTH a bundle and a `pt*.sh` file = **blocker** (the copy is the defect;
  delete the `pt*.sh` half)
- a bundle that calls a function another bundle owns = **blocker** (composition happens through
  `step`, at the composite, never by a sideways call between leaves)
- a shared operation lifted to the runtime at its FIRST or SECOND use = **nitpick**
  (`rule.prefer.wet-over-dry`)

## .see also

- `define.grove-provision-bundles.md` — how the tree and the quartet actually work
- `rule.require.grove-provision-bundles` — that a new member must be BORN a bundle
- `rule.require.upgrade-entries-verify-themselves` — the four phases a leaf owes
- `rule.require.every-function-has-a-driver` — that a declared function must be DRIVEN
- `rule.require.grove-provision-as-the-only-verb` — one driver, one list, subsets as filters
- `rule.prefer.wet-over-dry` — why the second use does not earn an abstraction
- `rule.prefer.most-common-denominator` — where a genuinely shared operation lands

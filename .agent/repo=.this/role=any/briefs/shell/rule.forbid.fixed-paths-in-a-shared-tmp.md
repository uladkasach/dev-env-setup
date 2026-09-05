# rule.forbid.fixed-paths-in-a-shared-tmp

## 🛑 .the rule, in one line

# **NO PHASE MAY WRITE TO A FIXED, GUESSABLE PATH UNDER `/tmp`.**

land it in a private dir instead:

```sh
local tmp_dir
tmp_dir="$(web_tempdir <label>)" || return 1     # 0700, random suffix
```

`web_tempdir` lives in `src/devenv.web.sh`, beside `web_fetch`, because every caller is a
fetch site — this is where the bytes LAND.

## .why — a grove is a MULTI-SEAT box, and /tmp is 1777

measured on `grove-ahbode-v20260811`, 2026-08-13
(`diagnose.shared-tmp-on-a-two-seat-box`):

```
/tmp = drwxrwxrwt root:root   (1777)
seats that share it: ubuntu(1000), ground(1001), camper(1002)
```

so **three** unprivileged accounts can create any name in that directory. and the seat that
runs the work — the camper, and therefore the seat an attacker lands on — is one of them.

### 🛑 the sticky bit does NOT close this

this is the belief the defect hid behind, and it is half right:

| sticky stops | sticky does NOT stop |
|---|---|
| one seat DELETES another seat's file | one seat CREATES a name first |
| one seat RENAMES another seat's file | that seat later REWRITES a file it owns |

⚠️ and the second column is what makes `rm -rf "$tmp_dir"` a **false guard**. against the one
case it existed for — a directory another seat already owns — sticky `/tmp` refuses the
rmdir, so the reset silently does no work and the phase carries on into the foreign dir. a
guard that fails only in the case it was written for is worse than an absent guard, because a
reader sees it and searches no further
(`gotcha.a-check-that-cries-wolf-gets-silenced`).

## .the measurement — ten sites, four of them fed to root

ten upsert phases wrote to a fixed name. four then hand that path to **root**,
and the worst of them carried its own signature check — and lost anyway. see
`rule.forbid.fixed-paths-in-a-shared-tmp.demo=ten-sites-measurement.md` for
the full chain.

> a check whose entire evidence set is attacker-writable is not a check.

## .why it was invisible

every one of the ten sites is guarded on *"is it already here?"*, so **on a converged box not
one of them runs.** a clean apply is evidence about the SKIP path and says not one word about
where the bytes land. this is the same blind spot that let `pkg_can_sudo` run broken through
two clean applies.

⇒ reach the code DIRECTLY from a play. do not infer it from a green apply.

## .the test

> **could another account on this box have created this path before I did?**

- a fixed name under `/tmp` → **yes**, always, on any multi-seat box
- `$(web_tempdir …)` → no; mode 0700 with a random suffix
- a path under `$HOME` → no; a seat owns its own `$HOME` (`term=seat`)

## .the exemption that is not one

*"but this file is not sensitive"* is not an exemption. the hazard is not the file's contents
— it is that **the path is a name another account can claim**, and what the phase then does
with that path. a font zip is unzipped into `$HOME`; an installer is executed; a `.deb` is
handed to root. the blast radius is the CONSUMER, not the artifact.

## .enforcement

- a fixed, guessable path under `/tmp` (or any world-writable dir) in any phase = **blocker**
- a `rm -rf` on such a path offered as the guard = **blocker**; sticky `/tmp` makes it a no-op
  in the one case it was written for
- a downloaded artifact and its own signature or key landed in the same non-private dir =
  **blocker**
- a temp dir widened past 0700 to silence apt's `Download is performed unsandboxed as root`
  notice = **blocker**; that notice is the price of the private dir, and the price is right

## .the TS twin, named so it is not re-derived

`ehmpathy/test-fns` ships **`genTempDir`** — the same policy for a jest process: ask the OS
for a private dir rather than name one. the mechanic role's
`rule.forbid.adhoc-gentempdir-reimpl` binds it there.

|  | `web_tempdir` (here) | `genTempDir` (test-fns) |
|---|---|---|
| serves | a bundle phase, on a box | a jest process, in a repo |
| extras | none — a label and a mode check | clone-a-fixture, auto-prune of >1hr dirs |

⇒ one policy with two implementations is the m.9 shape — but both reduce to `mktemp -d` /
`mkdtemp`, so the drift risk is low and a **named** twin is the whole repair.

### 🛑 do NOT reach for a `gen-temp-dir` CLI bin

proposed 2026-08-30, refused on a **dependency-order constraint** rather than a preference:
`4.5.nvim` and `4.3.2.emulator` call `web_tempdir`, and node arrives in `5.1.node`. a
section-4 bundle cannot depend on a bin that section 5 installs
(`rule.require.bundles-own-their-dependencies`).

⇒ and no capability would be gained. `mktemp -d` is POSIX, ships in coreutils, defaults to
0700, and generates the suffix. a node CLI would be strictly later, strictly slower, and
would add a `node absent` failure mode where this has none.

## .see also

- `src/devenv.web.sh` — `web_tempdir`
- `rule.forbid.fixed-paths-in-a-shared-tmp.demo=ten-sites-measurement.md` — the ten-site chain
- `rule.forbid.adhoc-gentempdir-reimpl` (mechanic) — the same policy, for TS tests
- `rule.require.security-paramount` — the general bar this serves
- `rule.require.one-command-provision` — why only a first apply exercises this
- `gotcha.a-check-that-cries-wolf-gets-silenced` — why the `rm -rf` guard was worse than absent
- `term=seat._.choice._.md` — why a grove has more than one account in the first place

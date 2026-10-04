# demo: 4.5.nvim configure.upsert — the kept copy, the plugin lockfile, the coder policy

## .what

`4.5.nvim/configure.upsert.sh` copies three files from this run's checkout: `init.lua`,
`lazy-lock.json`, and an imagemagick `policy.xml`. each block's measurement lives here.

## m1 — keep what the run is about to DESTROY (2026-09-06)

`rule.require.repo-as-source-of-truth` says a machine-side edit is LOST — correct as policy, a
claim about what SHOULD survive, never that the bytes were worthless. a `cp` is a partial write
with the widest possible radius.

📜 `~/.config/nvim/init.lua` had drifted **274 lines** from the checkout, in BOTH directions: a
destructive buffer-wipe present in no commit, AND five improvements the repo lacked
(`get_lua_kb`, `count_extmarks`, `count_chans`, log rotation, a stampede guard). the five were
read back by hand and shipped.

- ⚠️ "was that ALL of them?" is now **unanswerable**: the apply overwrote the file with no copy
  kept, and the only backup was hand-made, three days stale, and older than the drift
- ⇒ `gotcha.a-partial-write-discards-what-it-never-read`: a writer converges only the fields it
  reads, and this one read none
- it fires on DRIFT only: a converged box copies identical bytes, `cmp` matches, and no copy is
  kept (`rule.require.idempotent-install-procedures`)
- the word is DRIFT, never `divergence` — that names the STATE and loses the silence
  (`term=drift._.choice._.md`). the message said `DIVERGED` until 2026-09-07
- a failed backup is FATAL: to overwrite regardless destroys the bytes this exists to preserve

## m2 — DRIFT has TWO causes, and `cmp` tells them apart in NO way

| the cause | what the `.bak` is worth |
|---|---|
| the MACHINE was edited, and the repo was never told | evidence — read it, port it |
| the REPO moved ahead, and this apply carries it over | disposable — the old copy |

📜 2026-09-07: the first cut printed *"a machine-side edit the repo has not been told about"* and
told the human to *"move each part worth a keep INTO the checkout"*. the very next apply fired it
against a `.bak` whose whole content was the two lines the checkout had just replaced — no
machine edit, no part worth a keep.

- the ACTION was right and the REASON was invented — the hardest pair to catch, since the
  verdict looks correct and only the sentence beneath it is false (`…cries-wolf`, m.4)
- the CHEAP cause fires most: every apply after a checkout edit drifts, so a message that cries
  "somebody edited your machine" is a false ✋ on a schedule
- ⇒ the message states the FACT and hands the human `diff $bak $src`, the one command that
  separates the causes. it names neither

## m3 — 🛑 the PLUGIN LOCKFILE pins 13 repos

`init.lua` names 13 repos with NO ref, so each is taken at TIP, and `nvim-treesitter`'s `build =
':TSUpdate'` EXECUTES that tip — a push to any of the 13 was code execution on the next nvim
start.

- a LOCKFILE, never 13 `commit =` fields: 13 hand pins are 13 declarations of one fact.
  `lazy-lock.json` is lazy's OWN single declaration (`rule.require.bundle-as-sole-declaration`)
- ✔ MEASURED, lazy 85c7ff37, 2026-09-02 — a lockfile pins a FIRST install, not only `:Lazy restore`:

  ```
  lua/lazy/core/loader.lua:84           auto-install passes `lockfile = true`
  lua/lazy/manage/init.lua:82           git.clone → git.checkout{lockfile} → plugin.build
  lua/lazy/manage/task/git.lua:329,358  a lock entry OVERRIDES target; `checkout <lock.commit>` runs
  ```

  ⇒ the checkout precedes `plugin.build`, so `:TSUpdate` builds the PINNED tree, before any
  plugin's `config` or `init` has run
- ⚠️ the bound it does NOT hold: `git.clone` still FETCHES the tip's objects before the checkout
  rewinds. it pins what is EXECUTED, never what is transferred
- ⚠️ lazy reads `stdpath('config')/lazy-lock.json` (`core/config.lua:24`); a copy elsewhere is a
  file, not a pin
- 🛑 FATAL where the policy is not: an absent lockfile means the next start executes 13 tips
- the lockfile gets the SAME keep-the-copy guarantee as `init.lua`, and its risk is SHARPER:
  drift is the DECLARED bump workflow (`:Lazy update`, then copy back). a human who runs the
  update and applies before the copy-back loses every new pin, silently — and a guarantee given
  to one call and not its twin is a blocker (`rule.require.one-command-provision`)

## m4 — the imagemagick POLICY, owned because the bundle owns the tool

- `provision.upsert` step 6 installs imagemagick (`rule.require.bundles-own-their-dependencies`)
- the debian default calls ITSELF an "open security policy": it declares NO coder rule, and an
  absent rule is a PERMITTED one — PS/EPS/PDF/XPS reach ghostscript, MVG/MSL are interpreted.
  `imagemagick.policy.xml` carries the full account
- a SEAT path, no root: 📜 2026-08-31, a policy at `$XDG_CONFIG_HOME/ImageMagick` bites unaided,
  and the `$HOME/.config` fallback bites too — so the CAMPER owns it, rather than wait on `ground`
- not fatal, as step 6 is not; `configure.verify` asks that it bites

## .see also

- `4.5.nvim/configure.upsert.sh` — the phase these measurements back
- `gotcha.4-5-nvim.demo=configure-verify-measurements.md` — the verify's half
- `howto.install-configs-from-a-worktree` — why the source is `$GROVE_SRC`

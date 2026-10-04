# demo: 5.1.node — the install-time measurements behind fnm and pnpm

## .what

`5.1.node/provision.upsert.sh` installs fnm's pinned binary, the baseline node
versions, and a pinned pnpm on every one of them. this brief holds the dated
measurements behind each choice.

## m1 — a piped corepack question hangs the pane, cause unlogged

- `pnpm --version` under corepack, no `CI=1`, sat in `ep_poll` 57 minutes on
  grove-1 — corepack asked "Do you want to continue? [Y/n]" on stdout; a piped
  stdout swallowed it, so the read waited forever
- ⇒ `CI=1` is declared once at the driver; every corepack call leans on it

## m2 — fnm's release ships no signature sidecar, read 2026-08-13

- `gh api -X GET repos/Schniz/fnm/releases/latest` lists five zips, no `.sig`
  or `.sha256` sidecar
- ⇒ the sha256 pin here is READ off github's release api, not computed
  locally — it catches a corrupt transfer, a wrong mirror, a re-uploaded tag;
  it does not survive a github compromise

## m3 — a `fnm list | tail -1` scrape names a nightly, not the LTS, laptop 2026-07-30

- `fnm list` on this laptop:
  ```
  * v20.12.2 / v22.14.0 / v22.20.0 / v22.21.0 / v24.15.0
  * v24.18.1 default, lts-latest
  * system
  ```
- a scrape of the last line returned `v24.18.1`, right by coincidence — one
  `fnm install 25` retargets the scrape at a nightly
- ⇒ the default is named by the `lts-latest` ALIAS, never a scrape

## m4 — an absent baseline version opens an interactive prompt that hangs a duct, grove-1 2026-08-03

- fnm's use-on-cd hook does not fall back when a `.nvmrc` version is absent —
  it asks `Do you want to install it? [y/N]:` on stdin
- a plain `cd` into the checkout sat 4m16s on grove-1: a duct is tmux, so the
  prompt holds the pane and eats the next command sent down it as its answer
  (`rule.forbid.tty-as-a-proxy-for-a-human`)
- ⇒ a laptop's `fnm list` carries years of accidental installs, never a
  phase's — it cannot catch this. a fresh grove from this bundle held only
  v24.18.0/v24.18.1/system, which shows the gap
  (`rule.require.prove-changes-on-a-grove`)

## m5 — corepack's pnpm cache grew four pnpms from repeated `@latest` installs

- before the pin, this phase installed `pnpm@latest` per node version;
  corepack's cache held four separate pnpm downloads, one per run
- ⇒ the declared-version pin (`grove_pnpm_version_wanted`) closes the source

## m6 — an absent package.json cascades into 5 of 12 claims, fresh grove 2026-08-12

- a fresh grove's first apply reported no `packageManager` pin — cause: a
  partial checkout. the bootstrap push sent `src/` alone; `package.json` and
  `.nvmrc` sit BESIDE it at the repo root
- 5 of that run's 12 claims traced to the one absent file, cascaded across
  bundles: `5.1.node` no pnpm → `5.3.brains` no rhx → `5.4.gh` cannot read
  the rack → `5.10.repos` unauthed → `5.13.reach` declines
- ⇒ each downstream claim named a fix for its OWN bundle; a top-down reader
  repairs four innocent bundles (`rule.require.solve-at-cause`,
  `howto.add-a-new-grove` step 4)

## m7 — a silent registry stalls corepack and npm past 240s, 2026-08-14

- against a registry that accepted a connection and went quiet, neither
  `corepack` nor `npm` returned at 240s
- this loop runs PER NODE VERSION, so one stall multiplies
- ⇒ every call routes through `web_corepack`/`web_npm`, never the bare tools;
  `corepack enable` stays bare, since it reaches no registry

## m8 — the phase reported the wrong pnpm as installed, laptop 2026-07-30

- this phase's log named `pnpm@11.18.0` as the version just fetched, then
  reported `• pnpm 10.24.0 ✔` below it — a ✔ for a version never fetched
  (`rule.forbid.failhide`)
- ⇒ the report reads back `pnpm --version`, the version that ANSWERS, never
  the one the fetch command named

## m9 — one binary, two versions; the PATH explanation is false, grove-1 2026-08-06

- grove-1 held no standalone pnpm, one `type -a pnpm` entry, and answered two
  different versions by cwd
- corepack's shim DISPATCHES on the nearest `packageManager` field — one
  binary, two versions, a count of binaries could never show it
- ⇒ the diagnostic that discriminates is `cd ~ && pnpm --version`: the answer
  is a property of the directory, never of PATH

## m10 — a shim fossil outlived two applies, grove-1 2026-08-06

- a `claude` binary pinned at 2.1.87 by `5.3.brains` sat beside a stale
  2.1.220 copy:
  ```
  $PNPM_HOME/bin/claude  2.1.220  written 07-31   ← PATH picked this
  $PNPM_HOME/claude      2.1.87   written 08-06   ← the pin
  ```
- two applies of `5.3.brains` never closed the gap: neither install touches
  the OTHER dir's copy
- ⇒ the prune reads pnpm's own live dir (`grove_pnpm_shim_dir_live`), removes
  only a shadowed duplicate — never a stray pnpm at a path pnpm does not own

## m11 — the two shims DISAGREE on the prompt default, so no `corepack` call can see it

m1 above names the hang. this names why a `corepack` call cannot reproduce it, measured
2026-09-26 off corepack's own source:

| the shim | its default | so it |
|---|---|---|
| `corepack` | `COREPACK_ENABLE_DOWNLOAD_PROMPT ??= '0'` | never asks |
| `pnpm` | `COREPACK_ENABLE_DOWNLOAD_PROMPT ??= '1'` | **asks, on stdin** |

- a duct is tmux, so the question held the pane and ate the rest of the run
  (`rule.forbid.tty-as-a-proxy-for-a-human`). the aether gate's step 2:
  ```
  ! Corepack is about to download …/pnpm-10.11.0.tgz
  ? Do you want to continue? [Y/n]
  ```
- 📜 the gate then reported a DUCT fault — true of the duct, and the cause was this
  bundle's: a correct verdict over the wrong subject
  (`gotcha.a-check-that-cries-wolf-gets-silenced`, m.4)
- ⚠️ the env var is NOT the fix. to silence the prompt leaves the FETCH in place, so the
  box still needs the wire mid-run and still stalls on a slow registry — and this repo
  approves of corepack, so the answer is to hold what it will be asked for
  (`rule.require.solve-at-cause`)
- ⇒ hence `GROVE_PNPM_BASELINE`, a CACHE beside the pin. the two answer different
  questions and no amount of the second buys the first: a DEFAULT is what `pnpm` means
  outside any repo, exactly one by nature; a CACHE is which pins run with no wire call,
  as many as you like. a repo's own `packageManager` outranks the default, so two repos
  that declare two pnpms are served by no single default however it is chosen

## m12 — the cache loop's flags, each read off corepack's source

- `-g` is REQUIRED by corepack's own parser: `InstallGlobalCommand` declares it `{ required:
  true }`. `--cache-only` is what keeps the install off the global default — so the pair is no
  redundancy
- 🛑 `--cache-only` alone does NOT protect the default: corepack repoints it inside the DOWNLOAD
  path for any same-major, strictly-greater version, and `--cache-only` is read one level out,
  after that has fired. the guard is `COREPACK_DEFAULT_TO_LATEST=0`, exported once at the driver
  — absent it, the loop would move the pin `grove_pnpm_version_wanted` holds, and the verify
  would halt on its own "TWO pnpms"
- NOT per node: the cache is one dir per `$HOME` (`grove_pnpm_cached`), so a per-node loop would
  re-ask for a held version once per node
- the cache is re-ASKED after each install: corepack can exit 0 on a fetch it then declines to
  land, so its code is no evidence — and an unheld version is exactly the prompt this closes

## .see also

- `5.1.node/provision.upsert.sh` — the header these measurements back
- `5.1.node/_.sh` — m11's header, the cache this bundle declares
- `gotcha.5-1-node.demo=pnpm-shim-dir-split` — the neighbor demo, `_.sh`'s
  own two measurements on the shim-dir split
- `rule.require.solve-at-cause`, `rule.forbid.failhide`, `rule.forbid.tty-as-a-proxy-for-a-human`

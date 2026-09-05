# howto.rhx-upgrade

## .what

`rhx upgrade` is the one command that brings a box's rhachet, roles, brains, and
hooks up to current — **including the global shim**, which is what `pnpm install`
cannot do.

```sh
cd ~/git/more/dev-env-setup && rhx upgrade
```

## ⚠️ .why NOT `pnpm install`

they are not the same act. the difference cost a full diagnosis on 2026-08-05.

| | `pnpm install` | `rhx upgrade` |
|---|---|---|
| reads | the **pushed lockfile** | the registry |
| touches `node_modules` | ✔ | ✔ |
| touches the **global `rhx` shim** | ✋ never | ✔ |
| re-links roles + brains | ✔ (via the `prepare` entry) | ✔ |
| re-applies hooks | ✔ | ✔ |
| duration, measured on grove-1 | **15m 38s** | **6s** |

a `pnpm install` reinstalls whatever the lockfile on that box already names. so on
a grove whose lockfile was pushed weeks ago it faithfully reinstalls the OLD
version, reports success, and leaves the box exactly as stale as it found it.

measured on grove-1 2026-08-05: `pnpm install` ran 15m38s, printed a healthy
`✨ hooks · 32 updated`, and left rhachet at **1.44.4** while the fix under test
shipped in 1.45.1. every later probe then measured the old bug and read as a
finding.

> ⚠️ so a green `pnpm install` says the LOCKFILE was honored. it says none of
> whether the box is current.

## .the sequence, for a grove

```sh
# 1. wake it (needs aws sso — a human clicks a browser prompt)
rhx keyrack unlock --owner ehmpath --env camp
rhx git.grove.wake grove-1

# 2. push the manifest + lockfile you upgraded locally
rhx git.grove.push grove-1 --from package.json  --into git/more/dev-env-setup --mode apply
rhx git.grove.push grove-1 --from pnpm-lock.yaml --into git/more/dev-env-setup --mode apply

# 3. upgrade, from INSIDE the checkout
rhx git.grove.send grove-1 --what 'rhx upgrade'

# 4. VERIFY — never trust the ✨
rhx git.grove.send grove-1 --what 'cat node_modules/rhachet/package.json | head -6'
```

⚠️ step 4 is not ceremony. `rhx upgrade` prints `✨ rhachet upgraded locally`
whether or not the version moved, so the printed line is a claim and the
`package.json` read is the fact (`rule.require.trust-but-verify`).

## ⚠️ .why every call must run from INSIDE the checkout

rhachet's cli resolves the git repo root **before** it dispatches any subcommand,
so `rhx` from `$HOME` dies with:

```
BadRequestError: Not inside a Git repository   { "from": "/home/camper" }
```

and that error names the SHELL's cwd, not any fact about rhachet. a duct pane that
restarted sits at `~`, so send a `cd` first:

```sh
rhx git.grove.send grove-1 --what 'cd ~/git/more/dev-env-setup'
```

## 📜 .what a grove needed that was NOT in `src/` — settled 2026-08-12

`git.grove.push --from src` carries `src/` and **only** `src/`. three other paths had to be
pushed by hand, and each had bitten:

| what | why it matters |
|---|---|
| `package.json` + `pnpm-lock.yaml` | else the box reinstalls the OLD version |
| `.agent/` | holds `keyrack.yml` — an undeclared key reads `absent 🫧` forever |
| the `extends:` targets | `.agent/keyrack.yml` extends role manifests that `rhachet init` writes |

⇒ **`--from .` now carries all of it.** the push excludes `.git`, `node_modules`, `.log`,
`.temp`, and `.agent/.cache` on both carriers, so a whole-repo push is the correct and cheap
form. it prints the skip list on every run. the two-line push in step 2 above stays only
because an rhx upgrade genuinely wants the two manifests and no more.

⚠️ `--into` names the destination **directory**, never the file. `--into
…/package.json` makes a DIR of that name and pushes the file inside it. a FILE `--from` takes
the OPPOSITE `--into` shape to a dir's — the dir's own name belongs in `--into`, the file's
does NOT (`gotcha.grove-push-into-names-the-destination`).

## .the prompts that hold a duct pane

both of these read stdin, and a duct IS tmux — so the question sits on the pane
and then consumes the next command sent down the duct as its answer:

- **pnpm** — `The modules directory … will be removed and reinstalled from
  scratch. Proceed? (Y/n)`
- **fnm** — `Can't find an installed Node version matching vX. Do you want to
  install it? answer [y/N]`

answer them with `--anyway`, which types INTO the waiting process rather than
refusing because the pane is busy:

```sh
rhx git.grove.send grove-1 --anyway --what 'y'
```

(the fnm one is closed at cause — `src/zshrc.sh` carries
`fnm use --install-if-missing`. the pnpm one is not.)

## .the tell

before you report a box as upgraded, ask: **what version does it actually run?**

if the answer comes from a `✨` line rather than from a `package.json` read, the
box is unproven — say so in those words.

## .see also

- `rule.require.prove-changes-on-a-grove` — why a laptop cannot stand in for one
- `rule.require.trust-but-verify` — the general form of the `✨` trap
- `gotcha.grove-push-into-names-the-destination` — `--into` names a dir
- `rule.forbid.tty-as-a-proxy-for-a-human` — why a prompt on a duct is a defect

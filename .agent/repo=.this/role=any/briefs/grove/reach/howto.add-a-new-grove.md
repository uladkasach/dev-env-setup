# howto: add a new grove

## .what

infra handed you a box. register it, reach it, converge it, prove it — that is the whole
path to a grove that can run a test suite.

this brief is the **entry point** of a family:

| brief | covers |
|---|---|
| **this one** | a box you have just been handed → a grove that works |
| `howto.adopt-a-replacement-grove.md` | a box that REPLACED one you already had — the stale-exid trap |
| `howto.bootstrap-a-grove-from-scratch.md` | the raw first-contact detail, and every trap in it |
| `howto.grove-ready-test.md` | the ladder that decides whether it is done |

## .what you need from infra, before anything

four facts. ask for all four at once; a missed one costs a round trip:

| fact | why | example shape |
|---|---|---|
| the **exid** (its Name tag) | `wake` finds the box BY TAG, never by instance id | `grove-<org>-v<date>` |
| the **account id** | `wake` asserts the active credentials point there | a 12-digit id |
| the **env** | this repo's word for the account family | `camp` |
| the **nat exid**, if it sits behind one | a private box reaches ssm only through its egress | `camp-nat` |

⚠️ ask **which users the image creates, and which of them holds sudo.** this changed
between images and it is the single fact that decides whether a convergence run can work
at all. see `.the two seats` below.

## .1. register it

```sh
rhx git.grove.set <name> --exid <tag> --env camp --account <id> --nat <nat-exid>
```

a cloud grove is addressable by its **exid alone** — `wake` derives the address by tag, so
no `--at` and no `--alias` are needed.

⚠️ **`name` is OURS; `exid` is INFRA'S.** the name is a local json record that survives
anything; the exid addresses a box in their account and dies with it. the registry's whole
job is to hold the mapping (`term=exid`). give them the same value when you can — it
removes one more thing to get wrong.

| flag | when you need it |
|---|---|
| `--exid` | always, for a cloud grove |
| `--env` `--account` | always — the account is what `wake` asserts against |
| `--nat` | when the box sits behind a nat |
| `--at user@host:port` | when you must pin a **user** — see the two seats |
| `--alias` | when ssh config ALREADY carries the Host block. then we must not write one; ours would shadow theirs |

## ⚠️ .2. the two seats — this is the part that surprises

a modern grove image ships **two** login users, and they are not interchangeable:

| user | sudo | what it is for |
|---|---|---|
| `ground` | **yes**, `(ALL) NOPASSWD: ALL` | converge the box — every write to `/etc`, every apt install, every systemd unit |
| `camper` | **no**, deliberately | run the agent, its ducts, its trees |

`sshd_config.d/99-grove.conf` carries `AllowUsers ground camper` and
`PasswordAuthentication no`. camper's sudo-lessness is **the design**, not a defect: a
compromised agent must not be able to install a daemon, edit `/etc`, or persist across a
reboot (`ahbode/infrastructure` → `rule.forbid.camper-sudo.md`).

> ⇒ a `grove.provision` run from **camper** closes almost none of the tree. measured on
> 2026-08-10: it closed 6 of 78 claims, and every claim it missed was a system write.

### the trap in how that failure reads

a bundle that cannot write `/etc` reports **"the config is absent"** — which is exactly
what a bundle reports when the config is genuinely absent. so a wrong-seat run and an
un-converged box are **indistinguishable in the plan**. the one question that separates
them:

```sh
rhx git.grove.send <grove> --reply --play prove.ground-seat-converges
```

it exits 0 only if the seat holds all four powers a convergence needs: identity,
passwordless root, apt, and a live systemd.

### register a second seat on the same box

one box, two seats, two registry entries — the exid is the same for both:

```sh
# the work seat (agent, ducts, trees) — address by exid, wake writes the alias
rhx git.grove.set <name>        --exid <tag> --env camp --account <id> --nat <nat>

# the convergence seat — --at pins the user, so its Host block says `User ground`
rhx git.grove.set <name>.ground --at ground@localhost:36901 \
  --exid <tag> --env camp --account <id> --nat <nat>
```

⚠️ the `.ground` seat rides the **same tunnel**, so wake the box once and both work.

## .3. trust it, once

```sh
rhx git.grove.wake <name>
rhx git.grove.trust.gen --grove <name> --mode apply --trust tofu
```

⚠️ **`--trust tofu` is right here and ONLY here** — a NEW grove, a port that has never
answered, so there is no prior key to be wrong about. when a port that DID answer offers a
different key, tofu blind-accepts it; reach for `--on-changed replace` instead, which verifies
the scanned key against the box's own boot record over ssm
(`howto.adopt-a-replacement-grove.md`, `.the trust ladder`).

`wake` is idempotent and free — reach for it freely
(`rule.require.wake-the-grove-freely`). it resumes the nat, resumes the box, awaits the
ssm gate, binds the tunnel, and writes the ssh alias.

## .4. converge it, from the GROUND seat

```sh
rhx git.grove.push <name>.ground --from . \
  --into 'git/more/dev-env-setup' --mode apply

rhx git.grove.send <name>.ground --bare --why 'no tmux yet' \
  --detach --log '$HOME/grove.provision.1.log' \
  --what 'bash $HOME/git/more/dev-env-setup/src/grove.provision._.sh --mode apply'
```

### .what `--from .` carries that `--from src/` does not

`src/` is not the whole of what the bundle tree reads. five paths sit at the repo
**root**, beside `src/`:

| path | read by | bites on a grove? |
|---|---|---|
| `package.json` | `5.1.node` — the pnpm pin (`packageManager`) | **yes** |
| `.nvmrc` | `5.1.node` — the node pin | **yes** |
| `.agent/` | `5.13.reach` — it calls `rhx aws.reach.set`, a `repo=.this` skill | **yes** |
| `codium/sync.settings.yml` | `6.2.codium` | no — declines on cloud |
| `assets/kitty-icon.png` | `4.3.2.emulator` | no — but NOT by a decline |

⚠️ **`.agent/` is the one a grep will not find.** the first two are read through a
path expression (`$(dirname "$GROVE_SRC")/package.json`), so `grep` names them.
the third is a **skill invocation** — the phase says `rhx aws.reach.set` and the
dir that answer lives in appears in no argument, no import, and no declaration
(`gotcha.a-tool-found-by-path-answers-only-a-human`).

`git.grove.push` skips `.git`, `node_modules`, `.log`, `.temp`, and `.agent/.cache` on BOTH
carriers and prints that list on every run, so `--from .` carries the repo in one push.

.refs = howto.add-a-new-grove.demo=push-omitted-root-manifests, m1, m2, m3, m4

three details, each earned:

- **push the WORKTREE, not a clone.** a clone from main can only run what is merged, so it
  cannot prove an unmerged branch. push is also the only path onto a box with no github
  credential yet.
- **`--into` takes a REMOTE-HOME-RELATIVE path.** a `~` at the front expands on YOUR
  machine, and the grove's user is its own — and that user changes between images.
- **`--detach`.** a full apply outruns an ssh connection, and a grove can sleep mid-run. a
  detached job owns its own session.

### then converge camper's home too

the bundle tree has **no target-user axis yet** (it is 🟡 in the handoff). so a run from
`ground` converges the system plus **ground's** home; camper's home is still bare. until
that axis lands, run it twice:

```sh
rhx git.grove.push <name> --from . --into 'git/more/dev-env-setup' --mode apply
rhx git.grove.send <name> --detach --log '$HOME/grove.provision.1.log' \
  --what 'bash $HOME/git/more/dev-env-setup/src/grove.provision._.sh --mode apply'
```

⚠️ run **ground first**. camper's home bundles want packages the system half installs, so
the reverse order produces claims that are true only because of the order.

⚠️ **two seats means two applies, and that is NOT a second apply.** each seat converges its own
`$HOME` and no other, so each of these is the FIRST and only apply for its seat. what the bar
forbids is one seat that needs its apply run twice — that is a sequence defect, and its fix
belongs in the bundle that ran too early (`rule.require.one-command-provision`).

## .5. prove it

```sh
rhx git.grove.ready.verify <name>          # is the BOX ready?
rhx git.grove.provision test <name>        # and does a tree on it run green?
```

the first is five rungs; it halts at the first that does not hold and names its fix. exit 0
is the answer to "is this box ready" — read `howto.grove-ready-test.md` for how to read each
halt.

⚠️ the second is a separate command on purpose. the ladder's subject stops at the machine;
the tree and its suite belong to the command that can ESTABLISH them rather than merely
report them absent.

## ⚠️ .the transport rule that governs every step above

`git.grove.send --what '<cmd>'` rides the duct, which writes the command into a tmux pane
and returns. the pane keeps the answer; **you get the SEND's exit code**, which is 0
whenever the text landed.

> a **drive** may ride the duct. a **verify** may not.

so every read above passes `--reply`, which returns the command's own stdout and exit code.
the full measurement is in `gotcha.the-duct-returns-the-send-not-the-answer.md` — it cost
three false ✔ on a box that held no checkout at all.

## .what a fresh box does NOT have

a new box is a fresh disk. none of this carries over, and none of it is the upgrade's job:

| absent | how it arrives |
|---|---|
| every clone under `~/git` | `5.10.repos`, or a hand clone |
| the keyrack's `os.secure` entries | re-place by hand — that vault is a REPLICA on the disk |
| ssh host keys | `trust.gen --on-changed replace` — the VERIFIED rung, never tofu on a CHANGED key |
| containers + volumes (a testdb) | the suite recreates it |

⚠️ the rack's **`aws.params`** entries DO survive — they are central. `keyrack list` names
the vault per entry, and that column is the whole answer.

## .see also

- `howto.add-a-new-grove.demo=push-omitted-root-manifests` — the dated measurements behind
  the `--from .` requirement above
- `howto.grove-ready-test.md` — the ladder that answers "is it done"
- `howto.adopt-a-replacement-grove.md` — when the box replaced one you already had
- `howto.bootstrap-a-grove-from-scratch.md` — every trap in the first-contact window
- `ahbode/infrastructure` → `rule.forbid.camper-sudo.md` — why the two seats exist,
  and the userdata that mints them at first boot
- `gotcha.the-duct-returns-the-send-not-the-answer.md` — the transport rule
- `term=exid._.choice._.md` — why the name and the exid are a pair

# rule.require.install-via-procedures

## .what

when a human needs something installed or configured, hand them **the repo's entrypoint** —
never a one-off command, and never a `source <file> && <function>` pair.

```bash
rhx grove.provision --what <slug> --mode apply   # or bare `grove.provision`, from a shell
```

## .why

- **reproducible** — the repo is the record, so the next machine converges alike
- **idempotent** — a re-run is how a machine catches up
- **verified** — the bundle's `*.verify` phases prove the result (`rule.require.upgrade-entries-verify-themselves`)
- **discoverable** — `--mode plan` shows it first
- **one source of truth** — a one-off is a second, unrecorded way to change a box

## .examples

### 👍 good

```bash
rhx grove.provision --what 5.2.rust --mode apply
```

### 👎 bad — a raw one-off

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
```

### 👎 also bad — `source` + call, which THIS rule forbids

```bash
source ~/git/more/dev-env-setup/src/install_env.pt5.devtools.sh
install_rust
```

📜 that last form was this brief's "good" example until 2026-07-31, and its file was gone. an
example is read more often than the prose, so one that contradicts the `.what` teaches the
opposite with the rule's authority.

## 🛑 .on a GROVE, one command: `boot --what`

```bash
rhx git.grove.provision boot <grove> --what <slug> --mode apply   # drop --what: whole tree
```

it owns the reach, the push, and the ground-then-camper order. never hand a human its
internals (`wake`, `push`, `send … grove.provision._.sh`) as a list.

📜 2026-11-20: a clone found no `--what`, and handed the human six raw steps against a live
box. ⇒ **a skill short one flag is a skill to EXTEND, never a procedure to re-type.** a read
of a skill's internals for steps is the cue (`rule.forbid.adhoc-shell`).

## .how to find the slug

the bundle tree IS the inventory, so the slug is a path:

```sh
rhx grove.provision --mode plan   # every slug, at every depth
```

`src/grove.provision/5.devtools/5.2.rust/` → `--what 5.2.rust`.

## .exception

a one-off command is allowed only to unblock immediately, while the bundle is being written.
the bundle must follow — else the box holds a change the repo cannot reproduce
(`rule.require.repo-as-source-of-truth`).

## .note

`install` in the filename is a superseded verb, kept since the rule spans every one-off.

## .enforcement

- a one-off command handed to a human where a bundle exists = **blocker**
- a `source <file> && <function>` instruction = **blocker** (it is a one-off in disguise)
- a change applied to a box with no bundle to reproduce it = **blocker**
- a push + send sequence handed to a human to apply a bundle on a grove = **blocker** —
  `git.grove.provision boot <grove> --what <slug>` is the one command; extend it if it falls short

## .see also

- `rule.require.grove-provision-as-the-only-entrypoint` — there is one door
- `rule.require.every-function-has-a-driver` — and everything is reached through it
- `rule.require.repo-as-source-of-truth` — why an unrecorded change is the defect

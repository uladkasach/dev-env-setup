# rule.require.install-via-procedures

## .what

when a human needs something installed or configured, hand them **the repo's entrypoint** —
never a one-off command, and never a `source <file> && <function>` pair.

```bash
rhx grove.provision --what <slug> --mode apply
```

or, from a shell that has the aliases:

```bash
grove.provision --what <slug> --mode apply
```

## .why

- **reproducible** — the next machine gets the same thing, because the repo is the record
- **idempotent** — safe to re-run; a re-run is how the machine catches up
- **verified** — the bundle's `*.verify` phases prove the result, which a bare command never
  does (`rule.require.upgrade-entries-verify-themselves`)
- **discoverable** — `--mode plan` shows what would happen before it happens
- **one source of truth** — a one-off command is a second, unrecorded way to change a box

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

## ⚠️ .why that last example is here — this rule broke its own rule

📜 until 2026-07-31 the `source` + call form above was this brief's **"good" example**. it was
wrong twice over: the file it named had been deleted, so the command could not run — and
`source <file> && <function>` IS a one-off command anyway. it is unrecorded, it skips the
verify, it depends on a file layout free to change, and it converges no state. this brief
forbade one-off commands in its `.what` and modeled one in its `.examples`.

> **a rule's examples are read far more often than its prose.** an example that contradicts
> the `.what` does not merely fail to help; it teaches the opposite, with the rule's own
> authority behind it.

## .how to find the slug

the bundle tree IS the inventory, so the slug is a path:

```sh
rhx grove.provision --mode plan   # every slug, at every depth
```

`src/grove.provision/5.devtools/5.2.rust/` → `--what 5.2.rust`.

## .exception

a one-off command is allowed only to unblock immediately, while the bundle is being written.
it must be followed by the bundle — otherwise the box now holds a change the repo cannot
reproduce, which is `rule.require.repo-as-source-of-truth`'s whole concern.

## .note on this brief's own name

`install` is a **superseded** verb here (`term=grove.provision._.choice._.md`). the filename
stands because this rule is broader than `grove.provision` — it forbids one-off commands
generally.

## .enforcement

- a one-off command handed to a human where a bundle exists = **blocker**
- a `source <file> && <function>` instruction = **blocker** (it is a one-off in disguise)
- a change applied to a box with no bundle to reproduce it = **blocker**

## .see also

- `rule.require.grove-provision-as-the-only-entrypoint` — there is one door
- `rule.require.every-function-has-a-driver` — and everything is reached through it
- `rule.require.repo-as-source-of-truth` — why an unrecorded change is the defect

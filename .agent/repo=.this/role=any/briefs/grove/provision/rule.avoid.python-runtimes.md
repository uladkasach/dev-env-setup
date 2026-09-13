# rule.avoid.python-runtimes

## 🛑 .the rule, in one line

# **THIS REPO OWNS NO PYTHON RUNTIME. NO pipx, NO venv, NO pip, NO PYTHON-PACKAGED TOOL.**

when a bundle needs a tool, reach for a **pinned static binary** — a go or rust build that runs
with no interpreter at all. a python route is taken only where no static binary exists, and then
the reason is written into the bundle's `_.sh`.

📜 settled by the human 2026-09-11, mid-decision on `5.17.yq`: *"avoid pipx or python maximally"*.

## .why — a runtime is a SECOND dependency tree, and this repo would own it forever

a static binary is **one artifact, one pin, one digest**. that is the whole surface.

a python-packaged tool is not a tool; it is a tool plus everything under it:

| what arrives with it | what this repo would then own |
|---|---|
| an interpreter | which python — the distro's, or one we install? its own upgrade path |
| a venv | where it lives, who creates it, what happens when `$HOME` moves |
| a package installer | pip or pipx, its own version, its own cache, its own lockfile |
| transitive wheels | some of which build from source, so a compiler becomes a dependency too |
| a PATH shim | a fourth fact to converge, and a fourth to verify |

⇒ **a bundle's job is to converge ONE declared fact.** a python route makes it converge five,
and four of them are invisible in the bundle that asked for the first.

### the sharper half — a runtime's version is a fact the DISTRO already holds

the fleet spans two distros on purpose (jammy on a grove, noble on a laptop), and they ship
different pythons. so a python-packaged tool that installs cleanly on one box class is free to
install differently, or not at all, on the other — which is the exact shape
`rule.require.identical-bundle-composition` forbids.

a static binary has no such axis. the bytes are identical on every box, by construction.

## ✔ .the measured precedent — `5.6.aws` already took this route, before the rule existed

debian ships `awscli` **v1, a python package**. `5.6.aws` refuses it and fetches the v2 bundled
installer instead, gpg-verified against aws's own signer key:

```
#   - neither goes through `pkg_install` — debian ships awscli v1, a …
```

and its state reader carries the cost of a runtime inline, as a **bound** it had to add:

```
#   - the read is BOUNDED — the v2 cli unpacks a bundled python runtime
#     before its first byte, and this runs on every plan
```

⇒ a python runtime is slow enough at cold start that a `--version` read needed a `timeout`.
**that is a measured cost, paid on every plan, for a runtime we did not even install.**

## .the state of the tree, measured 2026-09-11

```sh
rhx grepsafe --pattern 'pipx|python3 -m pip|virtualenv|venv|pip install' --path src --glob '*.sh'
```

→ **zero** matches in any phase file. every hit was an unrelated `devenv` substring.

⇒ so this rule does not ask for a migration. it records a property the tree already has, and
keeps it.

## ⚠️ .what is NOT forbidden

the target is a runtime **this repo installs and maintains**. three cases are untouched:

| case | why it is fine |
|---|---|
| a **vendor-bundled** runtime — the aws v2 cli unpacks its own python | the vendor pins it, ships it, and upgrades it. we own one artifact and one pin |
| the **distro's** python, already on the box | apt itself needs it. we do not install it, upgrade it, or install INTO it |
| a python file a human runs by hand | not a bundle, not converged, not this rule's subject |

**the line that parts them: would a bump of the interpreter become THIS repo's problem?**
no → fine. yes → this rule fires.

## .the test, before you write the install line

> **1. is there a static binary for this — a go or rust build, one file, no interpreter?**
> **2. if yes, take it. if no, say so in the bundle's `_.sh`, in one line.**

⚠️ *"pipx reaches both box classes"* is **not** an argument for pipx. it is true, and it is the
trap: pipx buys the reach with a runtime, a venv, and an installer. the static binary buys the
same reach with none of them.

## .the worked case — `5.17.yq`

three routes were on the table, and the sort is the rule at work:

| route | reaches jammy? | reaches noble? | runtime owned |
|---|---|---|---|
| `apt install yq` | ✋ **no candidate at all** | ✔ 3.1.0-3 | — (and it is the python wrapper) |
| `pipx install yq` | ✔ | ✔ | **an interpreter, a venv, an installer** |
| the pinned go binary | ✔ | ✔ | **none** |

⇒ apt fails `rule.require.identical-bundle-composition` outright. pipx passes that bar and fails
this one. **the go build passes both**, which is why it is what `5.17.yq` installs.

## .enforcement

- a **python runtime, venv, or package installer** installed by a bundle, where a static binary
  exists = **blocker** — graded up from this rule's default, because the harm is nameable and
  permanent: a second dependency tree the repo owns on every box, forever
- a **python-packaged tool** taken where no static binary exists, with no reason in the bundle's
  `_.sh` = **nitpick**; record the reason and it is settled
- a `pip install` or `pipx install` on the provision path = **blocker**
- a reach for pipx **justified by its reach across box classes**, with no check for a static
  binary first = **nitpick** (the trap above)
- a **vendor-bundled** runtime cited as a violation of this rule = **false positive**; read
  `.what is NOT forbidden`

## .see also

- `rule.require.identical-bundle-composition` — the bar apt fails and pipx passes
- `rule.require.verify-binary-downloads` — what a static binary owes instead: a pin and a digest
- `rule.require.bundles-own-their-dependencies` — why a bundle's dependency surface is its own
- `src/grove.provision/5.devtools/5.17.yq/_.sh` — the worked case, argued inline
- `src/grove.provision/5.devtools/5.6.aws/_.sh` — the precedent, and the `timeout` a runtime cost

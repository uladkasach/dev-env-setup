# howto: adopt a replacement grove

## .what

infra replaced the box. a NEW instance is up, the OLD one is gone, and your registry still
names the dead one. this is how you point the forest at the new box — and what to check
before you run anything against it.

## ⚠️ .why this needs a brief at all

**the registry entry outlives the box it names.** `git grove list` will happily show
`grove-1` long after that instance is destroyed, because the entry is a local json record,
not a live read.

so the dangerous moment is the one that feels routine:

```sh
rhx git.grove.wake grove-1      # ← resolves an exid that no longer exists
rhx grove.provision …            # ← against WHICH box?
```

measured 2026-08-10: a new box came up and the mechanic reached straight for
`git.grove.wake grove-1`, the name every prior session used. a human stopped it with
*"its clearly NOT grove-1"*.

> a grove NAME is a habit. a grove EXID is an address. when infra rebuilds, the habit
> survives and the address does not.

## .the check that is free

```sh
rhx git.grove.get <name>
```

read the `exid`, `account`, and `env`. if the exid does not match the instance infra just
handed you, **the entry is stale and every command through it targets a ghost**.

```
{ "name": "grove-1", "exid": "grove-1",  … }     ← names the OLD box
   infra says: grove-ahbode-v20260810             ← the box that exists
```

⚠️ `wake` resolves the box **by exid tag**, so a stale entry does not fail loudly with "no
such host" — it fails at the aws lookup, or worse, finds some *other* instance that still
carries the tag.

## 🛑 .the MIRROR case — the entry is CORRECT and the box is NEW

the opposite of a ghost entry happens too, and every check on this page **passes** while it
does:

> infra rebuilds the box and **keeps the exid**, so the ssh alias remains usable. the
> registry is right. `wake` is right. and the first real command still refuses.

⇒ **`wake` converges the ALIAS and does not converge the TRUST.** those are two records about
one box, and only one of them is a fact about the endpoint's identity. so the free check above
answers *"does the entry name the right box?"* — a question that was never the one at fault.

.refs = howto.adopt-a-replacement-grove.demo=stale-registry-and-trust-mismatches, m1

### .the trust ladder — reach for the HIGHEST rung the case allows

| the case | the rung |
|---|---|
| FIRST contact — no prior key for this port | `--mode apply --trust tofu` |
| the key CHANGED, and the box can still be read | `--mode apply --on-changed replace` ← **verified** |
| the key changed and NO boot record can be read | `--mode apply --on-changed replace --trust tofu` |

```sh
# the verified rung — this is the one to reach for on a rebuild
rhx git.grove.trust.gen --grove <name> --mode apply --on-changed replace
```

it does **not** accept the key because you asked. it reads the box's OWN `/etc/ssh` keys over
ssm and writes only when the scanned key matches what the box attests:

```
├─ attest:   ssm (the box's own /etc/ssh keys)
├─ fingerprints
│  ├─ SHA256:…  ✔ matches the boot record
│  ├─ SHA256:…  ✔ matches the boot record
├─ replaced: stale entry dropped
└─ 🌴 trusted — re-trusted for the new box
```

⇒ that `✔ matches the boot record` line **is** the proof it is your rebuild and not a
man-in-the-middle. tofu proves no such thing — it accepts whatever answered the port.

🛑 **do NOT reach for `--trust tofu` on a CHANGED key.** every other brief in this repo shows
tofu, and each shows it for FIRST contact, where there is no prior key to be wrong about. on a
changed key the same flag blind-accepts the new one and discards the only signal that would
have caught a real substitution (`rule.require.security-paramount`,
`rule.prefer.prevent-over-correct`).

## .the moves

### 1. register the new grove

a cloud grove is addressable by its exid alone — `wake` derives the address by tag, so no
`--at` or `--alias` is needed:

```sh
rhx git.grove.set <name> --exid <instance-tag> --env camp --account <acct> --nat <nat-exid>
```

| flag | what it is | needed? |
|---|---|---|
| `--exid` | the instance's name tag — how `wake` finds it | yes, for a cloud grove |
| `--env` | this repo's word for the account family (`camp`) | yes |
| `--account` | the aws account id | yes — `wake` asserts it matches |
| `--nat` | the nat instance's exid, woken alongside | yes for a grove behind a nat |
| `--at` / `--alias` | for a grove you reach directly, or whose ssh Host infra already wrote | no, when `--exid` is given |

⚠️ **`--alias` vs `--at` decides who owns the ssh Host block.** `--at` means we write it;
`--alias` means ssh config already carries it (keys, ProxyCommand, SSM tunnel) and we must
not. if infra or declastruct wrote that config, use `--alias` — a Host block we write on top
will shadow theirs.

### 2. prune the dead entry

```sh
rhx git.grove.del <old-name>
```

do this **after** the new one registers, so the forest is never empty. a `del` unregisters
the record; it touches no box.

### 3. verify before you converge

```sh
rhx git.grove.list                 # the forest names the new box, and only it
rhx git.grove.get <name>           # exid matches what infra handed you
rhx git.grove.wake <name>          # tunnel comes up, account assertion passes
```

`wake` prints `account: <id> ✔ matches the registry` — that line is the proof the entry and
the box agree.

## .then, and only then, converge it

a fresh box holds none of this repo's config. bootstrap first, then upgrade:

```sh
rhx grove.provision --mode plan     # a survey: every verify runs, no upsert does
rhx grove.provision --mode apply
```

⚠️ **plan first is not ceremony on a new box — it is the inventory.** `--mode plan`
short-circuits every `*.upsert` and still runs every `*.verify`, so it tells you exactly
what a fresh box lacks before anything writes. read it for what is ABSENT, not only for what
is red (`rule.require.every-function-has-a-driver`).

## .what does NOT carry over

a replacement box is a fresh disk. these are gone, and are not the upgrade's job:

| gone | how it comes back |
|---|---|
| every clone under `~/git` | re-clone; `5.10.repos` |
| the keyrack's `os.secure` entries | re-place by hand — a REPLICA vault lives on the disk |
| ssh host keys | `trust.gen --on-changed replace` — the VERIFIED rung, never tofu (see the mirror case above) |
| containers + volumes (a testdb) | the suite recreates it |
| SSM registration | infra's side; a new instance registers itself |

⚠️ the rack's **`aws.params`** entries survive — they are central. **`os.secure`** entries do
not. `keyrack list` names the vault per entry, and that column is the whole answer.

## .the audit, when the OLD box is still alive

if the old box has not been destroyed yet, run the pre-loss audit against it before infra
takes it:

```sh
rhx git.grove.send <old> --play verify.grove-safe-to-wipe
```

it asserts no repo holds uncommitted or unpushed work, no stash exists, and no credential
lives only on that disk. exit 3 = there is work to rescue.

⚠️ **its AT RISK verdict is correct and not yet actionable.** "dirty" there means *"differs
from the grove's git HEAD"*, which is exactly what a pushed copy is supposed to be — the
audit answers *"is any file unique here?"* with *"some file is dirty here"*.

.refs = howto.adopt-a-replacement-grove.demo=stale-registry-and-trust-mismatches, m2

only a content compare separates the two claims — ask the old grove, through its duct, to
emit `sha256  path` for every dirty path in that checkout, and diff those hashes against
your own copies. a hash that agrees is a push artifact, safe to lose; a hash that differs is
the work to rescue.

## .see also

- `howto.adopt-a-replacement-grove.demo=stale-registry-and-trust-mismatches` — the dated
  measurements behind the mirror case and the audit above
- `howto.provision-a-grove.md` — the fuller provision path
- `howto.bootstrap-a-grove-from-scratch.md` — how a bare box first reaches this repo
- `rule.require.trust-but-verify` — the general form of the stale-entry trap
- `ahbode/infrastructure` → `rule.forbid.camper-sudo.md` — what a replacement box is
  expected to be born with, and the userdata that mints it

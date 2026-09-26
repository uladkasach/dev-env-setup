# gotcha: `op` is a keyrack VAULT BACKEND, and its absence failhides as a locked vault

## .what

`5.19.op` puts `op` — the 1password cli — on every box this repo converges, with no opt-in
and no decline. this file carries the measurements behind that bundle, so its header can stay
a `.what` + `.why` outline (`rule.forbid.narratives`).

three claims, each measured against rhachet 1.47.6 on 2026-09-25.

## .m1 — `1password` is one of keyrack's EIGHT vaults, not a convenience

it is first-class beside `aws.params` and `os.secure`:

| where it appears | what it says |
|---|---|
| `daoKeyrackHostManifest/schema.js` | `1password` is in the host manifest's own vault enum |
| `rhx keyrack --vault` help text | names it as an accepted value |
| `KeyrackVaultReachPolicy` | grades it `ADDRESSED` |
| `inferKeyGrade` | grades its keys `encrypted` |
| the mech table | it serves `PERMANENT_VIA_REPLICA`, `PERMANENT_VIA_REFERENCE`, `EPHEMERAL_VIA_GITHUB_APP` |
| `vaultAdapter1Password` | reaches the binary by **bare name** — `execFile('op', args)` |
| `isOpCliInstalled` | asks `which op` |

⇒ so `op` is not a tool a human might want. it is the backend of a vault this repo's whole
credential story rests on (`rule.require.bundles-own-their-dependencies`).

## .m2 — an absent `op` FAILHIDES as a locked vault

`vaultAdapter1Password.isUnlocked` opens with a fast path: if `op` is absent it returns
**false**, with no throw and no message.

⇒ a box with no `op` is **indistinguishable** from a box whose vault is merely locked, and
every reader of that verdict prints *"unlock it"* at a human who holds no tool to unlock with
(`rule.forbid.failhide`).

⚠️ its `set` path fails LOUD instead, and prints a runbook of `curl … | sudo gpg --dearmor`
hand-steps — the very shape `rule.require.install-via-procedures` forbids a human be handed.

⇒ both halves are answered by one fact: the tool is simply present.

## .m3 — the decline that hid it read TRUE and was FALSE

`6.5.onepassword` declined on every cloud box with:

> *"op without that app is inert"*

that is true of **one** auth path and no other. the adapter's own comment names the second —
*"biometric or service account token"* — and `op account add` is a third. a grove holds no
biometric and every service account token in the world, so the decline refused a headless box
the one auth path built for headless boxes.

⇒ `term=decline._.choice.reason` — a wrong REASON inside a decline that reads correct is the
hardest kind to catch, and this one hid for a month.

## .why the bundle sits in `5.devtools` and not `6.apps`

`6.apps/_.sh` states the two properties that make it the wrong home:

- *"the apps a human CLICKS, not the ones a robot calls"*
- *"a client a human clicks is a PREFERENCE, where every other bundle is a FACT"*

`op` is a binary keyrack calls, on a box with no screen. it is a fact. ⇒ it moved to the
section that holds facts, and the vault app stayed.

## .why its dispatch position is load-bear TWICE

`5.devtools/_.sh` runs it **second**, right after `5.17.yq`:

1. `1password` is one of keyrack's vaults and its adapter reaches the binary by bare name, so
   `op` must be down before `5.12.rack` — eight lines below — or the rack's own verify reads a
   vault whose backend is absent
2. it OWNS the 1password apt key and repo that `6.5.onepassword` consumes. `5.devtools` runs
   before `6.apps` and this bundle carries no opt-in, so the anchor is always placed before
   the vault asks for it

its own needs are `curl` and `gnupg`, both from `2.1.toolkit`, a whole section earlier.

## .why ONE writer owns the apt anchor

two writers on one apt trust anchor is the drift hazard
`rule.forbid.two-writers-on-one-artifact` names: a pin bumped in one file and not the other
flips the box by dispatch order. ⇒ the same shape `2.1.toolkit` already holds for `gnupg`.

`6.5.onepassword` now READS the anchor and writes neither half. a `--what 6.5.onepassword` run
against that bundle alone finds no anchor and says who owns it, rather than let apt fail with
*"the repository is not signed"* — which reads as a network fault and names no owner.

## .why the slug is `op` and not `onepassword.cli`

`op` is the name every caller reaches by — `src/backup_env.sh` and `src/util.yubikey.ssh.sh`
both call it, and the verify asserts that NAME resolves. `2.1.toolkit` sets the precedent: it
verifies `rg`, never `ripgrep` (`rule.require.bundle-names-name-their-subject`).

⚠️ `op` reads as "operation" to a reader who arrives from `domain.operations`. the bundle's
`.what` is the discriminator, and it is the first line of the file.

## .why the key pin is a WIRE READ, the weakest tier this repo accepts

1password's own install docs give `curl … | gpg` and state no key id, so no vendor-published
value exists to compare a read against (`term=pin`, `rule.require.verify-binary-downloads`).

it still beats an unpinned fetch: a key that changes under us reddens at the bundle rather
than land silently in apt's trust set.

⚠️ this key carries ONE primary and NO subkey, unlike vscodium's or docker's — so a pin can
never land on the wrong half here.

## .the proof — 2026-09-25, `grove-ahbode-v20260901`

| seat | apply 1 | apply 2 |
|---|---|---|
| `ground` | key verified against its pin ✔ · repo declared ✔ · `1password-cli 2.39.0` installed | `op ✔ (already installed)` — no apt call |
| camper | `op ✔ (already installed)` — short-circuits before it reaches for root | same |

and the claim that motivated the bundle, probed from a **non-interactive** shell
(`gotcha.a-tool-found-by-path-answers-only-a-human`):

```sh
rhx git.grove.send grove-ahbode-v20260901 --bare \
  --why 'this probe needs a NON-INTERACTIVE shell' --what 'command -v op'
# /usr/bin/op
```

⇒ `/usr/bin/op` is on every shell's PATH, interactive or not, so `execFile('op', args)`
resolves it. a PATH placed by an rc file would have answered a human and vanished for keyrack.

⚠️ on a **laptop** the upsert declines for want of root, since `pkg_can_sudo` demands
`local@unix` AND a tty. a human converges it from a terminal:

```sh
sudo -v && rhx grove.provision --what 5.19.op --mode apply
```

## .see also

- `gotcha.6-5-onepassword.demo=never-installed-by-any-run.md` — the app half's own record
- `rule.forbid.two-writers-on-one-artifact` — why one bundle owns the anchor
- `rule.forbid.failhide` — m2's shape
- `term=decline._.choice.reason.md` — m3's shape
- `gotcha.a-tool-found-by-path-answers-only-a-human` — why the probe is `--bare`

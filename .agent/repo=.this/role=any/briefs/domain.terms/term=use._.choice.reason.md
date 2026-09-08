# domain.term.choice.reason: use

## .etymology

latin *uti* "to employ, to make use of" (participle *usus*). the everyday english sense is exactly
the one this repo wants: *employ X for the work at hand*.

the virtue of the word is that it names the **human's motive**, not the mechanism. the human thinks
"i want to use the prep account now" — they do not think "i want to export an env var that a keyrack
unlock resolved". that is why one verb spans mechanisms as unlike as:

| declaration | mechanism beneath |
|-------------|-------------------|
| `use.ehmpathy.camp` | `rhx keyrack unlock` + `export AWS_PROFILE` |
| `use.ahbode.fastly` | `op get item` + `export FASTLY_API_KEY` |
| `use.mtu.1400` | `sudo ifconfig wlp113s0 mtu 1400` |
| `use.keymap.altswap` | a keyd remap function |
| `use.terraform.caching` | `mkdir` + `export TF_PLUGIN_CACHE_DIR` |

a verb named for a mechanism would have fractured across that table. one named for the motive did
not — and has already survived a mechanism swap: `_use_aws_profile` moved from `op` to
`rhx keyrack` with no rename at any of its 15 call sites.

## .the sense, stated precisely

**select X as the active context for what follows.** two properties fix it:

- **selects, does not persist** — the effect dies with the shell (env exports) or with the next
  contrary invocation (mtu, keymap). no durable store is written
- **scope varies, intent does not** — some members scope to the shell, some to the machine. the
  human's ask is identical in both: "make this the one in effect now"

## .rejected synonyms

### `assume` — the dangerous one

aws's **own** word for credentials — and that is precisely why it is forbidden. aws fixed `assume`
to a specific, different act: `sts:AssumeRole`. `_use_aws_profile` does **not** assume a role; it
unlocks a keyrack key and exports `AWS_PROFILE`, which points at a profile that may or may not
itself assume a role downstream.

to name our operation `assume.ehmpathy.camp` would overload a term the domain already spent on a
neighbouring concept — the exact hazard of `rule.forbid.term.addition.ambiguous`. verified unspent
elsewhere in this repo as a shell verb, so the collision would have been ours to cause.

### `set` — reserved, and a false promise

`set` is fixed by the ehmpathy verb taxonomy (`rule.require.get-set-gen-verbs`) to a **mutation that
persists** — an upsert. these operations persist no state. `set.ahbode.prep` would promise durable
state it does not deliver, and would read as a peer of `setCustomerPhone`, which it is not.

### `export` — names the mechanism, and is often false

the bash builtin. two failures: it describes *how* rather than *why*, and it is untrue for
`use.mtu.1400` (an `ifconfig` call) and `use.keymap.altswap` (a keyd remap). the table above is the
counter-evidence.

### `switch` — implies a "from" and an exclusivity, neither of which hold

`switch` presumes a prior active value to move away from; `use.terraform.caching` has no "from". it
also implies the new value displaces the old, but `use.ahbode.fastly` and `use.ahbode.prep` compose
freely in one shell — they activate orthogonal contexts, not competing ones.

### `activate` — a true near-synonym, no sense gained

not wrong, merely longer, and it drags venv / feature-flag connotations. when two words carry the
same sense, the shorter and more common wins.

### `with` — reserved

`with*` is the sanctioned prefix for higher-order wrappers (`withLogTrail`). unavailable.

## .evidence

**distribution scan** — `^(function use\.|alias use\.)` across `src/bash_aliases.sh` returns ~30
declarations, listed in the `.refs` of the say file. every one reads as "make X active now". a
single sense across 30 declarations, over 5 unlike mechanisms, is what earns the verb its place.

**cross-check on the family's boundary** — the sibling words in each declaration were checked for
itemization worth and deliberately excluded:

| word | why not itemized |
|------|------------------|
| `camp`, `prep`, `prod`, `test` | env slugs of the ehmpathy keyrack manifest — imported vocab |
| `owner` | a keyrack cli flag — imported vocab |
| `profile` | aws vocabulary — imported |
| `ahbode`, `ehmpathy`, `aether` | proper nouns (orgs), not domain terms |

## .the watch-item

`use.screencast` (`src/bash_aliases.sh:116`) is the family's weakest member — it launches an app
rather than activates a context, so it stretches the sense stated above. one outlier does not
unseat a 30-member family, and it is recorded here rather than disputed.

**if a second launch-an-app member ever lands under `use.*`, that is the moment to split** — either
rehome them under a launch verb, or widen this term's `.what` on purpose rather than by drift.

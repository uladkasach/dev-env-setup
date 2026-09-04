# domain.term: entry

term.chosen   = entry
term.kind     = noun
term.synonyms.forbidden:
- slug            # the ADDRESS, not the record — see term=slug
- key             # one AXIS of the address
- value           # what the entry HOLDS, not the entry itself
- record          # a synonym with no advantage; `entry` is already in use here
- pointer         # drifted into on 2026-08-10 for the entry's LOCAL half; say
                  # "manifest entry" or cite `KeyrackKeyHost` — see the drift note below

## .what
the stored record an address points at, as distinct from the address itself.

this repo keeps two stores of them, and the split holds in each:

| store | the address | the entry holds |
|---|---|---|
| the keyrack | a `slug` — `<org>.<env>.<KEY>` | the mechanism, the vault, the value |
| the grove registry | a grove name — `grove-ahbode-v20260901` | the seat, the port, the account, the nat |

⚠️ **every measurement below is a KEYRACK one**, because that store is where the split cost
real credentials. the registry half is evidenced in
`gotcha.a-partial-write-discards-what-it-never-read` (instance 3: one `git grove set --at`
blanked `env`, `account`, and `nat`) and in `.the entry that outlives its subject` below.

## ⚠️ .why it is a separate term from `slug`
an entry can EXIST while its slug will not resolve. measured on grove-1 2026-08-03: an entry sat
under `@all.camp.GITHUB_TOKEN` — `keyrack list` showed its mech and vault, and a `.age` file sat
on disk — yet every read of that slug answered `absent 🫧`, because the read path rejects an
`@all` org against the manifest's.

so "the entry is there" and "the slug resolves" are different claims. one word for both let
`✔ set` read as "the credential is placed", twice, at the cost of a real pat each time.

## ⚠️ .the split is FOUR-way, not two — measured 2026-08-10 on a fresh grove

the 2026-08-03 measurement found two causes behind one word. a fresh grove found two more. all
four answer the reader with the identical `absent 🫧`:

| cause | what is true | what the box needs |
|---|---|---|
| the value sits centrally AND the box may read it — but this `$HOME`'s manifest holds no entry | value ✔, grant ✔, manifest entry ✋ | the entry must be re-created — and keyrack has **no entry-only command**, so this costs a re-paste of a value that was never broken |
| the read path rejects the org sigil (`@all` vs the manifest's org) | value ✔, grant ✔, manifest entry ✔ | fix the read path; **no new secret** |
| the value is genuinely gone | value ✋ | mint a fresh secret |
| the box lacks the iam grant to reach the vault | value ✔, grant ✋ | fix the role, not the rack |

⚠️ read row 1 with the `keyrack set` section below before you act on it: "wire the manifest entry"
has **no unattended command** today, and the obvious reach for one destroys the value.

⇒ **four causes, one word, and only ONE of them wants a fresh secret.**

the 2026-08-10 chain, link by link, on `grove-ahbode-v20260810`:

- `5.4.gh` reported *"the rack holds no 'GITHUB_TOKEN' to give it"*
- `diagnose.keyrack-host-manifest` found `/home/ground/.rhachet/keyrack` **absent** — a manifest
  is per-`$HOME`, so the camper seat's manifest did the ground seat no good
- `keyrack init` minted one; the tree went 114 ✔ → 116 ✔
- the get still returned **0 bytes**, because `initKeyrack` writes `hosts: {}` — an empty index
- `diagnose.keyrack-says-absent-but-ssm-holds-it` then showed the box CAN read
  `/keyrack/infra/vault/aws.params/v1/ehmpath/_all_/camp/GITHUB_TOKEN` as its grove role

so the value stayed central and reachable throughout, while `absent` answered four separate
facts four separate times.

⚠️ the hazard this makes concrete: a reader who takes `absent` at face value reaches for
`keyrack set` — and a `set` fed a closed stdin stores an EMPTY value while it prints `✔ set`.
that replaces a live central pat with a blank, to cure a defect that was never in the value.

### `KeyrackKeyHost` is CITED here, never itemized — and `pointer` is DRIFT

the local half above is a `KeyrackKeyHost` inside the manifest's `hosts` map
(`node_modules/rhachet/dist/domain.objects/keyrack/KeyrackHostManifest.d.ts`). that is **imported
vocabulary from a dependency**, so it earns no cluster of its own — `rule.require.domain-term-itemization`
scopes the glossary to terms this repo's own dobjs/dops are built from. it is named here to keep
the mechanism legible, and it stays a citation.

⚠️ 📜 **`pointer` is a word I coined in prose on 2026-08-10, and it is drift.** it read well and
it named a real half — the local record, absent its value. but it is an undeclared synonym for a
dependency's dobj, in a file whose whole job is one word per concept. `rule.forbid.domain-term-synonyms`
says adhere or dispute, never drift. I drifted inside the glossary itself.

the canonical phrasings, all of which already work:

| say | not |
|---|---|
| the manifest entry (in this seat's `$HOME`) | the local pointer |
| the `KeyrackKeyHost` record | the pointer |
| the entry's local half | the pointer half |

"manifest entry" QUALIFIES `entry` rather than replaces it, so it is a scope, not a synonym.

**the durable lesson: a central vault does not imply a portable read.** `aws.params` makes the
VALUE survive a box's death and makes a rotation one write. it makes no claim at all about the
MANIFEST ENTRY, which every fresh `$HOME` still needs placed.

## 🛑 .a FIFTH state, and it is not a cause of `absent` — measured 2026-08-25

the four rows above are four causes behind ONE word. this state answers with the opposite word,
and is worse for it: the entry is healthy on **every axis the table measures**, and the
credential still does not work.

⇒ measured on a from-scratch grove, `@all.camp.GITHUB_TOKEN`:

| axis | reads |
|---|---|
| the value sits centrally | ✔ |
| the box may reach the vault | ✔ |
| this `$HOME` holds a manifest entry | ✔ |
| the slug resolves | ✔ |
| `get … --value \| wc -c` | **40** — exactly a classic pat |
| `get … --value \| cut -c1-8` | `ghp_0I0c` — a well-formed prefix |
| `curl -I api.github.com/user` with it | **`HTTP/2 401`** |

so `keyrack get` is **correct** and the box still cannot reach github. the fault surfaces three
components downstream as `gh: not logged in`, and a reader who follows it back arrives at a rack
with an unblemished record.

### .the boundary this draws

> **an entry's health is a claim about the BYTES. it says no word about whether those bytes are
> still honoured by the party that issued them.**

that is `declared` and `live` (`term=live`) in a place neither term had reached: the rack holds
the DECLARED credential; the ISSUER alone knows whether it is still honoured. the rack cannot
ask, so a perfect read is compatible with a dead secret.

⚠️ it also inverts the four-way table's own advice. every row there teaches *"do not reach for a
fresh secret — the value is probably fine"*: right four times out of five, and the exact wrong
move here. only the ISSUER can tell the two apart.

### .how to tell a dead pat from a malformed one, in one probe

read the **headers**, not the body — the body is `Bad credentials` in every case:

| what comes back | it means |
|---|---|
| `200`, with `x-oauth-scopes: repo, read:org` | live, and its scopes are named |
| `401`, **with** an `x-oauth-scopes:` header echoed | github parsed it and it is under-scoped |
| `401`, **with no** `x-oauth-scopes:` at all | github looked it up and found it dead — **expired or revoked** |
| a connection fault | the box's egress, not the credential |

this measurement hit the third row — the one row a body-only read cannot see.

⇒ so the fix here is a **fresh mint into the same slug**: the one remedy the four-way table
spends all its prose to steer a reader away from. the table is not wrong; its scope is the rack,
and this state lives past its edge.

## ⚠️ .and `keyrack set` cannot place a manifest entry ALONE — read from source 2026-08-10

the four-way split says cause 1 needs "no new secret". a reader may then reach for `keyrack set`
to wire the entry without a fresh value. **no such mode exists.**

- `setKeyrackKeyHost.js:47` calls `adapter.set(...)` **before** it ever touches `hostManifest.hosts`
- for `aws.params`, `vaultAdapterAwsParams.set:153` routes `PERMANENT_VIA_REPLICA` into
  `setKeyrackAwsParamReplica`, which acquires a secret and WRITES it into SSM, then roundtrip-verifies
- `keyrack set --help` carries no entry-only flag: `--key --mech --vault --env --org --exid
  --max-duration --at --prikey --json`, and every one of those is an attribute of the write

⇒ **a `set` run to "just wire the entry" overwrites the live central value.** the very hazard two
sections up, reached by a reader who took this term's own advice at face value.

📜 I made that mistake in the same session I wrote the four-way split: I recorded "cause 1 wants
no new secret", then recommended `keyrack set --vault aws.params` in the next breath. a human's
one question — *"isn't it already set in the camp account?"* — sent me to the adapter source. the
table was right; the remedy I paired with it was not.

## ✔ .MEASURED on both seats — 2026-08-10, and the answer reframes cause 1

| | camper | ground | laptop |
|---|---|---|---|
| manifest file | ✋ **none at all** | ✔ 751 bytes | ✔ |
| entries in it | — | **0** | 0 for this slug |
| `get` returns | 0 bytes | 0 bytes | `absent 🫧` |
| `gh auth status` | not logged in | not logged in | — |

⇒ **no live box holds an entry for this slug.** a human placed the entry once on grove-1
(2026-08-05); that box is gone. the SSM value survived its death **exactly as `aws.params`
promises**. the entry did not, because an entry lives in a `$HOME`, and the disk took that
`$HOME` with it.

so cause 1 is not "a fresh box was never wired". it is **an entry that DIED with its box while
its value lived on** — the split this whole term exists to name, at its sharpest.

and because `keyrack set` has no entry-only mode (above), re-creation of the entry costs a
re-paste of the pat — NOT because the value is bad, but because keyrack offers no way to point
at a value it did not just write. **that is the gap, stated exactly.**

⚠️ still unmeasured, and not to be guessed: whether `keyrack recipient set` + a shared `.age`
file is a sanctioned cross-seat path. it writes no secret, so it is the candidate to test.

## 🛑 .the entry that OUTLIVES its subject — measured 2026-09-02, the grove registry

the section above is an entry that **died** with its box while its value lived on. this is its
mirror, in the other store: an entry that **survived** a box that is gone.

```
rhx git.grove.list          → 3 groves, 6 seats
   grove-ahbode-v20260810   → :36901
   grove-ahbode-v20260811   → :36902
   grove-ahbode-v20260901   → :36903

rhx aws.ec2.get --tag 'exid=grove-*'   → found: 2
   <instance-id-1>     exid=grove-ahbode-v20260811
   <instance-id-2>     exid=grove-ahbode-v20260901
```

⇒ `grove-ahbode-v20260810` has two entries and no box.

### ⚠️ why it is worse than a stale row

a dead entry does not merely mislead a reader. **it holds a scarce resource.** a duct port is
unique per box, so the two orphaned rows own `:36901`, and the live lab grove sits at `:36902`.

the human's own record of that grove still says `:36901`. so the registry and the human
disagree, and the value they disagree on is one a dead box holds.

🛑 **the measured half and the inferred half, kept apart.** measured: the orphan, the squat, and
the mismatch. **inferred**: that the squat is what pushed the lab to `:36902`. no allocator was
observed to choose. the inference is cheap and may be wrong, and it is marked rather than
asserted.

### .the general shape

this is `gotcha.a-check-that-cries-wolf-gets-silenced`, q12 — *a record keyed on a field that
outlives its subject* — with one consequence that gotcha does not name:

> **an orphaned entry is not inert. it keeps whatever its address reserved.**

⚠️ and it is the m.14 shape too: one subject, two stores. the registry reports itself exactly;
AWS reports itself exactly; a delete that reached one of them makes the two disagree with no
signal. `aws.ec2.get` is the read that settles it, and no reader of the registry alone can.

## .refs
- `.agent/repo=.this/role=any/briefs/domain.terms/term=slug._.choice.reason.md`  # the dispute that split them
- `.agent/repo=.this/role=any/skills/git.grove.list.sh`                          # reads the registry's entries
- `.agent/repo=.this/role=any/briefs/evidence/gotcha.a-partial-write-discards-what-it-never-read.md`  # a registry entry, partly blanked
- `src/git-credential-keyrack.sh`                                                # reads the entry a slug names
- `src/grove.provision/5.devtools/5.4.gh/configure.upsert.sh`
- `.agent/repo=.this/role=any/briefs/creds/rule.require.github-token-at-all-camp.md`   # the slug every consumer reads

## .reason
see the ref-level cluster beside this choice:
- `term=entry._.choice.reason.md` — etymology, the resolved dispute, evidence

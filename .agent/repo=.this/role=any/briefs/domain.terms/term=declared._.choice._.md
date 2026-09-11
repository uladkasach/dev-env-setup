# domain.term: declared

term.chosen   = declared
term.kind     = adj
term.synonyms.forbidden:
- persistent
- static
- config
- desired
- intended
- durable

## .what
state as written in a durable declaration a machine reads at boot — `/etc/fstab`, a systemd
unit, a kernel cmdline, a repo manifest. the declaration is the cause; whatever the machine
holds right now is only its consequence.

## .the pair
`declared` is one half of a pair; its opposite is `live` (`term=live`). every check of machine
state reads one or the other, and which one it reads decides whether the check can be trusted
(`rule.require.judge-declared-state-not-live-state`).

## .why it is bare, not `grove.declared`
the glossary's scope test asks: could another domain object in this repo take this same word?
it could — a grove's fstab, a tree's config, a tree manifest are all declared state. but the
word means exactly the same in each, so it spans contexts rather than belongs to one. that is
the same allowance the sanctioned verb family holds, and the opposite of `stop`, which names a
different act per object. a prefix here would multiply one concept into three synonyms.

## .a CREDENTIAL has the same pair, and the split is invisible until it bites

`keyrack.yml` is a declaration in exactly this sense: it lists which keys exist, per env. the
rack (`~/.rhachet/keyrack/*.age`) holds their values. so a key has a declared half and a live
half, and only the declared half decides whether a get can find it.

measured 2026-08-02: `keyrack set` of a key **no manifest declares** succeeds and prints
`✔ set`. every later `keyrack get` of that same slug answers `status: absent 🫧`. the value
was written; the key was never declared, so it can never be read back.

⚠️ this is the pair's most dangerous shape yet, and it inverts the usual failure. elsewhere a
check that reads LIVE state gets a true answer about the wrong subject. here a WRITE to live
state reports success while the declaration it needed was never made — so the ✔ is about the
storage, and the question was about the declaration. `5.4.gh` addressed an undeclared key for
its whole life and would have reported an empty rack on a box whose rack was fine.

the fix is the same discipline as `/etc/fstab`: declare it first, then the value has somewhere
to be found.

### 🛑 .and a credential declaration is COMPOSED, so "which file declares it" has no one answer

every other declaration this term names is ONE file — an fstab, a unit, a cmdline. a
`keyrack.yml` is not: it carries an `extends:` list, so the effective declaration is assembled
from several files, each with its own `org:`.

📜 read 2026-09-07, `ahbode/svc-chat`:

```yaml
org: ahbode                                    # the ROOT
extends:
  - .agent/repo=bhrain/role=reviewer/keyrack.yml     # org: ehmpathy
  - .agent/repo=ehmpathy/role=mechanic/keyrack.yml   # org: ehmpathy
env.prep:
  - key: AWS_PROFILE                           # the root's OWN keys — no vendor key at all
```

⇒ so `FIREWORKS_API_KEY` is declared by a repo the tree merely extends, and every file it
pulls in pins a DIFFERENT org than the root.

🛑 **and the org axis is what a slug is addressed by**, so the composition rule decides which
slug a consumer composes — `ahbode.prep.KEY` or `ehmpathy.prep.KEY`. those are two different
entries, in two different accounts under `aws.params` (`term=entry`, the fifth cause).

✔ **the rule: the org of the TREE wins, never the org the child manifest pins.** settled by the
human, 2026-09-07:

> *"the roles will still need the orgs version of ahbode.prep.FIREWORKS_API_KEY"*

⇒ so a role's declaration is a **shape**, and the tree supplies the org that addresses it. one
role manifest yields a different slug per tree it is enrolled in.

⚠️ **and that is why a vendor key is per-ORG rather than per-vendor.** one fireworks account
may back every row; each org still needs its own entry, because the org is an axis of the
address AND — under `aws.params` — of the account the read authenticates into.

⚠️ it is settled by INTENT, and the measurement that confirms it is cheap and specific:
**`keyrack list` from inside the consumer's own checkout**, which prints the slugs it actually
composes. a read of the manifests does NOT settle it — that is the inference this note refuses,
and `rule.require.trust-but-verify` covers a human's in-flight sentence too.

⇒ the durable half: **a declaration you can read is not always the declaration in force.** for
a single-file declaration those are the same fact; for a composed one they are two, and only
the tool that performs the composition can report the second.

## .refs
where the term is declared / used:
- .agent/repo=.this/role=any/briefs/evidence/rule.require.judge-declared-state-not-live-state.md
- src/grove.provision/1.system/1.5.swap/configure.upsert.sh # writes the fstab declaration
- src/grove.provision/1.system/1.5.swap/configure.verify.sh # judges fstab, not `swapon`
- .agent/keyrack.yml                                       # a CREDENTIAL declaration; its root org
- .agent/repo=ehmpathy/role=mechanic/keyrack.yml           # where the github token is declared

## .reason
see the ref-level cluster beside this choice:
- `term=declared._.choice.reason.md` — etymology, rejected synonyms, the incident that earned it

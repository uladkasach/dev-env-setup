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

# gotcha: a partial write discards every fact it never read

## .what

a writer that renders a record from **its own inputs** silently destroys every field the
caller did not name. it prints success, exits 0, and the loss surfaces much later, in some
other component, as an absence nobody can trace back.

the mirror defect is a writer that COMPARES on one field: it keeps a record whose other
fields have drifted, and reports `[KEEP]` on a record that no longer works.

both are one mistake with two faces:

> **the fields a writer reads are the only fields it can converge. every other field it
> either preserves by accident, or destroys by accident — and it cannot tell you which.**

## .measurement — three instances in one hour, 2026-08-11

| # | writer | it read | what happened |
|---|---|---|---|
| 1 | `git.grove.wake`'s ssh-alias block | the **name** | port drifted 36901→36902; it printed `[KEEP] alias already written` and `🌳 grove's awake!` for a seat no command could reach |
| 2 | the FIRST repair for #1 | the **port** | converged the port and overwrote `User camper` with the default `ec2-user` — next send: `Permission denied (publickey)` |
| 3 | `git grove set --at …` | its **own flags** | a set that named one flag blanked `env`, `account`, and `nat`; `git.grove.ready.verify` halted at rung 1 with *"the entry names no account"* |

⚠️ **#2 is the instructive one.** it was written as the FIX for #1, by an author who had
just described the defect in a comment block — and it reproduced the defect at a smaller
radius in the same edit. a partial comparison is not a smaller version of a whole
comparison; it is the same bug with a narrower blast radius.

⚠️ and #3 was caused by the repair for #2: a `git grove set --at camper@…` run to declare
the seat's user, which is exactly the "name one field" call the writer could not survive.
each repair walked into the next instance because the SHAPE was never named.

## .the rule

| the write is a… | then it must… |
|---|---|
| **full render** (writes every field) | read the extant record and inherit every field the caller did not name |
| **comparison** (keep vs replace) | compare the WHOLE declared record, never one field |
| **field update** | be explicit that absent ≠ empty, and say which is which |

## .absent is not empty

a field-level upsert needs three states, and a test on the value alone gives two:

```sh
# 👎 cannot tell "not given" from "given as empty"
[[ -n "$nat" ]] || nat="$(jq -r .nat "$prior")"

# 👍 a marker per flag, set in the parse loop
--nat) nat="$2"; nat_given=1; shift 2 ;;
…
[[ "$nat_given" != 1 ]] && nat="$(jq -r '.nat // empty' "$prior")"
```

without the marker, `--nat ''` cannot clear a field, so the record grows values that can
never be removed — the opposite defect, arrived at by the obvious fix.

## .the tell

each of the three printed a **success** line:

```
🌲 grove 'x' registered → camper@localhost:36901       ← and blanked 3 fields
      └─ ssh  [KEEP] alias 'x' already written        ← and the port was dead
🌳 grove's awake!                                      ← for an unreachable seat
```

so the tell is never in the writer's output. it is in the SHAPE of the code:

> **does this write render fields it was not given a value for?**

if yes, and it does not read the extant record first, it is a data-loss bug that has not
fired yet.

## .why this repo walks into it repeatedly

it is `term=entry`'s split once more — *a store that HOLDS a record says none of what the
record's VALUE is* — and `rule.require.get-set-gen-verbs` makes it easy to walk into:
`set` means "overwrite", which is honest about the OPERATION and silent about its
**granularity**. `set` on the entry and `set` on a field are different promises, and one
verb spells both.

⇒ when you name a `set`, say what it overwrites: the record, or the fields named.

## .see also

- `term=entry._.choice._.md` — the store-vs-read split this instantiates
- `rule.require.get-set-gen-verbs` — `set` is overwrite; this is about its granularity
- `rule.forbid.failhide` — all three printed success while state was lost
- `gotcha.a-check-that-cries-wolf-gets-silenced` — its mirror, where the CHECK is wrong
  rather than the write
- `src/bash_aliases.sh` — `_git_grove_set` carries instance 3 inline
- `.agent/repo=.this/role=any/skills/git.grove.wake.sh` — instances 1 and 2, inline

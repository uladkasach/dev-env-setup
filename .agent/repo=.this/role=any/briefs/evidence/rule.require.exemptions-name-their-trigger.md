# rule.require.exemptions-name-their-trigger

## .what

when you write a **carve-out** — an exemption from a check, or a scope that covers less than the
whole — it must name two facts:

1. **its cover** — where the exempted case IS handled instead, cited by path or rule name
2. **its trigger** — the concrete observation that would VOID the carve-out

and a scope stated as an **enumeration** is forbidden. `applies to install_* and configure_*` is
an implicit exemption of every other verb, written by nobody and reviewable by no one. scope by
**principle plus a test**, then list the exemptions explicitly.

## .why

> a written exemption outlives the reason that justified it.

this is the failure mode, and it is counter-intuitive: a carve-out makes a gap **less** visible
than silence would. an absent check leaves a hole that reads as a hole. a *documented* reason to
skip the check reads as **considered** — so the next traveler trusts it and moves on, and the gap
survives every review that passes over it.

so the danger is not an omission. it is **false confidence**, which is worse than no confidence:
the reader stops looking precisely where they should look hardest.

## .the two shapes it takes

| shape | how it hides | the fix |
|---|---|---|
| **explicit** — "X is exempt, because it is covered by Y" | the premise `covered by Y` is asserted, never checked | cite Y by path; if you cannot cite it, X is not covered |
| **implicit** — "this rule applies to A and B" | everything outside A and B is exempted, silently | scope by principle + test; list exemptions explicitly |

the implicit shape is the more dangerous of the two, because no sentence in the repo admits the
exemption exists. there is nothing for a reviewer to disagree with.

## .how

when you write a rule, a scope, or a `.note` that skips something:

1. **state the scope as a principle**, with a test a reader can apply — never as a list of names
   or prefixes
2. **list each exemption explicitly**, one line each
3. **cite the cover** for each: the path or rule that handles it instead
4. **name the trigger** that voids it: what would have to become true for this carve-out to be
   wrong

if you cannot name a trigger, you do not have an exemption — you have a guess with a citation
format.

## .examples

### 👎 bad — an implicit exemption, by enumeration

```md
## .what
every `install_*` / `configure_*` function must be driven by a `step` line.
```

`clone_*`, `upgrade_*`, and every other verb are exempted, and no line says so.

### 👎 bad — an explicit exemption on an unchecked premise

```md
`send` / `read` are canonical get-set-gen family verbs, reused not re-itemized.
```

reads as considered. the premise is false — they are not in that family — and the note is what
kept anybody from checking.

### 👍 good — principle, test, cited exemption, named trigger

```md
## .what
**every** function this repo declares must be reached by a bundle phase — whatever its name.

## .the test
> does a chain of calls reach it from one of a leaf's four phases?  no → it is dead code.

## .the one exemption
- `devenv.bootstrap.sh` — outside the bundle tree, because it runs BEFORE the repo exists
  - cover: `readme.md` drives it; see `term=devenv.bootstrap._.choice._.md`
  - trigger: a bootstrap concern written INSIDE the bundle tree is not reached by this
    exemption — that is a blocker
```

## .evidence — two incidents, three rounds apart

both cost multiple rounds, and in both the **note was the cause**, not an innocent bystander:

1. **`grove.send`, hidden for four rounds.** rounds four and seven each recorded a judgment that
   "`send`/`read` are canonical get-set-gen family verbs, reused not re-itemized". the premise was
   false — they are ductwork's words, borrowed, and they needed clusters. the hole surfaced only
   when a later round EXTENDED the term and went looking for a cluster that was never written.
   a recorded reason to skip made the term invisible for **longer**, not shorter.
2. **`clone_this_repo`, dead for as long as it existed.** `rule.require.every-function-has-a-driver`
   scoped itself to `install_*` / `configure_*`, so a `clone_*` function walked through the gap —
   and it was named such that a reader would trust it as how the repo reached a new machine. it
   could never have worked: circular by construction, and it cloned over ssh, which no fresh
   machine can do.

the shared shape: in each case a reader who met the carve-out had **less** reason to look than a
reader who met silence.

## .the test

> if this carve-out were wrong, what would i observe?

- you can name it → the carve-out is accountable; write the trigger down
- you cannot → delete the carve-out and widen the check

## .enforcement

- a scope stated as an enumeration of names or prefixes, where a principle would serve = **blocker**
- an exemption with no cited cover = **blocker**
- an exemption with no named trigger = **blocker**
- an exemption whose premise asserts coverage that does not exist = **blocker** (this is the
  `grove.send` defect, and it is the most expensive of the four)

## .see also

- `rule.require.every-function-has-a-driver` — the rule this one was extracted from, and its one
  properly-formed exemption
- `rule.require.solve-at-cause` — a carve-out is often a symptom patch with a citation
- `rule.forbid.failhide` (mechanic) — the same family: a swallowed signal reads as a pass
- `.agent/.cache/repo=bhrain/role=learner/skill=learn.domain.terms/progress.md` — rounds eleven
  and thirteen, where both incidents are recorded in full

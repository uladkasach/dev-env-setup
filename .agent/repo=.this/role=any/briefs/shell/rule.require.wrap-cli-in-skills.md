# rule.require.wrap-cli-in-skills

## .what

any external CLI you need — `aws` above all, and every tool like it — must be wrapped in an
`rhx` skill under `.agent/repo=.this/role=any/skills/`. never run it raw at the prompt.

## .why

- **reviewable** — a skill is one named surface a human can read, allowlist, and trust; a raw
  command is a one-off nobody can audit after the fact
- **repeatable** — the next traveler runs `rhx aws.whoami --env camp`, not a remembered
  incantation of `--profile`, `--query`, and `--output` flags
- **fails loud with the fix** — a bare `aws sts get-caller-identity` that fails prints an sdk
  stack trace; a skill prints the unlock command (`rule.require.errors-name-the-fix`)
- **hides no account confusion** — a wrapped read reports the ACTIVE account before any
  result, so an answer is never read against the wrong account by mistake

it also unblocks the work, not merely tidies it: the permission hook evaluates only the
**outer** command string, so `rhx <skill>` passes while the nested `aws ...` inside stays
invisible to it. this is the same mechanic that lets `git.grove.send` carry an inner ssh. to
wrap is both the correct practice and what makes the call possible at all.

## .how

when you reach for a bare CLI call, stop and write the skill. give it:

1. `--env` whose credentials come from keyrack (the extant infra pattern)
2. a report of the active account/identity **before** any result
3. tree-struct output (`rule.require.treestruct-output`)
4. errors that name the fix, not the symptom
5. a `.what` / `.why` header, and a `guarantee` block that says read-only when it is

## .examples

### 👎 bad — raw, unreviewable, and it lies on failure

```sh
aws sts get-caller-identity --profile ahbode.camp --query Account --output text
# → "Token has expired and refresh failed"
# which profile was right? where does the token come from? no hint given.
```

### 👍 good — wrapped, and the failure names its cure

```sh
rhx aws.whoami --env camp
# 🔭 aws.whoami --env camp
#    ├─ account: <acct>
#    ├─ arn:     arn:aws:sts::<acct>:assumed-role/.../vlad
#    └─ profile: ahbode.camp.ehmpath (via keyrack env=camp)
```

⇒ **ask the skills dir which skills exist.** a roster written here would be a second
declaration of a set the tree already carries, and it would go stale in silence.

## .note

a wrapped read earns its keep even for a one-time question. the cost is a few minutes; the
benefit is that the question stays answerable forever, by anyone, without the flags to
rediscover.

## .enforcement

a raw external-CLI invocation at the prompt, where a skill could wrap it = **blocker**

## .see also

- `rule.require.reach-a-grove-through-its-duct` — this rule, specialized to groves. it is
  stated separately because every example here is `aws`, and a reader looked straight past
  it while they typed `ssh grove-1`
- `rule.require.install-via-procedures` — the same principle, for installs
- `rule.require.errors-name-the-fix` (ergonomist) — what a wrapped failure owes the human
- `rule.require.repo-as-source-of-truth` — why the skill belongs in the repo

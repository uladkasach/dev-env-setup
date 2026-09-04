# domain.term.choice.reason: dox

## .etymology

*dox* is short for *documents* — hacker slang from the 1990s for the act of publication of
someone's real identifiers. the word carries the sense this repo wants and no other word does:
the material is **not confidential**, and publication of it is the harm all the same.

that is the exact shape of an aws account id. it is not a secret. it is not encrypted. and to
publish it converts a stranger's broad scan into a narrow one.

chosen over:

| candidate | why it loses |
|-----------|--------------|
| `secret` | **taken, and opposite.** a secret GRANTS access; dox NAMES a resource. their first moves differ — rotate vs redact — so one word would prescribe the wrong one half the time |
| `pii` | names a PERSON. 19 of this repo's 21 findings name a MACHINE. borrowed from privacy law for an infrastructure problem, it imports the wrong remediation frame |
| `sensitive-info` | states that a judgment was made, not what the item enables. an unfalsifiable label — everything is arguably sensitive, so it grades none of it |
| `leak` | names the EVENT. useful, but you cannot say "this line is a leak"; you say a leak PUT the dox there. different part of speech, different concept |
| `identifier` | a slug, a bundle name, and a duct uri are all identifiers and all meant to be read. the word cannot separate what must be published from what must not |

## .what settled it — a blind sweep, 2026-08-08

a red-team subagent was given the repo and no list of what to look for. it returned:

```
CRITICAL (secrets needing rotation) …  0
HIGH   (account/arn/role/instance/host)  5
MEDIUM (resource names, secret paths, private repos)  9
LOW    (personal + environment fingerprint)  7
```

**zero and twenty-one.** the two categories did not merely differ in severity — one was
entirely absent and the other was everywhere. had they shared a word, the report would have
read "21 security findings" and the first move would have been ambiguous: rotate what?

⇒ the split is not a taxonomy for its own sake. it is what makes the report **actionable in
one read**.

## .the sharpest evidence — a rule that was correct and stopped none of it

`rule.forbid.dox-in-public-repo.md` already existed. it was thorough. it named the placeholder
table, the one-line test, and — remarkably — **ranked its own four slip-vectors in the order
they would occur**. the sweep then independently found all four, in that order, with pasted
command output as the dominant one.

the rule was booted as **neither `say` nor `ref`**, so it had never been in context.

three consequences, all measured:

1. **the briefs written the same week violated it.** `handoff.infra.grove-account-reach.md`
   alone carries 10 of the 21 findings.
2. **the file directly beside the rule violated it.** proximity in the filesystem is not
   proximity in context.
3. **it reached shipped `src/`, not only prose** — `zshenv.sh`, two `5.6.aws` phase files,
   `aws.reach.set.sh`. a "review the docs" pass would have missed those entirely.

📜 this is the **third** instance of the same failure in this repo. `boot.yml` carries two
prior comments that each say, in the same words, *"a rule that is not loaded is a rule that
does not exist"* — and this rule was added under neither. the lesson is not about dox at all:

> **a rule's correctness and a rule's reach are independent.** the repo has now proven,
> three times, that it will write an excellent rule and then not load it. the boot manifest
> is the artifact that decides whether a rule exists, and it is edited least often.

## .the partial-redaction tell

someone WAS redacting, by feel. the sns topic is truncated in two files and spelled out whole
in a third. the ellipsis style in use — `…8747…8849:…/<prep-oidc-role>` — shortens the arn
while it keeps **both** the account id and the role name.

⇒ **it redacted the boilerplate and kept the payload.** that is what redaction by eye produces,
and it is why the rule ships a placeholder TABLE rather than a principle. a table can be
applied mechanically; a feel cannot.

## .the deferral, with a trigger that can end it

`redact` (the verb) and `placeholder` (the noun) are named throughout the rule and hold no
clusters of their own. deliberate:

> **the trigger:** either earns a cluster the moment a defect turns on ITS boundary — a
> redaction that removed the boilerplate and kept the payload, argued as sufficient; or a
> placeholder that itself named a real resource.

the second nearly happened already: the ellipsis style above is that defect in embryo. it was
caught by a sweep rather than by an argument, so no dispute exists to record — yet.

## .disputes

none yet. `secret` is recorded as a forbidden synonym rather than a disputed one, because the
two are not competing words for one concept — they are two concepts, and the measurement above
is what demonstrates it.

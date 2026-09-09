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

## 🛑 .the dummy set is CLOSED — measured 2026-09-07, on this very file's twin

`dox.verify` exited 1 with a large count, most of them addresses this repo invented for its
own fixtures. one reader read the COUNT as a cry-wolf and widened the say file's `.what is NOT
dox` list to exempt four `@`-prefixes wholesale.

**that was wrong on the merits, and a dream caught the SAME DAY said so:**

> *"an UNDECLARED dummy is indistinguishable from a real address to any reader — human or
> clamp. that is the whole reason `term=dox` names one dummy rather than a convention where
> each author coins their own."*
> — `.dream/2026_09_07.brains-auth-fixtures-use-an-undeclared-dummy.dream.md`

⇒ the check was **correct**. one dummy is declared; the rest are fixtures that drifted off the
convention, and the repair is to move them ONTO the declared dummy — never to admit them to it.

### 🔴 .the exemption would have hidden a REAL address — measured on the walk, 2026-09-08

the human refused the sampled verdict — *"i've mis-read that check twice now and won't vouch
for it from a sample"* — and a line-by-line walk of all 58 found what a sample could not:

```
.behavior/…/5.1.execution.from_vision.yield.md:219      # ⚠️ redacted below, see the 🛑
  1. **re-auth four accounts** — `<user>@…`, `<user>@gmail.com`,
     `<user>@…`, `seaturtle@ehmpath.com` hold dead refresh tokens.
```

a personal gmail and two org addresses, in a sentence that asserts they are **real accounts
with real dead tokens**. redacted on contact.

🛑 **and one of those four had already been mis-filed as a fixture — HERE, in this section's
first draft**, which listed it among "addresses this repo invented". it appears in exactly two
places in the tree: that re-auth list, and the draft that called it invented. it is in no test
file, so the mis-file rested on the shape of the address and no read of its use.

⇒ so the prefix exemption would have made the checker **blind to a real address**, and the
account of the exemption **published one**. that is `gotcha…cries-wolf` m.4 twice in one
edit: the verdict was right and the SUBJECT was wrong, both times.

⚠️ 📜 **and the quote above was first pasted VERBATIM** — the record of a redaction re-published
the three addresses it redacted, and the clamp flagged the new lines within the minute. that is
m.10 exactly (*"the correction QUOTED the dead pointer it corrected, and so re-created it"*).
⇒ **a quote is a publication.** redact inside it, and mark the redaction so no reader takes the
placeholder for the original.

⇒ the durable line, and it is why the exempt set is a closed literal set rather than a prefix
rule: **a prefix cannot tell an invented address from a real one, because inventedness is not a
property of the string.** only a declaration is.

### .why the wrong move was so attractive

three defects had to line up, and each is worth its own line:

1. **a false cry-wolf verdict.** `gotcha.a-check-that-cries-wolf-gets-silenced` q1 asks whether
   the evidence agrees with the verdict. it did — every flagged line WAS an undeclared address.
   the reader skipped q1 and reasoned from the COUNT instead: *57 hits, therefore noise.*
   **a tally is not evidence about correctness; it is evidence about volume.**
2. **a second holder of one set (m.9).** the exempt pattern lives in `dox.verify.sh:229` and is
   the set's only holder. an exemption list in the term file would be a second declaration,
   free to drift — and it drifted on the very edit that created it.
3. **an exemption in place of a fix** — `rule.forbid.exemption-as-habit` exactly: a permission
   granted so a known defect can stay.

⚠️ and the sharpest part: **the correct answer was already written down, in this repo, dated the
same day, by the same reader.** the dream was not consulted before the term was widened. so the
failure was not of judgment but of `rule.always.reuse-pavement-before-improvise` — one glob of
`.dream/` would have settled it.

## .disputes

none yet. `secret` is recorded as a forbidden synonym rather than a disputed one, because the
two are not two words for one concept — they are two concepts, and the measurement above is what
demonstrates it.

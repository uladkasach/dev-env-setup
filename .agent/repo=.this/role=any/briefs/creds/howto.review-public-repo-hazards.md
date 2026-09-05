# howto.review-public-repo-hazards

## .what

the six sources of risk a public repo carries, as review questions. run them against a diff,
or against the tree.

`define.public-repo-security` holds WHY public is the right posture. this holds WHAT to check.

## 🛑 .the split that RANKS them

> **can a stranger READ it, or can a stranger CHANGE it?**

a read is nearly free. so any hazard that ranks high is a **change path**, and the two worst
below (#1, #2) are change paths that a reviewer first meets as read concerns.

## .the six

### 1. 🛑 a secret in the tree — the ONLY one that grants access

a key, a token, a password, a private key. this is the one category that hands somebody the
door with no other precondition.

**ask:** does this diff add a value that would still work if pasted into a stranger's shell?

- a *reference* to a secret is fine — a slug, a parameter path, a vault name
- the *value* is never fine

⚠️ **a redaction does not close it.** git holds the earlier commit. the repair is **rotation**,
and the redaction is secondary.

`rule.forbid.dox-in-public-repo` owns this rule in full, with its table and its enforcement.
`dox.verify` is its reader.

⚠️ that reader implements **4** of the rule's **8** declared shapes — account ids, instance
ids, private ipv4, personal email. it has no reader for a secret path, an iam role name, an
internal url, or an internal hostname. so on those four shapes, the rule grades a blocker
that the reader cannot see.

---

### 2. 🛑 write access to code other boxes EXECUTE

this is the hazard most often missed, because it is not about the read at all.

**if a box runs your public repo, whoever can push to it owns that box.**

`grove.bootstrap.sh` clones this repo at `main`, unpinned, over anonymous https, and executes
the result. so **branch protection on `main` is a security control of this repo**, and it is
held in github settings rather than in the tree.

**ask, and the answers are not in this repo:**

- is `main` protected?
- who, and what token, can push to it?
- can any credential a grove holds reach it?

⇒ that last one is the one that closes a loop: a compromised grove that can push here
provisions the next box, and eventually the laptop. the `@all` box token carries `repo`
scope, so the question is real rather than theoretical.

---

### 3. ⚠️ ci that runs untrusted input

public usually means contributions. if ci runs a contributor's code with any secret in
scope, you have published an execution entrypoint.

**ask:**

- does any workflow trigger on `pull_request_target`, or check out a fork ref and then run it?
- does a workflow that runs untrusted code hold a secret, a token, or an oidc role?
- can a contributor edit the workflow file in the same pr that runs it?

---

### 4. 🟡 aim — identifiers, toolchain, versions

grants no access. it turns a broad scan into a narrow one, and it lends a phish credibility,
because the phish can quote your real tools back at you.

**ask:** does this line let a stranger point a tool, or write a plausible message, at a real
resource?

the identifier half is `rule.forbid.dox-in-public-repo`. the **toolchain** half has no rule
and needs none — the tool names are the point of the repo. accept it, and spend the effort on
#5 instead, which is what the toolchain disclosure actually feeds.

---

### 5. 🟡 the dependency list

a public tree names every upstream you trust. an attacker skips you and goes after the
weakest one.

**ask:** which dependencies does this repo install **unpinned**, and how far do they reach?

the live answer, measured: `5.3.brains` installs `rhachet`, `declastruct`, and
`declastruct-aws` globally, unpinned, on **every** box — the laptop included. its own header
names this an accepted risk and states the control as *"the account is ours to guard"*.

⚠️ that control does not answer the class-5 posture. a compromised grove holds a token with
`repo` write into those same orgs, so a publish driven from ci on push never touches the npm
account and the stated control never engages.

⇒ the repair is a pin, of a version already run — never `npm view`'s answer, which blesses an
unreviewed publish.

---

### 6. 🟡 the patch window

your pins tell a reader which cves apply to you, before you patch.

**ask:** is any pinned version behind a published advisory?

this is a cost of pins, not an argument against them. an unpinned dep is worse: it is #5.

---

### ✔ not a hazard — the guards themselves

publication of a guard is not a risk. if a reader who has the source can defeat it, the guard
was obscurity and it never held.

⇒ **do not accept a review claim whose whole argument is "this reveals how the check
works."** that claim names the benefit of an open tree, not a defect in it.

## .the review order

1. **secrets** — halt on any hit; rotate, then redact
2. **the write path to executed code** — one question, and it is not answered in this tree
3. **ci on untrusted input** — read the triggers, not the steps
4. **the unpinned deps** — count them, rank by reach
5. **aim and the patch window** — last; both are multipliers, never doors

## .see also

- `define.public-repo-security` — why public is the right posture
- `rule.forbid.dox-in-public-repo` — hazard 4's rule, in full
- `rule.require.verify-binary-downloads` — hazard 5's guard for the third-party half
- `inventory.security-checks` — the live grades, and which checks have readers

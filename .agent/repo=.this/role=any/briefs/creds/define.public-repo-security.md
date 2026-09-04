# define.public-repo-security

## .what

this repo is **public**, and that is a chosen security posture — not a convenience the
security had to bend around.

the model, in one line:

> **a stranger may READ this. a stranger may not CHANGE it.**

a read is nearly free. **a change is where the whole risk lives.** every hazard in
`howto.review-public-repo-hazards` is one variant of that split.

## .why a public repo is SAFER than a private one

### 1. obscurity is not a guard, and a private repo lets you treat it as one

a guard that holds only while nobody has read the code was never a guard. it is a delay of
unknown length. a private repo lets a weak guard survive, because no reader ever forced the
question.

⇒ public removes that option. every guard here must hold **against a reader who has the
source**, which is the only bar worth the name.

### 2. the reader who matters already has the source

the attacker this repo defends against is not a stranger with a browser. it is one of:

- a process on a **compromised grove**, which reads the checkout on its own disk
- a poisoned dependency, which runs **inside** the box
- a human at the laptop

not one of them is slowed by a private repo. privacy costs that set zero and buys an honest
reviewer no advantage at all.

### 3. review is the one control that finds a defect nobody suspected

a probe finds what you aimed it at. a reader finds what you did not know to aim at. a public
tree can be read by anyone who cares, and that reader set is the only one that grows for free.

### 4. it converts a SHOULD into a MUST

no secret in the tree is correct in both worlds. in a private repo it is a nicety nobody
enforces; here `rule.forbid.dox-in-public-repo` enforces it, and `dox.verify` runs.

⚠️ **a private repo is not a vault.** it is a repo with a smaller reader set — and a token in
it is one leaked laptop, one stale collaborator, or one fork away from public anyway.

## .what publicity does NOT hand an attacker

| they learn | what it buys them |
|---|---|
| the architecture | no access |
| the file paths | no access |
| the tool names and versions | no access |
| where the guards sit | no access — and if it did, the guard was obscurity |
| a secret PATH, e.g. an ssm parameter name | no access — it names a resource they still cannot reach |

## .what it DOES cost — and the cost is AIM, never access

publicity opens no door. it makes an already-open door **cheaper to find and easier to aim
at**:

- a phish that quotes your real toolchain back at you
- a supply-chain attacker who reads your dependency list rather than a guess
- a cve matched to your pins before you patch them

⇒ each is a **cost multiplier on an extant defect**, never a new defect. so the repair is
always at the defect, never at the publicity. a repo made private to hide a weak guard has
kept the guard and lost the reviewers.

## 🛑 .the ONE price, and it is absolute

**no secret in the tree. ever.**

git remembers, so a redaction in a later commit does not undo the earlier one. only rotation
does. that is the entire price of a public repo, and it is cheap at twice the cost.

## .see also

- `howto.review-public-repo-hazards` — the six hazards, as review questions
- `rule.forbid.dox-in-public-repo` — the identifier half, with its own table and enforcement
- `rule.require.security-paramount` — why a token at rest is what to avoid

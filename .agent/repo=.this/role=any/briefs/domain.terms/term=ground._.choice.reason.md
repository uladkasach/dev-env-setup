# domain.term.choice.reason: ground

## .why this was captured the hour it was settled

a unix username is the **least reversible name this repo mints**. it lands in `/etc/passwd`,
in every home path, in `/etc/sudoers.d/`, in `authorized_keys`, in `sshd_config`, in every
brief and play that names a path — and, if ASK 2 of the handoff is taken, in the image's
user-data. to rename it later is a coordinated change across a live fleet.

⇒ so it was captured the same round it was settled, per the capture-now clause. a term this
expensive to change is the exact case the clause exists for.

## .etymology

*ground* — the land a keeper tends. it extends the extant family rather than a new one:

```
forest  →  grove  →  tree          the git metaphor, already itemized
camp                               already this repo's word for grove infrastructure
  ├─ camper   the one who camps there      ← INHERITED from the image
  └─ ground   the one who tends the grounds ← MINTED here
```

`camp` was not invented for this: `.agent/keyrack.yml` already declares `AWS_PROFILE` at
`env.camp`, and `rule.require.github-token-at-all-camp` fixes `@all.camp.GITHUB_TOKEN` as the
one slug every box reads. so the pair sits inside a bounded context that was already load-bear.

chosen over:

| candidate | why it loses |
|-----------|--------------|
| `admin` | says WHO may log in, not what the user is FOR. every box has an admin; the word carries no context and would read identically on a laptop, a grove, and a CI runner |
| `root` | taken by unix, and materially wrong — `ground` is a normal uid that MAY sudo. to name it `root` would state that the split does not exist |
| `groundskeeper` | correct in prose and used there. too long for a name typed at every `ssh`, every `sudo -u`, and every path in a brief |
| `sudoer` / `operator` / `maintainer` | generic sysadmin vocabulary. each names a job title, none names a place in this repo's metaphor, and `sudoer` states the mechanism rather than the purpose |

## .disputes

### dispute: `keeper` — raised 2026-08-09 — status: RESOLVED (keep `ground`)
- raised.by  = mechanic, the same round the term was minted
- claim      = **`camper` / `keeper` is the more symmetric pair.** both are `-er` agent
               nouns, both name a PERSON, both six characters. `camper` / `ground` is
               asymmetric on the axis that matters most for a username: `camper` names a
               person and `ground` names a PLACE. read cold in `/etc/passwd`, `ground` does
               not obviously denote a user at all. `rule.prefer.symmetric-term-pairs` says
               a contract reads clearer when complementary labels share one form
- counter    = three things hold `ground` up. **(1)** the human proposed it, twice, and a
               judgment made by the person who will type it daily outranks a symmetry
               argument made by the robot who will not. **(2)** `keeper` is generic in the
               way `admin` is — a keeper of what? `ground` at least carries the camp
               metaphor, and the full `groundskeeper` recovers the agent noun in prose where
               there is room for it. **(3)** the asymmetry is real but it is not ambiguous:
               `ground` collides with no other term in this repo, and one glance at
               `/etc/sudoers.d/` settles what it is
- resolution = keep `ground`; record `keeper` as a forbidden synonym. the symmetry
               observation stands as a genuine cost, recorded rather than argued away —
               so a future traveler who feels the same friction finds it already weighed
               instead of a re-litigation. dispute closed the round it opened

⚠️ this dispute is filed **before the name is applied to a box**. that is the cheap moment,
and it is the whole reason `howto.domain-term-disputes` exists. once `ground` sits in
`/etc/passwd` on a fleet, the counter-argument stops being about which word is better and
becomes "is it worth a migration" — a different and much worse question.

## .evidence

### the design this term serves, in one measurement

grove-1 today runs its agent as `camper`, and `camper` is root by **two** independent paths:

```
camper ALL=(ALL) NOPASSWD:ALL          # /etc/sudoers.d/
camper ∈ docker                        # docker run -v /:/host --privileged
```

the second is the one that catches people: **membership of `docker` is equivalent to sudo**.
a split that removes the sudoers line and keeps the group has changed the paperwork and left
the privilege. so `ground` only earns its meaning once `camper` loses BOTH — which is why the
handoff's step 1 is rootless docker and not the user split.

### what the term does NOT claim

`ground` bounds **escalation and persistence**, never exfiltration. credentials arrive from
IMDS at `169.254.169.254`, which any process reaches regardless of unix user — so a `camper`
with no sudo still holds the box's badge and every credential that resolves through it.

⇒ the word must not be read as "the box is now safe". it names one axis of one threat model,
and the handoff says so in its own ASK 3 rather than let the name imply more than it earns.

## .the deferral, with a trigger

**`camper`** holds no cluster of its own, deliberately: this repo did not choose that word —
the IMAGE names the login user, and the name has already changed once (`ec2-user` → `camper`).
to itemize a term whose authorship sits upstream would record a decision we did not make.

> **the trigger:** `camper` earns its own cluster the moment infra accepts ASK 2 of the
> handoff and both usernames become a **declared contract** rather than an image detail.
> at that point the word is ours to keep, and its per-image drift becomes a defect rather
> than a fact of life.

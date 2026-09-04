# domain.term.choice.reason: lens

## .etymology

`lens` because the run does what a lens does: it leaves the subject untouched and changes what
the viewer SEES. `grove.provision --for cloud --mode plan` on a laptop reports what a grove
would get; the laptop is unaltered, and every bundle is real code reading a real box.

that is also the argument against every rejected synonym. `simulation` and `pretend` both say
the RUN is fake — it is not; only its declared subject is another box. `preview` is the closest
miss and the worst one, because a plan is already a preview of THIS box, so the word collapses
the exact distinction the term exists to draw.

⚠️ the mode-spelling this repo bans repo-wide (see the `rule.forbid.term=` cluster for the
boolean-mode word) is doubly wrong here, which is what made it tempting. that rule rejects it as
a MODE spelling — a boolean where a mode belongs. a lens is not a mode at all; it names the
SUBJECT. so reaching for it would have hidden a second axis inside a word already forbidden for
hiding a first.

## .disputes

### dispute: a closed-set validator — raised 2026-09-03 — status: RESOLVED (keep the lens, halt the write)

- raised.by  = me, on the first read of redteam round 24's F1
- claim      = `grove.env.sh:439` admits `local@*|cloud@*` — the whole cross product — while its
               own error text one line below names only two values. so narrow the validator to
               that closed set, and the contradicted pairs cease to exist. one edit, and it
               closes F1 and F1b together
- counter    = it deletes a documented, useful workflow. `repo.overview.md:120` teaches
               `--for cloud` as *"as a grove would see it"*, and that lens works precisely
               BECAUSE it rewrites the value bundles test. a closed set kills the plan along
               with the apply.

               and it misreads what `--for` is for. `--for` sets only the TIER; the platform
               comes from a probe alone. so it cannot rescue a wrong derivation — a wrong
               derivation is a wrong PLATFORM, and that halts on NO FALLBACK regardless.
               `grove.env.sh:427-429` names `GROVE_ENV_SERVER=` as the real override, and it
               sets both halves. ⇒ `--for`'s ONLY reachable effect is to produce a contradicted
               pair, so a validator that forbids the pair forbids the flag
- resolution = the pair is not the defect. **a lens that WRITES is the defect.** the halt is on
               `--mode apply` alone, in the driver where the mode already lives. dispute closed.

⚠️ **`grove.for.sh:44` still carries the claim this dispute refuted** — *"`--for` still
overrides, because a derivation can be wrong and a human must be able to say so."* the sentence
names a job `GROVE_ENV_SERVER=` holds. it is left as a nitpick rather than edited in this round,
recorded here so the next reader meets the correction rather than the claim.

## .evidence

### the measurement, 2026-09-03 — the four arms

each run on the laptop, through `rhx`, against `3.2.theme` (a harmless bundle, so a broken gate
could not install a listener):

```
--for cloud --mode apply   → rc=2   REFUSED     ← the defect
--for cloud --mode plan    → rc=0   server cloud@unix, bundles declined for a grove
--for local --mode apply   → rc=0   server local@unix, applied
(no --for)  --mode apply   → rc=0   server local@unix, applied
```

then the real vector, end to end:

```
rhx grove.provision --for cloud --what 2.3.ssh --mode apply
→ rc=2, halted BEFORE the bundle ran. no metapackage, no listener.
```

### why the halt reads the natural tier and not the pair

a check on the literal strings `cloud@unix|local@aws.ec2` would be a **second declaration** of a
fact the probes already hold — m.9, and it would go stale the day a third platform is probed.
`GROVE_ENV_TIER_NATURAL` is the probe's own answer, so the gate derives the contradiction rather
than enumerating it.

### the measurement, 2026-09-03 — on a GROVE, the other direction

the laptop cannot produce `natural=cloud`, so the four arms above prove the halt in the
`cloud@unix` direction alone. run again on `grove-ahbode-v20260811`:

```
🔭 the box under test
   ├─ server:  cloud@aws.ec2
   └─ natural: cloud

   ✔ A. --for local  + apply   (the F1b defect)      halt  (rc=2)
   ✔ B. --for local  + plan    (the lens, documented) quiet (rc=1)
   ✔ C. --for cloud  + apply   (agrees with the probe) quiet (rc=0)
   ✔ D. no --for     + apply   (the everyday path)    quiet (rc=0)
```

⇒ **arm A is F1b, observed.** `local@aws.ec2` is the pair that makes `2.3.ssh`'s gate fall
FALSE, run the mask branch, and cut sshd on a box with no console. it halts before any bundle
runs. so the mirror is no longer an argument from symmetry.

⚠️ the play named `3.2.theme`, never `2.3.ssh`. the halt sits UPSTREAM of bundle selection, so
a theme bundle exercises the identical path — and cannot cut the duct on the box running the
probe if the gate were broken. **a probe must not be able to do the harm it measures.**

### 🛑 the arm that was wrong, and it is m.4

arm B first declared `want=0` and went RED on the grove. the halt was correct; the ARM was not.

a plan runs every verify, so its exit code carries **the box's convergence state**, never the
gate's verdict. `3.2.theme`'s verify refutes honestly on a grove — no compositor, so no GTK
stylesheet — and exits 1. that is the lens working exactly as designed.

⇒ the subject is `rc == 2` (the driver's halt) versus `rc != 2`. **2 is the driver; 1 is a
bundle's honest refutation, and it says nothing about the gate.** the arm now judges `halt` /
`quiet` and never a bare zero.

⚠️ **the laptop's arm B passed on `want=0` and hid this**, because there `3.2.theme` genuinely
converges. a pass for a reason its author never named — the same shape as m.8's arm that would
have passed either way.

### the residue

**no PERMANENT play guards these arms.** `prove.a-lens-may-not-write` lives in the gitignored
`.play/temporary/`, so it reaches no other box and rots with the checkout.
`rule.require.seam-claims-have-an-owner` argues for a tracked clamp, and the arms are cheap —
four driver calls with declared verdicts. recorded as owed rather than written, so a later
reader knows the absence was chosen (`gotcha.a-check-that-cries-wolf-gets-silenced`, m.13).

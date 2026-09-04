# domain.term: probe

term.chosen   = probe
term.kind     = verb
term.synonyms.forbidden:
- detect       (names the OUTCOME — a platform detected. a probe asks; it may answer no)
- check        (already the forbidden synonym of `claim`'s act; to reuse it here would overload one
                word across two axes — see `term=claim._.choice._.md`)
- test         (test-framework vocabulary. a probe runs in production, on every provision run)
- sniff        (jargon, and it implies a guess. a probe reports a fact or declines)
- is           (the sanctioned boolean prefix, and it promises PURITY a probe does not have — see
                `.reason`)

## .what
one callable function that asks the machine a single yes/no question about itself, and answers it
from evidence rather than from inference.

> `grove_env_probe_aws_ec2` — *"are you an ec2 instance?"*
> `grove_env_probe_desktop` — *"do you have a screen with a human at it?"*

a probe is **one question, one function**. that is why the word is load-bear: a probe you can
call, you can ask ON ITS OWN. an unaskable probe is an unprovable one.

| | asks the machine | callable alone | may cost |
|---|---|---|---|
| **probe** | yes | yes | a rung may (imds) |
| **predicate** | no — reads a derived string | yes | never |

## .probe ≠ signal
they are DISTINCT concepts, and both are kept:

- a **signal** is what the box publishes — `sys_vendor` holds `Amazon EC2`; `cloud-id` holds `aws`
- a **probe** is the function that reads signals and answers the question

one probe reads several signals. `grove_env_probe_aws_ec2` reads six across four rungs.

## .the ladder, and its rungs
the ordered sequence of probes is a **ladder**; one member is a **rung**. cheapest first, climb
until one answers, and refuse if none do (`cascade` and `chain-of-probes` are forbidden synonyms of
`ladder` — see `.reason`).

`chain` is NOT a synonym: it is sdk-environment's own word for the per-attribute parser order
(override → flag → inference), which is a wider concept that a ladder sits inside.

## .a probe must be BOUNDED

a probe that can hang is not a probe — it is a stall with a question mark on it. wrap every probe
that leaves the current process (a login shell, a package manager, the network, a lock) in
`timeout`, and feed it `</dev/null`. then it answers, or reports that it could not.

measured 2026-07-30: `grove_provision_5_1_node_login_probe` began as a bare
`bash -lc 'pnpm --version'`, and a whole `--mode plan` run hung on it — the same corepack shape
that sat in `ep_poll` 57 minutes on grove-1. a hang costs the entire run and yields no output; a
wrong answer costs a reader a minute. see `rule.require.bounded-probes-in-verifies`.

that run surfaced the second half: a login shell CHATTERS (rc files print), so a probe keeps
only the last line — the answer, not the hello before it.

## .a REMOTE probe is the same term, and it inherits both hazards

a probe need not ask the local box. `git.grove.auth.github.set` asks a GROVE four questions over
ssh — is it reachable, does it hold `rhx`, does its rack answer, does it have a rack at all.
each is a probe by this term's own test: one question, one call, answered from evidence.

a remote probe hits BOTH hazards above at once. 2026-08-02 hit both:

1. **the shell is part of the question.** `ssh host 'cmd'` runs a non-login, non-interactive
   shell that sources no rc file. the grove keeps its pnpm dir on PATH via `~/.profile`, which
   only a LOGIN shell reads. so a bare probe reported `rhx` ABSENT on a box that holds it at
   `/home/camper/.local/share/pnpm/rhx`. **the probe measured the SHELL and reported it as a
   fact about the MACHINE** — the remote form of the inference this term forbids. the fix is
   `bash -lc`, and it is not optional.

2. **the chatter came back, over the wire.** with `-l` restored, the grove's `~/.profile`
   printed `keynav started` (the line `1.1.keybinds` appends) into every probe's stdout. the
   local fix is "keep the last line"; the remote fix is stronger — **read the EXIT CODE and
   discard the output.** an exit code carries no banner, and a yes/no answer needs no bytes.

⚠️ the cost of a missed (1): the skill halted with *"5.3.brains never ran"* about a box where
`5.3.brains` had run fine, and named a bundle that would repair no part of it. a probe that
lies produces an error message that lies.

## ⚠️ .a probe must be able to FAIL the way the defect fails

the third hazard, and the costliest on 2026-08-05. it is distinct from both above: this probe
is bounded and it does not lie. it runs, answers truthfully, and is **irrelevant to the
question asked of it.**

> the global `rhx` shim on grove-1 was declared repaired on the evidence of `rhx --help`,
> which printed its usage tree happily. one command later a human ran `rhx keyrack get` and
> got `Cannot find module 'with-simple-cache'`.
>
> `--help` prints from the arg parser and loads no keyrack module, so it is the ONE path
> through that binary which cannot observe an absent keyrack dependency. it was a true
> answer to a question nobody had.

the test, before you trust any probe:

> **if the defect were present, would this probe go red?**
> if it would still pass, it proves the probe ran — never that the box is well.

this is the probe form of `rule.require.clamp-edge-cases`'s demand that a clamp be shown to
bite, and of `rule.require.trust-but-verify` generally. it recurred **three times in one
session** — an assumed `fnm list-remote` format, a `✔ set` read as a value, and this. that is
why it earns a term rather than a line in a log.

⚠️ the tell is a probe chosen for how EASY it runs. `--help` is fast, safe, and needs no
credentials — and each of those is a reason it touches none of the machinery under suspicion.
**reach for the cheapest probe that still exercises the defect, never the cheapest probe.**

## ⚠️ .a probe can be the RIGHT probe and still be blind — the conditions decide

the fourth hazard, measured 2026-08-06, distinct from the third: there the probe was the wrong
one. here the probe is exactly right — bounded, honest, and it does exercise the defect — yet
it still answers ✔ on a broken box, because of **when** it ran or **what was warm** at the
time. three shapes, all met in one session:

| shape | what happened |
|---|---|
| **run after the repair** | four probes were compared for which would redden on an absent vault peer — with the peer already reinstalled. all four passed, and the run proved only that four probes ran |
| **a warm cache answered instead** | with the peer deliberately removed, `keyrack get` STILL returned the pat: an unlocked value is served from the daemon's memory, so the get never reached the vault. the probe was correct and the daemon spoke for it |
| **only the first hop was exercised** | a `require.resolve` of `declastruct-aws` succeeded while the chain was broken one hop deeper at `declastruct`. a lookup FINDS; a require LOADS. the defect lived past where the probe stopped |

so the third hazard's test needs a companion:

> **would this probe go red — under these conditions, right now?**
> not "does this probe exercise the defect", but "is the defect reachable from here".

the discipline that follows: **make the defect, then ask.** remove the package, relock the
session, clear the cache — then run the probe and watch it redden. a probe never seen red is
a hypothesis (`rule.require.clamp-edge-cases`, whose revert-and-watch step is exactly this).

⚠️ the warm-cache shape is cruelest, because it also explains the OUTAGE it hides. that same
daemon memory is why grove-1 cloned happily at 02:13 and was dead by 10:31, rack untouched
between: the 540m session lapsed, and only then did the absent peer matter. **a defect masked
by warm state is a defect on a timer** — it surfaces when no human is there, and it looks like
the world broke rather than the box.

## ⚠️ .a probe can ask about the RIGHT machine and the WRONG process

the fifth hazard, and the subtlest: here the probe is not merely honest — it is **correct, and
correctly designed for its own question.** it simply answers about a different process than
the one that fails.

measured 2026-08-08. `5.8.docker`'s verify asks through `sg docker -c`, which enters the group
a fresh login would grant:

```
5.8.docker.provision.verify   ✔   (asked via `sg docker -c`)
docker compose up             ✋   permission denied on the socket
```

both are true at once. `sg docker` asks *"would a fresh login reach the socket?"* — the right
question for a VERIFY, since a group grant awaits a re-login. the testdb asks a different one:
*"do the groups THIS process holds reach it?"* — and that answer was no.

⇒ so the shape is a third question, beside hazards 3 and 4:

> **whose process does this probe answer about — mine, or a hypothetical one?**

a probe that enters a group, sources an rc, or spawns a login shell has, by that act, built a
process the workload will never be. `gotcha.a-tool-found-by-path-answers-only-a-human` is this
same split on PATH. on env it cost a whole round: a hypothesis about `AWS_SDK_LOAD_CONFIG` was
tested by an export in the SHELL, and both arms came back byte-identical, because the suite's
process had never read either one.

⚠️ the repair is rarely "drop the group entry". keep the verify's question AND add the
workload's — two claims, because they are two facts.

## 🛑 .a probe of N subjects with NO CONTROL cannot tell a pass from a NO-RUN

the sixth hazard, measured 2026-09-01, and it is the first that is not about **what** the
probe touched. hazards 3-5 each end *"the probe answered about the wrong subject"*. this one
ends *"the probe answered about no subject at all, and said ✔."*

a probe compared three rsync flag sets and printed three byte counts. the two SUBJECT arms
were green and agreed. every arm had in fact run the **identical** command: the runner took
`run "-az -v"` as one string, `shift` ate it as the label, and `"$@"` was empty — so all
three measured the default flags.

**ARM 3 was a control**: `-az -v` MUST produce output, by definition of `-v`. it reported
zero bytes, which is impossible of the subject and possible only of the harness.

⇒ so a probe owes at least one arm whose expected result is **known** before it runs:

| arm | expected | what its failure indicts |
|---|---|---|
| the subject arms | whatever holds | the SUBJECT |
| one known-POSITIVE control | must produce a result | the **PROBE** |
| one known-NEGATIVE control | must produce none | the **PROBE** |

> **a control arm is the only part of a probe that reddens when the PROBE is broken rather
> than when the SUBJECT is.**

⚠️ this hazard is invisible to hazard 3's test (*"if the defect were present, would this go
red?"*), because that test is asked of the probe **as designed** and this defect is in the
probe **as built**. a design can be correct and its harness still never reach the subject.

⚠️ and it is the one hazard a green page makes WORSE. N arms that agree read as
corroboration — the more subjects a probe carries, the more its silence persuades.
`gotcha.a-check-that-cries-wolf-gets-silenced`'s m.5 is the same shape at the fixture: a
setup that took in part, so every row was true and the verdict was about a world nobody
meant to build.

## .refs
- src/grove.env.sh                                                   # the three probes and the ladder
- src/grove.provision/5.devtools/5.3.brains/provision.verify.sh         # the require-not-lookup probe that survived that test
- src/grove.provision/5.devtools/5.1.node/configure.verify.sh          # the bounded login-shell probe
- .agent/repo=.this/role=any/briefs/evidence/rule.require.bounded-probes-in-verifies.md  # why a probe is bounded
- .agent/repo=.this/role=any/briefs/grove/provision/howto.detect-env-server.md         # the ladder, its evidence, its tests
- .agent/repo=.this/role=any/briefs/grove/provision/rule.require.conform-to-sdk-environment.md  # why probes live in one file

## .reason
see the ref-level cluster beside this choice:
- `term=probe._.choice.reason.md` — why `is*` lost despite its status as the sanctioned boolean
  prefix, why `ladder` beat `cascade`, and the dated evidence that an unaskable probe hides a
  wrong answer behind a right verdict
- `term=probe._.choice.example=one-question-three-misses.md` — the four hazards above, on ONE
  subject: three probes that each ask *"does this box export `AWS_PROFILE`?"*, each wrong
  differently. read it for the form the four share — **a probe answers about whatever it
  actually touched**. the question you meant is a property of what it reached, never of the
  probe

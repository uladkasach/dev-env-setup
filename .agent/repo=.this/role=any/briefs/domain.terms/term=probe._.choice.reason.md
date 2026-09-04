# domain.term.choice.reason: probe

## .etymology

a **probe** is an instrument you push into a thing to learn what it is made of — a soil probe, a
surgical probe, a space probe. three properties come with the word, and we need all three:

1. it **asks**, and the answer may be no. a probe that could only confirm is an assertion
2. it **touches the subject.** a probe reads the machine, never a value someone already derived
3. it is **one instrument, held alone.** you do not push four probes in at once and read a single
   number off them

it beat `detect`, which names the OUTCOME rather than the act — "cloud detect" reads as though a
cloud turned up, and half of every run's probes correctly find none.

## .disputes

### dispute: `is` (the sanctioned boolean prefix) — raised 2026-07-30 — status: RESOLVED (keep `probe`)

- raised.by  = mechanic, during the rewrite of the platform ladder
- claim      = `rule.require.get-set-gen-verbs` names `is*` as the canonical prefix for a boolean
               check, and every probe returns a boolean. so these should be `grove_env_is_aws_ec2`,
               `grove_env_is_desktop`. a domain-specific verb where a sanctioned prefix fits is
               exactly the drift the get-set-gen rule exists to stop
- counter    = `is*` is a **transformer** prefix, and the rule places it among "pure single-value
               shape work". a probe is not pure and not single-value:

                 · `grove_env_probe_aws_ec2` reads four sysfs files and execs `systemd-detect-virt`
                 · `grove_env_probe_aws_ec2_imds` makes a NETWORK CALL, measured at 1045ms on a
                   laptop where the endpoint never answers

               `is*` promises a reader a cheap answer, free of effects. one of these costs a
               second and touches the network. a name that hides that is
               `rule.forbid.surprises`, and the cost is the exact fact the ladder's ORDER turns
               on — the last property a name should conceal.

               the get-set-gen rule's own decision tree also declines: it routes to a transformer
               prefix only when the operation "transforms shape". a probe transforms no shape. it
               INTERROGATES A MACHINE, closer to a communicator (raw i/o at a boundary) than to a
               transformer — and communicators are not `is*` either.
- resolution = keep `probe`; record `is` as a forbidden synonym **for this concept only**. `is*`
               remains correct everywhere it means a pure check. dispute closed.

### dispute: `cascade` / `chain-of-probes` vs `ladder` — raised 2026-07-30 — status: RESOLVED (keep `ladder`)

- raised.by  = mechanic, who had already drifted across all three in one round
- claim      = `cascade` reads naturally for "try each in turn until one answers", and the first
               draft of `howto.detect-env-server` used it
- counter    = three problems.

               **one:** `chain` is already taken. sdk-environment calls its per-attribute parser
               order a "parser chain", and `rule.require.conform-to-sdk-environment` uses that word.
               a "chain of probes" is a second sense of one word, one scope apart — the
               `moneyType` shape of overload.

               **two:** `cascade` has no member-word. you cannot say *"the third cascade-step is the
               costly one"* without an invented compound. `ladder`/`rung` is a natural pair, and
               `rule.prefer.symmetric-term-pairs` asks for exactly that.

               **three:** `cascade` means *water falls through all of it*. the probe sequence does
               the opposite — it STOPS at the first answer, and the stop is load-bear: it is why a
               laptop never pays imds's 1045ms. `ladder` carries "climb until you are done";
               `cascade` carries "flow through it all", the wrong mental model for the one property
               the order exists to protect.
- resolution = keep `ladder`, with `rung` as its member. record `cascade` and `chain-of-probes` as
               forbidden synonyms. `chain` stays reserved for sdk-environment's parser order, a
               WIDER concept a ladder sits inside — not a synonym. dispute closed.

               `howto.detect-env-server` conformed the same round.

## .evidence

### the round that produced the word, 2026-07-30

the platform detection was one unbroken `if/elif` of raw file tests. it had no word for its parts,
because no caller could address them. two defects lived in it, and **an end-to-end check of the
value it produced saw neither**:

| defect | what it did | why a verdict-check missed it |
|---|---|---|
| the ec2 test | read `/sys/hypervisor/uuid` (absent on nitro) and `product_uuid` (mode 400, root-only). both declined, so a real grove fell through and called itself `local@unix` | the chain had one output. a reader saw a plausible answer and no way to ask either test alone |
| the desktop test | `[[ -n "…${XDG_SESSION_TYPE:-}" ]]`, and a grove publishes `XDG_SESSION_TYPE=tty`. so a headless box answered *"yes, I have a screen"* | it never bit — the ec2 test answered first. an end-to-end check returns `cloud@aws.ec2` and passes clean. **a wrong probe hidden behind a right one** |

the first cost a passphrase prompt opened onto a duct with no tty to answer it. the second
surfaced within an hour of the rewrite, through a play that asks each probe separately — and no
other route would have surfaced it.

> a sequence you can only ask for its verdict cannot tell a correct answer from two errors that
> cancel.

that sentence is the whole justification for the word. `probe` is not decoration on a refactor; it
names the property — **individually askable** — that turns an unprovable chain into a testable one.

### the measurement the word made possible

with probes named, both boxes could be asked question by question:

| | laptop (pop-os) | grove-1 (nitro) |
|---|---|---|
| `aws_ec2` | no | yes |
| `desktop` | yes | no |
| `aws_ec2_imds` | no *(1045ms)* | yes *(7ms)* |
| verdict | `local@unix` | `cloud@aws.ec2` |

the 150× cost spread on the third row fixes its position at the bottom of the ladder. a chain
yields no such number — it is a per-probe fact, and only a named probe has per-probe facts.

### the sixth hazard — a probe may report a claim about a subject it never reached, 2026-08-06

`5.8.docker.provision.verify` ran `docker info`. on a `permission denied` it printed

```
🌙 the daemon is up and this session cannot reach its socket.
```

and returned **0**. two separate faults, and the second is the one this term exists to catch:

- it **asserted what it had not measured.** a socket permission denial proves that the socket
  FILE exists and this user lacks the group. it says no word about whether the engine runs — a
  stopped daemon behind a systemd-activated socket produces the identical message
- it **passed on that assertion.** so a box whose group grant never takes effect reads green
  forever, while every compose stack on it fails with a socket error

the probe was bounded, honest about its own text, and perfectly able to fail — it fails loudly on
an absent binary and on a down daemon. it was blind in exactly one place: **the branch where it
could not ask, it answered anyway.**

the repair is not a softer message. ASK THE QUESTION — `sg docker -c 'docker info'` enters the
group for one command, which is precisely "would a fresh login reach it?". that turns an excuse
into a measurement, and the branch goes red when the answer is genuinely no.

> the five prior hazards are about a probe that measures the wrong subject. this one is about a
> probe that measures NO subject and reports a result regardless — the failhide shape, dressed as
> a probe.

## .invariants

- a probe answers about the MACHINE. a function that reads `$GROVE_ENV_SERVER` is a **predicate**,
  not a probe (`grove_env_server_tier`, `grove_env_server_platform`)
- a probe is callable alone, or it is not a probe. an inline test in a ladder is the defect that
  coined this term
- a probe's name must not hide its cost. that is why `is*` is forbidden here
- a probe adopted on the strength of ONE box is not a probe, it is a true statement. a discriminator
  must fire on one machine and stay silent on another
- a probe that could not reach its subject reports **that**, and never a verdict about the subject.
  "I could not ask" is not an answer to the question, and a branch that returns 0 on it is a
  failhide (`rule.forbid.failhide`). where a re-ask is possible, re-ask

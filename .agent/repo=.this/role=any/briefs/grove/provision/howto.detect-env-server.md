# howto.detect-env-server

## .what

how this repo answers **"which machine is this?"** — the probe ladder in `src/grove.env.sh`, the
evidence each rung rests on, and the test matrix that proves it.

read this before you touch a probe. `rule.require.conform-to-sdk-environment` governs the
*vocabulary* (`access` / `server` / `commit`, derived once); this governs the *detection*.

## .why it deserves its own brief

`$server` is the one attribute the repo has to **measure** rather than declare, and a wrong answer
is not cosmetic. every interactive step in the tree gates on it:

```sh
[[ "$GROVE_ENV_SERVER" != "local@unix" ]] || <offer the human a prompt>
```

so `$server` decides whether a box gets offered a prompt. get it wrong on a headless box and
`ssh-keygen` opens a passphrase prompt onto a duct with no tty to answer it — measured
2026-07-30, and the reason this file exists.

---

## .the ladder

two platforms, three probes, no fallback. climb it cheapest-first, and stop at the first answer —
the **stop** is load-bear, and it is why a laptop never pays imds's second.

| # | probe | asks | cost | fires on |
|---|---|---|---|---|
| 1 | `grove_env_probe_aws_ec2` | dmi vendor ×4 · `systemd-detect-virt` · cloud-init `cloud-id` · xen uuid | free | a grove |
| 2 | `grove_env_probe_desktop` | `WAYLAND_DISPLAY` · `DISPLAY` · `XDG_SESSION_TYPE` **by value** | free | a laptop at its keyboard |
| 3 | `grove_env_probe_aws_ec2_imds` | `169.254.169.254`, capped at 1s | **~1s when absent** | an ec2 box whose dmi did not answer |
| — | *no probe answered* | — | — | **✋ refuse, exit 2** |

ahead of all of it sit the two overrides the contract's parser order already blesses:
`GROVE_ENV_SERVER` (a full `$tier@$platform`), then `--for local|cloud` (a **tier only** — the
platform is still inferred).

### .why the ec2 probe is four rungs and not one

aws's own guidance is that **only the instance identity document (over IMDS) is authoritative**;
every cheap signal is explicitly a heuristic:

> this method is quick, but potentially inaccurate because there's a small chance that a system
> that is not an EC2 instance could have a UUID that starts with these characters
>
> — aws, *detect whether a host is an ec2 instance*

so no free rung is trustworthy alone, and the answer is **breadth**: four independent facts, any
one of which suffices, no two of which share a failure mode.

### .why imds is last, for TWO reasons

**cost.** measured: 7ms on a grove, **1045ms on a laptop**, a 150× spread. it may run only where
the free probes have all declined.

**availability.** imds is the one probe an operator can switch off:

> enables or disables the HTTP metadata endpoint on your instances. if you specify a value of
> **disabled**, you cannot access your instance metadata
>
> — aws, `modify-instance-metadata-options --http-endpoint disabled`

and `--http-put-response-hop-limit` (default 1) can put it out of reach of a container or a nested
netns, while a hardened ami may firewall the address for non-root.

so the two halves of the ladder fail in **opposite directions**, which is the whole reason to keep
both:

| | aws's verdict | can it be turned off? |
|---|---|---|
| the free rungs | *"potentially inaccurate"* | **no** — dmi is firmware, cloud-init's record is on disk |
| imds | authoritative | **yes** — switchable, hop-limited, firewallable |

an ec2 box with imds disabled still answers rung 1. an ec2 box with masked dmi still answers imds.
**"authoritative" is not the same claim as "always present."**

---

## .the evidence

nine candidates were measured on **both** boxes, 2026-07-30. a signal is a *discriminator* only if
it fires on one and stays silent on the other — a signal true of both is not a probe, however true.

| candidate | laptop (dell · pop-os) | grove-1 (r5.xlarge · nitro) | verdict |
|---|---|---|---|
| dmi `sys_vendor` | `Dell Inc.` | `Amazon EC2` | **kept** (rung 1) |
| dmi `chassis_vendor` | `Dell Inc.` | `Amazon EC2` | **kept** (rung 1) |
| dmi `bios_vendor` | `Dell Inc.` | `Amazon EC2` | **kept** (rung 1) |
| `systemd-detect-virt` | `none`, exit 1 | `amazon`, exit 0 | **kept** (rung 1) |
| cloud-init `cloud-id` | absent | `aws` | **kept** (rung 1) |
| imds token | no answer, 1045ms | answered, 7ms | **kept** (rung 3) |
| `/sys/hypervisor/uuid` | absent | **absent** (nitro) | kept as last rung, for xen only |
| dns search domain | `<isp-lan>` | `ec2.internal` | ✗ a dhcp OPTION SET; a vpc may carry any domain |
| hostname | `pop-os` | `ip-<private-ip>` | ✗ a human renames a host; provisioners rename first |
| block device model | `NVMe Micron 1024GB` | `Amazon Elastic Block Store` | ✗ needs `lsblk` — a package, not a file |
| nic driver | `iwlwifi` | `ena` | ✗ an interface walk; an instance may carry other nics |
| route to `169.254.169.254` | `via <lan-gateway>` | `via <vpc-gateway>` | ✗ **not a discriminator** — both answer |
| `product_uuid` | mode 400 | mode 400 | ✗ ROOT-ONLY; a provision run is not root |
| every `AWS_*` envvar | unset | **unset** | ✗ ec2 publishes no envvar at all |

### .the three acceptance criteria a candidate must pass

1. **it differs** between a grove and a laptop
2. **it costs no network call** (imds is the one deliberate exception, placed last)
3. **it is readable by a NON-ROOT user** — the criterion that killed `product_uuid`

### .the envvar question, settled

*"can we detect ec2 by envvar?"* — **no.** measured on a real grove, every aws-related envvar was
unset. ec2 publishes none.

and the `AWS_*` family must never be consulted even where set: `AWS_REGION`, `AWS_PROFILE`,
`AWS_ACCESS_KEY_ID` are set by a **human or by the aws cli**. they say *"this box talks to aws"*,
never *"this box IS aws"* — a laptop with credentials configured sets every one. an envvar is a
usable fact only when the **platform** sets it.

---

## .why there is NO fallback

🛑 **never close the derivation with a default:**

```sh
tier="${tier:-local}"; platform="${platform:-unix}"   # 👎
```

that silently calls an unknown box a laptop and reports success — `rule.forbid.failhide` in its
purest form. the guess is not neutral either: `local@unix` is the value every gate reads as
*"a human is at a keyboard"*, so the default for "I could not tell" is the more dangerous of
the two answers.

a fallback exists to cover boxes you cannot enumerate. **we own every machine this runs on**, so
there are none. the honest response to "no probe fired" is not to pick the likelier of two — it is
to say so and name the fix:

```
✋ cannot tell which machine this is — no platform probe answered
   fix — name the box yourself:
     GROVE_ENV_SERVER=local@unix    grove.provision   # a laptop
     GROVE_ENV_SERVER=cloud@aws.ec2 grove.provision   # a grove
```

> we control our environments. so the job is not to guess well — it is to detect reliably, and to
> refuse when we cannot.

---

## .the test cases

a `verify.env.server.probes` play asks **each probe on its own**, then the
verdict. run it on both boxes after any change here.

```sh
# a grove, through its duct (rule.require.reach-a-grove-through-its-duct)
rhx git.grove.push grove-1 --from . --into git/more/dev-env-setup.wip --mode apply
rhx git.grove.send grove-1 --play verify.env.server.probes
rhx git.grove.read grove-1 --lines 30

# the laptop, through a LOCAL duct — same shape, empty host in the uri
rhx duct.open --on 'duct:///envprobe/mechanic'
rhx duct.send --on 'duct:///envprobe/mechanic' \
  --what "bash /abs/path/to/verify.env.server.probes.play.sh"
rhx duct.read --on 'duct:///envprobe/mechanic' --lines 40
rhx duct.stop --on 'duct:///envprobe/mechanic'
```

> ⚠️ pass the play an **absolute** path. a fresh duct does not inherit your shell's cwd, so a
> relative `.agent/…` may point somewhere else and the play will not be found.
>
> the play itself is cwd-independent by design: it prefers `~/git/more/dev-env-setup/src` and falls
> back to the source tree it sits in, so it reads the right `grove.env.sh` from either box.

### the matrix

| # | given | then `$server` | gate | proven? |
|---|---|---|---|---|
| 1 | a grove | `cloud@aws.ec2` | CLOSED | ✔ measured on grove-1 |
| 2 | a laptop at its own keyboard | `local@unix` | OPEN | ✔ measured on pop-os |
| 3 | an ec2 box with dmi masked | `cloud@aws.ec2` via rung 3 | CLOSED | ✗ reasoned — no such box to hand |
| 4 | an ec2 box with imds disabled | `cloud@aws.ec2` via rung 1 | CLOSED | ✗ reasoned |
| 5 | a laptop reached over ssh | **refuses**, exit 2 | — | ✗ reasoned |
| 6 | `GROVE_ENV_SERVER` set | that value; no probe runs | per value | ✔ by inspection |
| 7 | `--for cloud` on a grove | `cloud@aws.ec2` — tier stated, platform still inferred | CLOSED | ✔ |
| 8 | `--for local` on an undetectable box | **refuses** — a tier is not a `$server` | — | ✗ reasoned |

> rows 3–5 and 8 are **reasoned, not measured**, and that is precisely the status this file paid a
> day to learn to distrust. treat them as claims. if you can produce the box, measure it and
> promote the row.

### the per-probe results this must reproduce

| | laptop | grove-1 |
|---|---|---|
| bash / zsh parse | ✔ ✔ | ✔ ✔ |
| `aws_ec2` | no | **yes** |
| `desktop` | **yes** | no |
| `aws_ec2_imds` | no *(1045ms)* | yes *(7ms)* |
| `$server` | `local@unix` | `cloud@aws.ec2` |
| gate | OPEN | CLOSED |
| full derivation | 272ms | 11ms |

the laptop's 272ms is the `commit` attribute's git calls — **not** detection. imds is never reached
by the derivation there, because the ladder stops at rung 2. that is the number to watch: if a
laptop run ever costs ~1.3s, a probe above imds has started to decline.

---

## .why per-probe, and not just the verdict

both defects found on 2026-07-30 were **invisible to an end-to-end check**:

### 1. the ec2 probe — a chain nobody could ask

two uuid tests sat mid-chain. on a nitro box `/sys/hypervisor/uuid` is absent (a xen-era file) and
`product_uuid` is mode 400 (root-only). both declined, the chain fell to `local@unix`, and a real
grove called itself a laptop. no one could run either test alone, so the wrong answer hid behind a
verdict that looked right for as long as it existed. it also hid behind `--for cloud`, whose
explicit tier sidesteps inference — so it surfaced only on the path a grove actually takes.

### 2. the desktop probe — a wrong probe behind a right one

its body was `[[ -n "${WAYLAND_DISPLAY:-}${DISPLAY:-}${XDG_SESSION_TYPE:-}" ]]` — non-empty across
all three concatenated. a grove publishes `XDG_SESSION_TYPE=tty`, so a **headless box answered
"yes, I have a screen."**

it never bit, because rung 1 answers first on that box. an end-to-end check returns
`cloud@aws.ec2` and passes clean. only a per-probe check finds it — and it would have surfaced the
instant rung 1 declined, which is precisely case 1 above.

> a ladder you can only ask for its verdict cannot tell a correct answer from two errors that
> cancel.

the fix in both places is the same: probes are **named functions**, so a box can be asked one
question at a time.

---

## .how to add a platform

the set is closed at two. `aws.lambda` and `cicd` probes were **removed** 2026-07-30 — both
correct, neither with a machine to run on. an unrun probe is an unproven probe.

when a third box arrives:

1. write its probe as a named function in `src/grove.env.sh` — never inline at a call site
2. **measure it on that box and on one it must stay silent on**
3. give it a rung, ordered by cost
4. add a row to the matrix above, and to the play
5. state its `$tier@$platform` — e.g. a ci runner is `local@cicd`: local tier, **no human**, which
   is the case a two-valued `local|cloud` tag cannot express

do not pre-build it. that is what the removed pair was.

## .see also

- `rule.require.conform-to-sdk-environment` — the vocabulary and the one-derivation rule this serves
- `rule.forbid.failhide` (mechanic) — why a default beats no answer is exactly backwards here
- `rule.require.errors-name-the-fix` (ergonomist) — the shape of the refusal
- `rule.require.reach-a-grove-through-its-duct` — how the grove half of the matrix is run
- `src/grove.env.sh` — the probes, each with its evidence beside it
- ⚠️ the two signal sweeps that produced `.the evidence` table were **removed 2026-08-11**.
  they were exhibits, not tools: each ran a fixed candidate list once, on two boxes, and that
  answer IS the table above. a sweep kept beside its own table is a second home for one fact
  (`term=drift`), and the one that goes stale in silence.
  <br>⇒ to re-measure, write a fresh sweep against the box in front of you. the candidate list
  was the value; the runner never was.
- [aws — detect whether a host is an ec2 instance](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/identify_ec2_instances.html)
- [aws — modify-instance-metadata-options](https://docs.aws.amazon.com/cli/latest/reference/ec2/modify-instance-metadata-options.html)

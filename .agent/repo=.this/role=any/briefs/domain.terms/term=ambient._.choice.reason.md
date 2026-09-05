# domain.term.choice.reason: ambient

## .etymology

`ambient` is borrowed from its plain english sense — *of the surroundings; present all
around, unbrought*. ambient light is the light already in a room; you do not switch it on.
an ambient identity is the identity the box already carries; you do not place it.

that is precisely the fact the repo needed a word for. a grove holds an iam instance role
because it IS an ec2 instance, not because any bundle put one there — so every verb this
repo owns (`set`, `gen`, `fill`) is the wrong verb for it, and the only honest operation
is to NAME it.

the word is also what the profile is literally called on disk (`[profile ambient]`), so a
human who greps `~/.aws/config` and a human who reads a brief find the same word.

## .the trace that forced the word — 2026-08-07

svc-chat's 19 integration suites all died at `AWS_PROFILE not set`. the first read of that
was "the grove has no aws credential" — which was false, and a hop-by-hop trace showed
where the truth sat:

```
a. IMDS                        ✔ role <camp-grove-role>
b. aws sts (bare, no profile)  ✔ account <camp-acct>
c. aws configure export-creds  ✔ emits AWS_ACCESS_KEY_ID / SECRET / SESSION_TOKEN
d. useKeyrack.ts:55            ✋ throws — AWS_PROFILE is unset
```

hop c is the exact call `useKeyrack.ts:60` makes. so the credentials existed, and exported
cleanly, through the very command the consumer runs. **one pointer was absent.**

⇒ the vocabulary had no way to say that. the repo's only credential noun was `rack`, which
means "a thing we placed" — and to describe the instance role as a rack entry that was
`absent 🫧` asserts a falsehood about it. it is not absent and never will be; it is
ambient, and what was absent was a NAME for it.

> a defect had gone unseen for as long as the vocabulary could not express it. the
> diagnosis and the term arrived in the same hour, which is the usual order.

## .why each forbidden synonym is forbidden

- **`instance`** — aws's own word (`Ec2InstanceMetadata`), and it binds the term to ONE
  platform. the concept is about provenance; a container's projected service-account token
  is ambient too, and is no instance role. it also collides with `instance` as "one live
  copy of a program", which this repo says often.
- **`default`** — names a PRECEDENCE, not an origin. the aws sdk has a "default credential
  chain" in which the instance role is merely the last rung; to call the identity `default`
  would conflate where it comes from with where it sits in a lookup order.
- **`imds`** — a transport, not a property. a term that names the mechanism goes stale the
  moment the mechanism changes, and it cannot describe the same concept off aws at all.
- **`inherited`** — implies a parent that handed it down, and a child that could refuse it.
  an ambient identity has no donor; it is a property of the machine.
- **`implicit`** — reads as "not written down", which is the opposite of what the phase
  does. the whole point is that the ambient identity is now EXPLICITLY declared, as
  `[profile ambient]`. the identity is ambient; its declaration is explicit, and a word
  that muddles those two would make the phase sound like a hack.

## .evidence

- the `rack` / `ambient` split, which is what makes the term load-bearing rather than
  decorative: a rack credential is fetched, stored, rotated by us, and its absence is a
  fillable gap; an ambient one is none of those, and its absence is a fact about the box
  that no `keyrack set` can change. code that treats one like the other fails in a way that
  reads as a credential problem when it is a vocabulary problem
- the phase writes a POINTER and never a value, and the term is why that reads as correct
  rather than as a shortcut: an ambient identity's keys rotate on the platform's clock, so
  a stored copy is stale by design
- measured by a `diagnose.grove-ambient-aws` probe — the four-hop trace above
- `src/grove.provision/5.devtools/5.6.aws/configure.verify.sh` — proves the ambient profile
  yields credentials, not merely that its text is present

## .disputes

none open.

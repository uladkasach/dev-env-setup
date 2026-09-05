# domain.term: wrapper

term.chosen   = wrapper
term.kind     = noun
term.synonyms.forbidden:
- shim         (a shim REDIRECTS and adds no behavior; a wrapper adds behavior — see `term=shim`)
- workaround   (names a verdict, not a shape — and prejudges; a wrapper is a fine DIAGNOSTIC)
- prefix       (names its position on a line, which is incidental — an env var wraps too)
- harness      (a harness runs a subject under measurement; a wrapper changes what the subject gets)
- helper       (says no word about what it does — forbidden by `rule.forbid.term=helpers`)

## .what

a command that runs another command with something ADDED — a group entered, an env
var set, a shell interposed:

```sh
sg docker -c 'docker info'          # adds a group membership
zsh /tmp/run.suite.zsh              # adds an rc/env read
AWS_PROFILE=ambient npm test        # adds a variable
```

it is the **counterpart of `shim`** on the does-it-add-behavior axis, and that pair is
what makes each word load-bear: a shim adds none and only redirects, so it is legitimate
forever; a wrapper adds what the bare command lacked, so it always names a gap.

## .the one question a wrapper always raises

> **who supplies this on a laptop, and why does the grove not?**

a wrapper a laptop does not need is a **measurement of a provision gap** — and never a
fix for it (`rule.require.identical-commands-on-every-server`). so it has exactly two
legitimate lifetimes:

| kind | lifetime | example |
|---|---|---|
| **diagnostic** | temporary — it locates the gap, then is deleted | `sg docker -c 'docker info'` while the group grant is chased |
| **probe-internal** | permanent, inside a verify, as a QUESTION | `5.8.docker.provision.verify` re-asks under `sg` to mean "would a fresh login reach it?" |

a wrapper kept in a play, a proof, or a human's muscle memory is neither. it is a gap
frozen in place, and the next command that needs the same thing fails for a reason the
last one already concealed.

## .refs

- `rule.require.identical-commands-on-every-server.md` — the rule this term serves
- `src/grove.provision/5.devtools/5.8.docker/provision.verify.sh` — the legitimate,
  permanent, probe-internal kind (`sg docker -c 'docker info'` as a question)
- `term=shim._.choice._.md` — the counterpart it is most often confused with

## .reason

see the ref-level file beside this choice:

- `term=wrapper._.choice.reason.md` — etymology, the 0-vs-31 measurement that forced the
  word, the resolved dispute against `shim`, and why each forbidden synonym is forbidden

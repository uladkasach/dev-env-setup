# domain.term: power.restart

term.chosen   = power.restart
term.kind     = verb (prefixed by its context, per `domain.terms/.readme.md`)
term.synonyms.forbidden:
- machine.reboot  (it EXISTED, as `systemctl reboot`, and the cost was measured — see below)
- reboot          (bare, and already spoken for in another context: `duct.reboot`)
- restart         (bare; it claims the whole repo, and a duct/service/session each restart too)

## .what

take this machine down and back up, **and snap the kitty window/pwd map first**.

```sh
alias power.restart='kitty.snap; reboot'
```

the snap is not a decoration on the verb — it is half of what the verb means. a reboot a
human types is the one reboot known in advance, so it is the cheapest place to save the map
(`term=snapshot`, `4.3.4.snapshot`).

## 🛑 .the noun split — where a new alias of this family goes

| namespace | owns | members |
|---|---|---|
| `power.*` | the POWER-STATE transitions | `power.off`, `power.restart`, `power.suspend` |
| `machine.*` | the SESSION-level acts | `machine.lock`, `machine.logout` |

⇒ ask which one a member changes. a reboot changes the power state, so it is `power.*`.
a lock leaves the machine powered and awake, so it is `machine.*`.

## ⚠️ .`machine.reboot` is forbidden, and it is forbidden because it EXISTED

it stood beside `power.restart` for as long as both did:

```sh
alias machine.reboot='systemctl reboot'      # ✋ deleted 2026-09-03
alias power.restart='kitty.snap; reboot'
```

one act, two words — but **not two equal words**. the pair was asymmetric in a way no
reader could see at the prompt: both reboot, and only one comes back with your terminals.

⇒ that is what earns a forbidden-synonym entry rather than a shrug. an ordinary synonym
costs drift. this one **cost the map**, silently, to whoever picked the wrong half — and
the wrong half was on the WRONG NOUN too, so it read as the more general of the pair.

⚠️ and the repo's only recommendation of a reboot named the lossy one:

```
src/grove.provision/1.system/1.2.power/configure.upsert.sh:174
  🌙 awaits a session restart — run 'machine.logout' or 'machine.reboot'
```

so the surface that TAUGHT the verb taught the half that discards the map — the same shape
as `rule.forbid.the-driver-by-path`'s ~140 worked examples. found by a human's one question:
*"why is there an alias of reboot and restart?"*

## .refs

- `src/bash_aliases.sh` — the declaration, with the ban recorded inline where the alias stood
- `src/grove.provision/1.system/1.2.power/configure.upsert.sh` — the fix-text, repaired
- `.agent/repo=.this/role=any/briefs/desktop/system/system.power.spec.md` — the command table
- `.agent/repo=.this/role=any/briefs/desktop/term/howto.restore-kitty-session.md` — why the snap
- `term=snapshot._.choice.reason.md` — the one-writer rule for the snap

## .reason

see the ref-level cluster beside this choice:
- `term=power.restart._.choice.reason.md` — etymology, the dated judgment, the evidence

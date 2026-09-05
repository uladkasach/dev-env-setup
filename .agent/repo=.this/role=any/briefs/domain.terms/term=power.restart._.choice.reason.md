# domain.term.choice.reason: power.restart

## .etymology

`restart` over `reboot` for one reason that survives the whole family: **`reboot` is already
spoken for in this repo.** `duct.reboot` means *replace the program a pane holds with a fresh
shell* — a real, distinct act on a different object. the `.readme.md` scope rule permits both
under prefixes, but a near-collision on the bare word invites exactly the drift that produced
this term's forbidden synonym.

`power.` over `machine.` because the namespace answers **what the act changes**:

| namespace | what a member changes |
|---|---|
| `power.*` | the machine's POWER STATE — off, down-and-up, suspended |
| `machine.*` | the SESSION on a machine that stays powered — locked, logged out |

that split is the reusable half of this cluster. `power.restart` is one instance of it; the
rule tells a future author where the next alias goes with no further argument.

## .disputes

### dispute: machine.reboot  —  raised 2026-09-03  —  status: RESOLVED (keep `power.restart`)

- raised.by  = the human, with one question — *"why is there an alias of reboot and restart?"*
- claim      = both aliases shipped and both rebooted the box, so one of them is surplus and
               the pair is a plain synonym to collapse either way
- counter    = they were **not** interchangeable. `power.restart` ran `kitty.snap` first;
               `machine.reboot` was a bare `systemctl reboot`. so the pair was asymmetric,
               and the asymmetry was invisible at the prompt — both reboot, and only one
               brings the terminals back. a human who picked the terser half, which also
               read as the more general of the two, lost the window/pwd map with no signal
               at all. it was on the wrong noun besides: a reboot changes the POWER state.
- resolution = `power.restart` is canonical. `machine.reboot` is deleted, not deprecated —
               a kept alias is a live second path (`rule.require.grove-provision-as-the-only-entrypoint`,
               the forwarder argument, applied at alias scale). the ban is recorded inline
               in `src/bash_aliases.sh` where the alias stood, so the next author meets it
               at the place they would re-add it. dispute closed.

## .evidence

### the measurement, 2026-09-03

```
src/bash_aliases.sh:125  alias machine.logout='loginctl terminate-user "$USER"'
src/bash_aliases.sh:126  alias machine.reboot='systemctl reboot'
src/bash_aliases.sh:486  alias power.restart='kitty.snap; reboot'
```

live references to the forbidden half: **two.** its own declaration, and one fix-text —

```
src/grove.provision/1.system/1.2.power/configure.upsert.sh:174
  🌙 awaits a session restart — run 'machine.logout' or 'machine.reboot'
```

⇒ so the repo's **only** recommendation of a reboot named the lossy half. that is the
`rule.forbid.the-driver-by-path` shape at a smaller radius: a reader meets the worked
example before any rule, so one bad example outranks the paragraph beside it.

### why a deletion and not a deprecation

`power.restart`'s own `.why` block already carried the argument, one screen away from the
alias that defeated it:

> a deliberate reboot is the one power event we know of in advance, so it is the cheapest
> place to save the window/pwd map.

a deprecated `machine.reboot` would keep that cheapest place reachable by a verb that
skips it. the `install_env` forwarder precedent applies: *a forwarder that still works IS
a second path*, and two paths must be kept honest with each other forever.

### the residue

no clamp reads the alias namespaces, so a future `machine.reboot` would be caught by a
reader and not by a check. it is one grep if it is ever worth one:

```sh
rhx grepsafe --pattern "^alias machine\.(reboot|off|suspend)" --glob 'src/bash_aliases.sh'
```

⚠️ **not written as a play.** the population it would guard is one entry, the ban is stated
where a re-add happens, and a check nobody runs decays into a false ✋ on its own
(`gotcha.a-check-that-cries-wolf-gets-silenced`, m.13). recorded here as a judgment, so a
later reader knows the absence was chosen rather than missed.

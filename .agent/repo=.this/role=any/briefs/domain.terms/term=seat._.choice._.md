# domain.term: seat

term.chosen   = seat
term.kind     = noun
term.synonyms.forbidden:
- user         (names the UNIX ACCOUNT, which is one third of a seat. a seat is
                the account PLUS the reach to it PLUS the powers it holds. two
                boxes can carry a `ground` user and only one grant you a seat)
- login        (names the ACT of arrival, not the durable arrangement)
- account      (taken, and at a different subject — an aws account, per `term=env`)
- role         (taken by rhachet; and an iam role is a separate concept again)
- identity     (what a seat AUTHENTICATES as; a seat is the whole arrangement)
- grove        (taken — a grove is the BOX. one grove holds many seats)
- profile      (reads as an aws profile or a shell profile, both live here)

## .what
one **reachable login on a grove, with its own home and its own powers**. a box
carries several; they are not interchangeable, and which one you sit in decides
what a command can do.

```
grove-ahbode-v20260810          → seat: camper, NO sudo   → runs the agent, ducts, trees
grove-ahbode-v20260810.ground   → seat: ground, NOPASSWD  → converges the box
```

## ⚠️ .a seat is three facts, and all three must hold

| | what it means | absent it, you have |
|---|---|---|
| an **account** | a unix user exists on the box | a name, and no way in |
| **reach** | your key is in its `authorized_keys`, and sshd allows it | a user you cannot be |
| **powers** | sudo, group membership, a writable home | a login that can look and not act |

a registry entry names a seat, not a box: `<grove>` and `<grove>.ground` share one
exid and one tunnel, and differ only in which seat they take.

## ⚠️ .a FOURTH fact, measured 2026-08-11 — the seat's login-shell RECORD

the three above decide whether you can act. a fourth decides **what shell answers you**,
and it is per-seat because it lives in `/etc/passwd`:

```
ground:  …:/usr/bin/zsh    ← `sudo chsh` SUCCEEDED — this seat has NOPASSWD
camper:  …:/bin/bash       ← and was refused — this seat has no sudo
```

so `ssh <seat> '<cmd>'` runs `zsh -c` on one seat and `bash -c` on the other, on ONE box.
that changes which startup files load, hence which tools sit on PATH, hence whether a
credential helper answers — and the command you typed shows none of it.

⇒ **powers and shell are coupled**: the seat that lacks sudo cannot write its own record,
so the seat that does the WORK most likely sits on the stock shell. same shape as every
other seat-split defect here — the constrained seat needs what it cannot grant itself
(`rule.require.seam-claims-have-an-owner`).

## ⚠️ .a FIFTH fact, measured 2026-08-12 — a seat converges its OWN home, and only that

`grove.provision` is per-seat. ground's run reported `done` with zero claims while camper's
`$HOME` was still bare; camper then needed its own full run to write its own rack manifest,
its own clones, its own `~/.local/bin`.

⇒ **a green run on one seat proves that seat, never the box.** `ground — ✔ 127 · ✋ 0` reads
like a converged machine and is a converged half. that is why rung 4 of `git.grove.ready.verify`
climbs BOTH seats and prints them on separate lines; a single tally would hide it.

## ⚠️ .the verdict a seat owes when the subject is the BOX — added 2026-08-12

fact 5 says a seat converges its own `$HOME`. its corollary sat unstated for a day and cost
five ✋ on one apply: **a seat also converges no fact OUTSIDE any `$HOME`** — a sysctl key, a
systemd unit, an `update-alternatives` selection, a `/etc` config. those belong to the box,
and the seat with sudo sets them, through this same bundle.

so when an upsert's subject is box-wide, the seat owes one of three verdicts:

| what the seat reads | verdict |
|---|---|
| the fact already holds | `•` … `✔`, return 0 |
| it does not, and this seat has root | set it |
| it does not, and this seat has no root | `🌙` — `bundle.root.declines` |

the third row is a **decline**, for `term=decline`'s second reason (*not observable — or here,
not writable — from this seat*), so it coins no new word. and the read that picks the row is
always free: every box-wide fact has a read-only query that needs no root (`sysctl -n`,
`systemctl is-enabled`, `cmp`, `update-alternatives --query`).

⇒ **a ✋ here would be a defect of privilege dressed as one of state.**

## ⚠️ .the camper's docker reach is SETTLED — a rootless daemon, never the group

three refs below stand OPEN on *"what powers does the camper lack?"*. for docker the answer
is measured: the camper lacks the group and needs none.

```
id -nG camper                             →  camper
docker context inspect --format …Host     →  unix:///run/user/1002/docker.sock
```

uid 1002 IS camper — its reach is a **daemon of its own**, in its own runtime dir. that same
hour it pulled an image and ran a postgres container for a test suite.

⇒ do NOT close this gap with a grant of the `docker` group to `camper`. that is
root-equivalent reach on the host, the precise power this seat exists without. an absent
power is a defect only when the seat's work needs it, and here the work already lands
another way.

## ⚠️ .why the word is load-bear

a bundle that cannot write `/etc` reports **"the config is absent"** — the exact
words it reports when the config genuinely is absent. so a run from the wrong seat
and an unconverged box read **identical in the output**.

⇒ a convergence read carries no meaning until you name the seat it came from.

## .the free check
```sh
rhx git.grove.send <seat> --play prove.ground-seat-converges --bare \
  --why 'a verify needs the remote verdict; the duct returns only the send'
```

## .refs
- src/bundle.upgrade.sh                                     # `bundle.root.declines`
- src/grove.pkg.sh                                         # `pkg_can_sudo` — the free read
- .agent/repo=.this/role=any/skills/git.grove.ready.verify.sh   # `SEATS`, `_ask_at`, rung 4
- .agent/repo=.this/role=any/briefs/grove/reach/howto.add-a-new-grove.md  # `.the two seats`
- ahbode/infrastructure                                     # rule.forbid.camper-sudo.md — the split, and the userdata that mints both seats at first boot

## .reason
see the ref-level cluster beside this choice:
- `term=seat._.choice.reason.md` — the etymology, the `user` dispute, and the
  2026-08-10 measurement that settled it

# domain.term.choice.reason: seat

## .etymology

a **seat** is a position you occupy — and which position you occupy decides what you can
reach. that is exactly the property this word must carry: two logins on one box are not
interchangeable, because one can write `/etc` and the other cannot.

the alternatives each name one third of the arrangement and drop the other two:

- **user** names the unix account, and says none of the reach or the powers
- **login** names the act of arrival, and says none of what the arrival gets you
- **identity** names what a login AUTHENTICATES as, not the whole arrangement

`seat` is the only word among them that reads as *the whole position*, so a sentence like
"which seat did you run that from" asks the right question. "which user" invites the answer
"camper", which is true and useless.

## .the measurement that settled it — 2026-08-10

a fresh grove was handed over and converged twice from the `camper` seat:

| run | ✔ marks | ✋ claims |
|---|---|---|
| fresh box, camper seat | 9 | 78 |
| after one apply, camper seat | 13 | 72 |
| after one apply, **ground** seat | 90 | 23 |

the camper apply closed **6 of 78** claims. every claim it missed was a system write — apt,
`/etc`, a systemd unit. the ground apply, on the same box, in the same minute, closed 77.

⚠️ **the discovery that makes the word load-bear:** the two runs are indistinguishable in
their output. a bundle that cannot write `/etc` reports *"the config is absent"* — which is
the exact sentence a bundle reports when the config genuinely is absent. so a convergence
read taken from the wrong seat and an unconverged box read identically, and no amount of
care at the READ end can tell them apart.

⇒ a convergence read is meaningless until you name the seat it was taken from. a word was
needed for the thing that must be named, and `user` was not it.

## .the third fact — a seat owns a HOME

the two-seat split also splits the home directory, and this is the half most apt to be
missed. a run from `ground` converges the system **plus ground's home**. camper's home is
still bare: no `~/.profile` hook, no `~/.local/bin`, no rc files.

the bundle tree carries no target-user axis, so until it does, the run happens twice — once
per seat. a word that named only the account would not have made that consequence visible.

## .disputes

### dispute: user — raised 2026-08-10 — status: RESOLVED (keep `seat`)
- raised.by  = the robot that measured the split
- claim      = `user` is the unix word, already in `sshd_config`, `whoami`, `/etc/passwd`.
               a new coinage where a standard word exists is a cost with no payer.
- counter    = `user` names the ACCOUNT, which is one third of the arrangement. the other
               two thirds — whether your key is in its `authorized_keys` and sshd allows
               it, and whether it holds sudo — are what actually decide a run's outcome.
               two boxes can each carry a `ground` user and only one grant you reach. so
               "the ground user" is true of both boxes and predicts neither, whereas "a
               ground seat" is a claim you can check and act on.
               ⚠️ additionally, the registry entry `<grove>.ground` names a seat, not a
               box: it shares one exid and one tunnel with `<grove>` and differs only in
               which login it takes. `user` cannot name that record without confusion,
               since the record is not a user at all.
- resolution = keep `seat`; record `user` as a forbidden synonym. the unix account keeps
               the word `user` in its own layer (a `useradd` call, an `AllowUsers` line);
               a seat is what this repo reasons about.

### dispute: box — raised 2026-08-10 — status: RESOLVED (keep both, they differ)
- raised.by  = the same round
- claim      = a `grove` already names the remote machine; a second noun for the same
               subject is sprawl.
- counter    = they are not the same subject. one grove holds **many** seats. the registry
               proves it: `grove-ahbode-v20260810` and `grove-ahbode-v20260810.ground` are
               two entries with one exid, one tunnel, one disk — and different powers.
               `grove` : `seat` is one : many, so one word cannot carry both.
- resolution = keep both. `grove` = the box. `seat` = a reachable login on it, with its own
               home and its own powers. `grove` joins the forbidden-synonym list of `seat`
               to keep the boundary explicit in both directions.

## .evidence

the claim that this repo DECLARES seats — rather than that a robot wrote the word down
once (`gotcha.my-own-note-became-my-evidence`) — rests on shipped code, not on prose:

- `.agent/repo=.this/role=any/skills/git.grove.ready.verify.sh` — declares a `SEATS` array,
  drives rung 4 once per seat with **ground first**, and takes `_ask_at "$SEAT"` as its
  transport. the seat is a loop variable in a shipped skill, not a turn of phrase.
- measured by a `prove.ground-seat-converges` probe — the four powers a convergence seat
  must hold: identity, passwordless root, apt, a live systemd. it exited 0 only when all
  four held, so "is this a convergence seat" is a checkable question.
- the registry itself — two json entries under one exid is the data shape a seat names.

## .refs

- `.agent/repo=.this/role=any/skills/git.grove.ready.verify.sh`
- `.agent/repo=.this/role=any/briefs/grove/reach/howto.add-a-new-grove.md` — `.the two seats`
- `ahbode/infrastructure` → `rule.forbid.camper-sudo.md` — the split's rule, and the
  userdata that writes it. it lives THERE because the seats are born at first boot,
  which is that repo's to declare and none of ours

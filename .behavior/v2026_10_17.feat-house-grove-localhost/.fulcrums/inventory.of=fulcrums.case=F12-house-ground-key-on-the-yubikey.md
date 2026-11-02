# F12 — the house ground authorizes the human's yubikey-held key, never a key file

## .the premise that fell
case=1 and case=3 said *"the ground key goes to the human, never where the supervisor's uid can
read it"*. on a house grove that sentence is unbuildable: the supervisor runs AS the human's own
uid on this laptop, so any key file the human can read, the supervisor can read too. a file mode
cannot separate two processes of one uid. `term=ground` names the custody as *"an admin ssh key
the agent lacks"*, and on this box a file is not a key the agent lacks.

## .the fork
- **A** a key file for ground in the human's `~/.ssh` — the agent reads it; custody is fiction
- **B** a key file with a passphrase, never loaded into an agent — the agent cannot use it
  without the passphrase, but a careless `ssh-add` hands it over for the session
- **C** the ground seat's `authorized_keys` names the human's yubikey-held public key; every
  signature needs a physical touch (`5.9.yubikey`, the laptop's paved ssh path per
  `define.github-auth-two-paths`: *"ssh, authorized by the yubikey behind `SSH_AUTH_SOCK`"*)

## .taken: C, and why at the time
- it is the only option whose custody is physical: the agent shares the socket and still cannot
  tap. the repo already grades a touch as a genuine human halt (`rule.require.wake-the-grove-freely`)
- it mints no new secret, so there is no ground key file to leak, rotate, or back up
- the camper seat keeps a plain key file in the supervisor's `~/.ssh` — the agent IS meant to
  hold that one

## .rework
clean — one line in one `authorized_keys`.

## .confidence 70% — why not higher
- that this laptop's yubikey key carries a touch policy of *always* is **unmeasured**; with a
  cached touch policy, C degrades toward B
- a supervisor `ssh house-1.ground` would offer the yubikey key and then wait on a touch. the
  reach must be bounded so it fails loud rather than hangs a duct (case=3 `[t2]`); the bound's
  shape is an execution call
- ci has no yubikey: the clamp authorizes a throwaway key for its own ground seat, and says so
  in its summary (case=5)

## .where
case=1 `[t0]`; case=3 `[t2]`; F3.

## .risk: risky
it decides the custody of the root seat key: the human yubikey-held key, a touch per use. a wrong call hands the agent root on the laptop.
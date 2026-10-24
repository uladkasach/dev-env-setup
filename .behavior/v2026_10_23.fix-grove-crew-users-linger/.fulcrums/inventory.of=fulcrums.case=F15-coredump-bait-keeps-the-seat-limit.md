# F15 — the coredump bait keeps this seat's core limit, under a 30s collector window

## .the fork

`prove.coredump-catches-a-crash` sends SIGSEGV to a bait and waits for `coredumpctl` to list it.

- **A.** raise the bait's core limit (`ulimit -c unlimited`) and wait about 10s
- **B.** keep the seat's own soft limit, and wait up to 30s, but stop at the first hit

## .taken — B, and why at the time

the play exists for one claim: the grove's tmux segfaulted ~110 times and left no core. that
server ran with the seat's own soft limit, 0 on a grove. a raised limit tests a path production
never takes. the core lands only because `core_pattern` pipes to a collector that ignores the
limit, so the un-raised bait is the claim itself.

the window stops at the first hit, so a fast box pays about 1s. 30s covers a loaded box where the
collector trails the signal, so a slow collector never reads as "no core".

## .rework — clean

two lines in one play: the `ulimit` and the loop bound.

## .confidence — 80%, and why it is not higher

the 30s bound is a judgment about load. no box here has yet shown a collector past 10s.

## .where

`.play/permanent/prove.coredump-catches-a-crash.play.sh` — the comment at the spawn and at the poll.

## .verdict

open — raised by 5.3 i004 r12 blocker.2 and i005 r12 blocker.1, disputed here each time

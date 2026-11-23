# F17 — each fix line pastes alone, and no fix line holds a grant

## .the fork

peer round i005 of 5.3 (r011) asked two things of 5.26's fix text:

- the damaged-meter fix repeats the full meter path in steps 1 and 2: shorten it (nitpick 2)
- a blocked-org line should name the command that lifts the block (nitpick 4)

the options:

- **shorten and add** — steps refer to "the file above"; a blocked line ends with its lift command
- **each step pastes alone; no grant is printed** — keep the full path per step; name no lift

## .taken

each step pastes alone; no grant is printed.

- a step that says "the file above" cannot be pasted; the reader must splice a path in by hand,
  on the one fix where a wrong path loses a block
- a lift is `git.commit.uses --org <org> allow`: a grant. this output is read by clones on the
  same box, and the org gate exists so that a clone never grants itself. the same reason cut the
  grant command from the local decline in this round

## .rework

clean: each is one echo line in `_.sh` or `configure.upsert.sh`.

## .confidence

85%.

## .where

`src/grove.provision/5.devtools/5.26.commitorgs/_.sh` (`damaged_fix`, the decline),
`configure.upsert.sh`, `configure.verify.sh`.

## .verdict

open: disputed in 5.3 peer round i005 (r011), for the council.

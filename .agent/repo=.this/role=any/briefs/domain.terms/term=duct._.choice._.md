# domain.term: duct

term.chosen   = duct
term.kind     = noun
term.synonyms.forbidden:
- session (tmux's own word for the mechanism; a duct is more than the session)
- channel
- pipe
- tunnel (that word names the ssh/ssm port-forward a duct may travel through)
- terminal
- shell

## .what
a named, durable terminal a command can be sent into and read back out of, whether it sits on
this machine or on a grove. it survives disconnect: close the laptop, the duct keeps whatever
was sent to it, and a later `duct.read` still finds the output.

## .how it is addressed
by a **duct.uri**, and only that: `duct://grove-1/main/mechanic`, or
`duct:///worktree/mechanic` for one on this machine. see `term=duct.uri._.choice._.md`,
which also records the scp-shaped `slug` it retired.

## .the operations it names
- `duct.open` — make a duct exist (idempotent; a duct already open is returned)
- `duct.send` — give a duct a command to run (refuses a BUSY duct; see `term=duct.idle`)
- `duct.read` — look at what a duct holds
- `duct.list` — what ducts exist
- `duct.stop` — close a duct (idempotent; an absent duct is already stopped)

## .why it is not `session`
a tmux session is the MECHANISM a duct is built from, not the concept. a duct also carries the
host it lives on, the ssh/ssm reach to get there, and the guarantee that a send and a later read
find each other. to call it a session names the implementation and loses the rest — and it
misdirects a reader on failure, since "session not found" sends them to hunt tmux when the box
may simply be asleep.

## .why it matters to say `duct` and not `ssh`
a duct is the DECLARED way to reach a machine in this repo. an ad-hoc `ssh <host> "<cmd>"` does
the same work once and keeps none of it: no scrollback, no survival across disconnect, no
`--play` review of what was sent. the human, 2026-07-28: *"why do you need bash -n? you
literally have ducts. thats all you should need"*.

so a duct is not a fallback for when a local tool is unavailable — it is the verification
surface this repo is built to have. see `.reason`.

this is now enforced as a rule of its own:
`rule.require.reach-a-grove-through-its-duct.md` — added 2026-07-28, after a robot read
this very section and typed `ssh grove-1` anyway. the section explained the CHOICE; the
rule states the OBLIGATION, and records that the Bash allowlist permits what it forbids.

## .refs
where the term is declared / used:
- src/ductwork.sh                                  # every `duct.*` operation
- .agent/repo=.this/role=any/skills/git.grove.send.sh
- .agent/repo=.this/role=any/skills/git.grove.read.sh
- .agent/repo=.this/role=any/briefs/desktop/term/howto.headless-terminal-streams.md

## .reason
see the ref-level cluster beside this choice:
- `term=duct._.choice.reason.md` — etymology, why it was deferred six rounds, evidence

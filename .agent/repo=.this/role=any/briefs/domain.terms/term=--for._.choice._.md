# domain.term: --for

term.chosen   = --for
term.kind     = noun (a flag: an axis, whose values are the adjs `local` and `cloud`)
term.values:
- local   — a machine with a screen and a human at its keyboard
- cloud   — a grove: a headless box reached over ssh/ssm, no screen, no human
term.synonyms.forbidden:
- scope
- target
- mode
- profile
- flavor
- desk (for `local`)
- remote (for `cloud`)
- grove (for `cloud` — a grove is the NOUN, cloud is the ADJ; see `.reason`)

⚠️ each synonym above is forbidden **in this axis's slot**, never repo-wide. `grove` stays
the canonical NOUN for the machine, and `scope` stays canonical for what a CREDENTIAL may
reach (`rhx keyrack get --scope github://org/<org>`) — *"how much"* is the wrong question
for a machine axis and the right one for a credential. see `.reason`, which records the
2026-08-02 round where this rejection was read too widely.

## .what
the axis that names which KIND of machine a provision operation is for. it selects what applies:
a run keeps the `any` units plus the units tagged with its own value.

## .the tag adds one more value
a unit of work carries the same vocabulary as the flag, plus `any` for both:
- `any`   — every machine
- `local` — a local machine alone
- `cloud` — a cloud grove alone

`any` is a TAG value, never a `--for` value: a run is always for exactly one kind of machine,
while a unit may belong to both.

## .the name is the FLAG, verbatim
this cluster was filed as `grove.provision.for`, then `<old>.for`. both were wrong, and the
human said so plainly: *"why the fuck is it called .for instead of just --for"*.

they are right. a term names a CONTRACT, and the contract here is `--for` — that is what a
human types. `<old>.for` names a command that does not exist and never will; the dotted form
implied an operation (`grove.provision`, `git.repo.pull` are typeable) where this is a flag.

**the general rule this yields:** a term for a flag is spelled as the flag. a term for a command
is spelled as the command. the glossary entry is the literal string a human types — never a
dotted paraphrase of it.

the scope question those dotted names tried to answer is real, and is settled below: this axis
belongs to no single operation.

## .whose flag it is
every provision operation that must ask "which kind of machine is this?" — `grove.provision` and
`grove.bootstrap.sh`. the axis is declared once, in `src/grove.for.sh`, and no caller holds a
copy of the detection or the tag rule.

⚠️ the axis reaches **every subset**, per the human who asked for it:
*"--for $what is always carried through even into each subset"*.

## .declared once
- `src/grove.for.sh` — `grove_for_detect`, `grove_for_valid`, `grove_for_applies`

two operations ask it, and neither holds a copy:
- `src/grove.provision._.sh` — `--for cloud|local`, passed down the bundle tree
- `src/bash_aliases.sh`     — `grove.provision --for cloud|local`

⚠️ the per-step `step any|local|cloud` tag this list once named is GONE, deleted with the
step driver on 2026-07-30. a bundle declines inline, on the fact it actually depends on,
never on a two-valued tag — see `rule.require.identical-bundle-composition` and
`term=decline._.choice._.md`.

🛑 **a bundle reads `$GROVE_ENV_SERVER` directly.** there is no `grove_env_has_screen` and no
`grove_env_has_human` to reach for, and do not write one: they were synonyms of each other, and
each name claimed a fact its body could not check — the screen one read the server string, so
it answered YES on a `local@cicd` runner (`src/grove.env.sh` carries all three reasons inline).

⚠️ and the worst kind of dead pointer is a **CALL**, not a path. a path a reader follows fails
visibly; a call reads as live and answers `command not found`. so a term file — whose whole job
is to say which word to use — can name a function nobody can invoke and still read as
authoritative. `term=decline._.choice.reason.md` argues the tag's retirement.

## 🛑 .a CONTRADICTED `--for` is a lens, and a lens may not write

this flag sets only the TIER — the platform comes from a probe alone. so an override cannot
name a new box class; it can only contradict the one probed, which yields `cloud@unix` or
`local@aws.ec2`. neither is a machine we own. each is the reader who asks *"what would the
OTHER kind of box get?"* — a legitimate plan, and never an apply.

`grove.provision._.sh` halts a contradicted `--for` on `--mode apply`. measured 2026-09-03: on
a laptop it made `2.3.ssh` install the ssh METAPACKAGE and skip the mask, while the verify rung
written to catch that tests the same glob and went silent. see `term=lens._.choice._.md`.

⚠️ so `--for` does NOT rescue a wrong derivation, and the `.reason` for `lens` records that
dispute. a wrong derivation is a wrong PLATFORM, and `grove.env.sh:427-429` names the override
that sets both halves:

```sh
GROVE_ENV_SERVER=cloud@aws.ec2 rhx grove.provision --mode apply
```

## .refs
where the term is declared / used:
- src/grove.for.sh                    # THE declaration
- src/grove.provision._.sh              # `--for`, passed to the tree
- src/bash_aliases.sh                  # `grove.provision --for`
- .agent/repo=.this/role=any/briefs/grove/provision/howto.provision-a-grove.md
- .agent/repo=.this/role=any/briefs/grove/provision/rule.require.every-function-has-a-driver.md

## .reason
see the ref-level cluster beside this choice:
- `term=--for._.choice.reason.md` — etymology, disputes, evidence

⚠️ that file is spelled `--for`, never `<old>.for`. this pointer said `<old>.for` until
2026-08-12 — a RETIRED spelling the glossary's own `.scope` rule forbids. so the dead ref
named a word the reader must not adopt, on top of the file it failed to reach.

# domain.term.choice.reason: term

## .etymology

`term` is the short form the repo already used before any skill wrapped it:
`src/termwork.sh` has carried that name since it was written, and its functions are
`__term_as_ssh_host`, `__term_open`, `__term_list`. the word was in the code; the
`term.*` skill family adopted it rather than coin a new one.

it is deliberately the SHORT form. `terminal` reads as the emulator program at least as
often as one of its windows, and this term names one window with a pid. the clipped form
carries no such double sense here.

## .the birth — 2026-09-03

the family was declared in one round, and the reason is worth a record because it is the
worked example behind `rule.forbid.adhoc-shell`.

a kitty window was owed against a remote duct. a raw `kitty --detach -e ssh …` was typed.
the inventory at that hour:

| family | skills |
|---|---|
| `duct.*` | 8 |
| `term.*` | **0** |

two peer families in one repo — one wrapped, one bare. so the absence carried no verdict
about the capability; it recorded which family somebody had reached for first.

the human's reads, in order: *"dont you have rhx skills for this?"* → *"entool"* →
*"never adhoc"* → *"if you cant entool it, why do you do it"*.

the repair was one `term.operations.sh` plus five thin dispatchers, which is where the
five operations of this term's `.refs` come from.

## .why the term vs duct split is load-bear

the two families share every verb — `open`, `list`, `read`, `send`, `stop` — so a reader
who takes them for synonyms will reach for the wrong one and get a failure that reads
plausible rather than one that reads obvious.

📜 measured the same day: `term.open --on 'grove-x:main/mechanic'` refused every remote
host with `'grove-x' is not a host — '' is not a hostname`. the cause was a bash
expansion-order bug in `__term_as_ssh_host`, and the reason it went unnoticed is that the
`user@host` form escaped it — one live path masked one dead path, and the verdict
contradicted the evidence printed beside it (`gotcha.a-check-that-cries-wolf-gets-silenced`,
q1).

⇒ so the split is not a taxonomy nicety. `term` reaches a box's ssh front door and `duct`
reaches a tmux session already on it, and a reader who fuses the two cannot tell which
half broke.

## .disputes

none raised.

## .evidence

- the word predates the skills: `src/termwork.sh` uses `term` throughout, in a file the
  repo has carried since before the family existed
- five operations now anchor it: `term.open`, `term.list`, `term.read`, `term.send`,
  `term.stop`
- the counterpart is itemized: `term=duct._.choice._.md`

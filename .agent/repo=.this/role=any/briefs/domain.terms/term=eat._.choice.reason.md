# domain.term.choice.reason: eat

## .etymology

`eat` = a mouth already open takes what came next. the word puts the blame in the
right place: not on the sender, who sent correctly; not on the wire, which delivered
correctly; but on a **receiver that should not have been there**.

that is the whole diagnosis of the duct's worst fault, in one verb.

## .why the receiver half earns a verb of its own

a reviewer who holds only `swallow` writes a sentence to say this, every time. with
both words, the verb carries the direction:

| said with one word | said with two |
|---|---|
| "the output was swallowed and then the next command was swallowed too" | "its question is swallowed; it eats the next command" |

and the repairs are opposite, which is the real reason the split pays:

| word | the repair |
|---|---|
| **swallow** | change the CARRIER — drop the `2>/dev/null`, split the `$( )`, quote the stderr |
| **eat** | remove the RECEIVER — `sudo -n`, `CI=1`, `GIT_TERMINAL_PROMPT=0`, so no prompt ever opens |

⇒ so a reader who confuses them reaches for the wrong repair. an author who reads
*"the credential prompt swallowed the next command"* hunts for a redirect, while the
defect is that a prompt exists at all.

## .the eight sites that say it correctly

each names a receiver, and each names a message that belonged to someone else:

| site | the receiver | the message it ate |
|---|---|---|
| `prove.git-never-prompts.play.sh:8` | git's credential ask | every command sent afterward |
| `prove.fnm-cd-never-prompts.play.sh:28` | fnm's install question | the next command down the duct |
| `prove.bundles.plan-apply-apply.play.sh:347` | any prompt on a headless box | the next command |
| `prove.ground-seat-converges.play.sh:25` | a sudo password prompt | the next command |
| `prove.ssm-shell-refused.play.sh:109` | an interactive ssm session | the next command |
| `diagnose.grove-user-split-shipped.play.sh:54` | a password prompt | the next command |
| `diagnose.credential-helper-ladder.play.sh:34` | a helper's prompt | every command afterward |
| `git.grove.send.sh:439` | a live job's stdin | the sent line |

⚠️ **note how uniform the right-hand column reads.** seven of eight eat *the next
command on a duct*. no coincidence — that is the shape of the hazard this repo keeps
at bay, and why `rule.forbid.tty-as-a-proxy-for-a-human` exists.

## 🛑 .the first LIVE eat — 2026-08-25, and its receiver was NEW

every row above is a receiver this repo already knew to fear: a sudo prompt, a
credential ask, an fnm question. all eight are hazards somebody foresaw and wrote a
play against.

on a from-scratch grove the term met a receiver **nobody had listed**, and the pane
recorded it verbatim:

```
You are seeing this message because you have no zsh startup files
--- Type one of the keys in parentheses --- { bash …/grove.provision._.sh --mode apply
Aborting.
ip-<private-ip>%  bash …/grove.provision._.sh --mode apply ; } > /tmp/duct.reply….out
zsh: parse error near `}'
```

`zsh-newuser-install` — zsh's own first-run wizard — opened on the pane and became
its reader. it ate the `{` that opens the reply wrapper as a keypress, aborted, and
the remainder landed on a bare prompt as a syntax error. no `.rc` file ever landed,
so the caller waited out its full `--within` and returned 97.

### .why the receiver was new, and why that is the point

no *command* opened this prompt. **the login shell itself** opens it, before any
command runs, when a seat's record names zsh and that seat holds none of zsh's four
startup files. so it evades every guard the eight rows above represent: `sudo -n`,
`CI=1`, `GIT_TERMINAL_PROMPT=0`, and every other "make this tool not ask" flag speak
about a TOOL, and the receiver here is the shell that would have run the tool.

⇒ **`eat`'s repair — remove the receiver — held exactly.** neither a flag nor a
redirect: give the seat an rc file, and the wizard has no reason to open.
`2.5.zsh.provision.upsert` now seeds one for every seat whose record it converges
(`rule.require.seam-claims-have-an-owner` — the seat that wrote the record owes the
seat a shell it can open).

### ⚠️ .this repo CREATED the receiver, in the same branch

the record write that flipped the camper to zsh is itself a fix — for
`gotcha.a-tool-found-by-path-answers-only-a-human`, where a bash record meant
`bash -c` and a bare PATH. it converged one hazard and manufactured another, because
ONE seat writes the record and ANOTHER writes the rc that makes it usable.

📜 and the ground seat escaped by accident of ORDER: its duct pane opened before this
bundle installed zsh, so tmux gave it bash. so the hazard reaches only the seat whose
pane opens second — on a two-seat grove, always the camper, and only ever on a first
apply. that is the "DARKEST corner" `define.provision-defect-shapes` names: one
box class, one run, no ambient evidence, and no static play can see it.

### .what each layer below the receiver did RIGHT

worth the record: it is the shape a well-built transport takes under an eat.

| layer | it reported |
|---|---|
| `git.grove.send` | a clean send — the text DID land (`gotcha.the-duct-returns-the-send-not-the-answer`) |
| `--reply` | `97` — the reserved transport code, never an answer |
| its message | *"still busy after 1800s — this is a BOUND, not a verdict"* |

so no layer claimed a fact about the box, and the 97 contract did exactly the job it
holds in reserve. the failure sat entirely above them, on the pane.

## .the two drift sites, recorded not repaired

two sites use `eat` for a CHANNEL, which is `swallow`'s half:

```
prove.bundle-pad-via-pipe.play.sh:25            "a pipeline eats an exit code"
prove.timeouts-kill-what-they-cut.play.sh:430   "its call all eaten"   ← a sed cut
```

neither holds a receiver. a pipeline and a `sed` are carriers, so both belong to
`swallow`. both are comments, and `rule.forbid.domain-term-synonyms` governs
CONTRACTS, so neither violates it today — they are **clean-when-disturbed**.

⚠️ they stand written here rather than fixed, on purpose. a mass rename against a
term paved the same hour is how a fresh distinction earns a reputation for churn, and
the rule itself says a synonym "may be left in place until disturbed".

## .why `block` lost, and it is the closest miss

`block` is what a human SEES: the run stopped. but a block implies a refused sender,
and here the sender **succeeded** — `git.grove.send` reports a clean send, exit 0,
because the text landed (`gotcha.the-duct-returns-the-send-not-the-answer`).

so `block` points a reader at the sender, which is healthy, and away from the pane,
which is not. the whole value of `eat` is that it names the party at fault.

## .evidence

10 sites, five authors. the word sits in four `prove` plays, two `diagnose` plays,
and one skill's fix-text — so it already lives in the language a human READS when a
duct misbehaves, not merely in the language the authors write.

## .disputes

none raised.

## .see also

- `term=swallow._.choice._.md` — the outbound half of the pair
- `term=duct._.choice._.md` — why a pane holds one reader
- `rule.forbid.tty-as-a-proxy-for-a-human` — why a tty test does not settle whether a
  human will answer
- `gotcha.the-duct-returns-the-send-not-the-answer` — why the sender still reports 0

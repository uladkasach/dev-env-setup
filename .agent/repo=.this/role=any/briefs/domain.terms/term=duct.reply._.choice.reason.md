# domain.term.choice.reason: duct.reply

## .etymology

the operation is `git.grove.send`. a `send` that comes back with an answer has one
obvious counterpart in plain english, and it is the one a human already reaches for:
a **reply**. no gloss is needed, and the pair `send`/`reply` reads symmetric at the
call site (`rule.prefer.symmetric-term-pairs`).

chosen over:

- **`sync`** — names the TIMING (does the caller block, or not), which is a mechanism
  detail. the caller does not want to block; they want the answer. a held wire is how,
  a reply is why.
- **`wait`** — same defect, and it collides head-on with `--await`.
- **`capture`** — reads as "save the output somewhere", which is `--log`'s job.
- **`verdict`** — accurate but narrow: it names the exit code and drops the stdout,
  and `--reply` returns both.

## .disputes

### dispute: await  —  raised 2026-08-13  —  status: RESOLVED (split — both words kept, one concept each)

- raised.by  = the human
- claim      = *"cant you upgrade the duct to `--await`?"* — the flag already exists,
               and "await" is the natural english for "hold until it is done". a second
               word for a second wait looks like needless vocabulary.
- counter    = `--await <secs>` was already taken, and it names a **different**
               concept: it polls until the pane falls IDLE and then sends, so a
               command does not land in a live job's stdin (`term=duct.idle`).
               that is a fact about the **duct**. the new wait is a fact about the
               **command** — has MY command finished, and what did it say.

               to spell both `await` would overload one word onto two concepts, which
               is the ambiguity `rule.forbid.domain-term-synonyms` exists to stop —
               and it would be the worse kind, because the two are ADJACENT: a reader
               who saw `--await 600` could not tell whether the 600 bounded the wait
               before the send or the wait after it.
- resolution = **split.** this is the second outcome in
               `howto.domain-term-disputes` — the disputed word turned out to name a
               genuinely distinct concept, so it earns its own term rather than
               replaces the extant one. `await` keeps the pre-send idle wait;
               `reply` takes the post-send answer. they compose:

               ```sh
               rhx git.grove.send <g> --await 600 --reply --what '<cmd>'
               #                      └ wait for a free pane   └ then carry the answer back
               ```

⚠️ **the human's real point was taken in full, and it is the load-bearing half.**
the dispute was about the WORD; the ask was *"upgrade your tools, not use escape
hatches"*, and that was correct and is now `rule.forbid.exemption-as-habit`. to have
answered "await is taken" and stopped would have been to win an argument about a name
and miss the actual instruction.

## .evidence

### the defect it names — measured 2026-08-13, `grove-ahbode-v20260811`

```
$ rhx git.grove.send <g> --what 'test -d /definitely/not/a/real/path'
🔧 duct://<g>/main/mechanic sent
caller saw exit=0
```

a command that cannot succeed returned success, and stdout was the send's own banner.

### 🛑 the CONTRACT held; the IMPLEMENTATION did not — measured 2026-08-31

on a fresh grove, every `--reply` of a long session returned the banner and **an empty
payload**. the word is not at fault and no dispute is opened — what the measurement
records is that a caller may receive a reply-shaped answer that carries no answer:

```
🐚 git.grove.send <g>.ground --reply
   ├─ what:   tail -4 $HOME/grove.provision.ground.log
   └─ within: 45s, asked every 2s
🔧 duct://<g>.ground/main/mechanic sent          ← the banner, and no payload
```

⇒ it cost `git.grove.provision boot` a **false ✋**: its watcher greps that payload for
`🌲 grove.provision done`, so it read an empty string ~1350 times and ran to its 2700s
bound against an apply that HAD converged.

🛑 **the cause is MEASURED, and it is not the shell** — 2026-08-31, second pass.

a first read of this pane blamed the poll's `zsh -ic`: an interactive zsh sources this
repo's `.zshrc`, so starship, fnm, and the alias suite load before the command runs, and a
reply asked every 2s might lose its own race. that read was hedged as *likely* and it was
wrong.

one probe discriminates it. `--reply --what 'echo PROBE_OK'` also answers empty — and no
shell start-up cost can delay an `echo` past 60s. so the defect is LOCAL to the caller, and
the box was never at fault:

| path | line | exit | what the caller sees |
|---|---|---|---|
| `--bare` | `git.grove.send.sh:438` | **127** | `__duct_strip_escapes: command not found` |
| `--reply` | `git.grove.send.sh:838` | **0** | the banner, and an empty payload |

both pipe the payload through `__duct_strip_escapes`, which an installed
`~/.bash_aliases.ductwork.sh` had lost while `src/ductwork.sh:229` still declared it. an
absent function empties the pipe, `pipefail` does not carry its rc out of the `$( )`, and
`rhx` DROPS a skill's stderr on a zero exit (`term=swallow`) — so the one line that named
the cause never reached a reader.

⇒ **an empty payload is a caller-side fault far more often than a slow box.** probe with a
command that cannot be slow before you blame the wire.

⇒ the repair is at cause: `git.grove.send`'s staleness gate read ONE borrowed function and
now reads every one of them, from a single `GROVE_SEND_BORROWS` declaration. a gate that
proves one member of a set and waves the rest through is
`gotcha.a-check-that-cries-wolf-gets-silenced` q11.

🛑 **and the 97 arm cannot see this.** 97 says *the transport faulted, so there is no
answer*. here the transport SUCCEEDED and delivered an empty one — a third state the
two-valued repair never anticipated:

| what happened | rc | payload |
|---|---|---|
| the command answered | its own | its stdout |
| the duct refused | 97 | none — halt, do not judge |
| **the duct delivered an empty answer** | **0** | **empty — reads as a FALSE answer** |

⇒ so a `--reply` caller must test the PAYLOAD, never the code alone. an empty payload
where output was expected is not a verdict about the box
(`gotcha.the-duct-returns-the-send-not-the-answer`, one layer in).

### the term's operation, proven in both directions

a term for an operation is unproven until the operation is seen to discriminate
(`gotcha.a-check-that-cries-wolf-gets-silenced`):

| case | result |
|---|---|
| `--reply --what 'test -d /nope'` | `exit=1` |
| `--reply --what 'whoami'` | prints `camper`, `exit=0` |
| `--reply --what 'sleep 6'` | reports busy, holds, `exit=0` |
| `--reply --play prove.root-decline-bites` | full play output + its real verdict |

### the invariant that makes it a distinct term rather than a flag detail

> the poll goes AROUND the pane, never through it.

to ask down the duct whether the duct is busy would put a command in the very pane
whose busyness is the question — it would land in the live job's stdin. so a `reply`
is necessarily observed beside the duct (over ssh), never inside it. that is the same
constraint `git.grove.play.await` documents, and it is what separates a `reply` from
"read the pane afterward": a pane read sees a RENDER, a reply reads the command's own
recorded result.

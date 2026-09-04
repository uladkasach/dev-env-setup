# gotcha: a duct returns the SEND's verdict, never the command's

## .what

`rhx git.grove.send <g> --what '<cmd>'` writes the command into a tmux pane and returns.
the **pane** keeps the output. the **caller** gets the exit code of the send — which is
`0` whenever the text landed, whatever the command then did with it.

so this is always true, on a healthy grove:

```sh
rhx git.grove.send <g> --what 'test -d /definitely/not/a/real/path'
# 🔧 duct://<g>/main/mechanic sent
# exit 0
```

a command that **cannot** succeed returns success. and its stdout is not empty — it is
the send's own two-line banner, which is worse, because an empty capture at least reads
as suspicious.

## .why it is so easy to walk into

every other transport in this repo returns what you expect. `--bare` does:

```sh
rhx git.grove.send <g> --bare --why '…' --what 'test -d /definitely/not/a/real/path'
# exit 1
```

so the duct is the one that differs — **silently, in the direction that looks safe**. a
check built on it does not error, does not hang, does not print an empty result. it prints
`✔`.

⚠️ and the duct is the **default**. `--bare` is the flag you must justify with a `--why`.
the transport that discards the answer is the one you get by habit; the one that returns it
is the one you must argue for.

## .measurement — three false ✔ on a ladder's first climb, 2026-08-10

`git.grove.ready.verify` climbs a ladder and halts at the first rung that does not hold. its
first climb printed this — ⚠️ **verbatim from 2026-08-10**, when the ladder still carried a
`6. tree` rung; that rung and `7. suite` were deleted 2026-08-30, and the transcript is kept
as the measurement it is:

```
      ├─ 4. devenv
      │  ├─ ✔ marks:  0
      │  ├─ ✋ claims: 0
      │  └─ ✔ every bundle verify held        ← on ZERO evidence
      ├─ 5. creds
      │  ├─ ✔ gh authed
      │  └─ ✔ aws identity answers
      ├─ 6. tree
      │  ├─ ✔ ahbode/svc-chat is cloned
      │  └─ ✔ deps are installed
```

the box held **no dev-env-setup checkout at all**. it was a fresh disk. rungs 5 and 6
asked real questions — `gh auth status`, `test -d ~/git/ahbode/svc-chat/.git` — and every
one of those answers was `0`, because every one was the SEND's answer.

rung 4's whole log was:

```
🪨 run solid skill repo=.this/role=any/skill=git.grove.send
🔧 duct://grove-ahbode-v20260810/main/mechanic sent
```

two lines of banner where a 200-line plan should have been.

⚠️ **only the tally guard caught a thing.** rung 4 counted `✔` and `✋` in that log and
found 0 of each — and 0 marks is what tripped the halt. had the rung judged the exit code
alone, as rungs 5 and 6 did, the ladder would have reported a bare box as fully ready and
then blamed the code when the suite failed.

## 🛑 .RESOLVED 2026-08-13 — the duct now carries the answer

`git.grove.send --reply` sends over the duct, waits for the command to finish, and returns
the command's own stdout and its own exit code:

```sh
rhx git.grove.send <g> --reply --what 'test -d /definitely/not/a/real/path'
# caller saw exit=1        ← the COMMAND's code, over the duct
```

⚠️ **the earlier fix — "use `--bare`" — was the wrong shape, and worth a record as such.**
it was an ESCAPE HATCH: the hatch got typed dozens of times with one `--why` string that
never varied. an exemption whose justification never varies is a permanent condition, and a
permanent condition is an absent feature (`rule.forbid.exemption-as-habit`, for which this
brief is the worked example).

## .the rule it yields

> a **drive** sends. a **verify** sends `--reply`. both ride the duct.

| the command's purpose | transport | why |
|---|---|---|
| change the box (an apply, an install, a clone) | `--what`, and `--detach` for a long one | survival across a disconnect is what you need; the exit code is not |
| read the box (a verify, a probe, a diagnose) | `--reply` | the answer IS the point, and `--reply` brings it back with no hatch |
| a box with no tmux yet, or a broken duct | `--bare --why '<trigger>'` | the duct cannot carry it at all |

⚠️ `--reply` is NOT the default, deliberately. a drive wants the duct's survival
across a disconnect and has no use for a verdict held on the wire, so it stays cheap.
the caller states which of the two they are.

## 🛑 .the ONE code `--reply` reserves: 97 means "no verdict"

`--reply` returns the command's own exit code, so its OWN faults must not borrow from that
range. a caller cannot tell these apart when they do:

| what happened | code, if the transport borrows 1 |
|---|---|
| `test -f x` ran and answered false | 1 |
| the duct refused the send, so it never ran | 1 |

⚠️ **.measured 2026-08-13, and it cost a false halt on a healthy grove.** a
backgrounded `git.grove.provision test` still held the pane when a second run started. every
probe was refused; `git.grove.ready.verify` read the 1 as an ANSWER and halted with
*"seat '…' holds src/ but no package.json beside it"* — plus a push command for a
file that was present the whole time, 610 bytes, listed on that box one command
later (`gotcha.a-check-that-cries-wolf-gets-silenced`, the false-✋ half).

⇒ **`--reply` now exits 97 for every fault of its own** — the send was refused, the
box went quiet, `--within` elapsed, the rc was unreadable, the args were malformed.
one code, not a table: those five differ in CAUSE and agree on the only fact a
caller acts on. a table would have to grow; a caller written before the growth
would read the new code as an answer — the very defect this closes.

```sh
rhx git.grove.send <g> --reply --what '<cmd>'
#   0-96, 98+  → the COMMAND's own code. this IS the answer
#   97         → the transport. there is no answer; halt, do not judge the box
```

### ⚠️ .why a reserved CODE, and not a marker in the command

a marker — `{ cmd ; } && echo __TRUE__ || echo __FALSE__`, absent marker means "never ran" —
**cannot be delivered.** `--what` takes ONE step, and `git.grove.send` refuses any `;`, `&&`,
or `||` in its raw text, a control that exists because the pretooluse hooks read only the
outer command. to encode past that guard would defeat it.

⇒ and the knowledge was never the command's to carry. the SEND already knows — it checks its
own delivery. it simply had no way to SAY so (`rule.require.solve-at-cause`).

### .why 97, and not a grep of the refusal text

the cheaper fix is to grep the message for `BUSY`. that makes every caller depend on
another component's output FORMAT — an invisible dependency that appears in no
argument and breaks silently the day that sentence moves, exactly as an output pad
once disarmed the idempotency play
(`gotcha.a-check-that-cries-wolf-gets-silenced`, m.2).

97 is a declared contract instead: 0-2 are everyday, 126-127 are cannot-execute and
not-found, 128+n is a signal. 97 sits in the unused middle and is **ours**.

### .what a caller must do with it

```sh
local out rc=0
out="$(rhx git.grove.send "$seat" --reply --what "$cmd")" || rc=$?
[[ "$rc" -eq 97 ]] && halt_naming_the_duct     # never judge the box
return "$rc"                                   # otherwise it IS the answer
```

⚠️ `|| rc=$?`, never `|| true` — a `true` discards the very code this reads and
leaves 1 indistinguishable from 97 again. proven both directions by
`prove.duct-contention-faults`, which stubs the transport and drives each helper
through a true answer, a false answer, and a refusal.

## ⚠️ .`--bare` keeps exactly TWO triggers

both describe a duct that **cannot carry** the command:

- `--why 'no tmux yet'` — the bootstrap window; a duct IS tmux
- `--why 'duct is broken'` — the duct exists but will not relay

🛑 **"a verify needs the remote verdict" is NOT one of them.** the duct carries the command
perfectly and `--reply` brings its answer back, so that trigger names a condition that no
longer exists (`rule.require.exemptions-name-their-trigger`).

## .a long job, judged

a long job rides the duct detached and is judged by a **second, separate read** — never by
the send:

```sh
rhx git.grove.send <g> --detach --log '$HOME/job.log' --what '<long job>'
# …later…
rhx git.grove.send <g> --reply --what 'tail -40 $HOME/job.log'
```

the send starts it; the reply judges it. do not let one call do both.

## .the test

before you trust a green row about a remote box:

> **did this row read the command's answer, or the send's?**

if the row's evidence is an exit code from a default `git.grove.send`, it read the send.
print the captured output beside the verdict and the answer is immediate — a two-line
banner where a plan belongs is unmistakable, and it was on screen the whole time.

⚠️ and a SECOND test, for a row that already uses `--reply`:

> **does this caller test for 97 before it judges the box?**

a `--reply` caller that branches on truthiness alone has closed the first defect and
kept the second: it reads a refused send as a fact about a box that never spoke.

## 🛑 .the same shape one layer IN — `rhx` drops stderr on a zero exit

a duct is a remote transport. `rhx` is a local one, and it has the same property:

> **`rhx` buffers a skill's stderr and relays it only when the skill exits NON-ZERO.
> on a zero exit, every line written to `>&2` is discarded.**

measured 2026-08-31, and it is the house convention that hides it. every skill here
writes its `✋` rows to stderr and exits non-zero, so those rows always arrive. what
does NOT arrive is an **advisory on the happy path** — and that is precisely where a
reader says *"I could not read part of my subject."*

`dox.verify` printed this from a direct `bash` run and printed no such line under
`rhx`, on the same tree, in the same minute:

```
   ⚠️ 201 tracked file(s) are ABSENT from disk and were NOT read
🌲 dox: none found across 603 tracked files ✔        ← all rhx relayed
```

⇒ **the repair is not a louder stream. it is an honest exit code.** an incomplete
subject is not a pass, so the reader now exits 2 and the message rides out with it.

| the line says | stream | exit | reaches the caller |
|---|---|---|---|
| a violation | stderr | non-zero | ✔ |
| a verdict of ✔ | stdout | 0 | ✔ |
| a caveat beside a ✔ | stderr | **0** | ✋ **discarded** |

### .the test

> **does every line that qualifies my verdict ride out on a NON-ZERO exit?**

if a caveat can only print on the zero-exit path, `rhx` eats it and the caller reads
an unqualified ✔. either raise the exit code, or the caveat is decoration.

## .see also

- `rule.forbid.failhide` — the general form; this is a transport-shaped instance
- `gotcha.a-check-that-cries-wolf-gets-silenced` — its mirror, where a check goes red on
  a subject that works. its `.the test` (does the evidence agree with the verdict?) is
  what catches this one too
- `rule.require.exemptions-name-their-trigger` — why the third trigger must be spoken
- `rule.require.reach-a-grove-through-its-duct` — the default this qualifies, and does
  not overturn
- `.agent/repo=.this/role=any/skills/git.grove.ready.verify.sh` — its `_ask` operation carries
  this measurement inline
- `.agent/repo=.this/role=any/skills/git.grove.operations.sh` — `_ask_at` / `_shell_at`, the
  two operations that read 97 and halt on it
- `git.grove.provision test` — what drives all three arms for real. its rung 0 halts on 97
  and reports on 0-96, so a helper that swallowed the code fails the gate

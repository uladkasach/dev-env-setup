# rule.prefer.open-the-window-rather-than-describe-it

## .what

when a question can be settled **only by the human's own hands** — a physical keypress, a
device interaction, a visual check — **open a real window for them and hand it over**. do not
write out steps for them to run.

```sh
rhx term.open --name <slug> --what '<cmd>'
# then say plainly what to do in it, and wait
rhx term.read --pid <pid> --lines 60
```

## .why

📜 the human named this unprompted, three times in one round, 2026-09-16 — after a key-chain
probe was opened for them rather than described: *"that was great"* · *"i love that you opened
the terminal for me"* · *"so convinient and helpful"*.

beyond the preference, it is more correct:

- **a described step is a step they may not run.** they paste a variant, a shell eats a quote,
  they run it in a different window — and the measurement is now about a setup neither of you
  can name
- **the window IS the fixture.** when the subject under test is the terminal chain itself
  (`howto.probe-the-key-chain-with-a-live-logger`), a window you opened with known flags is the
  controlled condition; a window they opened is not
- **it removes the copy-paste hop**, which is the whole friction a human feels at the moment
  they already do you a favor

## .when it fires

| when… | then… |
|---|---|
| the instrument has to be a **human finger** — a keypress, a chord, a device | 🔴 open it. there is no substitute and no reason to make them type the launch too |
| you would write *"run this and tell me the output"* | can you run it? then run it. can you not, because it needs their hands? then **open the window** |
| a visual check — a render, a theme, a font | open it on the artifact, so you both look at the same pixels |
| a device pair, a login, an sso prompt | open it, say which prompt to answer |

## ⚠️ .the bound

this is not a licence to open windows the human did not ask to look at.

- **one window, one question.** open it, get the answer, close it
- **say what to do in it**, in one line. a window with no instruction is worse than a described step
- **do not open a window to run what you could run yourself** — that is ceremony, and it
  charges the human for work that needed no one
- **address it by `--pid`.** `term://<name>` does not address it, and `duct.*` is remote-only

## .enforcement

- a step described for a human to run, where only their hands could settle it and a window
  could have been opened = **nitpick**
- a window opened with no instruction on what to do in it = **nitpick**
- a window opened for work the agent could have run itself = **nitpick**

## .see also

- `howto.probe-the-key-chain-with-a-live-logger` — the worked case this rule came out of
- `howto.terminal-window-management` — `term.open` / `term.read` / `term.send`
- `rule.forbid.tty-as-a-proxy-for-a-human` — the inverse hazard: a tty is not evidence a human is there

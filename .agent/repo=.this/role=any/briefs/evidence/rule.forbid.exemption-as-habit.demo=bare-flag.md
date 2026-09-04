# demo: exemption-as-habit — the `--bare` measurement

## .what

`rule.forbid.exemption-as-habit` states the rule: an exemption reached for every time, for the
same reason, is an absent feature. this holds the measurement that cut the rule.

## m1 — `--bare`, 2026-08-13

`git.grove.send` sends a command to a grove over its **duct**. a duct is tmux, so a send is a
keystroke: the caller gets the exit code of the SEND — `0` whenever the text reached the pane,
whatever the command then did.

```
$ rhx git.grove.send <g> --what 'test -d /definitely/not/a/real/path'
🔧 duct://<g>/main/mechanic sent
caller saw exit=0
```

so **every verify had to leave the duct**, through `--bare`, with a `--why` that recited the
same sentence each time:

```
--why 'a verify needs the remote verdict; the duct returns only the send'
```

that string was typed dozens of times in a single session. every one was correct. `--bare` was
the right flag, its trigger genuinely fired, and the guard that demands a `--why` was satisfied
honestly on each call.

and the human read it once and asked the right question: *"can't you upgrade the duct to
`--await`? you should just upgrade your tools, not use escape hatches."*

⇒ the answer was `--reply`: the duct now waits for the command to finish and returns its own
stdout and its own exit code. the trigger that fired dozens of times cannot fire again, because
the road now goes where those trips were headed.

⚠️ the tell was in the `--why` text itself. an exemption whose justification is identical on
every use is not justified per-call — it is a fixed condition, and a fixed condition is a
requirement nobody wrote down.

### why the guard did not catch it

`rule.require.exemptions-name-their-trigger` made `--why` mandatory precisely so the caller
would re-check the trigger each time. that worked: the trigger was re-checked, and it fired
every time regardless.

a guard that asks "does the trigger fire?" cannot detect "this trigger always fires." the first
is about one call; the second is about the distribution.

⇒ `--reply` is the shape to copy: it does one job, it composes with the extant `--await`
rather than absorb it, and it left the default cheap — a **drive** still sends and returns, and
only a **verify** pays for the wait.

## .see also

- `rule.forbid.exemption-as-habit.md` — the rule this measurement cut
- `gotcha.the-duct-returns-the-send-not-the-answer` — the measurement behind `--reply`
- `.agent/repo=.this/role=any/skills/git.grove.send.sh` — carries `--reply` and the retired
  trigger inline

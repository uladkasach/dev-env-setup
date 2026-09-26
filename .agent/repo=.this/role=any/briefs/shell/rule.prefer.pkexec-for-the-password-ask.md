# rule.prefer.pkexec-for-the-password-ask

## .what

when an act needs root and a password may be owed, **pick the escalator; do not assume
`sudo`**. a caller with no tty prefers `pkexec`, which asks through the desktop's polkit
agent and needs no terminal at all.

```
root?            → write directly, no ask
sudo -n works?   → sudo, and no human is asked
a tty?           → sudo, which asks on that tty
pkexec present?  → pkexec, which asks in a desktop dialog
none of these    → halt, and say so
```

## .why — `sudo`'s failure is SILENT, and it reads as success

`sudo` prompts on a **terminal**. a caller with none — an agent's shell, a hotkey, a
systemd unit, a duct send — gets no prompt. sudo returns **1**, writes not one byte, and
says so only on a stderr the caller usually discards.

⇒ the caller then sees a command that "ran", and a verify that reads the exit code of the
pipeline (or reads the state with no before/after diff) prints **✔ for a no-op**. that is
`rule.forbid.failhide` reached by a path nobody wrote on purpose.

`pkexec` is not merely a fallback. it is the **only** escalator that can still reach a
human when the caller holds no terminal, and a desktop session always has one to reach.

## .the measurement — 2026-09-24, `input.touchpad.refresh`

a builtin i2c-hid touchpad had paused mid-session; cosmic-comp had dropped the device.
the repair is an unbind + rebind under `/sys/bus/hid/drivers/hid-multitouch/`.

| the run | what happened |
|---|---|
| `--via sudo`, from an agent shell | both writes returned **1**. the skill printed `✔ refreshed — back on event5` |
| the truth | the sysfs input path was **unchanged** at `input11`. no reset occurred |
| a human retry via `!` in claude-code | the prompt could not be answered — the harness sent a newline at the ask |
| `--via pkexec`, same shell | a desktop dialog, one password, done |
| the truth | `input11` → **`input27`**, and cosmic-comp re-grabbed `event5`. the pointer tracked |

⚠️ **the first row is the whole lesson.** the ✔ was printed by a skill written in the same
hour, by an author who had just read `rule.forbid.failhide`. sudo's silence is convincing
because the command really does exit and really does return — it simply returns 1.

⚠️ and the third row names a caller that will recur: **claude-code's `!` prefix cannot
carry an interactive password prompt.** so "just run it yourself" is not a repair here; it
relocates the same defect onto the human.

## .what a caller owes, beyond the choice

1. **name the escalator in the output** — `--via pkexec` in the header, so the reader knows
   which one answered
2. **warn before a dialog** — `🔐 watch your screen` costs one line and saves a human who
   stares at a terminal while a dialog waits behind it
3. 🛑 **verify the EFFECT, never the exit code** — read a before/after fact the write must
   have changed. the touchpad skill compares the sysfs input path and halts where it is
   unchanged, whatever `tee` returned
4. **halt on the first failed write** — do not proceed to a second privileged act on the
   hope the first landed

## .the test

> **could this line ever run where no terminal is attached?**

- yes → pick the escalator at run time; a bare `sudo` there is a silent no-op
- no, and you can prove it → `sudo` is fine, and say why inline
  (`rule.require.exemptions-name-their-trigger`)

## 🛑 .this is NOT a tty test for a HUMAN

`rule.forbid.tty-as-a-proxy-for-a-human` forbids a tty check used to decide *whether a
human is present*. this rule reads a tty for a different and narrower question: **on which
channel can a password be asked for?**

| the question | the reader |
|---|---|
| *is a human here?* | 🛑 never a tty. that rule owns it |
| *can sudo prompt on this channel?* | ✔ a tty, and that is exactly what a tty means |

⇒ the two are adjacent and they do not collide. a `local@cicd` box has no tty AND no
human, so this ladder correctly ends at `pkexec` absent → halt.

## .the bound

- `pkexec` needs a **polkit agent** up. a headless box has none, so the ladder must end in
  a halt rather than a hang
- `pkexec` scrubs the environment. a command that leans on an inherited var breaks under it
- a **grove** is headless by construction, so `pkexec` never applies there — a grove's
  seat gets NOPASSWD sudo instead (`rule.require.one-command-provision`)

⇒ so this rule governs a **local@unix** box, where a desktop session is present. it adds
no capability to a cloud grove and takes none away.

## .enforcement

- a bare `sudo` on a path a tty-less caller can reach, with no escalator choice made at run
  time and no inline trigger = **nitpick**
- a privileged write judged by the exit code of its pipeline, with no before/after read of
  the effect = **blocker** (`rule.forbid.failhide` — the severity is that rule's, not this
  one's)
- a second privileged write attempted after the first returned non-zero = **blocker**
- a fix-text that tells a human to "run it yourself" where the harness cannot carry a
  password prompt = **blocker**; that is the defect relocated, never repaired

## .see also

- `rule.forbid.failhide` — what a silent sudo failure turns into
- `rule.forbid.tty-as-a-proxy-for-a-human` — the adjacent rule, and why they do not collide
- `rule.require.bounded-probes-in-verifies` — a `pkexec` dialog can wait forever; bound it
- `gotcha.a-check-that-cries-wolf-gets-silenced` — q1: does the evidence agree with the
  verdict? `✔ back on event5` beside an unchanged sysfs path is exactly that check
- `rule.forbid.adhoc-shell` — why the escalator belongs inside a skill, never at a prompt
- `.agent/repo=.this/role=any/skills/input.touchpad.refresh.sh` — `__tp_escalator` and
  `__tp_write_as_root` carry this ladder

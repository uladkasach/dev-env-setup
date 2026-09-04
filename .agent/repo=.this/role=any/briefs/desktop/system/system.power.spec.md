# system.power.spec

## .what

machine never suspends, sleeps, hibernates, or locks automatically.

all power state changes require explicit terminal commands.

## .why

- keyboard misfire on power/sleep keys is too common
- lid close while external monitor connected shouldn't suspend
- accidental suspend loses work context
- display disconnect triggers false lid-close events

## .behavior

| trigger | action |
|---------|--------|
| lid close | ignored |
| power key | ignored |
| suspend key | ignored |
| hibernate key | ignored |
| reboot key | ignored |
| idle timeout | ignored |
| screen idle | never turns off |

## .explicit commands

| command | action |
|---------|--------|
| `machine.lock` | lock the session |
| `power.suspend` | suspend to RAM |
| `power.restart` | snap kitty, then reboot |
| `power.off` | snap kitty, then power off |
| `machine.logout` | log out current user |

🛑 **there is no `machine.reboot`.** it stood beside `power.restart` as a bare
`systemctl reboot` — one act, two words, and the terser one discarded the
window/pwd map `4.3.4.snapshot` exists to preserve. a synonym is usually only
drift; this one had an invisible cost, since both verbs reboot and only one
brings your terminals back. `1.2.power`'s own fix-text recommended the lossy one.

⇒ the split is by noun: **`power.*` owns the power-state transitions**
(off / restart / suspend), **`machine.*` owns the session-level acts**
(lock / logout).

⚠️ **every command above is read from `src/bash_aliases.sh`.** this table is a
second holder of that file's contents, so it drifts with no signal
(`gotcha.a-check-that-cries-wolf-gets-silenced`, m.9). it carried
`machine.shutdown` — a command this repo has never declared — while the real
verb was `power.off`.

⇒ a reader who wants the live set asks the file, never this table:

```sh
rhx grepsafe --pattern "^alias (machine|power)\." --glob 'src/bash_aliases.sh'
```

🛑 and `machine.lock` is the row that most needed to exist. the two idle rows
above say this box never locks itself, so a deliberate lock is the ONLY lock —
and it was absent from the box for as long as this table claimed a lock command.

# F10 — two kernel facts the check rests on are owed a measure on a real grove

## .the facts
1. **the boot floor across a resume.** the check reads `NOW - /proc/uptime` as "the box just
   resumed". `/proc/uptime` counts boottime, which may include the time hibernated; if so, a box
   fresh from resume reads as booted long ago, and the floor holds naught
2. **a keystroke is a pts's atime.** the check reads `%A@`; the clamp proves the rule on a regular
   file, never the kernel's stamp on a real pts. the check reads numbered slaves only, so
   `/dev/pts/ptmx` — which every pty opens through — cannot pin the box; the measure confirms a
   slave's atime holds still while a detached pane prints, and moves on a typed line:
   `stat -c '%n %X %Y' /dev/pts/<n> /dev/pts/ptmx`, before and after each

## .the fork
- **measure first** — read one real resume (the uptime and the first tick after it) and one real
  keystroke (`stat -c '%X %Y'` on a pts before and after a typed line), then settle each read
- **ship as written** — the atime read is what `w(1)` rests on; the boot floor predates this change

## .taken — ship as written, measure at 5.3
- the boot floor is not new here: the old check read the same `/proc/uptime`, and this change
  neither widens nor narrows it
- this seat cannot read the kernel journal across a resume (`machine.journal.read --scope kernel`
  over 30 days matched no hibernation line)
- the 5.3 ground seat on 0901 can read both: the journal of a real resume, and a pts it types into

## .if the boot floor fails the measure
the timer is `OnUnitActiveSec=300` on CLOCK_MONOTONIC, which halts across a hibernate, so the first
tick after a resume can fire before a human connects. the repair is a resume stamp the check reads,
e.g. `systemctl show -p ExecMainExitTimestamp systemd-hibernate.service`.

## .a third fact, owed the same measure — `reset-failed` on a unit that never failed
the apply ends with `systemctl reset-failed idle-hibernate.service`, so its own verify reads a
clean Result rather than the stopgap's last `exec-condition`. systemd documents reset-failed as a
clear of the *failed* state; whether it also zeroes a `Result=exec-condition` on a unit that sits
`inactive`, not `failed`, is unmeasured. the play stub models it as cleared. if the 5.3 ground
apply shows it holds, the verify names that stale fault once and the next clean tick clears it —
a loud false ✋, never a hidden fault. the repair would be to read `Result` only when
`ExecMainExitTimestamp` is newer than the apply.

## .a fourth fact, owed the same measure — a pane pty under an idle TUI
a tmux pane's pty is a numbered pts, so `read_pts` reads it beside an ssh shell's. the atime rule
holds the box only on a READ from the slave — input that reached the process — so an idle claude
TUI in a detached pane should leave it still. if the TUI's own polls stamp atime, a crew that only
waits would pin its box awake forever with no keystroke. the measure, from the ground seat: a
detached pane under an idle `claude`, `stat -c '%n %X %Y' /dev/pts/<pane>` across three ticks.
the repair, if it fails, is to read only the ptys no tmux server holds (the pane ptys are listed by
`tmux list-panes -a -F '#{pane_tty}'`).

## .fact 1 no longer gates a wrong sleep — the wake floor (i008)
the check now reads its own record: `/run` is tmpfs, so a last tick further back than
`TICK_GAP` (3 × the timer's cadence) is a box that was frozen, and the check holds for
`IDLE_LIMIT` from that wake. the wake rides in the record, so the floor lasts the limit, never
one tick. arms `wakegap`, `wakecarry`, `wakeover`, `wakebadrecord` prove it on any box, and
the drift play's `tickgap` arm ties the gap to the timer. the boot-floor measure stays owed,
but a wrong answer to it now costs a redundant hold, never a sleep.

## .a fifth fact, owed the same measure — `/run` survives a hibernate
the wake floor and the `last sleep` line both rest on `/run` tmpfs that lasts through a
hibernate and resume. hibernate writes RAM to disk, so tmpfs should survive; a cold boot clears
it. the measure, from the ground seat after the first real sleep: `stat
/run/idle-hibernate.last-sleep` and the first tick's `newest=wake` in `/run/idle-hibernate.last`.
if `/run` is cleared, the box falls back on the boot floor — fact 1 — and the sleep line reads
"none since cold boot".

## .measured at 5.3 — facts 2 and 4, on this grove's kernel (2026-11-21)
`rhx play.run --play prove.pts-atime-moves-on-a-read-only` — a private tmux server, real
`/dev/pts/<n>`, 10s windows across the kernel's 8s tty-stamp bucket:

| arm | atime | mtime |
|---|---|---|
| a pane that only prints | held | moved |
| a pane blocked in a read, no input | held | — |
| one typed line, read by that pane | moved | — |
| a TUI that redraws and polls (`top -d 1`) | held | — |
| `/dev/pts/ptmx`, across a new pty | held | held |

⇒ fact 2 holds, and fact 4 holds for a TUI that polls; the play is permanent, so any box re-proves
it. a live claude pane is the one shape the play cannot stand in for — its keyboard read is node's
raw-mode stdin, which reads only on data, so the same rule should hold; a ground-seat watch of one
idle crew pane across three ticks confirms it.

facts 1, 3, and 5 need a real hibernate or root; they are the ground seat's
(`5.3.verification.handoff.v1.to_foreman.md`).

## .rework — clean
one reader in `idle-hibernate.sh`, and one arm in the clamp.

## .confidence — 60%, and why it is low
both are unmeasured on this box, and the first can let a resumed box re-hibernate within one tick.

## .where
`idle-hibernate.sh` `read_boot` and `read_pts`; owed at `5.3.verification`

## .verdict
facts 2 and 4 measured and hold (5.3). facts 1, 3, 5 open, owed the ground seat — and fact 1 no
longer gates a wrong sleep (the wake floor)

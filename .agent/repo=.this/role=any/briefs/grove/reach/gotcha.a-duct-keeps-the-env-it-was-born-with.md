# gotcha: a duct keeps the env it was born with

## .what

a duct is a tmux pane, and a pane's shell holds the environment it started with —
PATH, exported vars, functions — for as long as it lives. a later write to
`~/.profile` or `~/.bashrc` reaches every NEW shell and never the old one.

on a grove the boot opens each seat's duct at wake (step 1), before any apply has
laid PATH. so after step 2 converges, the duct's own shell still has no pnpm dir,
no fnm, no `rhx`.

## .the measurement — 2026-11-17, hetzner camper seat

a green boot, then the command the repo hands every human:

```
$ rhx git.grove.send <grove> --reply --what 'command -v rhx'
> (empty)            exit 1
```

a child shell on the same seat found it, because it read the rc files fresh:

```
$ rhx git.grove.send <grove> --reply --play <probe>
   parent:   bash started Nov 14   ← the pane, born at the first wake
   rc files: rewritten Nov 17      ← the converge
   parent PATH has pnpm: no
   rhx: ~/.local/share/pnpm/rhx    ← the child
```

one `rhx duct.reboot --on 'duct://<grove>/main/mechanic'` cured it: `respawn-pane`
starts the default shell as a login shell, which reads the converged `~/.profile`,
and the pane's cwd is kept.

## .the tell

a command works under `--play` (a child `bash`) and fails under `--what` (the pane's
own shell). the two differ in WHEN their shell was born, not in what is installed.

## .where it is fixed

- the boot reborns each seat's duct once its apply reads done —
  `boot_seat_duct_reborn` (`git.grove.provision.boot.operations.sh`)
- clamp: `prove.boot-steps-name-each-verdict`, arm 2c — the reborn line per seat, the
  halt when the duct refuses, and the call site in `drive_seat`

## .what remains true

an apply run OUTSIDE the boot (a human's `--what 'rhx grove.provision …'`) that
changes PATH leaves the duct it ran in on the old env. the repair is the same verb:

```sh
rhx duct.reboot --on 'duct://<grove>/main/mechanic'
```

## .see also

- `gotcha.the-duct-returns-the-send-not-the-answer` — the same transport, its other trap
- `rule.require.reach-a-grove-through-its-duct` — why the duct, not raw ssh
- `gotcha.a-tool-found-by-path-answers-only-a-human` — the PATH seam on the box itself

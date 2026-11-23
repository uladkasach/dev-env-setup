# F11 — the boot's `--what` step skips are proven live, never by a hermetic drive

## .the fork

`git.grove.provision boot --what <slug>` skips the keys, the admin-seat clean, the grants, and the
gate. a peer asked for a hermetic clamp of that selection.

- **A** — prove the skips on a live grove; each `--what` boot prints which steps it skips, and the
  log is the record. the bad-input half stays hermetic (`prove.boot-steps-name-each-verdict`)
- **B** — a hermetic drive: stub the wake, the reach, the push, the duct, and each seat apply, so
  the boot body runs to the selection on a fake grove
- **C** — lift the selection into a named function and clamp only that function

## .taken: A

- the selection sits in the skill's top-level body, after the transport. B stubs every transport
  step to reach six lines, and a stub that drifts from the real transport proves naught about it
- each `--what` boot already states its skips in its own output (`what: <slug> — one bundle, on each
  seat; no grants, keys, or gate`), and the live log holds no keys, admin-seat, grant, or gate step
- C is the clean upgrade if a regression ever lands: a lift plus one case, with no caller to touch

## .rework — clean

C is one function lifted from the boot body plus one play case. no caller depends on the shape.

## .confidence — 80%

## .risk — safe

an edit that ran a skipped step on a one-bundle boot would show in the next live boot's log, and
every skipped step is idempotent.

## .where

`.agent/repo=.this/role=any/skills/git.grove.provision.boot.sh`, the `[[ -n "$WHAT" ]]` block;
evidence `.log/grove-backup/boot.hetzner.tmux.i002.log`; disputed at i003 r008 nitpick.2

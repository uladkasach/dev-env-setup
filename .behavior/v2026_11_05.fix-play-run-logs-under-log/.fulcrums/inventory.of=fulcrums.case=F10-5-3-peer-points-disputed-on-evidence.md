# F10 — 5.3 peer points disputed on evidence

## .the fork

two 5.3 peer concerns ask for a change this route judges wrong. each is disputed, with its
evidence, rather than conceded and bent to fit.

### r3 blocker.1 — `prove.claude-enrolls-only-in-a-linked-repo` stubs the user manager

- **the ask**: an integration test that calls real `rhx`, real `claude`, and the real user
  manager, under `rule.require.external-contract-integration-tests`
- **the dispute**: that rule binds an EXTERNAL contract — a service this repo calls over a wire,
  with credentials. the play's subject is a local shell function, `claude()` in
  `bash_aliases.sh`, and its claim is which binary it chooses from three cwds. the `rhx` and
  `claude` stubs are on main, untouched here; this diff adds only the `_user_systemd_await` stub,
  so the function reaches the choice it is judged on. a real launch would open an interactive
  claude session from inside a play, and a play may not start one (`rule.forbid.tty-as-a-proxy-
  for-a-human`; the play header: *"launches no claude"*). no wire, no credential, no response
  shape exists to validate

### r6 nitpick.1 — a fault names a path repo-relative, and its `fix:` names it absolute

- **the ask**: one form within a block
- **the dispute**: the two forms do two jobs. the message names the artifact the way the header
  does (`.log/…/what=all/…`), so a human matches the two by eye. the `fix:` is a command to paste
  (`df -h …; ls -ld …`), and only an absolute path runs from any cwd: a human who runs `rhx` from
  a subdir of the repo, or from another shell, gets the right answer. a relative `fix:` would run
  wrong there, with no error, which is a worse defect than two forms in one block

### r6 nitpick.2 (i002) — a declined play wears 🌙 in the tree, its coda wears ✋

- **the ask**: one glyph for the declined state, tree and coda alike
- **the dispute**: the two glyphs mark two things. 🌙 in the tree is a per-play VERDICT, one of
  three (✔ · 🌙 · 💥). the coda is the run's ERROR HEADER, and `rule.require.qualified-error-headers`
  fixes its opener by class: `✋ ConstraintError:` for exit 2, `💥 MalfunctionError:` for exit 1.
  the fail coda's 💥 matches the tree by coincidence of class, not by a rule that the coda echoes
  the tree. `--play`'s own decline coda is `✋ ConstraintError:` too, so the run reads one way in
  both modes

### r2 nitpick.1 (i003) — rename the header pair `verdict:` / `plays:`

- **the ask**: a matched noun shape (`log:` / `dir:`), apart from the `verdicts` title
- **the dispute**: the pair is the vision's contract, approved by the director: *"the header names
  both artifacts, one line each: `├─ verdict:` and `├─ plays:`"*. each label names what its path
  HOLDS — the verdict, and the plays' logs — which is what a reader looks for; `log:` / `dir:` name
  the file shape and would leave a reader to ask which log. `verdict:` labels a path and `verdicts`
  titles a list, so the two do not read as twins. a rename here would move an approved contract
  inside a verification stone

### r12 blocker.2 (i004) — the decline coda changed from `🌙` to `✋ ConstraintError:`

- **the ask**: restore `🌙`, or win the wisher's sign-off
- **the dispute**: the same point as r6 nitpick.2 above, raised as a blocker, and again at i005.
  the coda is an exit-2 error header, and `rule.require.qualified-error-headers` makes
  `✋ ConstraintError:` its only legal opener. 🔴 **two reviewers demand opposites here**: 5.1's
  mech-failhides (i002 blocker.1) required the `✋`, and it was conceded; 5.3's r12 requires the
  `🌙` back. a restore re-breaks a repo rule, so the `✋` stands and the director rules. it
  changes a glyph and a class name, never the exit code, the tally, or the log a reader reads

### r12 nitpick.1 (i004) — the clamp declines under root

- **the ask**: gate only the cases that need a read-only dir
- **the dispute**: root ignores file modes, so the locked, unsearch, truncated, and playlock
  cases would each pass for the wrong reason or fail for no defect. a clamp that runs half its
  cases and reads green is the partial pass `rule.forbid.failhide` names. the decline exits 2 and
  names the fix; the ci workflow runs as a non-root user

### r12 nitpick.2 (i004) — runner behavior drifted past the wish

- **the ask**: note that a caller may have relied on the old tolerance
- **the dispute**: each change is recorded in the 5.1 yield's foreman section, and q11 searched
  every caller in `.play`, `.github`, `src`, and `.agent/repo=.this`: none drives `play.run` but
  the runner and its clamp

### r10 nitpick.5 (i004) — unrelated changes in the tree

- **the ask**: split them out
- **the dispute**: the commit is staged by name at the done gate. the director ruled the
  package bumps and the hook swap ride along; the three plays ride under F8; the
  `settings.of.grove.json` symlink and the home-path line in `settings.of.repo.json` stay out

### r11 nitpick.4 (i004) — the claim faults use internal terms, and their `fix:` is a read

- **the dispute, in part**: the repeated `rmdir:` prefix is repaired. "claim" is the vision's
  word for the stamp's `mkdir` (q9), the same word the code and the dimensions use. the `fix:` is a
  read because the cause is unknown at the moment of the fault — a full disk, a mode, a path too
  long — and each wants a different repair; to print one would guess

### r11 nitpick.4 (i005) — three snap titles claim what a masked tree cannot show

- **the ask**: snap a `what=all/` tree with stamp ordinals for red-after-green, next free second,
  and 4 at once
- **the dispute**: each claim is about WHICH stamp — the next second, the newest by name — and
  each is asserted by name in the play (`redafter — the red log is the newest by name`,
  `shift — …`, `race — …`), the only place the real stamps are visible. a snap masks every stamp
  by design, so an ordinal there would be a second, hand-built name scheme that could drift from
  the asserts. the titles name the case; the asserts carry the proof

## .taken, why

each disputed. r1 nitpick.1 (the emulator phase) is held under F8, not here.

## .rework, why clean

each is a local edit if the director prefers the ask: a real-launch probe, or a relative path.

## .confidence — 80%, why low

r3's rule reads, at a glance, as "every mock owes a real twin"; a reader may weigh it wider than
its external-contract scope.

## .where

5.3 peer review, i001: r003 blocker.1 · r006 nitpick.1. i002: r006 nitpick.2. i003: r002 nitpick.1. i004: r012 blocker.2 · r012 nitpick.1 · r012 nitpick.2 · r010 nitpick.5 ·
r011 nitpick.4.

## .verdict

- **the decline coda — ruled by the director, 2026-11-07: keep `✋ ConstraintError:`.**
  `rule.require.qualified-error-headers` is a repo rule, and 5.1 conceded it. 5.3 r12's point
  stands disputed
- the other points here: owed by the director.

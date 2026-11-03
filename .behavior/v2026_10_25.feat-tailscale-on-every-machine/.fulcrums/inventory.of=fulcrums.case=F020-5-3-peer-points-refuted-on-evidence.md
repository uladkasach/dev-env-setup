# F020 — 5.3 peer points refuted on evidence, or outside #174's surface

- **fork:** change the code to quiet each point · or answer it with the evidence that it does not hold
- **taken, why:** answered on evidence, one per point
  - **r2 blocker.3**, "a brief ships diff markers and an open fence".
    `rule.require.prove-each-bundle-plan-apply-apply.md` holds no `-#` or `+#` line, and its
    8 fences pair up (`rhx grepsafe --pattern '^[-+]#|^\`\`\`'`). the reviewer read the review
    prompt's diff hunk as file content
  - **r3 nitpick.1**, "no tracked play paves plan-apply-apply". the gap predates #174: the play
    the briefs cited lived under the gitignored `.play/temporary/`, so no checkout ever carried it.
    this pr ADDED the "no tracked play paves this" paragraphs, to replace a pointer that reached no
    file. a
    tracked play for the per-bundle triple is a repo-wide change, outside a tailscale pr. the pass
    conditions this pr rewrote beside it are a separate question, reserved for the commander in F021
  - **r4 nitpick.1**, "a fixture for the `@` charset". the real tree is the fixture: the play
    prints `✔ …/user@.revive.conf` for the real asset, and its own bite plants an untracked
    asset and sees the count move. a synthetic `@` fixture would prove a weaker claim than the
    real one
  - **r1 blocker.3**, "the transcript snap is not in the diff".
    `git ls-files --stage` lists `.play/permanent/prove.for-detect-refuses-an-underived-env.snap/transcript.snap`
    as staged, and the play reports `snapshot matches: transcript ✔`
  - **r1 blocker.4**, "the evidence cites a play not present". the same command lists
    `.play/permanent/prove.hetzner-probe-reads-its-declaration.play.sh` staged, and
    `rhx play.run --play prove.hetzner-probe-reads-its-declaration` holds all 19 claims
  - **r1 nitpick.8**, "`git.grove.play.await.sh` is truncated". the file has 389 lines on disk;
    the cut is the review prompt's, never the file's
  - **r4 blocker.1**, "the gh fix-text lacks a snapshot in the target".
    `.play/permanent/prove.gh-names-no-aws-params-off-ec2.snap/transcript.snap` is staged and
    sat in r4's own target list (its `input.scope.json`); it holds both texts, off ec2 and on
  - **r4 blocker.2**, "the transcript snap holds only the `grove_for_valid` line". the staged
    snap holds every arm, one aligned row each, and the play's stdout is built from the same
    lines it snaps
  - **r5 nitpick.3**, "`local@house` and the gh bundle sit outside the catalog". the catalog is
    #174's (tailscale). the gh rows are S007's ruled fix, proven by their own play; `case=_`
    names both as out of its scope, so no row hides
  - **r6 nitpick.2**, "the fix lines say `grove.provision`, not `rhx grove.provision`". the
    refusal fires inside the entrypoint, where `rhx` may be absent on a fresh box.
    `grove.provision` is the shell alias every box gets from `2.7.aliases`, and
    `repo.overview` names it the same command
  - **i003 r1 nitpick.4**, "a house grove is not a class this repo detects". it is a class
    this repo declares: `repo.overview` and `rule.forbid.aws-params-off-ec2` list local, house,
    and cloud, and #174 names a house box among the remote groves. no probe names one yet, so
    `_platform_is_ec2` fails it CLOSED, which is what the comment says
  - **i003 r6 nitpick.5**, "the two done verdicts name different subjects". each names what its
    read observed. pgrep sees the play, so `the play finished`. tmux sees only the pane, so
    `idle … the pane is back at 'zsh'`. one subject for both would claim the coarse read saw a
    play it never saw, the false ✔ the skill exists to prevent
  - **i005 r2 blocker.3 · r4 nitpick.2**, "the for-detect footer is outside the snap". the footer
    `🌲 all claims held ✔` reports the snap's own result, so it prints after the snap is read. a
    line cannot sit inside the snapshot whose match it announces. every line before it is snapped,
    and a drift fails the play with rc 1 whatever the footer says
  - **i005 r2 blocker.4 · r4 blocker.5**, "plan/apply/apply has no tracked play". the same point as
    r3 nitpick.1 above. the howto's sentence names the gap, a tracked per-bundle triple is a
    repo-wide play outside a tailscale pr, and the work is caught as dream
    `2026_10_26.track-the-plan-apply-apply-play`
  - **i005 r2 nitpick.5**, "the devtools dispatch order has no test". `prove.every-bundle-is-dispatched`
    proves every bundle is reached, `5.23.tailscale` among them (it passed). #174's one change to
    `5.devtools/_.sh` adds `5.23.tailscale`, which reads no key and so carries no order of its own.
    the constraints the reviewer names (`5.19.op`, `5.16.keys`, `5.18.openhours`) predate this pr
    and are unchanged by it; a test of the whole order is a repo-wide play
  - **i005 r6 nitpick.1**, "the pid list ends in a space". `PIDS="$(__grove_play_pids …)"` is a
    command substitution, which strips the final newline, so `${PIDS//$'\n'/ }` joins with inner
    spaces only. the live run read `(pid <n>)`, flush
  - **i005 r6 nitpick.2**, "a failure row shifts the `→` column". a failure row opens with its
    error class, per `rule.require.qualified-error-headers`. a pad on the pass rows to match would
    put 21 blank columns before every success, and a failure row is meant to stand apart
  - **i006 r11 nitpick.1**, "shouts in the snaps". a capped word inside a refusal body (`NOT
    installed`, `BOX-WIDE`, `ONCE`) is this repo's house emphasis, shared by about 30 refusals
    across the bundle tree (`rhx grepsafe --pattern 'NOT installed|NOT declared' --path src`). a
    rewrite in this pr's files alone would leave one bundle out of step with its peers, and a sweep
    across the tree is outside a tailscale pr. the class header, which a rule binds, is fixed:
    `✋ ConstraintError: key fingerprint mismatch`
  - **i006 r11 nitpick.7**, "`[stub] rhx git.grove.read` is harness noise". it is the snap's record
    that the skill reads the pane's tail after each verdict. a stub that printed naught would let a
    skill that dropped the tail read pass with the same bytes
- **rework:** clean. each is one reviewer's point, and a fix later is local
- **risk:** low|safe
- **confidence 85%**

# F8 — a play whose fetch fails exits 2 (unread), never 1

- fork: grade a failed fetch in `prove.tmux-tarball-matches-the-pin` as a malfunction, exit 1
  (`rule.require.exit-code-semantics`) vs exit 2, the play contract's "no claim was graded"
- taken: exit 2. a play's exit is a VERDICT on its claim, not a skill's who-fixes code:
  0 proven, 1 disproven, 2 could not read. every play in `.play/permanent` declares that
  same `2 =` line in its header (20 of 20 that declare exits). exit 1 here would read "the
  pin's digest is wrong" — the one false claim this play exists to catch — on a network blip
- rework: clean — one exit code
- confidence 85%; low only because the skill rule reads as general, and plays are not named
  in it as an exception
- where: `.play/permanent/prove.tmux-tarball-matches-the-pin.play.sh`

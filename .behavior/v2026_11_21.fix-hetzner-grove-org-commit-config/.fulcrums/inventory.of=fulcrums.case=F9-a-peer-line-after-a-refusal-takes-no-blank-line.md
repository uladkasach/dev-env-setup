# F9 — a peer line after a ✋ block takes no blank line

## .the fork

peer round i001 of 5.3 (r006 nitpick.4) asked for a blank line, or a sub-label, between a verify's
✋ block and the `•` pass line that follows it, so a reader sees the ✋ end.

- **a blank line** — a visual stop between the refusal and the next claim
- **depth alone** — the `•` line returns to the ✋ header's own depth (3 spaces), a peer, while
  the ✋'s why/fix body sits at 6 and 9; the return to depth IS the end of the block

## .taken

depth alone. a verify's claims are peers on one trunk, and `rule.forbid.treestruct-header-gap`
grades a blank line between branches of one trunk a blocker. every verify in this repo renders a
✋ and its peers this way, so a blank line here would make this bundle the one that differs.

## .rework

clean: one `echo ""` after each ✋ block in `configure.verify.sh`, and a snap rebuild.

## .confidence

85%. the ergonomist's read (a reader may take the `•` as a second clause of the ✋) is a fair
read of the bytes; the counter is the repo-wide treestruct rule and the depth already present.

## .where

`src/grove.provision/5.devtools/5.26.commitorgs/configure.verify.sh`; snap
`.play/permanent/prove.commitorgs-reads-the-meter-as-the-gate.snap/transcript.snap`.

## .verdict

open: disputed in peer round i001 of 5.3, for the council.

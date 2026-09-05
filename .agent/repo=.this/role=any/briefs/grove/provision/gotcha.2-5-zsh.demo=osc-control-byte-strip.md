# gotcha.2-5-zsh.demo=osc-control-byte-strip

## .what

the dated measurements behind `2.5.zsh/configure.verify.sh`'s claim 5 — why the strip is
RUN rather than grepped for, and why every emit site is read rather than a bare word.

## m1 — a grep passed for a release; the sink it passed also ate every emoji

2026-08-31: a grep for the right-shaped byte range in the strip passed a release. the
same sink that let it pass also stripped every emoji it was handed — a grep proves a
strip is WRITTEN, and only a run proves it BITES.

## m2 — seen to discriminate, one run, 2026-08-31, on this laptop

GREEN half: the `LET THROUGH` arm stayed silent — zsh's `${x//[[:cntrl:]]/}` eats both
`07` (BEL) and `1b` (ESC) on this build. RED half: the same run reddened against an
INSTALLED rc that predated the strip. both directions proved in one run
(`rule.require.seam-claims-have-an-owner`).

## m3 — a bare-word grep is satisfied by a comment

a `grep -q 'cntrl' "$rc_live"` matches one partial word anywhere in the file. a COMMENT
that says `cntrl` satisfies it; this rc carries four such lines. one stripped
emitter then satisfies the grep for all four — every other emitter could ship bare and
the row would still read ✔ (`gotcha.a-check-that-cries-wolf-gets-silenced`, m9).

## m4 — seen to discriminate, 2026-09-01, the old reader vs the new, on six trees

| the rc handed to each reader | old | new |
|---|---|---|
| the shipped rc | ✔ green | ✔ green |
| every strip removed, comments intact | ✔ green | 🛑 RED |
| one emitter bare — the OSC 7 cwd | ✔ green | 🛑 RED |
| one emitter bare — the OSC 2 title | ✔ green | 🛑 RED |
| one emitter bare — tmux @repo | ✔ green | 🛑 RED |
| one emitter bare — tmux @branch | ✔ green | 🛑 RED |

the old column is ✔ on every break, even the tree with no strip at all — a check that
cannot fail.

## m5 — the new reader's bound, stated rather than left to be found

the reader follows a value two hops: `_osc7_cwd` strips `PWD` into `safe`, renames it to
`url_path`, and emits that. a per-line reader would redden on correct code; a third hop
escapes this reader. that is a deliberate bound — the rc is ours and its shape is
two hops. a reader tuned past its subject buys reach nobody uses.

## .see also

- `gotcha.a-check-that-cries-wolf-gets-silenced` — m9, the bare-word grep trap in m3
- `rule.require.seam-claims-have-an-owner` — the two-direction proof in m2
- `rule.require.security-paramount` — why this claim exists at all

# F13 — qualify the web runtime's error headers here, or defer them

## .the fork

- **a.** qualify all 33 `✋` echoes in `src/grove.web.sh` now, with a class each, and resnap
- **b.** defer to a dream with the full shape of the fix

## .taken: a — after (b) was first chosen and then measured wrong

found 2026-10-23 at 5.3, in self-review `has-ergonomics-validated`: a digest miss opened with
`✋ INTEGRITY CHECK FAILED`, no class — it failed `rule.require.qualified-error-headers`.

(b) was taken first on a guess: "33 judgments in a shared runtime, every bundle's output moves".
the buttonup review measured the ripple before it trusted the guess:
`rhx grepsafe --pattern '✋ (web_|the fetch|…|the pinned commit)' --path .play` → only
`prove.tmux-pin-upsert-fails-safe/{A,M}.snap` carry a runtime header. the class is inserted after
the glyph, so every phrase a play matches still sits whole inside the new line. one file and two
snaps: clean.

## .what landed

- the classes follow `rule.require.exit-code-semantics`:
  - `✋ ConstraintError:` — a bad call, an absent input, no gpg, a digest / key / signature / commit
    that misses its pin
  - `💥 MalfunctionError:` — a timeout, a refused fetch, an unresolved host, a failed fetch or
    clone, a hash or temp-dir or chmod failure
- return codes unchanged; text after the class unchanged
- proof: 0 unqualified headers left (`echo "   (✋|💥) [^CM]` → 0 matches); A and M red on the old
  snaps, resnapped, rerun ✔; `prove.tmux-tarball-matches-the-pin`,
  `prove.tmux-plugins-converge-past-a-whole-tpm`, `prove.kitty-signature-binds-the-pin`,
  `prove.nvim-fetches-no-unpinned-plugin` ✔; 435 files parse

## .rework: clean

text only, in one file. a council that prefers a narrower branch reverts one file and two snaps.

## .confidence 80%

the classes are judgment calls; `the server REFUSED the fetch` (an http ≥400) could read as a
constraint when the url is wrong. it sits with the network faults because a retry is the first
move and the url is pinned in the repo.

## .where

`src/grove.web.sh:256–1029`; `__snaps__/prove.tmux-pin-upsert-fails-safe/{A,M}.snap`.

## .verdict

open — done in this branch, offered to the council.

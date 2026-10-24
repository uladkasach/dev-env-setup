# F6 — bundle and play ✋ rows stay bare glyphs, not `✋ ConstraintError:` headers

- fork: qualify every ✋/💥 row this route adds (`rule.require.qualified-error-headers`) vs
  keep the bare glyph rows every bundle phase and play in this repo prints
- taken: bare — for three reasons, each measured
  1. **a row is not a header.** a phase prints into `grove.provision`'s tree, indented under
     its bundle; the one top-level header is the entrypoint's own `✋ grove.provision finished
     with failures`. the rule governs the line a human reads FIRST, and that line is not ours
  2. **the class would lie about the exit.** a phase returns 0 or 1 to `bundle.upgrade`, and a
     play exits 0 proven / 1 disproven / 2 could not read. `ConstraintError` promises exit 2
     and `MalfunctionError` promises exit 1 (`rule.require.exit-code-semantics`); neither maps
     onto "the claim is false", which is what most of these rows report
  3. **the repo speaks one dialect.** `grepsafe` over `src/grove.provision`: the qualified form
     appears only in `2.7.aliases/brains.auth.sh`, a human-run CLI. over `.play/permanent`: zero
     (the one hit quotes a CLI's output). a qualified row in two new bundles would be the only
     one among every phase in the tree
- i002: reason 1 conceded — the rule's 👎 examples are bash echoes, so a row is not exempt by
  its place. reasons 2 and 3 stand; the call is reserved for the council, since a reviewer
  refuted the guess twice
- verdict: ruled by the director — concede; the reviewer is right. every error row this route
  touches now opens with a qualified header: `✋ ConstraintError:` or `💥 MalfunctionError:`,
  in the bundles `2.8.tmux`, `1.6.4.keyrackd`, `1.6.7.linger`, `1.6.8.coredump` and the
  route's plays. glyph and class stay paired; every edited play re-ran green
- rework: clean — a header rewrite is a text edit; a repo-wide dialect change is its own route
- confidence 75%, low because the rule's text says "every human-read error", and a phase row
  IS human-read; the case rests on "row vs header", which the rule does not draw
- where: every `✋` row in `2.8.tmux`, `1.6.7.linger`, `1.6.8.coredump`, and the route's plays

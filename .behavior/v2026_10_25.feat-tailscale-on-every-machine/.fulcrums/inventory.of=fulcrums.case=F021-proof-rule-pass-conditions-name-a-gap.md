# F021 — the proof rule's apply pass conditions now admit a named gap

- **fork:** the per-bundle proof rule (`rule.require.prove-each-bundle-plan-apply-apply`) read
  "1st apply: exit 0, any ✋ is a defect" and "2nd apply: exit 0 AND convergence". `5.23.tailscale`
  cannot meet that on a fresh laptop: the join's last step is the human's sign-in (#174's own
  invariant), so the first apply ✋s by design until the human acts. three options:
  - **(a) keep the rewrite in this pr** — a ✋ passes only where it is a **gap**: it names what a
    human or a credential alone can supply, and names that handoff. a ✋ for work the bundle owed
    stays a defect. the 2nd apply owes the same exit, the same gaps, no new ✋, and convergence
  - **(b) split it out** — revert the two briefs here, ship the criteria change as its own pr. until
    that pr lands, #174's laptop first apply counts as a defect under the old text
  - **(c) revert, no replacement** — keep the old bar, and treat the sign-in ✋ as an accepted
    exception named in `inventory.approved-divergences`
- **taken, why (best guess, lean a):**
  - the tree-scale gate in the same brief already admitted it: "every bundle which still claims is
    one a grove genuinely cannot clear (a credential)". the rewrite brings the per-bundle bar into
    line with the tree-scale one, and adds no new tolerance
  - the old howto already read non-zero applies on their merits, so practice matched (a)
  - the defect/gap split keeps the teeth: a ✋ that names bundle-owed work still fails
  - the fixed-point step the rewrite dropped from `rule.require.idempotent-install-procedures`
    ("then plan once more and require it to report no work owed") is restored. that drop was an
    accident, never the intent
- **what was NOT changed:** no tracked test, snapshot, or assertion. the mechanized diff of the two
  applies the old briefs promised was never in any checkout (a gitignored scratch play); the
  briefs now say so, and dream `2026_10_26.track-the-plan-apply-apply-play` holds the work
- **rework:** clean — two brief files; (b) or (c) is a revert of those files and touches no code
- **risk:** low|safe — a written bar, no box state
- **status:** **for the commander** — a change to a proof bar is his to rule, raised by r12 at i006
  and raised again at i008, in the same three points. r12 confirmed no tracked test or snap was
  loosened and the fixed-point step is restored; the one open question is whether the bar may move
- **confidence 70%, why not higher:** a reviewer reads any change to a pass condition as a
  weaker bar, and the commander may prefer the criteria change in its own pr (b)

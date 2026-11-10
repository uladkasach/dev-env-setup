# F13 — ❓ for the commander: is the apply the "unlock path" wish #3 asks for, or is a skill owed?

- **fork**: wish #3 asks for "an unlock path ... that only dev-env-setup's own skill uses, to change
  the file on purpose and lock it again" (r010 nitpick.1, i006)
  - **A. the apply is the path** (as built): a declared key changes in the patch, then the apply
    swaps a fresh file in the declared mode. a key the patch does not declare is a hand edit, then
    the apply — which keeps it and restores the declared mode
  - **B. a skill**: `rhx claude.settings.edit` unlocks, opens `$EDITOR`, then runs the apply
- **taken**: A. under the shipped `off` there is no lock to lift, so the hand edit needs no
  `chmod`. under `on` the brief's unlock row says `chmod u+w`, which is the step the vision says
  the commander never runs — B closes that gap, and is owed before the value flips to `on`
- **rework**: clean — B is one new skill that composes the apply; no extant code moves
- **confidence 70%, low because**: the wish names a skill, and A answers it with the apply — a
  sense of the words the commander has not confirmed
- **where**: `define.5-3-brains.declared-keys`, the lock section
- **verdict**: open — for the commander

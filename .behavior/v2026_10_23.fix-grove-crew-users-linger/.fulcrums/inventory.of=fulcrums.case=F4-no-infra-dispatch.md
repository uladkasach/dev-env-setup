# F4 — no dispatch to ahbode/infrastructure

- fork: dispatch tmux/linger to `genGroveHibernatorUserData.ts` vs not
- taken: not — the userdata installs neither tmux nor linger (read at origin/main), so the
  "same source" the wish names does not live there; grove.provision owns both
- rework: clean — a later radio task, if the wisher wants linger at `useradd` as defense in depth
- confidence 75%
- where: n/a
- re-asked i004 by r10 (enroll-impl-behavior-intent, blocker.7): camper does not linger until
  its first provision, and one `loginctl enable-linger` in the userdata would close that window.
  the window holds no crew (crews start after provision), so the dispatch is defense in depth.
  the director's call; disputed on the lane to this row

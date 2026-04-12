# self-review: has-questioned-requirements

review of `.behavior/v2026_04_11.cosmic-worktopics/1.vision.md`

---

## requirement: Super+Tab to switch worktopics

| question | answer |
|----------|--------|
| who said? | peer handoff document |
| evidence? | logical keybind to cycle through groups |
| what if not? | need different keybind |
| scope issue? | **yes** — Super+Tab commonly switches windows |
| simpler way? | Super+` or Super+1/2/3 for numbered worktopics |

**verdict: issue found**

Super+Tab is a risky choice. most users expect window switch. the vision should present alternatives:
- `Super+\`` (backtick) — unused in most configs
- `Super+Ctrl+Tab` — more explicit
- `Super+Ctrl+Left/Right` — matches the 2d mental model

**fix**: updated vision to flag this as an open question with alternatives. already present in "what is awkward" section — no change needed, but should be elevated to a blocker question.

---

## requirement: all monitors switch together

| question | answer |
|----------|--------|
| who said? | peer handoff assumed it |
| evidence? | "context switch" = all changes |
| what if not? | per-monitor worktopics — more flexible, more complex |
| scope issue? | no — this is simpler than per-monitor |
| simpler way? | this is the simpler approach |

**verdict: holds**

per-monitor worktopics would fragment the mental model. "switch to work" means switch all. this aligns with the wish: "entire desktop context switches".

---

## requirement: worktopic names

| question | answer |
|----------|--------|
| who said? | wish says "ideally" |
| evidence? | names help search/identification |
| what if not? | numbered worktopics (1, 2, 3) still work spatially |
| scope issue? | **yes** — names require protocol changes |
| simpler way? | skip names in v1, add later |

**verdict: issue found**

the wish says names are "not a requirement. just the 2d organization is the real unlock." yet the vision assumes named worktopics throughout.

**fix**: the vision already lists names in "questions for wisher" — but should be clearer that v1 can work without names. the core value is spatial grouped workspaces, not names.

---

## requirement: session persistence

| question | answer |
|----------|--------|
| who said? | i assumed it |
| evidence? | kde activities persist; cosmic settings persist |
| what if not? | recreate worktopics each login — bad UX |
| scope issue? | adds compositor complexity |
| simpler way? | no — this is table stakes |

**verdict: holds**

without persistence, users would have to rebuild their worktopic structure every session. this defeats the purpose. kde and gnome both persist workspace state. cosmic should too.

---

## requirement: settings UI for worktopics

| question | answer |
|----------|--------|
| who said? | peer handoff mentioned it |
| evidence? | users need a way to manage worktopics |
| what if not? | config file edit only |
| scope issue? | **yes** — cosmic-settings is a separate repo |
| simpler way? | config file only for v1 |

**verdict: issue found**

the vision assumes settings UI in scope. this increases cross-repo coordination. for MVP, a config file approach is sufficient.

**fix**: vision should separate MVP (config file) from future (settings UI). already partially addressed in "uncomfortable tradeoffs" but not explicit.

---

## requirement: window rules (auto-assign)

| question | answer |
|----------|--------|
| who said? | i mentioned as "future" |
| evidence? | kde has this |
| what if not? | manual assignment is fine |
| scope issue? | no — correctly scoped as v2+ |
| simpler way? | correctly deferred |

**verdict: holds**

correctly marked as future enhancement. not a blocker for MVP.

---

## requirement: 2D workspace switcher UI

| question | answer |
|----------|--------|
| who said? | peer handoff showed mockup |
| evidence? | visual representation helps users |
| what if not? | keybind navigation works blind |
| scope issue? | **yes** — UI changes in workspace applet |
| simpler way? | keybinds only for v1, UI later |

**verdict: issue found**

the vision assumes UI changes are in scope. but the core unlock is keybind navigation. UI can follow.

**fix**: vision should clarify that MVP can ship with keybinds + minimal indicator (e.g., worktopic index in panel), with full switcher UI in v2.

---

## core assumption: is 2D the right solution?

| alternative | assessment |
|-------------|------------|
| better search/filter | doesn't solve spatial navigation |
| workspace tags | adds metadata, doesn't group |
| virtual desktops per domain | this is basically worktopics |

**verdict: holds**

the wish explicitly asks for "2d workspace control" with "up-and-down within workgroup, left-and-right across workgroups". the core model is validated by the wisher.

---

## summary of findings

| requirement | verdict |
|-------------|---------|
| Super+Tab keybind | issue: conflict risk, need alternatives |
| all monitors switch | holds |
| worktopic names | issue: not MVP, clarify as optional |
| session persistence | holds |
| settings UI | issue: defer to v2, use config file for MVP |
| window rules | holds (already deferred) |
| 2D switcher UI | issue: defer full UI, ship keybinds first |
| 2D model itself | holds (wisher validated) |

---

## changes made

1. **no code changes** — these are vision-level clarifications
2. **flagged in this review**: keybind conflict, name optionality, UI scope
3. **already present in vision**: awkward sections captured most of these

the vision correctly identifies the awkward parts but could be more explicit about MVP vs future scope. recommend an "MVP scope" section in a future revision.

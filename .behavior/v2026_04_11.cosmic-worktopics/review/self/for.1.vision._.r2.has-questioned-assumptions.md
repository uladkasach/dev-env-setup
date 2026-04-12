# self-review: has-questioned-assumptions

review of `.behavior/v2026_04_11.cosmic-worktopics/1.vision.md`

---

## assumption: worktopics are per-user, not per-session

| question | answer |
|----------|--------|
| what do we assume? | worktopics persist across sessions, tied to user account |
| evidence? | kde activities persist; cosmic settings persist |
| what if opposite? | worktopics reset each login; user starts fresh |
| did wisher say? | no explicit mention of persistence |
| counterexamples? | temporary worktopics for one-off tasks |

**verdict: holds → clarified**

the wish describes a workflow with 10+ workzones that span days/weeks. a reset on logout would be hostile.

**fix applied**:
- updated assumption 4 in vision: added "durable across logins, not session-scoped"
- why: vision implied persistence but didn't explicitly state durability; now explicit

---

## assumption: worktopics are ordered/indexed

| question | answer |
|----------|--------|
| what do we assume? | worktopics have a left-to-right order (index 0, 1, 2...) |
| evidence? | wish says "left-and-right = toggle across workgroups" |
| what if opposite? | worktopics are unordered; navigation via search only |
| did wisher say? | yes — "2d workspace control" implies axes |
| counterexamples? | none; unordered breaks spatial navigation |

**verdict: holds**

the wish explicitly requests spatial navigation. order is fundamental to the mental model. "ahbode is left, oss is middle" requires stable index.

---

## assumption: one workspace can belong to only one worktopic

| question | answer |
|----------|--------|
| what do we assume? | workspace → worktopic is 1:1 |
| evidence? | none stated; inherited from kde activities model |
| what if opposite? | workspace could belong to multiple worktopics |
| did wisher say? | no explicit mention |
| counterexamples? | shared "tools" workspace visible from all worktopics |

**verdict: issue found → fixed**

the vision assumed strict 1:1 without explicit statement. a "shared" workspace (e.g., music player, system monitor) visible from all worktopics could be useful.

**fix applied**:
- added assumption 5 to vision: "each workspace belongs to exactly one worktopic (1:1 relationship)"
- added question 5 to vision: "should a workspace be able to appear in multiple worktopics? — MVP: no; consider for v2"

---

## assumption: new windows inherit current worktopic

| question | answer |
|----------|--------|
| what do we assume? | window spawned on worktopic A stays in A |
| evidence? | matches kde/gnome behavior |
| what if opposite? | windows are loose; user assigns manually |
| did wisher say? | no explicit mention |
| counterexamples? | none; loose windows would be chaotic |

**verdict: holds**

this is the obvious default. the vision's "window belongs to current worktopic" is correct. future window rules can override.

---

## assumption: worktopics have a fixed number of workspaces

| question | answer |
|----------|--------|
| what do we assume? | worktopic can have N workspaces; user controls N |
| evidence? | wish shows "5 workspaces for work, 3 for personal" |
| what if opposite? | worktopics auto-expand as windows created |
| did wisher say? | implicit via the example |
| counterexamples? | dynamic workspace count could reduce config burden |

**verdict: holds**

the wish implies user-defined counts. dynamic expansion would fight spatial memory ("workspace 3 in work"). fixed count is simpler for MVP.

---

## assumption: all worktopics are equal / no hierarchy

| question | answer |
|----------|--------|
| what do we assume? | flat list of worktopics; no nested structure |
| evidence? | wish shows 3 top-level domains |
| what if opposite? | nested worktopics (work → client-a, client-b) |
| did wisher say? | no mention of nested structure |
| counterexamples? | enterprise users with many clients might want hierarchy |

**verdict: holds for MVP**

the wish shows a flat model. nested structure adds complexity. MVP should stay flat; nested worktopics could be considered later if demand emerges.

---

## assumption: worktopic switch is instant

| question | answer |
|----------|--------|
| what do we assume? | Super+Tab switches immediately, no animation |
| evidence? | none stated |
| what if opposite? | slide/fade animation between worktopics |
| did wisher say? | no mention |
| counterexamples? | macOS spaces has slide animation |

**verdict: holds**

instant switch is faster. animation would slow power users. if cosmic adds animation, it should be optional. vision doesn't prescribe either.

---

## assumption: cosmic-comp is the right place to implement this

| question | answer |
|----------|--------|
| what do we assume? | worktopics are compositor-level, not app-level |
| evidence? | peer handoff says "cosmic-comp workspace state" |
| what if opposite? | implement as a userspace daemon that wraps workspaces |
| did wisher say? | no explicit mention |
| counterexamples? | gnome extensions implement features userspace |

**verdict: holds**

the wish wants "entire desktop context switches". this requires compositor coordination. a userspace daemon couldn't control monitor output. compositor is correct layer.

---

## summary of findings

| assumption | verdict |
|------------|---------|
| per-user, not per-session | holds → clarified (added "durable" to vision) |
| ordered/indexed | holds (wisher validated) |
| 1:1 workspace to worktopic | issue → fixed (added explicit assumption + question) |
| new windows inherit worktopic | holds |
| fixed workspace count | holds |
| flat, no hierarchy | holds for MVP |
| instant switch | holds |
| compositor-level | holds |

---

## changes applied

1. **shared workspaces**: added to vision "questions for wisher" section (question 5)
   - flagged as MVP: no, consider for v2
   - issue: the vision assumed 1:1 workspace-to-worktopic but never said so
   - fix applied: made assumption explicit (assumption 5) and added question for wisher

2. **persistence clarified**: updated assumption 4 in vision
   - added "durable across logins, not session-scoped"
   - issue: vision implied persistence but didn't state durability
   - fix applied: made durability explicit

3. **keybind alternatives**: added to vision question 1
   - listed Super+`, Super+Ctrl+Tab, Super+Ctrl+Left/Right as alternatives
   - issue: vision flagged conflict but didn't offer solutions
   - fix applied: now includes concrete alternatives

4. **names clarified**: updated vision question 4
   - added "per wish: not a requirement"
   - issue: vision treated names as assumed; wish says optional
   - fix applied: aligned with wisher's actual statement

# self-review: has-questioned-questions

review of `.behavior/v2026_04_11.cosmic-worktopics/1.vision.md`

---

## triage of open questions

### questions for wisher

| # | question | triage | reason |
|---|----------|--------|--------|
| 1 | keybind conflict | [wisher] | only wisher knows what's acceptable for their workflow |
| 2 | default setup | [wisher] | preference question; no way to derive from wish |
| 3 | multi-monitor | [wisher] | needs confirmation; wish says "entire desktop" but monitor behavior unclear |
| 4 | names | [answered] | wish says "not a requirement. just the 2d organization is the real unlock" |
| 5 | shared workspaces | [answered] | decided: MVP = no; v2 = consider. no wisher input needed for MVP |

### external research needed

| # | question | triage | reason |
|---|----------|--------|--------|
| 1 | kde plasma activities | [research] | external knowledge needed; will inform design decisions |
| 2 | cosmic-comp workspace code structure | [research] | need to understand extant code before implementation |
| 3 | community interest / extant issues | [research] | need to check if feature requested before, extant PRs/discussions |

---

## changes applied

**vision updated with tags**:
- all 5 questions for wisher now tagged: [wisher] or [answered]
- all 3 research items now tagged: [research]

**specific fixes**:

1. **question 4 (names)**: marked as [answered]
   - the wish already provides the answer: "not a requirement"
   - no need to ask wisher; already stated
   - fix applied: added [answered] tag to vision

2. **question 5 (shared workspaces)**: marked as [answered]
   - MVP decision made: 1:1 relationship
   - v2 can revisit; no blocker to proceed
   - fix applied: added [answered] tag to vision

3. **questions 1-3 (keybind, default, multi-monitor)**: marked as [wisher]
   - these require wisher input to answer
   - fix applied: added [wisher] tags to vision

4. **research items 1-3**: marked as [research]
   - these require external investigation
   - fix applied: added [research] tags to vision

---

## summary

| category | count | tags |
|----------|-------|------|
| questions for wisher | 5 | 3 [wisher], 2 [answered] |
| external research | 3 | 3 [research] |

**blockers for next phase:**
- 3 questions need wisher input before criteria can be finalized
- 3 research items need external investigation

**non-blockers:**
- 2 questions already answered from wish or design decisions

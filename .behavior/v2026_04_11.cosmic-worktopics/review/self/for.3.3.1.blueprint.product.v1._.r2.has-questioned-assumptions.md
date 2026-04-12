# self review (r2): has-questioned-assumptions

---

## deeper examination

the r1 review surfaced 7 assumptions but missed a critical one hidden in plain sight.

---

## issue found: multi-monitor workspace memory

### the contradiction

**blueprint says (data model):**
```
Worktopic
├── workspaces: Vec<WorkspaceHandle>
└── active_workspace_index: usize      # SINGLE index
```

**blueprint says (multi-monitor behavior):**
> "each monitor shows its last-active workspace in new worktopic"

**the problem:**
- if there's only ONE `active_workspace_index`, all monitors show the SAME workspace
- but we want each monitor to remember its own last-active workspace per worktopic
- these contradict

### what should happen

user has 2 monitors in worktopic "work":
- monitor 1 shows workspace 2
- monitor 2 shows workspace 3

user switches to worktopic "personal", then back to "work":
- monitor 1 should show workspace 2 (remembered)
- monitor 2 should show workspace 3 (remembered)

### what current design would do

with single `active_workspace_index`:
- monitor 1 shows workspace X (the one index)
- monitor 2 shows workspace X (same index)

this is wrong.

### the fix

**option A: per-output index in Worktopic**
```
Worktopic
├── workspaces: Vec<WorkspaceHandle>
└── active_workspace_per_output: HashMap<OutputId, usize>
```

**option B: per-worktopic index in Output state**
```
Output
├── ...
└── active_workspace_per_worktopic: HashMap<WorktopicIdx, usize>
```

**option C: use extant workspace mechanism**

cosmic-comp might already handle per-output workspace state. if so:
- each output tracks its active workspace
- worktopic switch just filters which workspaces are visible
- no new per-output memory needed in Worktopic

### which option?

option C aligns with how cosmic-comp likely works. when you switch worktopics:
1. each output already tracks its active workspace
2. worktopic switch filters to only show workspaces in that worktopic
3. if output's active workspace isn't in new worktopic, fallback to first visible

this means:
- `active_workspace_index` in Worktopic is a FALLBACK, not primary
- primary workspace state stays in Output (extant mechanism)
- no per-output map needed in Worktopic

### fix applied to blueprint

changed Worktopic comment to clarify:
```
Worktopic
├── workspaces: Vec<WorkspaceHandle>
└── active_workspace_index: usize      # fallback for outputs with no history
```

and added clarification to composition flow:
- outputs maintain their own active workspace state
- worktopic switch filters visible workspaces
- fallback to `active_workspace_index` if output's workspace isn't in worktopic

---

## other assumptions re-examined

### assumption: workspace navigation operates on worktopic's index

**r1 said:** `switchWorkspaceNextInWorktopic` modifies `worktopic.active_workspace_index`

**r2 question:** should it modify the OUTPUT's workspace state instead?

**answer:** yes. workspace navigation should:
1. operate on the current output's active workspace
2. stay within worktopic's workspaces
3. not touch worktopic's `active_workspace_index` (that's the fallback)

this is consistent with how normal workspace navigation works — it's per-output.

### assumption: workspace_idx in coordinates is worktopic-relative

**r1 assumed:** coordinates emit `[worktopic_idx, workspace_idx_within_worktopic]`

**r2 question:** is `workspace_idx` relative to worktopic or global?

**answer:** should be worktopic-relative for consistency:
- `[0, 2]` = worktopic 0, workspace 2 within that worktopic
- not global workspace index

but this needs upstream input — the protocol may have expectations.

---

## fixes applied

1. **clarified active_workspace_index semantics**
   - it's a fallback for outputs with no history in that worktopic
   - primary workspace state stays in Output (extant mechanism)

2. **clarified workspace navigation flow**
   - operates on output's active workspace
   - stays within worktopic boundaries
   - doesn't modify worktopic's index

3. **flagged coordinate semantics for upstream**
   - need to confirm if workspace_idx is worktopic-relative or global

---

---

## issue found: persistence of per-output workspace state

### the cascade

if outputs maintain their own active workspace per worktopic, that state needs to persist too.

**current WorktopicDef:**
```
WorktopicDef
├── workspace_count: usize
└── active_workspace_index: usize     # single fallback
```

**what about per-output state?**

when user logs out:
- output 1 shows workspace 2 in worktopic "work"
- output 2 shows workspace 3 in worktopic "work"

when user logs back in:
- this state should be restored

**where should it persist?**

option A: in WorktopicDef
```
WorktopicDef
├── workspace_count: usize
├── active_workspace_index: usize
└── output_workspaces: HashMap<OutputId, usize>
```

option B: in separate output config (extant mechanism)

cosmic-comp likely already persists output state. the per-worktopic workspace memory might be part of that extant mechanism.

**decision:**
- defer to phase 3 (persistence)
- investigate how cosmic-comp persists output state
- align with extant mechanism

**fix:** add note to phase 3 that per-output workspace state persistence needs investigation.

---

## issue found: phase 4 test complexity

### the assumption

phase 4 tests multi-monitor in nested mode.

**r1 said:** nested mode can mock outputs

**r2 question:** how do we verify per-output workspace memory in tests?

**the test case:**
1. create 2 mock outputs
2. set output 1 to workspace 2, output 2 to workspace 3
3. switch worktopics
4. switch back
5. verify output 1 shows workspace 2, output 2 shows workspace 3

**can nested mode do this?**

unknown. needs verification in phase 0.

**fix:** add this specific test case to phase 4 description.

---

## assumptions re-examined again

going line-by-line through the blueprint:

### line 9: "users group workspaces by domain"

**assumption:** users WANT to group workspaces

**evidence:** the wish explicitly describes this pain point

**verdict:** holds — this is the core problem statement

### line 14: "keybind handlers for Super+Ctrl+Tab"

**assumption:** Super+Ctrl+Tab is the right keybind

**what if wrong:** user might prefer different keybind

**mitigation:** keybinds should be configurable

**verdict:** holds for MVP; configurability can come later

### line 15: "2D coordinate emission via extant protocol"

**assumption:** clients can handle 2D without breakage

**what if wrong:** extant clients might fail

**mitigation:** already in risks section — version check, fallback to 1D

**verdict:** risk is acknowledged

### line 16: "session persistence via cosmic_config"

**assumption:** cosmic_config is the right mechanism

**what if wrong:** cosmic_config might not support complex nested types

**evidence:** cosmic_config uses RON which supports HashMap

**verdict:** holds

### lines 52-54: Worktopic fields

**assumption:** two fields (workspaces, active_workspace_index) are sufficient

**what if wrong:** need per-output index for multi-monitor

**fix:** r2 clarified active_workspace_index is fallback, per-output state is in Output

**verdict:** clarified

### lines 120-124: keybind contracts

**assumption:** Super+Shift+Tab is worktopic prev

**what if wrong:** user might want Super+Shift+Tab for "move window to next worktopic"

**consideration:** the vision mentions "move current window to next worktopic" as a feature

**question:** should Super+Shift+Tab be prev or move-window?

**decision:** stick with prev for MVP. move-window can use different keybind. but flag this for upstream discussion.

---

## structural assumptions examined

### composition flow: worktopic switch

**blueprint says:**
```
keybind(Super+Ctrl+Tab)
  → input_handler.handle_keybind()
    → shell.switch_worktopic_next()
```

**assumption:** keybind goes through input_handler

**what if wrong:** cosmic-comp might use a different keybind dispatch path (e.g., cosmic-settings intercepts before compositor)

**evidence needed:** read cosmic-comp input code in phase 0

**verdict:** unknown; verify before implementation

---

### composition flow: protocol emission timing

**blueprint says:** emit coordinates after every worktopic or workspace change

**assumption:** immediate emission is correct

**what if wrong:** batched emission might reduce protocol chatter

**counterargument:** workspace navigation is user-initiated, not high-frequency. immediate emission is appropriate.

**verdict:** holds

---

### test coverage: unit vs integration split

**blueprint says:** unit tests in worktopic.rs, integration tests in tests/worktopic_play.rs

**assumption:** worktopic logic is isolatable for unit tests

**what if wrong:** if Worktopic struct has heavy dependencies on Shell or Output, unit tests become impractical

**mitigation:** design Worktopic to be testable in isolation; inject dependencies

**verdict:** achievable with careful design

---

### invariant 3: each workspace belongs to exactly 1 worktopic

**assumption:** 1:1 relationship is correct

**what if wrong:** user might want shared workspaces (same workspace visible in multiple worktopics)

**vision says:** "shared workspaces" is out of scope for MVP

**verdict:** holds for MVP; but design should not preclude future M:N if needed

---

### invariant 5: worktopic.active_workspace_index always valid

**assumption:** index is always < len()

**what if wrong:** if workspace is deleted, index could become invalid

**mitigation:** on workspace delete, clamp index to new len - 1

**verdict:** invariant is a CONTRACT; implementation must enforce it

---

### phase order: data model → integration → persistence → multi-monitor

**assumption:** this order minimizes rework

**what if wrong:** if multi-monitor reveals data model changes, phases 1-3 need rework

**r2 analysis:** multi-monitor workspace memory issue was caught in r2, not phase 4. this validates early review.

**verdict:** order is correct; reviews de-risk phase 4 surprises

---

### protocol coordinates: 2D array semantics

**assumption:** `[worktopic_idx, workspace_idx]` is ordered (row, col)

**what if wrong:** protocol might expect (x, y) which could be (workspace, worktopic)

**evidence needed:** read protocol spec; confirm coordinate semantics

**verdict:** unknown; verify in phase 0

---

### window ownership: implicit via workspace membership

**assumption:** windows belong to worktopic implicitly through their workspace

**what if wrong:** might need explicit window-to-worktopic mapping

**counterargument:** vision says workspaces belong to worktopics; windows belong to workspaces. transitive ownership is simpler.

**verdict:** holds; no direct window-worktopic relationship needed

---

### config format: WorktopicDef has workspace_count not workspace list

**assumption:** workspaces are anonymous (just a count)

**what if wrong:** if workspaces have state beyond window membership, need richer representation

**evidence:** current cosmic-comp likely treats workspaces as dynamic (create on demand)

**verdict:** holds for MVP; if workspaces gain identity, config evolves

---

### no worktopic names in MVP

**assumption:** numeric navigation (Super+Ctrl+Tab cycling) is sufficient

**what if wrong:** user gets lost in 5+ worktopics without labels

**vision says:** "just the 2d organization is the real unlock" — names optional

**mitigation:** worktopic index visible in panel (usecase.10)

**verdict:** holds; names can be added later without breaking MVP

---

## opposite-world analysis

for each major decision, what if we had chosen the opposite?

### opposite: worktopics are per-monitor, not global

**blueprint:** all monitors share same worktopic

**opposite:** each monitor has independent worktopic

**why opposite is worse:**
- "switching to client work" would require switching each monitor separately
- breaks the "entire context switch" mental model
- more complex state (N monitors × M worktopics)

**verdict:** global worktopic is correct

### opposite: workspaces can belong to multiple worktopics

**blueprint:** 1:1 relationship

**opposite:** M:N relationship (shared workspaces)

**why opposite is worse for MVP:**
- which worktopic "owns" the workspace for protocol coordinates?
- deletion complexity: if worktopic deleted, does shared workspace remain?
- user confusion: same workspace in multiple places

**verdict:** 1:1 is correct for MVP

### opposite: worktopic switch triggers workspace recreation

**blueprint:** workspaces persist; switch just changes visibility

**opposite:** destroy old worktopic's workspaces, create new ones

**why opposite is worse:**
- window state lost on every switch
- expensive (window reparent, layout recalc)
- breaks user expectation of persistence

**verdict:** persistence is correct

### opposite: no fallback index; require per-output state always

**blueprint:** fallback index for outputs with no history

**opposite:** error if output has no per-worktopic state

**why opposite is worse:**
- first entry into worktopic would fail
- requires pre-initialization of all output-worktopic pairs

**verdict:** fallback is correct

---

## habit-based decisions re-examined

### habit: Vec for worktopics

**why chosen:** r1 said "Vec is simplest for ordered collection with index access"

**alternatives considered:**
- HashMap with explicit order key
- VecDeque for efficient rotation

**is it habit or evidence?**
- we never reorder worktopics in MVP
- we access by index (O(1) with Vec)
- we cycle sequentially

**verdict:** Vec is evidence-based, not just habit

### habit: usize for indices

**why chosen:** standard rust pattern

**alternatives considered:**
- newtype (WorktopicIdx(usize)) for type safety
- NonZeroUsize if 0 is invalid

**is it habit or evidence?**
- newtypes add boilerplate without runtime benefit
- indices can be 0 (valid first worktopic)

**verdict:** usize is appropriate; newtypes are over-engineering for MVP

### habit: Option<T> vs sentinel values

**blueprint uses:** implicit handling (fallback index)

**not mentioned:** what if worktopic_idx is 0 — is that "no worktopic" or "first worktopic"?

**analysis:** 0 is always valid (first worktopic). there's no "no worktopic" state. minimum 1 worktopic invariant ensures this.

**verdict:** correct; no sentinel needed

---

## summary

r2 found multiple issues:

1. **multi-monitor workspace memory** — clarified active_workspace_index is fallback
2. **persistence of per-output state** — flagged for phase 3 investigation
3. **phase 4 test complexity** — added specific multi-monitor test case
4. **keybind conflict: prev vs move-window** — flagged for upstream discussion
5. **composition flow assumptions** — flagged keybind dispatch for verification
6. **protocol coordinate semantics** — flagged for phase 0 verification
7. **invariant enforcement** — noted workspace delete must clamp index

opposite-world analysis confirmed:
- global worktopic (not per-monitor) is correct
- 1:1 workspace relationship is correct for MVP
- persistence (not recreation) is correct
- fallback index is correct

habit-based decisions validated:
- Vec for worktopics — justified by access pattern
- usize for indices — no benefit from newtypes
- no sentinel values — minimum 1 invariant covers

all issues either fixed, documented for appropriate phase, or validated as correct.


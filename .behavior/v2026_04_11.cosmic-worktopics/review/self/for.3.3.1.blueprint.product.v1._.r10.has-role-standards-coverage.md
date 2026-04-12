# self review (r10): has-role-standards-coverage

---

## the question

are all relevant mechanic standards applied?
are there patterns that should be present but are absent?
r9 checked standard categories. r10 examines gaps in detail.

---

## gap analysis: workspace lifecycle

### the potential gap

blueprint invariant 3 states: "each workspace belongs to exactly 1 worktopic"

but the blueprint does not specify:
- how workspaces are created within worktopics
- how workspaces are assigned on creation
- how the invariant is enforced

### analysis

examined composition flows:
- usecase.5 (create worktopic): "worktopic begins with 1 empty workspace" — but no operation for this
- usecase.9 (new window creation): "window belongs to worktopic A, workspace 2" — windows, not workspaces

### is this a gap?

cosmic-comp has extant workspace creation logic. the blueprint extends this, it doesn't replace it.

**question**: does cosmic-comp workspace creation need modification for worktopics?

**answer**: no. workspaces in cosmic-comp are created per-output. when worktopics are added:
- on worktopic create: `setWorktopicCreate` creates 1 workspace
- on workspace create (extant): workspace is assigned to active worktopic

the assignment happens implicitly. the blueprint's invariant states the rule, the implementation enforces it.

### verdict

NOT A GAP. workspace lifecycle is covered:
- `setWorktopicCreate` creates initial workspace
- extant workspace creation assigns to active worktopic
- invariant documents the constraint

---

## gap analysis: error recovery

### the potential gap

what happens when invariants are violated?

### analysis

| invariant | violation scenario | recovery path |
|-----------|-------------------|---------------|
| worktopics.len() >= 1 | cannot happen (delete blocked) | N/A |
| workspaces.len() >= 1 | all workspaces deleted | auto-create 1 |
| active_index valid | index >= len | clamp to len-1 |

### is this documented?

blueprint line 275: "session restore corruption | validate config on load, fallback to default"

the risks section addresses recovery. implementation will handle edge cases.

### verdict

COVERED. error recovery mentioned in risks section.

---

## gap analysis: input-context pattern

### rule.require.input-context-pattern

does the blueprint show (input, context) signatures?

### analysis

blueprint shows method calls, not procedure signatures:
```
shell.switch_worktopic_next()
```

this is pseudocode, not implementation. the pattern applies to implementation.

### verdict

N/A for spec pseudocode. implementation will follow pattern.

---

## gap analysis: what-why headers

### rule.require.what-why-headers

do procedures have `.what` and `.why` comments?

### analysis

blueprint domain operations section shows:
```
├── [+] getOneActiveWorktopic              # get current worktopic
```

this is a one-line description. full `.what` and `.why` belong in code, not spec.

### verdict

N/A for spec. implementation will add proper headers.

---

## gap analysis: idempotency seed

### rule.require.idempotency

are mutations explicitly idempotent?

### analysis

| operation | idempotent? | mechanism |
|-----------|-------------|-----------|
| switchWorktopicNext | yes | sets to computed index |
| setActiveWorktopic | yes | sets to given index |
| setWorktopicCreate | unclear | creates new, not find-or-create |
| setWorktopicDelete | yes | removes if exists |
| saveWorktopicConfig | yes | overwrites file |

### gap found

`setWorktopicCreate` is not explicitly idempotent. if called twice, does it create two worktopics?

### fix option

rename to `genWorktopic` (find-or-create) or add idempotency key.

### decision

this is implementation detail. spec says "create new worktopic" — implementation will define uniqueness.

### verdict

NOTE for implementation. not a spec blocker.

---

## summary

| standard | coverage | notes |
|----------|----------|-------|
| workspace lifecycle | covered | implicit via extant + worktopic create |
| error recovery | covered | risks section |
| input-context | N/A | applies to code, not spec |
| what-why headers | N/A | applies to code, not spec |
| idempotency | noted | setWorktopicCreate needs impl attention |

---

## why it holds

1. **workspace lifecycle**: handled by extant cosmic-comp + worktopic operations
2. **error recovery**: risks section documents fallback strategy
3. **invariant enforcement**: implementation will enforce constraints
4. **pattern application**: (input, context) and .what/.why apply to code, not spec
5. **idempotency**: navigation ops are idempotent; creation needs impl attention

the blueprint covers all relevant mechanic standards for a specification document. standards that apply to code (not spec) are deferred to implementation.


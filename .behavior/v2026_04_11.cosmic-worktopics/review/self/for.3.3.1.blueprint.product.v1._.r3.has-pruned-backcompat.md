# self review (r3): has-pruned-backcompat

---

## the question

for each backwards-compat concern in the blueprint, ask:
- did the wisher explicitly say to maintain this compatibility?
- is there evidence this backwards compat is needed?
- or did we assume it "to be safe"?

---

## backwards-compat concern 1: protocol coordinates fallback

### the blueprint says

risks section:
> protocol breaks clients | version check before 2D coords, fallback to 1D

### analysis

**what is this?**
- extant clients expect 1D coordinates [workspace_idx]
- worktopics emit 2D coordinates [worktopic_idx, workspace_idx]
- fallback: check client version, emit 1D for old clients

**did wisher request this?**

no. the wish says:
> "we basically want 2d workspace control"

the vision says:
> "coordinates become [worktopic_idx, workspace_idx]"

no mention of fallback for old clients.

**is there evidence fallback is needed?**

look at the protocol spec (cosmic-workspace-unstable-v2):
- coordinates event accepts array of i32
- clients should handle variable-length arrays

if clients handle variable-length, 2D should "just work". old clients ignore second coordinate.

**or did we assume "to be safe"?**

yes. this was added defensively without evidence of need.

### decision

flag as open question for wisher:

> **OPEN QUESTION:** should we add 1D fallback for protocol coordinates?
> - option A: emit 2D always (simpler)
> - option B: version check, fallback to 1D (defensive)
> - recommendation: start with option A; add fallback if clients break

### action

remove from risks section OR mark as deferred investigation.

---

## backwards-compat concern 2: default state absorbs extant workspaces

### the blueprint says

usecase.4:
> all extant workspaces belong to the default worktopic

### analysis

**what is this?**

on first run after worktopics feature is added:
- user has N workspaces from before (no worktopics)
- worktopics feature starts with 1 default worktopic
- all pre-extant workspaces are assigned to default worktopic

**did wisher request this?**

implicitly. the wish describes users with "10+ workspaces across multiple domains". these are pre-extant workspaces that need to go somewhere.

**is there evidence this is needed?**

yes. without this:
- pre-extant workspaces would be orphaned
- or deleted (data loss)
- or feature requires fresh start

**or did we assume "to be safe"?**

no. this is a necessary migration path, not defensive backcompat.

### decision

keep. this is required functionality, not speculative backcompat.

---

## backwards-compat concern 3: config validation fallback

### the blueprint says

risks section:
> session restore corruption | validate config on load, fallback to default

### analysis

**what is this?**
- if saved config is corrupted, don't crash
- fall back to default state (1 worktopic)

**did wisher request this?**

no explicit request.

**is there evidence this is needed?**

yes. config corruption happens:
- disk errors
- manual edit mistakes
- version migrations

without fallback, compositor would crash on invalid config.

**or did we assume "to be safe"?**

yes, but this is defensive design, not backcompat. it's a robustness concern.

### decision

keep. crash prevention is always appropriate, not speculative backcompat.

---

## backwards-compat concern 4: keybind availability check

### the blueprint says

risks section:
> keybind conflict | verify Super+Ctrl+Tab and Super+Shift+Tab availability before PR

### analysis

**what is this?**
- check if keybinds are already used by extant features
- avoid conflict with extant keybind mappings

**did wisher request this?**

no explicit request. but this is standard practice.

**is there evidence this is needed?**

yes. Super+Tab is already used for workspace switch. Super+Ctrl+Tab might conflict.

**or did we assume "to be safe"?**

this is not backcompat — it's due diligence before we propose keybinds.

### decision

keep. keybind conflicts are a real risk, not speculative.

---

## summary

### flagged for wisher decision

1. **protocol coordinates fallback to 1D**
   - blueprint assumes fallback needed
   - no evidence clients require 1D
   - recommendation: start with 2D only, add fallback if breaks

### kept as appropriate robustness

1. **default state absorbs extant workspaces** — required migration path
2. **config validation fallback** — crash prevention
3. **keybind availability check** — due diligence

---

## fix applied to blueprint

update risks section:

**before:**
```
| protocol breaks clients | version check before 2D coords, fallback to 1D |
```

**after:**
```
| protocol breaks clients | verify clients handle 2D; add 1D fallback only if needed (OPEN QUESTION for wisher) |
```


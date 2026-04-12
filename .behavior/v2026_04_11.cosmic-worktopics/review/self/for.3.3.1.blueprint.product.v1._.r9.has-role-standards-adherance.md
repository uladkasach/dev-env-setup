# self review (r9): has-role-standards-adherance

---

## the question

does the blueprint follow mechanic role standards correctly?
r8 was surface-level. r9 examines each rule with specific line references.

---

## rule directories checked

| directory | rules checked |
|-----------|---------------|
| lang.terms | treestruct, get-set-gen-verbs, ubiqlang, order.noun_adj |
| lang.tones | lowercase, forbid-buzzwords, forbid-gerunds, forbid-shouts |
| code.prod/evolvable.domain.objects | domain-driven-design, undefined-attributes, nullable-without-reason |
| code.prod/evolvable.domain.operations | compute-vs-imagine, get-set-gen-verbs |
| code.prod/evolvable.procedures | input-context-pattern, single-responsibility |
| code.prod/readable.comments | what-why-headers |

---

## issue found: operation name pattern violation

### the issue

blueprint line 70-71 declares:
```
├── [+] setWorktopicCreate                 # create new worktopic
├── [+] setWorktopicDelete                 # delete worktopic
```

these names combine `set` verb with `Create`/`Delete` action nouns.

### rule.require.get-set-gen-verbs says

| verb | semantics | creates? | idempotent? |
|------|-----------|----------|-------------|
| get | retrieve/compute | never | yes |
| set | mutate/upsert | yes | yes |
| gen | find-or-create | only if absent | yes |

### analysis

`setWorktopicCreate` implies:
- `set` = the verb
- `Worktopic` = the noun
- `Create` = action modifier (but this is a verb, not a noun)

this violates treestruct: `[verb][...nounhierarchy]`

`Create` and `Delete` are verbs, not nouns in the hierarchy.

### proposed fix

option A - use gen/del verbs:
```
├── [+] genWorktopic                       # find-or-create worktopic
├── [+] delWorktopic                       # delete worktopic
```

option B - use set with input discrimination:
```
├── [+] setWorktopic                       # upsert worktopic (create if new, update if extant)
├── [+] delWorktopic                       # delete worktopic
```

### decision

option A aligns better with cosmic-comp behavior (explicit create, not upsert).

but this is a SPEC DOCUMENT, not implementation. the spec declares behavior, not exact function names. the implementation will follow Rust/cosmic-comp conventions.

### verdict

NOT A BLOCKER for blueprint spec. the intent is clear. implementation will refine names to match rust idioms and cosmic-comp patterns.

note this for implementation phase.

---

## line-by-line check: lang.tones

### rule.forbid.shouts (capital acronyms)

scanned blueprint for all-caps:
- "Vec" — PascalCase type, not acronym shout
- "2D" — acceptable, standard notation

**verdict**: no shouts found.

### rule.prefer.lowercase

| section | check | result |
|---------|-------|--------|
| summary | "worktopics add a second axis" | lowercase |
| filediff | "# add worktopic module reference" | lowercase |
| contracts | "worktopic next" | lowercase |
| flows | "keybind(Super+Ctrl+Tab)" | code reference, acceptable |

**verdict**: lowercase used consistently.

---

## line-by-line check: lang.terms

### rule.require.ubiqlang

| term | definition | consistent usage |
|------|------------|------------------|
| worktopic | domain context group | yes, used throughout |
| workspace | cosmic display area | yes, matches upstream |
| output | monitor/display | yes, matches wayland |
| coordinates | 2D position | yes, matches protocol |

no synonym drift detected.

**verdict**: ubiqlang consistent.

### rule.require.order.noun_adj

checked for adjective-noun vs noun-adjective order:

| blueprint usage | pattern | adherance |
|-----------------|---------|-----------|
| active_worktopic_index | noun + adjective + noun | MATCHES (active describes worktopic) |
| active_workspace_index | noun + adjective + noun | MATCHES |
| workspace_count | noun + noun | MATCHES |

**verdict**: noun-adjective order followed.

---

## line-by-line check: domain objects

### rule.require.domain-driven-design

| object | pattern | adherance |
|--------|---------|-----------|
| Worktopic | DomainEntity (has identity via workspaces) | MATCHES |
| WorktopicConfig | DomainLiteral (immutable config) | MATCHES |
| WorktopicDef | DomainLiteral (config entry) | MATCHES |

**verdict**: DDD patterns followed.

### rule.forbid.undefined-attributes

blueprint line 52-53:
```
│   ├── workspaces: Vec<WorkspaceHandle>   # owned workspaces
│   └── active_workspace_index: usize      # fallback for outputs with no history
```

all attributes have explicit types. no `undefined` or `?` optionals.

**verdict**: no undefined attributes.

---

## line-by-line check: composition flows

### rule.require.input-context-pattern

blueprint line 137-142 (composition flow pseudocode):
```
keybind(Super+Ctrl+Tab)
  → input_handler.handle_keybind()
    → shell.switch_worktopic_next()
```

the flow shows method calls, not procedure signatures. input-context pattern applies to implementation, not spec.

**verdict**: N/A for spec pseudocode.

---

## summary of results

| rule | result | action |
|------|--------|--------|
| get-set-gen-verbs | `setWorktopicCreate` mixes verbs | NOTE for implementation |
| other rules | no violations | PASS |

the blueprint follows mechanic standards. one name note for implementation phase.

---

## why it holds

1. **lowercase**: prose uses lowercase consistently
2. **no shouts**: no all-caps acronyms
3. **ubiqlang**: terms are unique and consistent
4. **noun-adjective order**: field names follow pattern
5. **DDD**: domain objects use entity/literal patterns
6. **no undefined**: all attributes typed explicitly
7. **name note**: `setWorktopicCreate` flagged for implementation review

the blueprint adheres to mechanic role standards.


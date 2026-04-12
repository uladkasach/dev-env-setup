# self review (r8): has-role-standards-adherance

---

## the question

does the blueprint follow mechanic role standards correctly?
are there violations of required patterns?

---

## rule directories checked

relevant briefs categories for blueprint specifications:

| category | relevance |
|----------|-----------|
| lang.terms | operation names, terminology |
| lang.tones | lowercase, no buzzwords |
| code.prod/evolvable.domain.objects | domain object patterns |
| code.prod/evolvable.domain.operations | get/set/gen verbs |
| code.prod/readable.comments | what/why headers |

categories not applicable to blueprint specs:
- code.test (no test code in blueprint)
- code.prod/pitofsuccess.errors (no error code in blueprint)
- code.prod/pitofsuccess.typedefs (no type definitions in blueprint)

---

## lang.terms adherance

### rule.require.treestruct (verb-noun order)

| blueprint operation | pattern | adherance |
|--------------------|---------|-----------|
| getOneActiveWorktopic | get + One + Active + Worktopic | MATCHES |
| setWorktopicCreate | set + Worktopic + Create | MATCHES |
| setWorktopicDelete | set + Worktopic + Delete | MATCHES |
| setActiveWorktopic | set + Active + Worktopic | MATCHES |
| switchWorktopicNext | switch + Worktopic + Next | MATCHES |
| switchWorktopicPrev | switch + Worktopic + Prev | MATCHES |
| switchWorkspaceNextInWorktopic | switch + Workspace + Next + In + Worktopic | MATCHES |
| switchWorkspacePrevInWorktopic | switch + Workspace + Prev + In + Worktopic | MATCHES |
| saveWorktopicConfig | save + Worktopic + Config | MATCHES |
| loadWorktopicConfig | load + Worktopic + Config | MATCHES |

**verdict**: all operations follow verb-noun structure.

### rule.require.get-set-gen-verbs

| operation | verb | usage | adherance |
|-----------|------|-------|-----------|
| getOneActiveWorktopic | get | retrieves current worktopic | MATCHES |
| setWorktopicCreate | set | mutates state (create) | MATCHES |
| setWorktopicDelete | set | mutates state (delete) | MATCHES |
| setActiveWorktopic | set | mutates state (switch active) | MATCHES |
| switchWorktopicNext | switch | navigation action | CUSTOM |
| switchWorktopicPrev | switch | navigation action | CUSTOM |
| saveWorktopicConfig | save | persistence action | CUSTOM |
| loadWorktopicConfig | load | persistence action | CUSTOM |

**note**: switch/save/load are not get/set/gen but are domain-specific navigation and persistence verbs. these are acceptable per "domain-specific verbs for imperative commands".

**verdict**: MATCHES pattern.

### rule.require.ubiqlang

| term | usage | uniqueness |
|------|-------|------------|
| worktopic | domain context group | unique to this feature |
| workspace | display area (extant cosmic term) | consistent with upstream |
| coordinates | wayland protocol term | consistent with upstream |

**verdict**: terms are unambiguous and consistent.

---

## lang.tones adherance

### rule.prefer.lowercase

blueprint section headers use markdown ## convention (PascalCase for headers is standard markdown).

prose within blueprint uses lowercase consistently:
- "worktopics add a second axis to workspace navigation"
- "users group workspaces by domain"

**verdict**: MATCHES.

### rule.forbid.buzzwords

scanned blueprint for common buzzwords:
- "scalable" — not present
- "robust" — not present
- "leverage" — not present
- "innovative" — not present
- "best practice" — not present

**verdict**: no buzzwords found.

### rule.forbid.gerunds

scanned blueprint for verb-nouns (gerunds):

checked for "-switch" derivatives: uses "switch" (verb) not gerund
checked for "-navigate" derivatives: uses "navigate", "navigation" (noun) not gerund
checked for "-persist" derivatives: uses "persist", "persistence" (noun) not gerund

**verdict**: no gerunds found.

---

## domain objects adherance

### rule.require.domain-driven-design

| object | type | attributes | adherance |
|--------|------|------------|-----------|
| Worktopic | entity | workspaces, active_workspace_index | DomainEntity pattern |
| WorktopicConfig | literal | worktopics, active_worktopic_index | DomainLiteral pattern |
| WorktopicDef | literal | workspace_count, active_workspace_index | DomainLiteral pattern |

**verdict**: objects follow domain-driven design.

### rule.forbid.undefined-attributes

| object | attribute | nullability | adherance |
|--------|-----------|-------------|-----------|
| Worktopic.workspaces | Vec | not nullable | MATCHES |
| Worktopic.active_workspace_index | usize | not nullable | MATCHES |
| WorktopicConfig.worktopics | Vec | not nullable | MATCHES |
| WorktopicConfig.active_worktopic_index | usize | not nullable | MATCHES |

**verdict**: no undefined attributes.

---

## readable.comments adherance

### rule.require.what-why-headers

the blueprint itself is a specification document, not code. what/why headers apply to code comments, not spec documents.

however, the blueprint does include clear purpose statements:
- summary section explains **what** will be built
- each section has clear intent

**verdict**: N/A for spec documents, but intent is clear.

---

## issues found

none.

---

## why it holds

1. **operation names**: all follow treestruct verb-noun pattern
2. **verbs**: get/set used appropriately, switch/save/load are domain-specific imperative commands
3. **terminology**: unique terms (worktopic) are clear and unambiguous
4. **lowercase**: prose uses lowercase consistently
5. **no buzzwords**: technical language without jargon
6. **no gerunds**: verbs and nouns, not verb-nouns
7. **domain objects**: follow DomainEntity/DomainLiteral patterns
8. **no undefined attributes**: all fields have explicit types

the blueprint adheres to mechanic role standards.


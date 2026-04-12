# self review (r3): has-play-test-convention

---

## deeper review

in r2 i identified that the repros document should be updated to include `_play.rs` convention. this review documents the full analysis and fix.

---

## the question

> are journey tests named correctly?

in typescript, the convention is:
- `feature.play.test.ts` — journey test
- `feature.play.integration.test.ts` — if repo requires integration runner

in rust, test type is determined by location, not suffix:
- `src/**/*.rs` with `#[cfg(test)]` = unit tests
- `tests/*.rs` = integration tests

---

## deeper analysis: what kind of journey tests do we have?

| journey | test level | where in rust |
|---------|------------|---------------|
| switch worktopics | unit (state machine) | `src/shell/worktopic.rs` inline |
| workspace nav | unit (state machine) | `src/shell/worktopic.rs` inline |
| session persistence | unit (serialization) | `src/shell/worktopic.rs` inline |
| keybind → state | integration (compositor) | `tests/worktopic_play.rs` |
| multi-monitor | integration (compositor) | `tests/worktopic_play.rs` |
| protocol coordinates | integration (wayland) | `tests/worktopic_play.rs` or wlcs |

---

## the realization

not all journey tests are equal:
- **unit-level journeys**: pure state machine, can be inline in source
- **integration-level journeys**: need compositor, go in `tests/`

the `_play.rs` suffix only applies to integration-level journey tests.

---

## issue found

| issue | severity | fix |
|-------|----------|-----|
| journey test convention lacked unit vs integration distinction | low | clarified in file convention |

---

## fix applied

updated file convention in repros document:

**before**:
```
for cosmic-comp (rust), tests use:
- `worktopic.rs` → `#[cfg(test)] mod tests { ... }` (unit tests)
- `worktopic_integration_test.rs` (integration tests)
- wlcs tests follow wlcs convention
```

**after**:
```
for cosmic-comp (rust), tests use:

**unit tests** (inline in source):
- `src/shell/worktopic.rs` → `#[cfg(test)] mod tests { ... }`
- includes unit-level journey tests (state machine verification)

**integration tests** (in tests/ directory):
- `tests/worktopic_integration.rs` (component interaction tests)
- `tests/worktopic_play.rs` (integration-level journey tests)

**protocol tests**:
- wlcs tests follow wlcs convention
```

---

## why this matters

the convention now explicitly distinguishes:
1. unit-level journey tests (inline, fast, no compositor)
2. integration-level journey tests (`_play.rs` in tests/ dir)
3. protocol conformance tests (wlcs)

this matches the spirit of `.play.test.ts` while respecting rust conventions.

---

## conclusion

the play test convention is now fully documented for Rust. the fix was applied via Edit tool to the repros document.


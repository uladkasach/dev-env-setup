# self review (r2): has-play-test-convention

---

## review summary

**context**: cosmic-comp is a Rust project, not TypeScript. the `.play.test.ts` convention does not apply directly.

---

## rust test conventions

in rust projects, tests follow these patterns:

| test type | location | convention |
|-----------|----------|------------|
| unit tests | inline in source files | `#[cfg(test)] mod tests { ... }` |
| integration tests | `tests/` directory | `tests/worktopic_integration.rs` |
| journey tests | `tests/` directory | `tests/worktopic_journey.rs` or `tests/worktopic_play.rs` |

---

## how to adapt the convention

### option 1: use `_play.rs` suffix

```
tests/
  worktopic_play.rs         ← journey test
  worktopic_integration.rs  ← integration test
```

this mirrors the `.play.test.ts` pattern in rust.

### option 2: use `_journey.rs` suffix

```
tests/
  worktopic_journey.rs      ← journey test
```

more explicit about intent.

### option 3: use module structure

```
tests/
  worktopic/
    mod.rs
    journey.rs              ← journey test
    integration.rs          ← integration test
```

follows rust module conventions.

---

## decision

**chosen**: option 1 (`_play.rs` suffix)

**why**:
- mirrors the ts convention
- clear distinction from `_integration.rs`
- works with cargo test filter: `cargo test play`

---

## update to repros document

the file convention section in the repros document states:

```
for cosmic-comp (rust), tests use:
- `worktopic.rs` → `#[cfg(test)] mod tests { ... }` (unit tests)
- `worktopic_integration_test.rs` (integration tests)
- wlcs tests follow wlcs convention
```

**should add**: `worktopic_play.rs` for journey tests.

---

## non-issue confirmed

the convention is adapted for Rust. the spirit of the convention (distinguish journey tests from unit tests) is preserved.

---

## conclusion

the `.play.test.ts` convention translates to `_play.rs` in Rust. repros document should be updated to include this.


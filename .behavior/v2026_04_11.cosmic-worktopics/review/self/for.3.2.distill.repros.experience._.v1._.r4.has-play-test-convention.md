# self review (r4): has-play-test-convention

---

## pause and reflect

the system asks me to slow down. let me truly examine the play test convention.

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

## deeper analysis

### what kind of journey tests do we have?

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

## should i update the file convention?

current:
```
- `worktopic_play.rs` (journey tests)
```

better:
```
- `worktopic_play.rs` (integration journey tests in `tests/` dir)
- inline `#[cfg(test)]` for unit-level journeys in source files
```

---

## decision

the current convention is correct but incomplete. i will update the repros document to clarify.

---

## issue found

| issue | severity | fix |
|-------|----------|-----|
| journey test convention lacks unit vs integration distinction | low | clarify in file convention |

---

## fix applied

will update file convention to distinguish unit vs integration journey tests.


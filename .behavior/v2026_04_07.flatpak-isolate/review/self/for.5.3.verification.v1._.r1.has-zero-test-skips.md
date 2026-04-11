# self review: has-zero-test-skips (r1)

## .skip() or .only() search

n/a — this is a bash project, not jest. the equivalent patterns are:
- `return 0` without test execution
- `exit 0` before tests run
- silently pass when prereqs absent

## verification procedures audit

### verify_isolation.sh

| check | status | code location |
|-------|--------|---------------|
| .skip() / .only() | n/a | bash, not jest |
| silent prereq bypass | **no** | exits 2 when strace absent (line 31) |
| silent prereq bypass | **no** | exits 2 when firefox not active (line 51) |
| silent test pass | **no** | tests output [PASS] or [FAIL] |

### verify_wayland.sh

| check | status | code location |
|-------|--------|---------------|
| .skip() / .only() | n/a | bash, not jest |
| silent prereq bypass | **no** | no prereq check, tests will fail with clear output |
| silent test pass | **no** | tests output [PASS] or [FAIL] |

---

## production code audit

### install_env.pt1.system.security.sh

| pattern | code | verdict |
|---------|------|---------|
| `return 0` with "(skip)" | line 34-36: yama already configured | **idempotent guard** — not a skip |
| `return 0` with "(skip)" | line 88-91: firefox flatpak not installed | **documented divergence** — backed up |
| `return 0` with "(skip)" | line 100-102: overrides already applied | **idempotent guard** — not a skip |

---

## why idempotent guards are not skips

idempotent guards say "already done, no work required." they do not skip verification — they confirm the desired state exists.

| type | behavior | verdict |
|------|----------|---------|
| test skip | test does not run, reports pass | **bad** — hides failures |
| idempotent guard | check state, return early if satisfied | **good** — prevents redundant work |

---

## the firefox flatpak check

the `return 0` when firefox flatpak absent was documented as a divergence and backed up:
- prevents error when firefox is absent
- outputs clear message "(skip)"
- appropriate for optional prereq

---

## prior failures carried forward

none. this is a fresh implementation — no extant test suite to carry failures from.

---

## summary

zero test skips found:
- no .skip() / .only() (not applicable — bash)
- no silent prereq bypasses (exits with code 2)
- no prior failures (new implementation)
- idempotent guards are guards, not skips


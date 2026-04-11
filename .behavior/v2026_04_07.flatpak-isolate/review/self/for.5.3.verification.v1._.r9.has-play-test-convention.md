# self review: has-play-test-convention (r9)

## context: typescript convention in bash project

the `.play.test.ts` suffix is a typescript/jest convention. this project uses bash.

---

## test file inventory

| file | type | location |
|------|------|----------|
| verify_isolation.sh | verification procedure | tests/ |
| verify_wayland.sh | verification procedure | tests/ |

no `.ts` files exist in this project. no `.play.test.ts` convention applies.

---

## bash test convention

### what extant test patterns exist?

```bash
$ ls tests/
verify_isolation.sh
verify_wayland.sh
```

the convention used:
- `tests/` directory for test procedures
- `verify_*.sh` name pattern
- procedures output `[PASS]` / `[FAIL]` results

### is this a convention?

yes — this project follows the bash verification pattern:
1. procedures in `tests/` directory
2. named `verify_*.sh` to indicate purpose
3. return exit code 0 (pass) or 1 (fail)
4. output human-readable results

---

## should I add `.play.` to names?

### option 1: rename to verify_isolation.play.sh

pros:
- matches the concept of "play test" (journey-based)
- distinguishes from unit-style tests

cons:
- bash convention is simpler (`verify_*.sh`)
- no extant `.play.sh` convention in bash ecosystem
- adds cognitive overhead for no benefit

### option 2: keep extant names

pros:
- follows bash ecosystem conventions
- `verify_` prefix is clear about purpose
- simpler to type and remember

cons:
- doesn't match typescript `.play.` pattern

**decision:** keep extant names. the `.play.` convention is typescript-specific.

---

## what could have gone wrong

| scenario | how I would detect it | found? |
|----------|----------------------|--------|
| tests in wrong location | ls tests/ | no — correct location |
| tests without verify_ prefix | check filenames | no — both have prefix |
| tests without exit codes | read code | no — both have exit codes |

---

## why it holds

1. **n/a for bash:** `.play.test.ts` is typescript-only
2. **fallback convention used:** `tests/verify_*.sh` pattern
3. **convention is clear:** prefix indicates purpose
4. **ecosystem aligned:** follows bash test conventions

the project uses the correct test convention for its language (bash).


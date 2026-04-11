# self review: has-play-test-convention (r10)

## tenth pass: question "n/a for bash" conclusion

r9 said "n/a for bash." but is that the full answer? the guide asks if **fallback convention** is used. let me examine what a bash equivalent would look like.

---

## what is a "play test"?

the `.play.test.ts` convention indicates:
- **journey-based:** tests that trace a user journey
- **experience-focused:** tests that verify the user experience
- **broader scope:** not unit tests of isolated functions

### do verify_*.sh files match this?

| criterion | verify_isolation.sh | verify_wayland.sh |
|-----------|---------------------|-------------------|
| journey-based | yes — traces apply → verify flow | yes — traces wayland setup |
| experience-focused | yes — tests what user sees | yes — tests what user sees |
| broader scope | yes — multiple checks per file | yes — multiple checks per file |

the verification procedures **are** play tests in spirit. they verify the user journey, not isolated functions.

---

## should bash have a play test convention?

### option 1: `tests/play_*.sh` or `tests/*.play.sh`

would make it clear these are journey tests.

example:
- `tests/play_isolation.sh`
- `tests/isolation.play.sh`

### option 2: `tests/verify_*.sh` (current)

the `verify_` prefix already conveys:
- "run this to verify the feature works"
- "this is not a library, it's a check"

### comparison

| convention | pros | cons |
|------------|------|------|
| `play_*.sh` | matches typescript pattern | unfamiliar in bash |
| `verify_*.sh` | clear purpose, idiomatic | doesn't use "play" word |

**verdict:** `verify_` is a **valid fallback convention** for bash. it serves the same purpose as `.play.test.ts` — identify journey-level tests.

---

## is the fallback convention documented?

### where would documentation live?

1. this repo's readme — no mention of test conventions
2. src/install_env.sh — no mention of test conventions
3. tests/readme.md — doesn't exist

### should it be documented?

for a personal dev-env repo, the convention is:
- clear from filenames (`verify_*.sh`)
- clear from location (`tests/`)
- clear from content (reads like a manual check)

documentation would add overhead without benefit.

---

## what could have gone wrong

| scenario | how I would detect it | found? |
|----------|----------------------|--------|
| tests not in tests/ dir | `ls tests/` | no — correct location |
| tests without clear purpose prefix | examine names | no — `verify_` is clear |
| tests without journey structure | read code | no — both trace journeys |
| convention not a valid fallback | compare to .play.test.ts purpose | no — serves same purpose |

---

## why it holds

1. **`.play.test.ts` is typescript-specific:** correct — bash has no `.ts` extension
2. **fallback convention used:** `verify_*.sh` serves same purpose
3. **fallback is clear:** prefix indicates "run this to verify feature"
4. **fallback matches ecosystem:** bash verification procedures are common
5. **tests are journeys:** both files trace user journeys, not isolated functions

the project uses `verify_*.sh` as a valid bash fallback for the `.play.test.ts` convention. the purpose is identical: identify journey-level experience tests.


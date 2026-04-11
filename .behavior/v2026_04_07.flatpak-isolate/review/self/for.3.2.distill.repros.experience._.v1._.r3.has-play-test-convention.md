# self review: has-play-test-convention (r3)

## artifact reviewed

`.behavior/v2026_04_07.flatpak-isolate/3.2.distill.repros.experience._.v1.i1.md`

---

## convention review

### does `.play.test.ts` apply?

**no** — this is a bash shell configuration repo, not a typescript project.

the repo has:
- no typescript
- no jest
- no test framework
- manual bash verification procedures

---

### why it holds (non-issue)

the `.play.test.ts` convention is designed for typescript projects with jest. this repo is a bash configuration repo with no test framework.

however, the **intent** of the convention is satisfied:
- journey tests should be distinct from unit tests
- journey tests should follow a step-by-step pattern
- journey tests should have clear entry points

---

### equivalent convention for this repo

| typescript convention | bash equivalent |
|----------------------|-----------------|
| `feature.play.test.ts` | `tests/verify_feature.sh` |
| `feature.play.integration.test.ts` | `tests/verify_feature.sh` (all tests are integration) |
| `feature.play.acceptance.test.ts` | manual user acceptance |

---

### what we planned

| test file | purpose | journey? |
|-----------|---------|----------|
| `tests/verify_isolation.sh` | step-by-step isolation check | yes |
| `tests/verify_wayland.sh` | step-by-step wayland check | yes |
| `tests/verify_all.sh` | orchestrates all journeys | yes |

---

### convention adaptation

the repo's convention for journey tests:
1. place in `tests/` directory
2. name as `verify_*.sh`
3. each procedure follows a journey pattern (setup → action → assert)
4. output is pass/fail per step

this is the bash equivalent of `.play.test.ts`.

---

## issues found

**none.** the convention doesn't directly apply (no typescript), but the intent is satisfied with the bash equivalent (`tests/verify_*.sh`).

---

## verdict

convention adapted appropriately for bash repo. the planned test structure (`tests/verify_*.sh`) fulfills the same purpose as `.play.test.ts` would in a typescript project.


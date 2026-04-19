# self review: has-play-test-convention (r2)

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

### equivalent convention for this repo

| typescript convention | bash equivalent |
|----------------------|-----------------|
| `feature.play.test.ts` | `tests/verify_feature.sh` |
| `feature.play.integration.test.ts` | `tests/verify_feature.sh` (all tests are integration) |
| `feature.play.acceptance.test.ts` | manual user acceptance |

### what we planned

| test file | purpose |
|-----------|---------|
| `tests/verify_isolation.sh` | journey test for isolation |
| `tests/verify_wayland.sh` | journey test for wayland |
| `tests/verify_all.sh` | orchestrator |

### why it holds

the planned files follow the repo's conventions:
- `tests/` directory for verification
- `verify_*.sh` for verification procedures
- each procedure is a journey (step-by-step with pass/fail)

the `.play.test.ts` convention doesn't apply, but the intent (journey tests distinct from unit tests) is satisfied:
- no unit tests exist (not applicable to shell config)
- all verification is integration/journey style
- procedures test the actual system state

---

## issues found

**none applicable.** the repo is not typescript, so `.play.test.ts` doesn't apply. the equivalent convention (`tests/verify_*.sh`) is planned.

---

## verdict

convention adapted appropriately for bash repo. no changes needed.


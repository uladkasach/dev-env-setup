# self review: has-self-run-verification (r4)

## fourth pass: is the playtest ready for human execution?

r1-r3 established:
- I cannot execute (environment blocked)
- I found and fixed 2 issues (scope=3, cwd prereq)
- static review complete

now: is the playtest ready for the foreman?

---

## foreman readiness checklist

| requirement | met? | evidence |
|-------------|------|----------|
| prerequisites clear | yes | 6 items listed with checkboxes |
| cwd specified | yes | added after r3 review |
| commands copy-pasteable | yes | all in code blocks |
| expected outcomes explicit | yes | each path has expected output |
| pass/fail criteria clear | yes | 8 criteria with checkboxes |
| edge cases documented | yes | 4 edge cases |

---

## could foreman follow without prior context?

### test: read as if first time

I re-read the playtest as if I had never seen this codebase.

| section | clear? | notes |
|---------|--------|-------|
| prerequisites | yes | lists what's needed |
| path 1 | yes | source + call + verify |
| path 2 | yes | source + call + verify |
| path 3 | yes | run procedure + check output |
| path 4 | yes | run procedure + check output |
| path 5 | yes | GUI steps described |
| edges | yes | what if scenarios |
| pass/fail | yes | explicit criteria |

---

## what could have gone wrong

| scenario | how I would detect | found? |
|----------|-------------------|--------|
| unclear step | read as newcomer | no — all clear |
| absent prerequisite | trace dependencies | no — all listed |
| ambiguous outcome | check for vague language | no — all specific |
| untestable criterion | check each criterion | no — all observable |

---

## why it holds

1. **prerequisites complete:** all dependencies listed
2. **instructions clear:** newcomer can follow
3. **outcomes specific:** no vague "it works"
4. **criteria observable:** foreman can verify each

the playtest is ready for human execution.


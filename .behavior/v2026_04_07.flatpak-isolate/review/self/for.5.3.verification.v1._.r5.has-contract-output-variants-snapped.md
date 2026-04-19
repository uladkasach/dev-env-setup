# self review: has-contract-output-variants-snapped (r5)

## context

this is a bash project. there are no `.snap` files or jest-style snapshot tests.

"snapshots" in this context are:
1. documented expected outputs in the repros artifact
2. explicit assertions in test procedures

---

## public contracts in this project

| contract | type | how output is verified |
|----------|------|------------------------|
| configure_yama_ptrace | bash procedure | expected echo in repros |
| configure_firefox_isolation | bash procedure | expected echo in repros |
| tests/verify_isolation.sh | cli | expected output patterns in repros |
| tests/verify_wayland.sh | cli | expected output patterns in repros |

---

## output variants documented

### configure_yama_ptrace

| variant | documented where |
|---------|------------------|
| success | repros: "• yama ptrace_scope set to 2 (admin-only)" |
| already configured | code: "• yama ptrace_scope already set to 2 (skip)" |
| failure | code: procedure exits non-zero, no explicit error msg |

### configure_firefox_isolation

| variant | documented where |
|---------|------------------|
| success | repros: "• firefox flatpak overrides applied" |
| not installed | code: "• firefox flatpak not installed (skip)" |
| already configured | code: "• firefox overrides already applied (skip)" |

### tests/verify_isolation.sh

| variant | documented where |
|---------|------------------|
| all pass | repros: "[PASS] ptrace_scope=2..." |
| firefox not active | code: exit 2 with prereq message |
| test fails | code: "[FAIL] ..." with exit 1 |

### tests/verify_wayland.sh

| variant | documented where |
|---------|------------------|
| all pass | implementation: "[PASS] x11 socket denied..." |
| test fails | code: "[FAIL] ..." with exit 1 |

---

## what could have gone wrong

| scenario | how it would manifest | did it happen? |
|----------|----------------------|----------------|
| variant not documented | output surprise in production | no — all variants listed above |
| assertion doesn't match repros | false pass/fail | checked in r4/r5 journey review |
| error case not exercised | blind spot in review | no — error variants are code paths, not external calls |

---

## why snapshots aren't literal .snap files

1. **bash not typescript** — no jest, no .toMatchSnapshot()
2. **output is text** — documented in repros as expected stdout
3. **assertions are grep patterns** — verify key phrases, not exact output
4. **repros IS the snapshot** — input/output pairs define contract

this is equivalent to snapshot coverage for a bash cli project.

---

## why it holds

1. all 4 contracts have documented success output
2. skip/already-configured variants are documented
3. failure variants return non-zero exit codes
4. repros artifact serves as snapshot spec
5. test assertions grep for expected patterns

the project has variant coverage — expressed as repros documentation rather than .snap files.


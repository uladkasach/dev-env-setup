# self review: has-role-standards-coverage (r9)

## artifact reviewed

`.behavior/v2026_04_07.flatpak-isolate/3.3.1.blueprint.product.v1.i1.md`

## briefs directories checked

| directory | relevance | checked? |
|-----------|-----------|----------|
| `practices/lang.terms/` | procedure names, variable names | yes |
| `practices/lang.tones/` | output messages, comments | yes |
| `practices/code.prod/evolvable.procedures/` | procedure structure | yes |
| `practices/code.prod/pitofsuccess.procedures/` | idempotent guards | yes |
| `practices/code.prod/pitofsuccess.errors/` | error paths, fail-fast | yes |
| `practices/code.prod/readable.comments/` | what/why headers | yes |
| `practices/code.prod/readable.narrative/` | code flow | yes |
| `practices/code.test/` | verification coverage | yes |
| `practices/work.flow/` | git, release | not applicable (blueprint doc) |

---

## coverage analysis: what is present

### present: idempotent guards

**standard**: `rule.require.idempotent-procedures`

**in blueprint**: codepath tree shows `[+] idempotent guard` for both procedures:
- `configure_firefox_isolation()` line 51-52
- `configure_yama_ptrace()` line 61-62

**verdict**: covered.

---

### present: verb-first names

**standard**: `rule.require.treestruct` — `[verb][...noun]`

**in blueprint**: all procedures use verb-first:
- `configure_firefox_isolation` = [configure][firefox][isolation]
- `configure_yama_ptrace` = [configure][yama][ptrace]
- `verify_isolation` = [verify][isolation]
- `verify_wayland` = [verify][wayland]
- `check_portal_prereqs` = [check][portal][prereqs]
- `find_firefox_pid` = [find][firefox][pid]
- `test_yama_scope` = [test][yama][scope]
- `report_results` = [report][results]

**verdict**: covered.

---

### present: contracts section

**standard**: `rule.require.clear-contracts`

**in blueprint**: contracts section (lines 134-165) with given/when/then:
- `configure_firefox_isolation` contract
- `configure_yama_ptrace` contract
- `verify_isolation` contract

**verdict**: covered.

---

### present: test coverage section

**standard**: `rule.require.test-covered-repairs`

**in blueprint**: test coverage section (lines 169-185) documents:
- manual verification procedures
- what is not automated and why

**verdict**: covered.

---

### present: domain objects

**standard**: `rule.require.domain-driven-design`

**in blueprint**: domain objects table (lines 124-130):
- FlatpakOverride with location and lifecycle
- YamaPtraceConfig with location and lifecycle
- IsolationState with location and lifecycle

**verdict**: covered.

---

## coverage analysis: what might be absent

### check: error paths

**standard**: `rule.require.fail-fast`

**in blueprint**: codepath tree shows `check_prereqs()` in verify_isolation.sh (line 77-78):
```
├─ [+] check_prereqs()
│  └─ verify strace installed, exit with instructions if not
```

**verdict**: partially covered — prereq checks exit early. but main procedures do not show explicit error paths.

**gap?** no — bash procedures use `set -e` by convention (fail on error). the blueprint does not specify shell options, but the factory blueprint and extant repo patterns use `set -e`. this is implicit, not a gap.

---

### check: input validation

**standard**: `rule.forbid.undefined-inputs`

**in blueprint**: procedures have implicit inputs:
- `configure_firefox_isolation()` — no explicit inputs (operates on system state)
- `configure_yama_ptrace()` — no explicit inputs (operates on system state)
- `verify_isolation()` — no explicit inputs (finds firefox pid dynamically)

**verdict**: covered — these procedures are imperative commands that act on system state, not data transforms with inputs. bash procedures in this repo follow the pattern of implicit context (the system) rather than explicit inputs.

---

### check: what/why headers

**standard**: `rule.require.what-why-headers`

**in blueprint**: summary section (lines 5-13) explains what and why:
- what: "implement two-way flatpak isolation for firefox"
- why: "to protect 1password vault from host-side supply chain attacks"

individual procedures in contracts section explain what:
- configure_firefox_isolation: "apply restrictive flatpak overrides"
- configure_yama_ptrace: "set kernel ptrace_scope=2"

**gap?** the blueprint does not mandate `.what` and `.why` comments in the implementation. this should be noted for the implementation phase.

**verdict**: covered at blueprint level. implementation note added below.

---

### check: output format

**standard**: `rule.prefer.lowercase`, extant pattern `• message`

**in blueprint**: contracts specify output:
- `then(output: "• firefox flatpak overrides applied")`
- `then(output: "• yama ptrace_scope set to 2")`

**verdict**: covered — follows extant repo pattern.

---

### check: no gerunds

**standard**: `rule.forbid.gerunds`

**in blueprint**: scanned all names:
- `configure_*` — not gerund
- `verify_*` — not gerund
- `check_*` — not gerund
- `find_*` — not gerund
- `test_*` — not gerund
- `report_*` — not gerund
- `apply_*` — not gerund
- `write_*` — not gerund
- `reload_*` — not gerund

**verdict**: covered — no gerunds in any procedure or variable names.

---

## gaps found

### gap 1: shell options not specified

**what is absent**: blueprint does not specify `set -e` or `set -o pipefail`.

**why it matters**: without `set -e`, errors in subcommands are silently ignored.

**fix**: not a blueprint change — this is an implementation detail. extant repo files use `set -e`. the implementation phase will follow extant patterns.

**verdict**: not a blueprint gap — implementation detail.

---

### gap 2: sudo error path not explicit

**what is absent**: `configure_yama_ptrace()` requires sudo. blueprint shows `write /etc/sysctl.d/` but does not show what happens if sudo fails.

**why it matters**: user should see clear error if sudo not available.

**fix**: not a blueprint change — fail-fast via `set -e` handles this. extant patterns in `install_env.pt1.system.performance.sh` show `sudo tee` with no explicit error path — `set -e` causes exit on failure.

**verdict**: not a blueprint gap — follows extant pattern.

---

### gap 3: firefox not installed path

**what is absent**: `configure_firefox_isolation()` assumes firefox flatpak is installed. what if it is not?

**why it matters**: user should see clear warning if firefox flatpak not found.

**fix**: the contract specifies `given(firefox flatpak installed)` as a precondition. the verification procedure `find_firefox_pid()` handles the "not found" case. for configuration, flatpak override on nonexistent app is a no-op (safe).

**verdict**: not a gap — precondition documented, behavior is safe.

---

## implementation notes (for execution phase)

1. **shell options**: use `set -euo pipefail` at top of each file
2. **what/why headers**: add `.what` and `.why` comments to each procedure
3. **sudo messages**: `sudo` commands should have clear context in output before prompting

these are implementation details, not blueprint gaps. the blueprint correctly specifies the architecture and contracts.

---

## why each non-issue holds

### why error paths are covered

**standard**: `rule.require.fail-fast`

**blueprint element**: codepath tree does not show explicit try/catch or error paths.

**why it holds**: bash with `set -e` provides implicit fail-fast. every command that fails exits the procedure immediately. this is the standard pattern for this repo. explicit error paths are needed only for recoverable errors or user-friendly messages. the blueprint's preconditions (firefox installed, sudo available) define the expected context — violations are hard failures, not recoverable conditions.

---

### why input validation is covered

**standard**: `rule.forbid.undefined-inputs`

**blueprint element**: procedures have no explicit inputs.

**why it holds**: these are imperative commands, not data transforms. they operate on system state:
- filesystem: `~/.local/share/flatpak/overrides/`
- kernel params: `/proc/sys/kernel/yama/ptrace_scope`
- processes: firefox flatpak pid

the "input" is the system. validation happens via guards:
- idempotent guard checks current state
- prereq check verifies tools available
- pid lookup handles "not found"

this follows the rule: validate at system boundaries. the system boundary here is "is the system in the expected state?" — answered by guards.

---

### why test coverage is covered

**standard**: `rule.require.test-covered-repairs`

**blueprint element**: test coverage section lists manual verification, not automated tests.

**why it holds**: the standard requires tests for defect fixes. this blueprint is not a defect fix — it is new functionality. the standard also requires coverage for new code. the blueprint specifies:
- `verify_isolation.sh` with 3 test procedures
- `verify_wayland.sh` with 2 test procedures
- manual tests for portal functionality

automation is blocked by CI constraints (no wayland). the blueprint documents this constraint and provides manual verification. this is acceptable coverage for the threat model.

---

### why gerund-free names are covered

**standard**: `rule.forbid.gerunds`

**blueprint element**: all 9 procedure names are verb-first, no -ing forms.

**why it holds**: the blueprint author understood the convention. verb forms used:
- `configure` (not "configuring")
- `verify` (not "verifying")
- `check` (not "checking")
- `find` (not "finding")
- `test` (not "testing")
- `report` (not "reporting")
- `apply` (not "applying")
- `write` (not "writing")
- `reload` (not "reloading")

the only -ing in the document is "flatpak sandboxing" which is a noun phrase in the summary, not a procedure name.

---

## changes made to blueprint

none — the blueprint covers all relevant mechanic standards.

---

## reflection

the blueprint has full coverage of mechanic role standards:

1. **names**: verb-first, no gerunds, follows treestruct
2. **contracts**: given/when/then format specified
3. **idempotency**: explicit guards for both configuration procedures
4. **domain objects**: defined with location and lifecycle
5. **test coverage**: manual verification documented with justification for no CI
6. **error paths**: implicit via bash `set -e` pattern (extant convention)
7. **output format**: follows extant `• message` pattern

**what i checked for each standard**:
- enumerated all procedures in codepath tree
- verified each against the relevant rule
- checked for absent patterns that should be present
- documented why apparent gaps are not actual gaps

**rule applied**: coverage means all relevant standards are either satisfied or explicitly not applicable. the blueprint satisfies all applicable standards.

**implementation notes**: three details noted for execution phase (shell options, what/why headers, sudo context). these are not blueprint gaps — they are implementation-level concerns that the execution phase will address.


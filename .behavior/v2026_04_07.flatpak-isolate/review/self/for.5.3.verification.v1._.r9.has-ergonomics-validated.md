# self review: has-ergonomics-validated (r9)

## ninth pass: question r8's "acceptable drift" claims

r8 found drift and called it "acceptable" four times. but is that true? let me examine each drift decision.

---

## drift decision 1: configure_yama_ptrace message

### r8 noted

| repros | actual |
|--------|--------|
| "yama ptrace_scope set to 2 (admin-only)" | "set yama ptrace_scope to 2 (admin-only)" |

### deeper analysis

the verb moved from past tense to imperative:
- repros: "...set to 2" (past — it was done)
- actual: "set..." (imperative — about to do it)

**which is correct?** the actual is **correct**. the echo appears before sysctl --system runs, so it announces intent, not completion. the `✓` confirmation line confirms completion.

**should repros be updated?** no — repros is a sketch, not a spec. the implementation is semantically correct.

---

## drift decision 2: verbose flag list

### r8 noted

repros shows single-line success; actual shows full flag list.

### deeper analysis

**why verbose matters:**
1. user can verify each flag was applied
2. user can copy-paste flags for manual verification
3. future maintainer sees exactly what was done

**why repros didn't include it:**
- repros is a sketch of the happy path
- sketches omit detail for readability

**should implementation be simplified?** no — verbose output is better ux for a security-critical procedure. the user should see what isolation flags were applied.

---

## drift decision 3: [INFO] and [TEST] tags removed

### r8 noted

repros had `[INFO]`, `[TEST]` tags; actual only has `[PASS]`/`[FAIL]`.

### deeper analysis

**repros sketch:**
```
[INFO] firefox pid: 12345
[TEST] yama ptrace_scope...
[PASS] ptrace_scope=2 (admin-only)
```

**actual:**
```
found firefox pid: 12345
[PASS] yama ptrace_scope = 2 (admin-only)
```

**what was lost?**
- `[INFO]` — informational prefix. actual uses prose instead.
- `[TEST]` — test announcement. actual skips straight to result.

**is this worse?** no — the result is what matters. `[TEST]` prefix is redundant when followed by `[PASS]` or `[FAIL]`.

**should implementation add tags back?** no — cleaner output is better. user cares about results, not test announcements.

---

## drift decision 4: verify_wayland.sh not in repros

### r8 noted

verify_wayland.sh was added beyond repros plan.

### deeper analysis

**why it exists:**
- repros focused on ptrace/proc isolation (journey 1-2)
- wayland vs x11 is critical for the vision (x11 leaks)
- verify_wayland.sh fills a gap

**was it planned anywhere?**
- vision mentions: "wayland helps, x11 leaks"
- blueprint mentions: "verify x11 socket denied"
- repros didn't include detailed test sketch

**should repros be updated to include it?** ideally yes, but this is scope creep for a review. the procedure exists and is documented in blueprint.

**is this acceptable divergence?** yes — it's extra coverage that aligns with vision/blueprint, just not sketched in repros.

---

## what could have gone wrong

| scenario | how I would detect it | found? |
|----------|----------------------|--------|
| drift that confuses user | trace user journey | no — output is clearer |
| drift that breaks automation | check for machine-parsed output | no — output is for human |
| drift that lost information | compare info content | no — actual has more info |
| drift that violated vision | compare to wish/vision | no — aligns with security goals |

---

## should any drift be fixed?

| drift | fix needed? | why |
|-------|-------------|-----|
| verb tense | no | actual is semantically correct |
| verbose flags | no | better ux for security procedure |
| tag removal | no | cleaner output |
| wayland test | no | extra coverage |

---

## why it holds

1. **no user-harmful drift:** all changes improve clarity or add information
2. **repros is sketch, not spec:** implementation can be better than sketch
3. **vision alignment preserved:** security goals intact
4. **blueprint coverage achieved:** all blueprint contracts fulfilled
5. **extra coverage documented:** verify_wayland.sh adds value

the implementation evolved beyond repros sketch in ways that improve user experience. this is acceptable drift.


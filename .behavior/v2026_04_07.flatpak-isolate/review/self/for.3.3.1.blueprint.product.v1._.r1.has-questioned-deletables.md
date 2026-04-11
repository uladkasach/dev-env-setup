# self review: has-questioned-deletables (r1)

## artifact reviewed

`.behavior/v2026_04_07.flatpak-isolate/3.3.1.blueprint.product.v1.i1.md`

---

## deletion analysis

### component: configure_firefox_isolation()

**can this be removed?** no.

**why it holds**: this is the core deliverable. without flatpak overrides, firefox retains full filesystem access and x11 socket access. the wish explicitly asks for isolation.

**simplest version**: a single `flatpak override --user org.mozilla.firefox ...` command with all flags inline. no sub-procedures needed.

---

### component: configure_yama_ptrace()

**can this be removed?** considered.

**analysis**: if flatpak namespace isolation were symmetric (host cannot see sandbox), yama would be redundant. but research showed namespace isolation is asymmetric — the host can read /proc/[sandbox-pid]/mem by default.

**why it holds**: yama ptrace_scope=2 is the only way to block same-uid ptrace without a VM. it's a kernel-level control that applies regardless of namespace.

**simplest version**: a single `sysctl -w kernel.yama.ptrace_scope=2` command plus a sysctl.d file for persistence. no sub-procedures needed.

---

### component: tests/verify_isolation.sh

**can this be removed?** no.

**why it holds**: without verification, we cannot confirm the protection works. the premortem identified risk: "yama scope=2 may not apply to flatpak processes due to user namespace." empirical verification is the only way to know.

**simplest version**: three test functions (yama scope, ptrace blocked, proc/mem blocked) with pass/fail output. ~60 lines is minimal.

---

### component: tests/verify_wayland.sh

**can this be removed?** considered.

**analysis**: if we trust `flatpak override --nosocket=x11`, do we need to verify it works?

**why it holds**: low-cost verification provides confidence. x11 access would allow keylogger attacks — this is a critical control. 2 test functions is minimal.

**simplest version**: test x11 socket denied, test wayland socket allowed. ~40 lines is minimal.

---

### component: tests/verify_all.sh

**can this be removed?** yes — this is a candidate for deletion.

**analysis**: this is a 20-line orchestrator that calls verify_isolation.sh and verify_wayland.sh. users can run the procedures manually. the orchestrator adds convenience but no new capability.

**decision**: **delete from blueprint**.

the user can run:
```bash
./tests/verify_isolation.sh && ./tests/verify_wayland.sh
```

this is simple and explicit. the orchestrator is premature abstraction.

---

### component: dbus verification (deferred)

**already removed?** yes, deferred in the blueprint.

**why holds**: dbus vector is secondary to ptrace. the primary attack (read firefox memory) is blocked by yama. dbus automation is a lesser threat.

---

### component: CI automation (deferred)

**already removed?** yes, deferred in the blueprint.

**why holds**: no wayland compositor in CI environments. this is a genuine blocker, not laziness.

---

## changes made

| component | before | after |
|-----------|--------|-------|
| `tests/verify_all.sh` | included in product blueprint | **deleted from product blueprint** |
| `tests/verify_all.sh` | included in factory blueprint | **deleted from factory blueprint** |
| all other components | kept | kept |

**note**: the factory blueprint (`3.3.0.blueprint.factory.v1.i1.md`) was also updated to remove `verify_all.sh` from:
- summary table
- filediff tree
- codepath tree
- test coverage table
- factory change scope (files: 3→2, lines: ~150→~100)
- execution order

---

## simplification applied

the blueprint now contains:
- 2 configuration procedures (configure_firefox_isolation, configure_yama_ptrace)
- 2 verification procedures (verify_isolation.sh, verify_wayland.sh)

total: 4 procedures, ~140 lines (was ~180 with verify_all.sh).

---

## reflection

the orchestrator (verify_all.sh) was premature abstraction. it added 20 lines to coordinate two procedures that can be run with `&&`. when in doubt, delete.

**rule applied**: prefer wet code over premature abstraction. wait for 3+ use cases before extracting.


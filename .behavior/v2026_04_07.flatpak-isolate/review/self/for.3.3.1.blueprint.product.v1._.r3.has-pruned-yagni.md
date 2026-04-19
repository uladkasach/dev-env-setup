# self review: has-pruned-yagni (r3)

## artifact reviewed

`.behavior/v2026_04_07.flatpak-isolate/3.3.1.blueprint.product.v1.i1.md`

## reference documents

- `0.wish.md` — protect 1password from host-side supply chain attacks
- `1.vision.md` — two-way flatpak isolation
- `2.1.criteria.blackbox.md` — 7 usecases for isolation behavior
- `2.3.criteria.blueprint.md` — blueprint acceptance criteria

---

## yagni analysis

### component: configure_firefox_isolation()

**requested?** yes, explicitly.

**evidence**: vision states "configure flatpak permissions". criteria specifies "flatpak override configuration" as a subcomponent contract.

**minimum viable?** yes. the procedure applies overrides with a single flatpak command. no sub-procedures except idempotent guard and prereq check (both necessary for robustness).

---

### component: configure_yama_ptrace()

**requested?** yes, explicitly.

**evidence**: research phase identified yama ptrace_scope=2 as the only way to block same-uid ptrace. blueprint criteria references "namespace isolation" which requires yama.

**minimum viable?** yes. single sysctl file write + reload. no abstraction layers.

---

### component: verify_isolation.sh

**requested?** yes, implied by criteria.

**evidence**: blueprint criteria states "has manual test: attempt ptrace from host" and "has automated check: runs both tests, outputs pass/fail". verification is required to confirm the protection works.

**minimum viable?** yes. three test functions (yama scope, ptrace blocked, proc/mem blocked). no extra features.

---

### component: verify_wayland.sh

**requested?** yes, implied by criteria.

**evidence**: blueprint criteria states "has manual test: grim/screenshot from host" and wayland isolation tests. usecase.7 in blackbox criteria covers wayland.

**minimum viable?** yes. two test functions (x11 denied, wayland allowed). no extra features.

---

### component: check_portal_prereqs()

**requested?** not explicitly, added for robustness.

**added "while we're here"?** partially. this was added in the has-questioned-assumptions review to address the assumption that portals are installed.

**is it yagni?** no — this is a defensive guard. without the check, the procedure could silently fail when the user tries to upload files. the prereq check prevents confusion.

**decision**: keep. this is minimal viable robustness, not feature creep.

---

### component: check_prereqs() in verify_isolation.sh

**requested?** not explicitly, added for robustness.

**added "while we're here"?** partially. this was added to check for strace before the test runs.

**is it yagni?** no — without strace, the test would fail with an unclear error. a prereq check provides clear guidance.

**decision**: keep. this is minimal viable robustness.

---

### component: portal configuration documentation

**requested?** implied by usecases.

**evidence**: usecase.4 requires file picker to work. portal configuration enables this.

**minimum viable?** yes. the documentation explains dependencies without extra implementation.

---

### component: dbus verification

**status**: already deferred in blueprint.

**correct decision?** yes. dbus vector is secondary to ptrace. the primary threat (memory scrape) is addressed by yama. deferral is appropriate YAGNI.

---

### component: CI automation

**status**: already deferred in blueprint.

**correct decision?** yes. no wayland compositor in CI. deferral is correct — we don't build what we can't use.

---

## yagni violations found

none. each component traces to a requirement in the vision, criteria, or research.

---

## "while we're here" review

| potential extra | decision | rationale |
|-----------------|----------|-----------|
| dbus filter implementation | deferred | not primary threat vector |
| CI automation | deferred | blocked by environment |
| verify_all.sh orchestrator | deleted | premature abstraction |
| portal prereq check | kept | prevents silent failure |
| strace prereq check | kept | prevents unclear errors |

---

## requirement traceability matrix

| blueprint component | requirement source | specific reference |
|---------------------|-------------------|-------------------|
| configure_firefox_isolation() | 2.3.criteria.blueprint.md | "flatpak override configuration" subcomponent |
| configure_yama_ptrace() | 2.3.criteria.blueprint.md | "namespace isolation" via yama |
| verify_isolation.sh | 2.3.criteria.blueprint.md | "has manual test: attempt ptrace from host" |
| verify_wayland.sh | 2.1.criteria.blackbox.md | usecase.7 wayland isolation |
| portal prereq check | 2.1.criteria.blackbox.md | usecase.4 file operations must work |
| strace prereq check | implicit | test must not fail with unclear error |

---

## reflection

the blueprint is lean. the verify_all.sh orchestrator was already deleted in the has-questioned-deletables review. the prereq checks added in has-questioned-assumptions are defensive guards, not feature creep — they prevent failures that would confuse users.

**yagni score**: 0 violations found. all components trace to explicit requirements or are minimal guards for robustness.

**rule applied**: minimum viable means minimum required to succeed, with guards that prevent silent failures. defensive checks are not yagni if they prevent user confusion.

**what i looked for but did not find**:
- no "for future flexibility" abstractions
- no "while we're here" feature additions beyond defensive guards
- no premature optimization
- deferrals (dbus, CI) are correct — they address things we can't build or don't need now


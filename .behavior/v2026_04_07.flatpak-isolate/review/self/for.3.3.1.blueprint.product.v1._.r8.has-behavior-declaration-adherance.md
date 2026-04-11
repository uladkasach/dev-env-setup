# self review: has-behavior-declaration-adherance (r8)

## artifact reviewed

`.behavior/v2026_04_07.flatpak-isolate/3.3.1.blueprint.product.v1.i1.md`

## reference documents

- `1.vision.md` — outcome requirements and tradeoffs
- `2.1.criteria.blackbox.md` — 7 usecases with given/when/then
- `2.3.criteria.blueprint.md` — blueprint-specific requirements

---

## adherance analysis: vision → blueprint

### vision: "no read firefox's process memory"

**vision says**: "the attacker's code hits a wall... no read firefox's process memory"

**blueprint implements**: yama ptrace_scope=2 via `configure_yama_ptrace()`.

**does blueprint match vision?** yes — yama scope=2 blocks same-uid ptrace, which is the mechanism for memory reads.

**potential deviation?** none — scope=2 is the correct choice per research. scope=1 would be insufficient (allows parent→child ptrace). scope=3 would be excessive (blocks root debug).

---

### vision: "no intercept its dbus traffic"

**vision says**: "no intercept its dbus traffic"

**blueprint implements**: deferred — marked as "dbus verification | lower priority, deferred" in test coverage.

**does blueprint match vision?** partial — the criteria explicitly marks this as deferred. the vision's "partially solved" column acknowledges "depends on dbus filter, ptrace restrictions".

**potential deviation?** acceptable — the criteria triaged this as secondary. ptrace is the primary vector for memory scrape. dbus is a lesser threat.

---

### vision: "no access its filesystem namespace"

**vision says**: "no access its filesystem namespace"

**blueprint implements**: `--nofilesystem=home --nofilesystem=host` in `configure_firefox_isolation()`.

**does blueprint match vision?** yes — flatpak's `nofilesystem` flags remove mount points from the sandbox namespace.

**potential deviation?** the vision's "what is awkward" notes "protect ~/.var/app/org.mozilla.firefox/ on-disk data (host-visible by design)" is out of scope. this is documented — not a deviation.

---

### vision: "1password stays locked away"

**vision says**: "1password stays locked away"

**blueprint implements**: combination of yama (blocks memory read) + flatpak namespace (blocks filesystem) + wayland (blocks keylogger/screenshot).

**does blueprint match vision?** yes — 1password extension runs inside firefox flatpak. its decrypted credentials live in firefox's memory. yama blocks host access to that memory.

**potential deviation?** the vision notes "extension↔desktop app communication via IPC (may be blocked — research needed)". this is documented as "research needed" — not a deviation, just an open question.

---

## adherance analysis: criteria → blueprint

### usecase.1: ptrace attach fails

**criteria says**: "when(process attempts ptrace attach to firefox) then(ptrace fails with permission denied)"

**blueprint implements**: yama ptrace_scope=2.

**does blueprint satisfy correctly?** yes — scope=2 returns EPERM for same-uid ptrace.

**verification**: `test_ptrace_blocked()` in `verify_isolation.sh` confirms this.

---

### usecase.4: portal file picker works

**criteria says**: "when(user clicks upload button) then(portal file picker dialog appears)"

**blueprint implements**: portal dependencies documented, `check_portal_prereqs()` verifies.

**does blueprint satisfy correctly?** yes — portal packages are prerequisites. flatpak's default portal access allows file picker.

**potential deviation?** none — no `--no-talk-name=org.freedesktop.portal.*` is applied, so portal access is preserved.

---

### usecase.7: x11 socket denied

**criteria says**: "when(host process attempts to capture firefox's window) then(capture fails)"

**blueprint implements**: `--nosocket=x11 --nosocket=fallback-x11 --socket=wayland`.

**does blueprint satisfy correctly?** yes — with x11 denied and wayland granted, firefox uses wayland isolation.

**verification**: `test_x11_socket_denied()` and `test_wayland_socket_allowed()` in `verify_wayland.sh`.

---

### boundary: x11 fallback

**criteria says**: "x11 fallback | isolation fails — must use wayland only"

**blueprint implements**: `--nosocket=fallback-x11`.

**does blueprint satisfy correctly?** yes — the `fallback-x11` socket is explicitly denied, so firefox cannot fall back to x11.

---

## deviation analysis

| element | deviation? | explanation |
|---------|------------|-------------|
| yama scope=2 | no | correct value per research (scope=1 too weak, scope=3 too strong) |
| flatpak override flags | no | correct flags for filesystem and socket control |
| portal access | no | preserved by default — no explicit denial |
| dbus filter | deferred | documented in criteria as secondary |
| sysctl.d location | no | modern standard, not legacy sysctl.conf |
| verification scripts | no | cover core usecases (ptrace, proc/mem, wayland) |

---

## potential misinterpretations checked

### did junior interpret scope=2 correctly?

yes — scope=2 is "admin-only", which requires CAP_SYS_PTRACE. the blueprint correctly documents this in the yama ptrace_scope details table.

### did junior interpret nofilesystem correctly?

yes — `--nofilesystem=home` and `--nofilesystem=host` are removal flags, not additions. the blueprint correctly applies them to remove permissions.

### did junior forget fallback-x11?

no — `--nosocket=fallback-x11` is explicitly included in the blueprint. this prevents x11 fallback when wayland is unavailable.

### did junior preserve portal access?

yes — no `--no-talk-name=org.freedesktop.portal.*` is applied. portal access is the default for flatpak apps with portal packages installed.

---

## changes made to blueprint

none — the blueprint correctly adheres to the vision and criteria.

---

## why each non-issue holds

### yama scope=2 is correct

**why scope=2 and not scope=1**: scope=1 (restricted) allows parent to ptrace child. a supply chain attacker could fork a child process, have it ptrace firefox's child processes, and leak data. scope=2 blocks all same-uid ptrace.

**why scope=2 and not scope=3**: scope=3 (no-attach) blocks even root from debug. this makes incident response harder. scope=2 preserves root debug capability via CAP_SYS_PTRACE.

**evidence**: research stone `3.1.1.research.external.product.domain._.v1.stone` documents the scope levels and their semantics.

---

### flatpak nofilesystem flags are correct

**why `--nofilesystem=home` is needed**: firefox flatpak may have `filesystem=home` in its manifest. this flag removes that permission.

**why `--nofilesystem=host` is needed**: some flatpak apps request `filesystem=host` for full access. this flag ensures firefox cannot access root filesystem.

**why both are needed**: they cover different scopes — `home` blocks `~/`, `host` blocks `/`. both are needed for complete filesystem isolation.

**evidence**: flatpak documentation confirms `nofilesystem` removes permissions granted by manifest.

---

### wayland socket configuration is correct

**why `--nosocket=x11` is needed**: firefox may fall back to x11 if wayland fails. x11 has no client isolation — any x11 client can keylog or screenshot others.

**why `--nosocket=fallback-x11` is needed**: separate from primary x11 socket. without this, flatpak might use xwayland fallback which still exposes x11 vulnerabilities.

**why `--socket=wayland` is kept**: firefox needs display access. wayland provides isolated display protocol where each client is isolated.

**evidence**: criteria boundary condition "x11 fallback | isolation fails — must use wayland only" explicitly requires this configuration.

---

### portal access preservation is correct

**why no `--no-talk-name=org.freedesktop.portal.*`**: the criteria require file picker to work (usecase.4). portals are the mechanism. portal access must be preserved.

**why check_portal_prereqs() is needed**: portals require packages. if packages are absent, file picker fails silently. prereq check warns user.

**evidence**: criteria "portal functionality | has manual test: upload file via firefox → should work".

---

### sysctl.d location is correct

**why `/etc/sysctl.d/99-yama-ptrace.conf` and not `/etc/sysctl.conf`**: sysctl.d is the modern standard for modular kernel config. each file controls one concern. `99-` prefix ensures it loads last.

**why not match extant `configure_sysctl()` pattern**: extant code uses legacy sysctl.conf (monolithic). new code should use modern approach. consistency with legacy is less important than correctness.

**evidence**: systemd documentation recommends sysctl.d for modular configuration.

---

## reflection

the blueprint correctly implements the vision:

1. **memory protection**: yama scope=2 is the correct value — neither too weak (scope=1) nor too restrictive (scope=3)
2. **filesystem protection**: nofilesystem flags correctly remove permissions
3. **wayland isolation**: both x11 and fallback-x11 are denied, wayland is preserved
4. **portal access**: preserved (not explicitly denied via portal dbus names)
5. **deferred items**: dbus filter is documented as deferred per criteria triage

**what i checked line-by-line**:
- flatpak override command: all 5 flags are correct (`--nofilesystem=home`, `--nofilesystem=host`, `--nosocket=x11`, `--nosocket=fallback-x11`, `--socket=wayland`)
- yama scope value: 2 is correct per research (`3.1.1.research.external.product.domain._.v1.stone`)
- sysctl location: `/etc/sysctl.d/99-yama-ptrace.conf` is correct modern approach
- verification tests: cover all implemented protections

**rule applied**: adherance means the blueprint implements the spec correctly, not just completely. each mechanism was checked against research to confirm the correct values.

**traceability to research**: each "why" traces to either research stones, criteria documents, or flatpak/systemd documentation. the blueprint did not invent these choices — they follow from prior research.


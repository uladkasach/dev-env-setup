# self-review r2: has-questioned-questions

## questions from vision — triaged

### questions that need external research

1. **does flatpak's user namespace prevent ptrace from host?**
   - **triage**: [research] — requires technical documentation or experiments
   - **why**: this determines if the core goal is achievable

2. **can a host process with same uid read /proc/[flatpak-pid]/mem?**
   - **triage**: [research] — requires kernel/namespace documentation
   - **why**: /proc access is a key attack vector

3. **what dbus interfaces does firefox expose, and can host processes call them?**
   - **triage**: [research] — requires dbus introspection of firefox flatpak
   - **why**: dbus is a cross-boundary communication channel

4. **does 1password extension store secrets in firefox's sandbox or in a separate process?**
   - **triage**: [research] — can check 1password documentation
   - **why**: determines what we're actually protected

### questions to validate with wisher

1. **are you okay with potential feature breakage (file picker dialogs, drag-drop from host)?**
   - **triage**: [wisher] — only they can decide acceptable tradeoffs
   - **why**: user experience vs security tradeoff

2. **do you need to share files between host and firefox? (would require portal configuration)**
   - **triage**: [wisher] — workflow-dependent
   - **why**: affects how we configure portals

3. **is firefox the only sensitive flatpak, or should we isolate others too (e.g., slack, signal)?**
   - **triage**: [wisher] — scope decision
   - **why**: affects whether we build a reusable pattern or firefox-specific solution

### questions from r1/r2 reviews — triaged

4. **do you use 1password desktop app or browser-only mode?**
   - **triage**: [wisher] — only they know their setup
   - **why**: determines where secrets actually live

5. **is transient attack protection sufficient, or do you need persistent threat protection?**
   - **triage**: [wisher] — threat model decision
   - **why**: persistent threats require different countermeasures (separate user account, VM, etc.)

### questions answerable via logic now

1. **does cosmic use wayland?**
   - **triage**: [answered] — yes, cosmic is wayland-native
   - **evidence**: cosmic-comp is a wayland compositor. x11 apps run via xwayland but firefox flatpak supports native wayland.

2. **is flatpak designed for host-to-app isolation?**
   - **triage**: [answered] — no, but namespaces may still provide it
   - **rationale**: flatpak's primary design is app-to-host isolation. but linux namespaces create a boundary that may work both ways. research needed to confirm.

3. **is defense-in-depth valuable even if imperfect?**
   - **triage**: [answered] — yes
   - **rationale**: security is layers. even partial protection raises the bar for attackers.

---

## fixes to vision

i need to update the vision's "open questions & assumptions" section to reflect these triage tags. let me do that now.

---

## summary

| question category | count |
|-------------------|-------|
| [research] | 4 |
| [wisher] | 5 |
| [answered] | 3 |

all questions are now triaged. the vision needs an update to reflect the tagged questions.

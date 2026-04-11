# self-review r2: has-questioned-assumptions

## deeper look — assumptions i missed in r1

### assumption: namespaces work symmetrically

**what i assumed**: linux namespaces create symmetric barriers — if app can't see host, host can't see app.

**evidence**: none. namespaces are designed to restrict the sandboxed process, not the parent.

**what if the opposite is true**: namespace isolation is asymmetric by design. the parent (host) has full visibility into child namespaces. flatpak may not change this.

**verdict**: **issue found**. this is the most critical assumption. if namespaces are asymmetric, the entire vision fails. must research how flatpak achieves (or fails to achieve) host-to-sandbox isolation.

---

### assumption: 1password data is in the browser

**what i assumed**: 1password extension stores vault data locally in firefox's storage.

**what if the opposite is true**: 1password's real vault is on 1password's servers (or in the desktop app). the browser extension is just a client that decrypts and displays credentials. the decrypted credentials live in memory briefly, but the "vault" isn't in the browser.

**implication**: even with perfect browser isolation, the decrypted credentials pass through firefox's memory. a memory read attack could still capture them while unlocked.

**verdict**: **non-issue for scope** — to protect firefox memory is still valuable. but i should clarify that we protect "credentials while in use" not "the vault itself."

---

### assumption: attack is transient

**what i assumed**: malicious npm code runs once, does its damage, and we're done.

**what if the opposite is true**: attacker persists via cron job, systemd unit, shell rc files. they wait for you to unlock 1password, then capture the master password via keylogger.

**verdict**: **issue found**. persistent attacks bypass per-session isolation. vision should acknowledge this limitation — we protect against smash-and-grab, not persistent APT.

---

### assumption: flatpak is the right tool

**what i assumed**: flatpak is the answer.

**alternatives i didn't consider**:
- VM (virtualbox/qemu): stronger isolation, but heavyweight
- separate user account: run terminal as different uid
- qubes os: purpose-built for compartmentalization
- firejail: lighter sandbox than flatpak

**verdict**: **non-issue** — flatpak is reasonable for this use case. but should mention alternatives in research phase.

---

### assumption: cosmic wayland is secure

**what i assumed**: cosmic's wayland is secure.

**evidence**: wayland protocol is secure by design. but cosmic is new software (alpha/beta quality).

**what if the opposite is true**: cosmic could have bugs that leak input across surfaces, or that allow screen capture.

**verdict**: **issue found**. should verify cosmic's wayland implementation in research phase.

---

### assumption: prevention is enough

**what i assumed**: if we prevent host-to-sandbox access, we're done.

**what if the opposite is true**: we should also detect breaches. how would we know if someone bypassed the sandbox?

**verdict**: **non-issue for vision scope** — detection is a separate concern. but could mention in the awkward section.

---

### assumption: "configure flatpak permissions" achieves the goal

**what i assumed**: we can configure flatpak to restrict host access.

**problem**: flatpak permissions control what the app can access (outbound). they don't control what can access the app (inbound). these are different security boundaries.

**verdict**: **issue found**. the vision conflates outbound (app→host) and inbound (host→app) isolation. these require different mechanisms.

---

## fixes needed in vision

1. **clarify asymmetry**: be explicit that flatpak's default isolation is outbound (app→host), and we need to research whether inbound (host→app) is even possible.

2. **scope the protection**: protect "credentials in memory" not "the vault."

3. **acknowledge persistence gap**: we guard against transient attacks, not persistent threats.

4. **separate inbound vs outbound**: don't conflate flatpak permissions (outbound control) with namespace isolation (potentially inbound).

## summary

| assumption | r1 status | r2 status | action |
|------------|-----------|-----------|--------|
| namespaces symmetric | missed | **critical gap** | research if inbound isolation is possible |
| 1password in browser | raised | clarified | scope as "credentials in memory" |
| attack is transient | missed | **gap** | acknowledge limitation |
| flatpak is right tool | not questioned | acceptable | mention alternatives |
| cosmic wayland secure | holds | **unverified** | research |
| prevention enough | missed | acceptable for scope | could add detection note |
| flatpak permissions = isolation | missed | **conflated** | separate inbound vs outbound |

# self-review: has-questioned-requirements

## the core requirement: two-way flatpak isolation

### who said this was needed?
the wisher, in response to supply chain attack concerns.

### what if we didn't do this?
a compromised terminal process could access firefox's memory, dbus interfaces, or storage — which exposes 1password vault data.

### is this requirement misdirected?

**issue found**: i assumed 1password extension stores secrets inside firefox's sandbox. but this may be wrong.

1password has two modes:
1. **browser-only**: extension stores vault in browser storage — a sandbox around firefox would help
2. **with desktop app**: extension talks to 1password desktop app via native messages — the desktop app holds the secrets, not the browser

if the wisher uses the desktop app, then:
- the secrets are in the 1password app, not firefox
- to protect firefox does not protect the vault
- we'd need to sandbox 1password desktop app instead

**action**: must ask wisher which mode they use.

## the scope question

### is the scope too large?

**issue found**: the vision talks about "two-way isolation" as if it's a single toggle. but there are multiple attack vectors:
1. ptrace / /proc/pid/mem access
2. dbus messages
3. x11 snoop attacks (keyloggers, screen capture)
4. filesystem access
5. clipboard interception

each requires different mitigations. the vision lumps them together.

**action**: in criteria phase, separate these into distinct requirements with distinct verification.

### could we achieve the goal simpler?

**question**: what if the threat model is wrong?

the wisher assumes a supply chain attack runs as their user. but:
- if malware has user access, it could also modify flatpak overrides
- if malware has user access, it could install a keylogger at the wayland compositor level
- if malware has user access, it could wait for you to type your 1password master password

**non-issue**: defense in depth is still valuable. even if not perfect, to raise the bar is worthwhile. the goal isn't "unhackable" — it's "raised bar."

## wayland assumption

### what evidence supports this?
cosmic uses wayland. i know this from prior work on this machine. but should verify in research phase.

**non-issue**: cosmic is wayland-native. x11 apps run via xwayland but firefox flatpak uses wayland natively.

## dbus filter assumption

### is this achievable?
i assumed dbus filter is practical. but:
- flatpak apps need some dbus access for portals
- over-filter breaks functionality
- the line between "needed" and "dangerous" is unclear

**action**: research what dbus interfaces firefox requires vs what would be dangerous.

## summary

| requirement | status | action |
|-------------|--------|--------|
| two-way isolation | holds | core goal, worth pursuit |
| protect 1password | **needs clarification** | ask: desktop app or browser-only? |
| dbus filter | holds, needs research | research firefox dbus requirements |
| wayland | holds | cosmic is wayland-native |
| scope definition | **needs work** | separate attack vectors in criteria |

## what i would do differently

1. ask about 1password setup before i wrote the vision
2. separate attack vectors into distinct requirements earlier
3. acknowledge the defense-in-depth frame from the start (not "perfect protection" but "raised bar")

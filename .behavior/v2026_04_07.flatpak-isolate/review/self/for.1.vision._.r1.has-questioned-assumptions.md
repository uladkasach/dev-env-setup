# self-review: has-questioned-assumptions

## assumption 1: supply chain attacks run as user

### what i assumed
malicious code from npm/pip/cargo runs with user permissions, not root.

### evidence
this matches how these tools work — they execute code as the current user.

### what if the opposite were true?
if malware escalates to root, flatpak sandbox doesn't help — root can do anything.

### verdict
**non-issue**: root escalation is a different threat model. the wisher's concern is specifically user-level supply chain attacks. defense in depth still helps.

---

## assumption 2: flatpak supports bidirectional isolation

### what i assumed
flatpak can prevent host processes from access to sandboxed apps.

### evidence
none cited. i inferred this from general namespace knowledge.

### what if the opposite were true?
if flatpak only provides unidirectional isolation (host FROM app), the entire vision is wrong.

### did the wisher say this?
no — the wisher asked "howto?" implying we need to research whether it's possible.

### verdict
**issue found**: i stated "flatpak sandbox that the host cannot penetrate" as fact. but this is unverified. must research whether flatpak's namespace isolation actually prevents host access.

**action**: mark as "must research" and be honest that this might not be achievable with flatpak alone.

---

## assumption 3: the wisher runs firefox as flatpak

### what i assumed
firefox is already a flatpak install.

### evidence
the wisher mentioned "flatpak isolation" — implies they use flatpak.

### did the wisher actually say this?
they said "flatpak isolation" but didn't confirm firefox is already flatpak.

### verdict
**non-issue**: the wisher framed the question in terms of flatpak. safe inference.

---

## assumption 4: user namespaces block /proc access

### what i assumed
flatpak uses user namespaces, which prevent /proc/[pid]/mem read.

### evidence
none. i assumed namespace isolation covers this.

### what if the opposite were true?
if host can still read /proc/[flatpak-pid]/mem, memory snoop attacks work.

### verdict
**issue found**: this is a critical assumption with no evidence. must research.

---

## assumption 5: wayland prevents keylog attacks

### what i assumed
wayland isolates input per-surface, unlike x11.

### evidence
this is well-documented wayland design. cosmic is wayland-native.

### what if the opposite were true?
if xwayland leaks, or if wayland has its own snoop vectors, the assumption fails.

### verdict
**non-issue**: wayland's input isolation is documented. but must verify firefox uses native wayland, not xwayland.

---

## assumption 6: dbus can be filtered while portal works

### what i assumed
we can block hostile dbus traffic while portal dbus works.

### evidence
none. i assumed this is possible.

### what if the opposite were true?
if dbus filter is binary (block all or allow all), we break functionality or break isolation.

### verdict
**issue found**: need to research flatpak's dbus filter mechanisms.

---

## assumption 7: clipboard via portal is secure

### what i assumed
clipboard portal provides secure cross-boundary copy-paste.

### evidence
none.

### what if the opposite were true?
if host can snoop on portal traffic, clipboard is a leak channel.

### verdict
**issue found**: must research portal security model.

---

## assumption 8: no performance cost

### what i assumed
sandbox overhead is negligible.

### evidence
general knowledge of namespace overhead (minimal).

### verdict
**non-issue**: namespace overhead is well-documented as minimal. this holds.

---

## assumption 9: one-time setup

### what i assumed
setup is a one-time configuration.

### evidence
none.

### what if the opposite were true?
if flatpak updates reset permissions, or if portal config drifts, setup recurs.

### verdict
**issue found**: should clarify that audit of permissions may be periodic, not one-time.

---

## summary

| assumption | status | action |
|------------|--------|--------|
| supply chain = user-level | holds | threat model is scoped |
| flatpak bidirectional | **unverified** | must research |
| firefox is flatpak | holds | safe inference |
| namespaces block /proc | **unverified** | must research |
| wayland prevents keylog | holds | verify firefox uses native wayland |
| dbus filter + portal | **unverified** | must research |
| portal clipboard secure | **unverified** | must research |
| no perf cost | holds | documented |
| one-time setup | **partly wrong** | clarify as "initial + periodic audit" |

## what i would do differently

1. be more explicit that bidirectional isolation is the hypothesis, not a fact
2. separate "what we assume" from "what we've verified" in the vision
3. frame the vision as "if this works, here's the world" rather than "this works"

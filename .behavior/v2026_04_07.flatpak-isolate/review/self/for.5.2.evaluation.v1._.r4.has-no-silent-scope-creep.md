# self review: has-no-silent-scope-creep (r4)

## fourth pass: deeper than the checklist

r3 confirmed no scope creep via checklist. r4 questions the checklist itself.

---

## the real question: did the implementation stay true to the wish?

### what was the wish?

> "we want the flatpak isolation to be 2way"
> "if this machine is compromised from a supply chain attack or some other defect, that no one can reach into firefox from my terminal, and snoop on my unlocked 1password extension"

### what did the blueprint promise?

1. configure ptrace_scope=2 (yama)
2. configure flatpak overrides (filesystem, socket, dbus)
3. create verification procedures

### what did the implementation deliver?

exactly that — plus two defensive additions (extra test, prereq check).

---

## where scope creep typically hides

| spot | found here? | evidence |
|------|-------------|----------|
| test code | yes — extra test | documented as divergence |
| prereq checks | yes — firefox installed check | documented as divergence |
| config options | no | no extra flags added |
| file structure | no | matches blueprint tree |
| error messages | no | follow blueprint patterns |
| dependencies | no | no new external dependencies |

---

## the scope creep I *didn't* do

what I could have added but deliberately avoided:

| temptation | why avoided |
|------------|-------------|
| dbus verification procedure | blueprint deferred it ("lower priority") |
| CI automation | blueprint said "no wayland compositor in CI" |
| 1password desktop app isolation | blueprint said "out of scope" |
| automatic firefox install | blueprint assumed firefox flatpak extant |
| systemd unit for yama persistence | sysctl.d is sufficient and simpler |
| flatpak permission GUI hints | not in blueprint, not necessary |

---

## why scope stayed focused

1. **wish was specific** — "protect 1password from host compromise"
2. **blueprint was bounded** — explicit "out of scope" section
3. **new files only** — no temptation to touch extant code
4. **divergences caught early** — r1/r2 reviews found firefox check

---

## what would have made this scope creep

| scenario | would be scope creep because |
|----------|------------------------------|
| added slack/signal isolation | wish was firefox-specific |
| refactored install_env.sh structure | unrelated to isolation |
| added 1password desktop verification | blueprint marked out of scope |
| added flatpak auto-update | unrelated to security isolation |

none of these occurred.

---

## why it holds

the implementation stays within the wish boundary:
- delivers the protection the wish asked for
- adds only defensive code (documented as divergences)
- respects blueprint's "out of scope" boundaries
- creates no new maintenance burden beyond the ask

scope is contained because the wish was clear and the blueprint enforced boundaries.


# self review: has-divergence-addressed (r3)

## third pass: deeper scrutiny

r2 validated both backups. this pass asks: did we miss any angle?

---

## divergence 1: extra test_x11_sockets_denied()

### could this cause problems later?

**potential issue: test brittleness**

the test parses `flatpak override --user --show` output. if flatpak changes output format, test breaks.

**assessment:** acceptable risk. test failure would surface a real need — either flatpak changed, or the override was removed. both warrant attention.

**potential issue: false positive**

the test could pass (nosocket=x11 present) even if the override is not effective due to higher-priority system override.

**assessment:** the blueprint test (test_x11_socket_denied) catches that case by socket visibility check. together they cover both failure modes.

### why it holds

the extra test catches a failure mode the blueprint test cannot: configuration present but not in the right place. no downside, small maintenance cost.

---

## divergence 2: extra firefox flatpak installed check

### could this cause problems later?

**potential issue: silent skip**

exit 0 when firefox is absent means the caller cannot distinguish "isolation configured" from "isolation skipped".

**assessment:** the echo message clarifies. the procedure is for the dev-env-setup workflow where firefox flatpak is expected. on a machine without firefox, the message is informative, not deceptive.

**potential issue: wrong abstraction level**

should the prereq check live in the caller, not the procedure?

**assessment:** the caller is a human who has sourced the file. the guard inside the procedure follows the repo's extant pattern (see install_env.sh guards for optional tools). consistent with rule.require.pitofsuccess.

### why it holds

the check follows the repo's extant pattern of graceful response when optional prereqs are absent. no silent failure — outputs clear message.

---

## meta: are we just lazy?

| check | answer |
|-------|--------|
| did we avoid work the blueprint required? | no — all blueprint deliverables present |
| are we backup to avoid a hard fix? | no — both divergences are additions |
| would a senior reviewer push back? | unlikely — both are defensive code |

---

## what could have gone wrong

1. **test_x11_sockets_denied could have been redundant** — but it tests configuration, not visibility. different concern.
2. **firefox check could have masked a real error** — but it outputs a clear message, doesn't hide the skip.
3. **could have added more divergences we missed** — r1 and r2 found the firefox check was absent from divergence table. fixed.

---

## summary

both backups hold under scrutiny:
1. extra test — catches configuration issues independent of socket state
2. firefox check — prevents error on absent prereq, follows repo pattern

no repairs needed. divergence resolution is complete and valid.


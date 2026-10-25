# F15 — the verify restates each declared key by hand, never derives them from the patch

- **fork**: the patch lives as a local in `_settings_upsert`; the verify's `_settings_claims`
  lists each key and its want a second time (r011 nitpick.6, i006)
  - **A. two lists** (as built)
  - **B. one constant**: lift the patch into `_.sh`, and derive the verify's value claims from it
- **taken**: A. a verify that reads the same constant the apply wrote can no longer catch a wrong
  constant — a typo in the patch would be applied and then ✔ed by its own echo. the second list is
  the independent half of a double entry, and a key added to one list and not the other makes the
  verify ✋ loudly, which is the signal the reviewer asks for
- **rework**: clean — B is a lift and a loop, local to two files
- **confidence 70%, low because**: the derive is cheaper to keep, and the cost of a missed key
  (unverified, not wrong) is real
- **where**: `configure.upsert.sh` `_settings_upsert`; `configure.verify.sh` `_settings_claims`
- **verdict**: open

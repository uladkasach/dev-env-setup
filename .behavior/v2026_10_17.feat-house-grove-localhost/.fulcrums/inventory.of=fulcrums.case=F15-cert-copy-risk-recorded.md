# F15 — B, second half: a 0600 cert can be copied off the box for up to 7 days

## .the fork
- **A** record the copy risk and accept it in this stone; keep the key path one profile line,
  so a hardware-held key later is a one-line swap
- **B** hold the key in the laptop's TPM, so it cannot leave the box
- **C** A, plus a shorter cert lifetime (e.g. 1 day, renewed daily), which shrinks the window

## .taken: A, and why at the time
- a copy needs read on the camper's key: the camper uid, root, or a sudo seat. each of those
  already holds the live badge on the box, so the copy adds reach off the box, not power on it
- B rests on an unverified premise: 📌 that `aws_signing_helper` signs with a TPM-held key on
  this laptop. a ci runner has no TPM either, so B splits the clamp from the box
- C's lifetime is a CA config, so it is `#36`'s knob, not this tree's; the box half renews at
  any lifetime (case=7 `[t2]`)

## .what A costs
a stolen cert works anywhere for up to its lifetime — longer than EC2's hours-long sessions.
the vision's cons now say so in those words.

## .rework
clean — `credential_process` names the cert and key paths in one line; a TPM or PKCS#11 key is a
change to that line plus a research row.

## .confidence 70% — why not higher
B is the stronger wall if the helper supports it. **the commander's to rule** (seed S2); if B,
a research row on the helper's TPM support is owed before execution.

## .where
yield `.cons`, `.edges`; case=4; case=7 `[t2]`.

## .risk: risky
it accepts that a copied cert works off the box for up to its lifetime in the prep account. that is a credential exposure window, recorded on purpose.
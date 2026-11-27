# F16 — the unit gains no process-scope bounds in this change

## .the fork
- **harden now** — `ProtectSystem=strict`, `ReadWritePaths=/run /tmp`, `NoNewPrivileges=yes`, and a
  capability set of `CAP_SETUID CAP_SETGID CAP_DAC_READ_SEARCH`, as `tmp-cleanup.service` carries
- **ship the fix with the unit's bounds as they are**, and harden in a change a grove proves

## .taken — ship as is
- each option changes what the check can SEE, and a wrong one fails toward a wrong sleep, the
  costly direction:
  - `ProtectHome=yes` hides `/home`, so every walk reads zero traces in silence — the wish's defect
  - `PrivateTmp=yes` hides `/tmp/tmux-*`, so every duct vanishes
  - a capability set without `CAP_DAC_READ_SEARCH` blinds the walks to a seat's 0700 dirs
- none of these can be proven in a fixture: a fixture runs no unit. the proof is a ground apply on
  an ec2 grove, then `prove.idle-check-reads-this-box` from the ground seat, with `seen traces>0`
  and every duct counted under the hardened unit
- the exposure the review named — a root client on a planted socket — is closed at its cause by
  `dial_duct`'s drop to the socket's owner, and by `say`'s control-byte filter on every line the
  check emits

## .rework — clean
add the block to `idle-hibernate.service`, apply from the ground seat, run the live play. the
drift play's byte check carries the new unit to every grove on its next apply.

## .confidence — 70%, and why it is low
the hardened unit is plainly the better end state; the open question is only whether it rides this
change or the next. a reviewer who weighs root-on-user-paths above a wrong-sleep risk would take
it now.

## .where
`src/grove.provision/1.system/1.15.hibernate/idle-hibernate.service`

## .verdict
open — best-guessed at 5.1, flagged in the PR

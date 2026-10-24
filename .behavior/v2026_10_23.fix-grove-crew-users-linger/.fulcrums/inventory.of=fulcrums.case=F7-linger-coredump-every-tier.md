# F7 — linger and coredump reach every tier; only the tmux pin stays cloud-only

- fork: keep `1.6.7.linger` and `1.6.8.coredump` cloud-only (their first draft) vs apply them
  on every tier, the laptop included
- taken: every tier — `rule.forbid.divergence-without-a-physical-reason`. linger is a logind
  record and logind runs on every kind; systemd-coredump is an apt package and core_pattern a
  kernel knob. neither decline named a physical subject: one named a desktop session (an
  effect), the other named "no human to choose" (a capability claim the rule forbids)
- the tmux pin stays cloud-only: F2, struck by the director — a scope call, not a physical one
- what the coredump apply does on every tier, the laptop included: it installs
  systemd-coredump, points `core_pattern` at it, and turns apport's boot claim off
  (`enabled=0` in `/etc/default/apport`), since apport's init takes the pattern back at every
  boot. the cost on a laptop: apport stops to file crash reports into `/var/crash`;
  systemd-coredump keeps each core instead. the apply prints that loss and the undo
  (`enabled=1`), after which the verify ✋s, since the next boot hands the pattern back
- rework: clean — restore the two `local@*` declines, or gate the apport release to `cloud@*`
  and let a laptop's verify name the apport choice as a human's
- confidence 60%, low because the laptop's apport release changes a collector a human may have
  chosen, and a laptop's verify ✋s until a human runs the root apply once
- where: `1.6.7.linger/provision.{upsert,verify}.sh`, `1.6.8.coredump/provision.{upsert,verify}.sh`;
  laptop parity clamped by U5, U10 (coredump) and U3, V3 (linger)
- re-asked i004 (r10 blocker.5), i008 (r10 blocker.3, r11 nitpick.5): the record had said the
  upsert ✋s rather than override apport — true before the i006 boot-claim repair, false after.
  revised in place to what the code does. the laptop question stays the director's call

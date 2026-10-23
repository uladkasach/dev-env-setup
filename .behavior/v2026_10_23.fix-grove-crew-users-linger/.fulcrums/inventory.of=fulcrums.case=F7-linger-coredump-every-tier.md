# F7 — linger and coredump reach every tier; only the tmux pin stays cloud-only

- fork: keep `1.6.7.linger` and `1.6.8.coredump` cloud-only (their first draft) vs apply them
  on every tier, the laptop included
- taken: every tier — `rule.forbid.divergence-without-a-physical-reason`. linger is a logind
  record and logind runs on every kind; systemd-coredump is an apt package and core_pattern a
  kernel knob. neither decline named a physical subject: one named a desktop session (an
  effect), the other named "no human to choose" (a capability claim the rule forbids)
- the tmux pin stays cloud-only: F2, struck by the director — a scope call, not a physical one
- rework: clean — two early returns restored
- confidence 80%, low because a laptop's verify now ✋s until a human runs the root apply once,
  and on a box where apport holds core_pattern the coredump upsert ✋s rather than override a
  collector a human may have chosen
- where: `1.6.7.linger/provision.{upsert,verify}.sh`, `1.6.8.coredump/provision.{upsert,verify}.sh`

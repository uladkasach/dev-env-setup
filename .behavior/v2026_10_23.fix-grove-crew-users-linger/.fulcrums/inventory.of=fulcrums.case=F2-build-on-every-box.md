# F2 — the pinned build applies on every box, laptop included

- fork: build 3.5a everywhere vs only on `cloud@*` (keep the distro tmux on a laptop)
- taken: everywhere — `rule.forbid.divergence-without-a-physical-reason`; the laptop drives
  ducts on its own tmux too, and no physical fact parts the two
- rework: clean — one tier gate in the upsert
- confidence 60%, low because a laptop's live server may be a different version than the new
  client for one session, and a human's own long-lived tmux carries more risk than a grove's
- where: `2.8.tmux/provision.upsert.sh`
- verdict: struck by the director (S2) — the laptop build is out of this route's grove
  scope. the pin stays `cloud@*` only. this is a SCOPE call, never a physical reason:
  `rule.forbid.divergence-without-a-physical-reason` still calls it a miss, so a laptop
  pin is owed by a later route, not refused for good

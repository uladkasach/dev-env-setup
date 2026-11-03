# F022 — the hermetic plays are unit grain, not acceptance tests

- **fork:** grade the `.play/permanent/*.play.sh` plays by the acceptance rules (no mocks, action
  through the contract) · grade them as unit-grain tests of a phase's logic, with the boundaries
  faked by injection
- **taken, why:** unit grain
  - each play sources one bundle and calls its phase function, with root, apt, the network, the
    daemon, and ssh replaced by stubs. that is `rule.forbid.unit.remote-boundaries`' own cure:
    fakes injected in place of the remote boundary, no real fs/db/network touched
  - this repo's contract boundary is `rhx grove.provision --what <slug> --mode apply`. it needs
    real root, a real apt, and a real tailnet, so no hermetic play can drive it. the acceptance
    proof for that path is the run on a grove (`rule.require.prove-changes-on-a-grove`) and the
    commander's laptop apply (fleet.asks `tailscale-174-first-apply`) — the open row in the yield
  - the seam overrides r9 names (`bundle.root.owns`, `pkg_*`, `web_*`, the platform probe) are
    the boundaries, not the subject: the phase's branches over their answers are what each row
    proves, and the real runtime decline is sourced where the row's claim is its text
  - every play the lane names but four predates this pr; a regrade of the repo's test grain is
    repo-wide, outside a tailscale pr
- **what r9 asked that is cheap and owed:** the inline `.mock/.why/.real` note at each stub, so a
  reader knows which claim a row proves and which real run covers the rest — dream
  `2026_10_26.tailscale-l3-followups`, item 18
- **rework:** clean — a note per stub; no assertion moves
- **risk:** low|safe — no code path changes
- **status:** best-guessed by the driver; for the commander at the end council
- **confidence 80%, why not higher:** the lane's bind now names the plays, so it will grade them as
  acceptance every round; the commander may prefer a lane that grades the unit grain instead

# F1 — pin tmux 3.5a, not latest 3.8

- fork: 3.5a (what keepalive hand-built on the live box) vs 3.8 (latest, 2026-09-09)
- taken: 3.5a — the instruction names "carry the same"; one version on the box and in the
  repo means the first apply on the live box is a no-op rather than a binary swap under live crews
- rework: clean — one pin + one sha256 constant in `2.8.tmux/_.sh`
- confidence 80%, low because 3.8 carries two more years of fixes and 3.5a's crash record on
  this workload is hours old
- where: `src/grove.provision/2.shell/2.8.tmux/_.sh`

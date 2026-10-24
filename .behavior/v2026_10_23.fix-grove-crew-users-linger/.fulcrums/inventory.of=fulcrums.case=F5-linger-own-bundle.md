# F5 — linger moves to its own bundle, out of 1.6.4.keyrackd

- fork: patch the linger block inside keyrackd vs a dedicated bundle under 1.6.procs
- taken: own bundle — linger serves crews and the user manager, not only the prune timer;
  keyrackd skips it when its skill is absent (`provision.upsert.sh:47`) and checks only `$USER`
  (`:119`). one owner, read per seat, ✋ on a failed grant
- rework: clean — a new leaf dir + one dispatch line; keyrackd's verify still reads the fact
- confidence 85%
- where: `src/grove.provision/1.system/1.6.procs/`

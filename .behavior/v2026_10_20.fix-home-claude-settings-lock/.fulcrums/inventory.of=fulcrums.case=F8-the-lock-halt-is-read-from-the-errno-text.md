# F8 — the lock halt is read from the init's errno text on the settings path

- **fork**: classify the init's failure from its output vs a structured signal from the init
- **taken**: the output, narrowed: `EACCES` AND `.claude/settings.json` in one output. no structured channel exists — an npm command reports only an exit code, and rhachet's init exits 1 for every failure. `EACCES` is the kernel's errno name, which node prints verbatim in every fs error, so it is a stable contract, not prose
- **what the narrowing buys**: an EACCES on any other path, a timeout (124), or any other failure keeps the lock and halts with ✋; only the settings file earns the write-bit restore (clamp arms 8b, 8f, 8g, teeth b8f)
- **rework**: clean — one predicate, `_grove_provision_5_3_brains_init_halted_by_lock`
- **confidence 80%, low because**: a future init could report the path relative to some other root, which would read as "other" — a safe miss (lock kept, ✋), never a false unlock
- **where**: `configure.upsert.sh`
- **verdict**: open

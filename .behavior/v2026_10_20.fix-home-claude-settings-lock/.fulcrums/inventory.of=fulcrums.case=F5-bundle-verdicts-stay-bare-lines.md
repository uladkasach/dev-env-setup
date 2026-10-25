# F5 — bundle verdicts stay bare `✋` lines, never qualified error headers

- **fork**: `✋ ConstraintError:` / `💥 MalfunctionError:` headers (`rule.require.qualified-error-headers`) vs the verdict-line form every bundle phase prints
- **taken**: the verdict-line form. a phase prints one indented `   ✋ <claim>` line under its bundle tree, beside `✔` and `🌙`, and each carries a `fix:` line. 159 bundle files use it; `ConstraintError:` appears only in standalone clis (`machine_wifi_link_watchdog`, `brains.auth.sh`), whose stderr is a whole message
- **exit codes**: the bundle runtime reads 0 = held, nonzero = not held (`src/bundle.upgrade.sh`); a 1-vs-2 split inside one phase has no reader
- **rework**: dirty — one phase alone in the qualified form reads as a second dialect in one tree; the cure is a repo-wide convention change, the human's call
- **confidence 85%, low because**: the qualified-header rule is a mechanic blocker, and this repo never ruled whether bundle verdict lines fall in its scope
- **where**: `5.3.brains/configure.{upsert,verify}.sh`
- **verdict**: open

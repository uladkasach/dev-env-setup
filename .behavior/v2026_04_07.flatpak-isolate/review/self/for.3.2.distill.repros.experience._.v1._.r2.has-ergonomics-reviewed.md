# self review: has-ergonomics-reviewed (r2)

## artifact reviewed

`.behavior/v2026_04_07.flatpak-isolate/3.2.distill.repros.experience._.v1.i1.md`

---

## input/output ergonomics review

### journey 1: apply isolation

#### input

```bash
source src/install_env.pt1.system.security.sh && configure_firefox_isolation
```

| criterion | assessment |
|-----------|------------|
| feels natural? | **yes** — standard pattern in this repo |
| can we simplify? | **no** — already minimal (source + call) |
| friction? | **none** — matches extant patterns |

**why it holds**: this matches the established pattern in the repo. all install procedures work this way. users who know this repo will succeed without documentation.

#### output

```
• firefox flatpak overrides applied
```

| criterion | assessment |
|-----------|------------|
| feels natural? | **yes** — matches extant echo patterns |
| could be clearer? | **maybe** — could list which overrides applied |
| friction? | **none** |

**why it holds**: the bullet point format matches other procedures in the repo. consistency trumps verbosity.

---

### journey 2: verify isolation

#### input

```bash
./tests/verify_isolation.sh
```

| criterion | assessment |
|-----------|------------|
| feels natural? | **yes** — single command, no args |
| can we simplify? | **no** — already minimal |
| friction? | **none** |

**why it holds**: zero-arg entry point is the lowest friction possible. no configuration needed.

#### output

```
=== flatpak isolation verification ===
[INFO] firefox pid: 12345
[TEST] yama ptrace_scope...
[PASS] ptrace_scope=2 (admin-only)
```

| criterion | assessment |
|-----------|------------|
| feels natural? | **yes** — clear pass/fail per test |
| could be clearer? | **no** — format is scannable |
| friction? | **none** |

**why it holds**: each test is labeled, each result is pass/fail, summary at end. user can scan for failures without the need to read details.

---

### journey 3: attacker attempt fails

**why it holds**: attacker experience is intentionally hostile. the "Operation not permitted" message is correct — it tells the attacker they are blocked without reveal of implementation details.

---

## pit of success review

| criterion | why it holds |
|-----------|--------------|
| intuitive design | procedure names are verbs that describe action: configure_*, verify_* |
| convenient | no required inputs; procedures work with system defaults |
| expressive | procedure names match their purpose; no hidden behavior |
| composable | procedures can chain: `configure_firefox_isolation && configure_yama_ptrace` |
| lower trust contracts | verification reads actual system state, not cached values |
| deeper behavior | idempotent guards prevent double-apply damage |

---

## issues found

**none.** ergonomics reviewed, all hold.

---

## verdict

input/output ergonomics are natural and follow repo conventions. no changes needed.


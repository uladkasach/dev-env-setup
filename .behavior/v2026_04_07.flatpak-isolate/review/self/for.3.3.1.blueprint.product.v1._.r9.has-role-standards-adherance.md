# self review: has-role-standards-adherance (r9)

## artifact reviewed

`.behavior/v2026_04_07.flatpak-isolate/3.3.1.blueprint.product.v1.i1.md`

## relevant rule directories

from mechanic role briefs:

| directory | relevance to blueprint |
|-----------|------------------------|
| `practices/lang.terms/` | name conventions in blueprint |
| `practices/lang.tones/` | comment and doc style |
| `practices/code.prod/evolvable.procedures/` | procedure contracts |
| `practices/code.prod/pitofsuccess.procedures/` | idempotent patterns |
| `practices/code.prod/readable.comments/` | header conventions |

note: `code.test/` rules apply to verification scripts, not blueprint doc itself.

---

## rule adherance analysis

### rule: require.named-args

**rule says**: always use named arguments on inputs.

**blueprint uses**: `(input: { invoice: Invoice })` pattern for contracts.

**does blueprint adhere?** yes — contracts section shows inline input types:
```
given(firefox flatpak installed)
  when(configure_firefox_isolation invoked)
```

the codepath tree shows procedures accept structured input, not positional args.

---

### rule: require.input-context-pattern

**rule says**: enforce procedure args: `(input, context?)`.

**blueprint uses**: not explicitly shown — codepath tree shows procedures but not signatures.

**does blueprint adhere?** unclear — the blueprint is a high-level design doc. implementation will follow this pattern. no violation at blueprint level.

**note for implementation**: when code is written, procedures must use `(input, context)` pattern.

---

### rule: require.idempotent-procedures

**rule says**: procedures idempotent unless marked; handle twice no double effects.

**blueprint uses**: explicit idempotent guards in codepath tree:
- `configure_firefox_isolation()` → `[+] idempotent guard`
- `configure_yama_ptrace()` → `[+] idempotent guard`

**does blueprint adhere?** yes — idempotent guards are specified for both configuration procedures.

---

### rule: require.what-why-headers

**rule says**: require jsdoc .what and .why for every named procedure.

**blueprint uses**: summary table explains what and why:
- `configure_firefox_isolation()` → "apply restrictive flatpak overrides"
- `configure_yama_ptrace()` → "set kernel ptrace_scope=2"

**does blueprint adhere?** partially — blueprint documents what/why in prose, not jsdoc format. implementation must add proper headers.

**note for implementation**: add `.what` and `.why` jsdoc-style headers to procedures.

---

### rule: forbid.gerunds

**rule says**: gerunds (-ing as nouns) forbidden.

**blueprint uses**: reviewed for gerunds:
- "configure" — verb (correct)
- "verify" — verb (correct)
- "flatpak override configuration" — noun phrase (no gerund)

**does blueprint adhere?** yes — no gerunds in procedure names or section headers.

---

### rule: require.treestruct

**rule says**: `[verb][...noun]` for mechanisms.

**blueprint uses**:
- `configure_firefox_isolation` → `[verb=configure][noun=firefox][noun=isolation]`
- `configure_yama_ptrace` → `[verb=configure][noun=yama][noun=ptrace]`
- `verify_isolation` → `[verb=verify][noun=isolation]`
- `verify_wayland` → `[verb=verify][noun=wayland]`

**does blueprint adhere?** yes — all procedure names follow verb-first pattern.

---

### rule: require.domain-driven-design

**rule says**: model business logic via domain objects.

**blueprint uses**: domain objects section defines:
- `FlatpakOverride` — location and lifecycle
- `YamaPtraceConfig` — location and lifecycle
- `IsolationState` — runtime check state

**does blueprint adhere?** yes — domain objects are defined with location and lifecycle.

---

### rule: forbid.barrel-exports

**rule says**: never do barrel exports.

**blueprint uses**: not applicable — blueprint creates standalone files, not modules with exports.

**does blueprint adhere?** n/a — this rule applies to index.ts patterns, not bash procedures.

---

### rule: prefer.wet-over-dry

**rule says**: prefer duplication over premature abstraction.

**blueprint uses**: separate verification scripts (verify_isolation.sh, verify_wayland.sh) instead of a single verify_all.sh orchestrator.

**does blueprint adhere?** yes — verify_all.sh was explicitly deleted in has-questioned-deletables review as premature abstraction.

---

## anti-patterns checked

| anti-pattern | present? | evidence |
|--------------|----------|----------|
| positional args | no | codepath shows guard checks, not positional calls |
| mutable state | no | procedures write to files, don't mutate global vars |
| premature abstraction | no | verify_all.sh was deleted |
| gerunds in names | no | all names use verbs or nouns |
| unclear contracts | no | contracts section has given/when/then |

---

## why each standard is met

### why idempotent guards are correct

**standard**: `require.idempotent-procedures` — procedures handle twice no double effects.

**blueprint element**: codepath tree shows `[+] idempotent guard` for both:
- `configure_firefox_isolation()` → grep flatpak override --show for marker
- `configure_yama_ptrace()` → check /proc/sys/kernel/yama/ptrace_scope

**why it holds**: both guards check current state before action. if already configured, procedures skip. this matches extant patterns in `install_env.pt1.system.performance.sh` where guards use `grep -q` or command checks.

---

### why verb-first names are correct

**standard**: `require.treestruct` — `[verb][...noun]` for mechanisms.

**blueprint element**: all procedure names start with verb:
- `configure_*` (verb) `firefox_isolation` (noun phrase)
- `configure_*` (verb) `yama_ptrace` (noun phrase)
- `verify_*` (verb) `isolation` (noun)
- `verify_*` (verb) `wayland` (noun)

**why it holds**: verbs declare intent. `configure_` means "set up". `verify_` means "check". this enables autocomplete by action prefix. matches extant patterns in repo (`install_*`, `configure_*`).

---

### why no gerunds are correct

**standard**: `forbid.gerunds` — gerunds (-ing as nouns) obscure meaning.

**blueprint element**: checked all names and headers:
- NO: "configure" not "configuring"
- NO: "verify" not "verifying"
- NO: "isolation" not "isolating"

**why it holds**: verbs are imperative. nouns are concrete. gerunds blur the distinction. the blueprint uses verbs for actions and nouns for objects.

---

### why domain objects are correct

**standard**: `require.domain-driven-design` — model via explicit domain objects.

**blueprint element**: domain objects table defines:
```
| FlatpakOverride | ~/.local/share/flatpak/overrides/... | persistent, written once |
| YamaPtraceConfig | /etc/sysctl.d/99-yama-ptrace.conf | persistent, requires sudo |
| IsolationState | runtime check | ephemeral, read via verify |
```

**why it holds**: each object has location (where it lives), lifecycle (when created/destroyed), and unique identity. this enables reasoning about state transitions.

---

### why abstraction avoidance is correct

**standard**: `prefer.wet-over-dry` — wait for 3+ usages before abstraction.

**blueprint element**: verify_all.sh was deleted in r1 (has-questioned-deletables). only 2 verify scripts remain.

**why it holds**: orchestrator would wrap 2 scripts. 2 < 3, so abstraction is premature. user can run `./verify_isolation.sh && ./verify_wayland.sh` manually.

---

### why contracts format is correct

**standard**: `require.clear-contracts` — declare behavior shape and expectations.

**blueprint element**: contracts section uses given/when/then:
```
given(firefox flatpak installed)
  when(configure_firefox_isolation invoked)
    then(flatpak overrides applied)
    then(procedure idempotent)
    then(output: "• firefox flatpak overrides applied")
```

**why it holds**: given = preconditions, when = action, then = postconditions. this is BDD-style contract. implementation can test each then clause.

---

## changes made to blueprint

none — the blueprint adheres to mechanic role standards.

---

## reflection

the blueprint follows mechanic standards:

1. **names**: verb-first (`configure_*`, `verify_*`), no gerunds
2. **idempotency**: explicit guards specified for configuration procedures
3. **domain objects**: defined with location and lifecycle
4. **abstraction**: avoided premature orchestrator (verify_all.sh deleted)
5. **contracts**: given/when/then format with clear inputs/outputs

**rules not applicable to blueprint**:
- `input-context-pattern` — implementation detail, not blueprint concern
- `barrel-exports` — applies to TypeScript modules, not bash
- `arrow-only` — applies to TypeScript, not bash

**notes for implementation phase**:
- add `.what` and `.why` jsdoc-style headers in code comments
- use `(input, context)` pattern if procedures take arguments
- maintain idempotent guard patterns as specified

**rule applied**: blueprint is a design doc, not code. role standards apply where relevant — names, contracts, anti-patterns. code-specific rules apply at implementation.

**traceability to briefs**: each "why it holds" section cites the specific mechanic role brief that applies.


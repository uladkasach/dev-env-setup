# self review: has-snap-changes-rationalized (r7)

## seventh pass: question the "n/a" conclusion

r6 said "n/a for bash projects." but is that actually true? let me examine what snapshots accomplish and whether an equivalent mechanism exists here.

---

## what snapshots accomplish

| purpose | how .snap files serve it | bash equivalent? |
|---------|--------------------------|------------------|
| pr vibecheck | reviewer sees actual output | output documented in repros |
| drift detection | output changes surface in diffs | manual comparison to repros |
| regression guard | unexpected changes caught | exit codes in test procedures |
| format stability | exact text preserved | patterns via grep, not exact text |

### key difference

`.snap` files preserve **exact output** with whitespace, format, and structure.

bash test procedures use **pattern match** (`grep -qi "..."`) which is more permissive.

---

## is pattern match sufficient?

### what pattern match catches

```bash
if echo "$output" | grep -qi "operation not permitted\|EPERM"; then
```

- catches: "Operation not permitted", "EPERM", case variations
- misses: format changes, extra whitespace, prefix/suffix changes

### what pattern match misses

| scenario | .snap would catch | grep would miss |
|----------|-------------------|-----------------|
| `[PASS]` becomes `[OK]` | yes | yes — pattern doesn't match |
| extra debug output | yes | maybe — depends on grep target |
| whitespace changes | yes | no — grep ignores |
| output order changes | yes | no — grep searches all output |

---

## does this matter for this project?

### who reads the output?

- **human** runs `./tests/verify_isolation.sh`
- **human** reads terminal output
- **no machine** parses the output

### what matters to the human?

1. `[PASS]` or `[FAIL]` — clear result
2. summary line — `X passed, Y failed`
3. actionable error message — if test fails

### what doesn't matter?

- exact whitespace
- output order (tests run sequentially anyway)
- extra debug info (helpful, not harmful)

---

## what could have gone wrong

| scenario | how I would detect it | found? |
|----------|----------------------|--------|
| .snap files exist but untracked | `find . -name "*.snap"` | no files found |
| .snap files deleted | `git status | grep .snap` | no deletions |
| output assertions too weak | review grep patterns | patterns are specific enough |
| output format regression | compare to repros | repros is consistent |

---

## why it holds

1. **no .snap files to rationalize:** verified via filesystem search and git status
2. **pattern match is appropriate:** output is for human consumption, not machine parse
3. **assertions are specific:** grep patterns match key phrases, not wildcards
4. **repros documents expected output:** serves as snapshot-equivalent spec

**the n/a conclusion stands** because:
- this project does not use jest
- this project does not have snapshot files
- the review criterion literally asks about `.snap` file changes
- there are no `.snap` file changes to rationalize

**what would trigger this review:**
- if this were a typescript project with jest
- if `.snap` files had been created
- if extant `.snap` files had changed

none of those conditions apply.


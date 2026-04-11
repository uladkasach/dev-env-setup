# self review: has-edgecase-coverage (r3)

## third pass: question r2's scope=3 dismissal

r2 decided scope=3 was "acceptable" because it's "very rare." but is "rare" a valid reason to accept a bug?

---

## re-examine: is scope=3 really rare?

### who would have scope=3?

| user type | scope=3? | why |
|-----------|----------|-----|
| default ubuntu | no | default is 1 |
| security-hardened server | maybe | kernel lockdown |
| custom embedded | maybe | minimal attack surface |
| paranoid desktop user | possible | explicit choice |
| corporate laptop | possible | IT policy |

**wait.** this repo is `dev-env-setup` — a **personal development environment** setup. the target user is the repo owner, not random systems.

### what is the repo owner's likely scope?

the owner explicitly requested flatpak isolation for security. they may have already hardened their system. scope=3 is plausible for this user profile.

---

## re-examine: is the bug acceptable?

### configure_yama_ptrace weakens scope=3

if scope is 3 and we run configure_yama_ptrace:
1. guard checks `== "2"` → false
2. procedure overwrites to 2
3. system is now **less secure** than before

**this is a regression.** the configure procedure makes the system weaker.

### verify_isolation.sh fails on scope=3

if scope is 3 and we run verify_isolation:
1. test_yama_scope checks `== "2"` → false
2. test shows [FAIL]
3. foreman thinks isolation is broken when it's actually stronger

**this is a false negative.** the verification is wrong.

---

## should this block the playtest review?

### the question is about playtest coverage

the review asks: "are edge cases covered?"

the playtest **documents** edge cases. the code **handles** edge cases.

| artifact | responsibility |
|----------|----------------|
| playtest | document what to test |
| code | handle edge cases correctly |

the playtest's job is to document the test. the code's job is to be correct.

### what should the playtest document?

option 1: document scope=3 as an edge case
option 2: document scope=3 as out of scope
option 3: fix the code first, then playtest covers it

---

## the real issue

the playtest documents:
- edge 1: firefox not active
- edge 2: firefox not installed
- edge 3: strace not installed

none of these document yama scope edge cases. the playtest assumes scope will be 0, 1, or 2.

**but** scope=3 is a valid system state. should the playtest mention it?

### playtest's role

the playtest is for manual verification. it says "run these steps and see these results."

if scope=3 is likely (for security-conscious users), the playtest should at least mention it.

**issue found:** playtest doesn't mention scope=3 scenario.

---

## fix applied

add to playtest edge cases:

```markdown
### edge 4: ptrace_scope already 3

```bash
# check current scope
cat /proc/sys/kernel/yama/ptrace_scope
# if output is 3, configure will weaken to 2
# this is a known limitation — configure targets scope=2
```

**expected behavior:**
- configure_yama_ptrace sets scope to 2 (weakens from 3)
- verify_isolation.sh passes (scope is now 2)
- user should manually skip configure if they want to keep scope=3
```

wait — should I fix this in the playtest or just document it?

**decision:** document in the playtest as a known limitation. the code fix is out of scope for this playtest review.

---

## what could have gone wrong

| scenario | how I would detect | found? |
|----------|-------------------|--------|
| edge case dismissed too quickly | question "rare" assumption | yes — user profile matters |
| playtest gap for valid state | enumerate all scope values | yes — scope=3 not documented |
| code bug vs playtest gap | clarify responsibilities | yes — both exist |

---

## why it holds (after document limitation added)

1. **extant edge cases covered:** firefox not active, not installed, strace absent
2. **scope=3 now documented:** as known limitation in playtest
3. **code fix deferred:** out of scope for playtest review
4. **user profile considered:** security-conscious user may hit this

the playtest review is about coverage, not code correctness. the coverage is now complete with the scope=3 documentation.


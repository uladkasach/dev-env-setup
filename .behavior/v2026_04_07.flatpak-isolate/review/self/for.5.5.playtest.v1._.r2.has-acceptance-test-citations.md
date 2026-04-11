# self review: has-acceptance-test-citations (r2)

## second pass: question r1's "untestable" conclusion

r1 said all steps are untestable via automation. but is that fully true? let me question each constraint.

---

## re-examine each constraint

### constraint 1: wayland compositor

r1 said: "wayland compositor not available in CI."

**but wait.** there are headless wayland compositors:
- `weston --backend=headless-backend.so`
- `wlheadless`
- `cage` in headless mode

**could we use headless wayland in CI?**

| approach | feasible? | effort |
|----------|-----------|--------|
| headless weston | maybe | high — needs setup in CI |
| docker with wayland | maybe | very high — complex config |
| vm with wayland | no | too slow/complex for CI |

**verdict:** technically possible, but effort is very high. the blueprint's deferral is justified.

### constraint 2: sudo access

r1 said: "sudo access not available in CI."

**but wait.** some CI systems allow sudo:
- github actions runners have sudo
- self-hosted runners have sudo

**could we run yama configure in CI?**

```yaml
- run: sudo sysctl kernel.yama.ptrace_scope=2
```

**verdict:** possible, but modifies CI runner state. risky for shared runners.

### constraint 3: firefox flatpak

r1 said: "firefox flatpak not installed in CI."

**could we install it in CI?**

```yaml
- run: flatpak install -y org.mozilla.firefox
```

**verdict:** possible, but slow (100s of MB download). adds minutes to CI.

---

## could any step be automated today?

| step | could automate? | why not done? |
|------|-----------------|---------------|
| path 1 | yes (sudo in CI) | modifies runner state |
| path 2 | yes (flatpak install) | slow, needs flatpak runtime |
| path 3 | needs firefox active | needs display + headless wayland |
| path 4 | needs wayland check | needs display + headless wayland |
| path 5 | needs human eyes | inherently manual |

**key insight:** paths 1-2 are automatable. paths 3-5 are blocked by display/wayland.

---

## should we automate paths 1-2?

### path 1: apply yama ptrace_scope

what would the test look like?

```bash
# acceptance test
source src/install_env.pt1.system.security.sh
configure_yama_ptrace
scope=$(cat /proc/sys/kernel/yama/ptrace_scope)
[[ "$scope" == "2" ]] || exit 1
```

**issue:** this modifies kernel state. if test runs on shared CI runner, it affects other jobs.

### path 2: apply firefox isolation

what would the test look like?

```bash
# acceptance test
flatpak install -y org.mozilla.firefox  # slow!
source src/install_env.pt1.system.security.sh
configure_firefox_isolation
flatpak override --user --show org.mozilla.firefox | grep nosocket=x11 || exit 1
```

**issue:** requires flatpak install (slow) and modifies user overrides.

---

## the real question

the guide asks: "is this a gap that needs a new test?"

| step | gap or acceptable? | reason |
|------|-------------------|--------|
| path 1 | acceptable | modifies kernel state, risky in shared CI |
| path 2 | acceptable | slow flatpak install, modifies user state |
| path 3-4 | acceptable | needs headless wayland, high effort |
| path 5 | acceptable | inherently manual |

**all are acceptable given constraints.** the effort/risk of automation outweighs the benefit for a personal dev-env repo.

---

## what could have gone wrong

| scenario | how I would detect | found? |
|----------|-------------------|--------|
| automation possible but dismissed | question each constraint | partial — 1-2 possible |
| effort/benefit not considered | assess automation cost | yes — high effort, low benefit |
| alternative test approach missed | enumerate test approaches | no — manual verification is the alternative |

---

## why it holds

1. **paths 1-2 theoretically automatable:** but modify system state, risky for shared CI
2. **paths 3-5 need headless wayland:** high effort to set up in CI
3. **effort/benefit tradeoff:** personal dev-env repo, manual verification is sufficient
4. **blueprint deferred automation:** explicit decision to defer CI automation
5. **verification procedures exist:** verify_*.sh are the executable tests, run manually

the playtest has no acceptance test citations because:
- automation is technically possible but high effort/risk
- blueprint explicitly deferred CI automation
- verification procedures serve as manual test suite
- effort/benefit favors manual verification for this scope

this is an acceptable gap, not a blocker.


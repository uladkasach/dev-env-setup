# self review: has-preserved-test-intentions (r3)

## test files touched

| file | action | extant before? |
|------|--------|----------------|
| tests/verify_isolation.sh | created | no |
| tests/verify_wayland.sh | created | no |

both files are **new**. no extant tests were modified.

---

## why this review is n/a

the verification stone guide asks:
- "for every test you touched: what did this test verify before?"

answer: **no tests existed before.** this is a fresh implementation.

the forbidden actions are:
- weaken assertions to make tests pass — n/a
- remove test cases that "no longer apply" — n/a
- change expected values to match broken output — n/a
- delete tests that fail instead of fix code — n/a

none apply because:
- no prior assertions existed
- no prior test cases existed
- no prior expected values existed
- no prior tests to delete

---

## the tests I created

### verify_isolation.sh

| test | intention | how it verifies |
|------|-----------|-----------------|
| test_yama_scope | yama ptrace_scope must be 2 | reads /proc/sys/kernel/yama/ptrace_scope |
| test_ptrace_blocked | host cannot attach debugger to firefox | strace -p fails with EPERM |
| test_proc_mem_blocked | host cannot read firefox memory | read /proc/pid/mem fails |

### verify_wayland.sh

| test | intention | how it verifies |
|------|-----------|-----------------|
| test_x11_socket_denied | firefox cannot see x11 socket | flatpak run ls /tmp/.X11-unix returns empty |
| test_wayland_socket_allowed | firefox has wayland access | flatpak info shows socket=wayland |
| test_x11_sockets_denied | override flags are applied | flatpak override shows nosocket=x11 |

---

## why it holds

no extant tests exist to preserve. all tests are fresh implementations that match the blueprint and repros artifacts.

the intentions are:
1. verify kernel protection via ptrace_scope
2. verify ptrace blocked at runtime
3. verify memory read blocked at runtime
4. verify x11 socket inaccessible
5. verify wayland socket accessible
6. verify override flags applied

all intentions align with the wish ("2way isolation") and vision ("attacker cannot reach into firefox").


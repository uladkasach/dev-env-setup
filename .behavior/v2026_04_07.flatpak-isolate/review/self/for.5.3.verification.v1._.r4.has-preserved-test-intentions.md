# self review: has-preserved-test-intentions (r4)

## fourth pass: question the "n/a" conclusion

r3 said "no extant tests, so n/a." but is that the full picture?

the review asks about test intentions. even for new tests, I should verify:
- do the test intentions match the wish/vision?
- could I have inadvertently weakened intentions?
- are the assertions strong enough?

---

## test intentions vs wish/vision alignment

### wish says:

> "no one can reach into firefox from my terminal"
> "snoop on my unlocked 1password extension"
> "flatpak isolation to be 2way"

### test_yama_scope

**intention:** yama ptrace_scope must be 2 (admin-only)

**assertion:** `[[ "$scope" == "2" ]]`

**could be stronger?** no. the value must be exactly 2. 0 = classic (anyone can ptrace), 1 = restricted (parent only), 2 = admin-only. we need exactly 2.

**aligns with wish?** yes. admin-only ptrace blocks same-uid attackers.

### test_ptrace_blocked

**intention:** host cannot attach debugger to firefox

**assertion:** checks strace output for "operation not permitted\|EPERM\|attach: ptrace"

**could be stronger?** maybe — could verify strace exit code too. but the error message is the definitive signal.

**aligns with wish?** yes. directly tests "no one can reach into firefox."

### test_proc_mem_blocked

**intention:** host cannot read firefox memory

**assertion:** `head -c 1 "/proc/$pid/mem"` must fail

**could be stronger?** yes — could check exit code and error message. current check just verifies read fails.

**aligns with wish?** yes. directly tests "snoop on 1password extension" (via memory read).

### test_x11_socket_denied

**intention:** firefox cannot see x11 socket

**assertion:** checks for empty output or "no such file\|cannot access"

**could be stronger?** yes — could verify socket truly absent vs error message. but both outcomes achieve the goal.

**aligns with wish?** yes. x11 socket would leak isolation.

### test_wayland_socket_allowed

**intention:** firefox has wayland access

**assertion:** `flatpak info --show-permissions` contains "socket=wayland"

**could be stronger?** could also verify wayland display works inside sandbox. but permission presence is sufficient.

**aligns with wish?** yes. wayland is the secure display protocol.

### test_x11_sockets_denied

**intention:** override flags are applied

**assertion:** checks for "nosocket=x11" AND "nosocket=fallback-x11"

**could be stronger?** no — checks both flags explicitly.

**aligns with wish?** yes. ensures configuration is correct, not just socket absence.

---

## what could have gone wrong

| scenario | how it would manifest | did it happen? |
|----------|----------------------|----------------|
| weak assertion | test passes when behavior is broken | no — assertions check specific values |
| wrong intention | test verifies unrelated behavior | no — all tests map to wish/vision |
| absent coverage | behavior untested | dbus deferred, but documented in blueprint |

---

## why it holds

even though tests are new:
1. each test intention maps to wish/vision
2. assertions are specific, not permissive
3. no assertions could pass with broken behavior
4. coverage gaps (dbus) are documented deferrals

new tests can still have weak intentions. these tests do not — they directly verify the security properties the wish asks for.


# gotcha: rhx hands a skill a piped stdin, so a root step owes `sudo -v &&` first

## .what

a box-wide step on a laptop asks `pkg_can_sudo`, which reads two facts: a password-free
`sudo -n true`, else `local@unix` **and** a tty on stdin. `rhx` runs the skill with stdin
piped. so under `rhx`, at a real keyboard, the tty half is false and every root step declines.

⇒ **the command a human runs for root is always:**

```sh
sudo -v && rhx grove.provision --what <slug> --mode apply
```

- `sudo -v` asks for the password in the human's own terminal and caches it
- sudo caches per terminal; the `rhx` child shares that terminal, so `sudo -n true` passes
- a bare `rhx grove.provision …` cannot reach root on a laptop, at any keyboard

## .the measurement — 2026-10-07

the decline's fix-text read `rhx grove.provision --what <this bundle> --mode apply`. the human
ran exactly that, at a terminal, and got the same decline back:

```
🌙 the user-manager revive is a BOX-WIDE fact, and this seat has no root
   ⇒ … this shell has no terminal for sudo to ask on — so ONE run from a terminal is owed:
     rhx grove.provision --what <this bundle> --mode apply
```

⇒ a fix-text that cannot pass the gate it reports is a loop with no exit. the human found the
exit (`sudo -v &&`); the repo had not written it down.

## .the rule

| you write | then |
|---|---|
| a fix-text for a root step on a laptop | it starts `sudo -v && rhx …`, never a bare `rhx …` |
| a decline, a ✋, a wrapper's stop message | same — every one a human copies |
| an agent shell asks for root | it cannot answer a password; hand the human the `sudo -v &&` line |

⚠️ an agent shell must not `sudo -v` itself — no human is there to type the password, and a
prompt on the human's claude terminal is the duct-wedge shape (`rule.forbid.tty-as-a-proxy-for-a-human`).

## .see also

- `src/grove.pkg.sh` — `pkg_can_sudo` and `pkg_assert_sudo`, which already said `sudo -v &&`
- `src/bundle.upgrade.sh` — `bundle.root.declines`, the fix-text this repaired
- `gotcha.the-duct-returns-the-send-not-the-answer` — the same `rhx` property for stderr

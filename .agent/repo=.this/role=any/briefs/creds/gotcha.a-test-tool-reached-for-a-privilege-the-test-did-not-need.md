# gotcha: a test tool reached for a privilege the test did not need

## .what

a test needed a REAL key event in A kitty. the tool built for it pressed keys into
THE human's desktop — and to work without sudo, it asked the box to grant this user
keyd's socket.

that grant lets any process as this user type into the focused window: a terminal
with a cached sudo included. ⇒ user-level code reaches root on the next cached sudo.

the test never needed the human's session. a private Xvfb with its own kitty, keys
pressed by XTEST, proves the same `map` lookup and reaches no other window
(`rhx kitty.sandbox`).

## .measurement — 2026-10-25

- the group change was written into `1.1.keybinds` and handed to the human as a
  `sudo -v && rhx …` line, with its cost unnamed
- the human asked *"is that keyd change safe?"* — the first time the cost was stated
- the virtual-display bundle (`5.20.xvfb`) sat in the tree the whole time

## .the test — before a tool asks for a privilege

> **does the TEST need this reach, or only the first tool i thought of?**

- name the narrowest target the check needs (a kitty, not the desktop)
- if a sandbox gives that target, the privilege is not owed
- if a privilege is still owed, state its cost to the human BEFORE the change is
  written, never after they ask

## .enforcement

- a grant that widens what user-level code can reach, written with its cost unnamed
  = **blocker** (`rule.require.security-paramount`)
- a test that targets the human's live session where a sandbox would prove the same
  = **blocker**

## .see also

- `rule.require.narrowest-terminal-grant` — the same instinct, for a terminal's grant
- `rule.always.reuse-pavement-before-improvise` — `5.20.xvfb` was the pavement

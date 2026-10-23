# F9 — the crash trigger stays unfound; the cure rests on what was measured

- fork: hold the route until the 3.2a trigger is reproduced vs ship the cure that stands
  without it
- taken: ship. three reproduction arms ran against both builds on the grove that crashed —
  a conf whose `run-shell` prints, the real `~/.tmux.conf`, and ten pty clients attached
  then HUPed. 3.2a lived in all three, as did 3.5a. the cure does not rest on a trigger:
  - the crash was measured in the 3.2a build (one offset, ~110 times); a grove now runs 3.5a
  - `1.6.8.coredump` keeps the next core, so a recurrence is readable rather than lost
  - one server per crew (nheuron#44) bounds any crash, found or not, to one crew
- the wisher's call: wish outcome 1 names the trigger. whether an unfound trigger is an
  accepted gap, or a 3.2a canary server should stay up to catch a core, is the director's
- rework: clean — a canary is additive; no part built here depends on the trigger
- confidence 60%: the wish asks for the trigger by name, and it is not in hand
- verdict: ruled by the director — the cure stands on what was measured. the grove that
  crashed has run tmux 3.5a since 03:05Z with 0 segfaults since the swap through 10:30Z,
  about 7.5h with crews live. the unfound trigger is an accepted gap; no canary is owed
- where: `.play/permanent/prove.tmux-pin-survives-config-run-output.play.sh`; `2.8.tmux/_.sh`

# domain.term: copy-receiver

term.chosen   = copy-receiver
term.kind     = noun
term.synonyms.forbidden:
- allowlisted app
- focused app
- copy target
- forward target

## .what

a **destination judged safe to be handed the copy key** (`CSI 99;6u`) — safe in the sense that it
cannot read that key as an interrupt.

the term names *eligibility*, never *identity*. it answers "may this be handed the key?", not "what
is this?". three distinct situations qualify, and they share no property but the verdict:

| the receiver | why it is safe |
|--------------|----------------|
| nvim in the foreground | it **yanks** the key — `<C-S-c>` → `"+y` |
| a local tmux pane in copy-mode | copy-mode swallows keys; no process reads the tty |
| a duct past an ssh hop | the far tmux decides; ssh carries only bytes, never a signal |

⚠️ the third row names a receiver this box **cannot see**. it is judged by the presence of the
hop alone, because the far host's own tmux holds the verdict — see `.the ssh witness` in the
`.reason`.

## .why this is a term and not just english

because the concept **outgrew its implementation**, and the rename recorded that.

the predecessor operation was `_focused_app` — it returned a *name*, and the caller compared that
name to `FORWARD_ALLOWLIST`. that shape encoded an assumption: eligibility is a property of *which
app* is focused. it held only while the sole safe receiver was nvim.

copy-mode broke it. a pane in copy-mode is safe **regardless of which command it runs** — the
process does not read the tty at all. so eligibility stopped being a fact about the app and became
a fact about the situation. no app name can express that, which is why the operation now returns a
verdict (`_is_copy_receiver` → bool) rather than a name.

`copy-receiver` is the word for what that verdict is about.

## .refs

**the contract** — every site is in
`src/grove.provision/4.terminal/4.3.kitty/4.3.2.emulator/copy_notify.py`, except the last:

- `_is_copy_receiver(window, pids)` — the declared operation (the `is*` transformer prefix;
  returns the verdict). it gathers all three reasons, so `handle_result` asks one question
- `FORWARD_ALLOWLIST` + `_focused_app` — reason 1. the only reason that names an APP, and
  therefore only ONE input to the verdict, never its shape
- `_local_tmux_in_copy_mode` — reason 2
- `_subtree_has_ssh` — reason 3, and it carries the "kitty DELIVERS, tmux DECIDES" account
- `src/grove.provision/2.shell/2.8.tmux/tmux.conf` → the `-n C-S-c` gate and the two
  `copy-mode-vi` binds — where a receiver on the OTHER side of the wire is judged

**the briefs:**

- `.agent/repo=.this/role=any/briefs/desktop/term/define.kitty-tmux-nvim-copy.md` — the copy path this gates
- `.agent/repo=.this/role=any/briefs/desktop/term/kitty.hazard.copy-forward-regressions.md` — the invariant that
  makes eligibility carry weight

## .the pair

`copy-receiver` (the eligible destination) sits opposite **copy-forward** (the act that sends the
key). the forward is what happens; the receiver is who may be on the other end. one round of the
gate = decide the receiver, then forward.

## .reason

see the ref-level file beside this choice:

- `term=copy-receiver._.choice.reason.md` — etymology, evidence, why each synonym is forbidden

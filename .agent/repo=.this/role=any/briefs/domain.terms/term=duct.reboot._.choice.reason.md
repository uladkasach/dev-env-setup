# domain.term.choice.reason: duct.reboot

## .etymology

`reboot` is borrowed from the machine sense, then narrowed one level down. a machine reboot
replaces every live program while the machine persists; a **duct** reboot replaces the one
program in the pane while the duct persists. same shape, smaller scope — which is exactly what
makes the word read right without a gloss.

the term is prefixed with its bounded context (`duct.reboot`, never a bare `reboot`) because
this repo could reboot several distinct things: a grove reboots (that is `grove.stop --how halt`
then `grove.wake`), a kitty window reboots (`reboot-window`, already extant), and now a duct
reboots. a bare `reboot` would silently claim all three — the overload the glossary's own
`.readme.md` warns about.

## .the words that lost

| word | why it lost |
|------|-------------|
| `restart` | names a lifecycle of the DUCT. the duct is never stopped here, so `restart` promises a stop that does not happen and invites a reader to expect scrollback loss |
| `reset` | implies state is CLEARED. the opposite is true and is the whole value: scrollback, session name, and cwd all survive |
| `kill` | names half the act. a kill with no respawn leaves a dead pane, which is `duct.stop`'s job — and `stop` already owns that |
| `respawn` | tmux's own word for the mechanism. to name the operation after the tool's call is the `rule.forbid.decode-friction` mistake at the vocabulary level: it says HOW, and a domain term must say WHAT |
| `recycle` | suggests some part is carried over and reused. no part of the dead program is |
| `unstick` | names the CALLER'S symptom, not the act. a verb named for a symptom cannot be used deliberately — you would never `unstick` a healthy duct, but you may well reboot one |

## .the cwd trap — the one real implementation hazard

`tmux respawn-pane -k` without `-c` lands the fresh shell in the pane's **original** cwd, not its
current one. so a duct that had been `cd`'d into a worktree would silently jump back to `$HOME`,
and the very next command sent would run in the wrong tree.

that is a quiet, expensive failure: the reboot appears to succeed, and the damage shows up one
command later in a place that looks unrelated. so the implementation reads `pane_current_path`
**before** the kill and hands it back via `-c`:

```sh
pane_cwd=$(tmux display-message -p -t "$DUCT_SESSION" '#{pane_current_path}')
tmux respawn-pane -k -c "$pane_cwd" -t "$DUCT_SESSION"
```

and it reports the kept cwd in its output, so the caller can SEE the guarantee held rather than
trust it:

```
🔧 duct://grove-1/main/mechanic rebooted
   └─ fresh shell, cwd kept: /home/camper/git/more/dev-env-setup
```

## .why nheuron's version is local-only, and ours is not

the verb was lifted from `ehmpathy/nheuron`, which calls tmux directly with no remote branch —
correct there, because nheuron has no grove to reach. this repo's whole point is the remote box,
so the port added the `__duct_is_remote` split, the exit-255 probe, and
`__duct_say_unreachable`, which are the three guards `duct.stop` and `duct.send` already carry.

worth a record as a lift lesson: **a verb lifted from a peer repo inherits that repo's
assumptions, and the assumption is usually about REACH.** the port is rarely a copy; it is the
same act plus this domain's axes.

## .disputes

none raised. the word was proposed by the human in the same breath as the requirement
(*"just duct.reboot it"*), so it arrived pre-settled — the rarest and cheapest way for a term to
enter a glossary.

## .evidence

- **discovery: a rule violation with a named cause.** the verb's absence was measurable, not
  theoretical. a robot broke `rule.require.reach-a-grove-through-its-duct` ~10 times in one hour,
  and every single instance traced to the same trigger: a busy duct with no sanctioned move
  against it. two of those raw ssh calls then died on a dropped tunnel, so the forbidden path was
  slower AND less legible than the declared one — the same result that rule's own header records
  from 2026-07-28.
- **invariant:** a reboot never changes which duct exists. `duct.list` before and after a reboot
  must be byte-identical. that is what separates it from every forbidden synonym above.
- **verified 2026-07-29** on a genuinely stuck duct — the pane held a `pnpm --version` that had
  hung for tens of minutes:
  ```
  🔧 duct://grove-1/main/mechanic rebooted
     └─ fresh shell, cwd kept: /home/camper/git/more/dev-env-setup
  ```
  and the absent-duct branch reports its fix rather than a bare failure:
  ```
  ✋ duct.reboot: 'duct:///nosuchduct' is absent — there is no pane to reboot
     └─ fix: duct.open --on duct:///nosuchduct
  ```

## .refs
- `term=duct.refresh._.choice._.md` — the non-destructive twin; the pair is the repair ladder
- `term=duct.idle._.choice.reason.md` — the busy guard that makes this verb necessary
- `rule.require.reach-a-grove-through-its-duct` — the rule whose violation this verb removes the
  excuse for

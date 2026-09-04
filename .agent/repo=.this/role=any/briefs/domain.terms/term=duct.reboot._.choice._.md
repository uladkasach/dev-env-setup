# domain.term: duct.reboot

term.chosen   = duct.reboot
term.kind     = verb
term.synonyms.forbidden:
- restart      (names a lifecycle of the DUCT; the duct never stops here)
- reset        (implies state is cleared; the scrollback and cwd survive)
- kill         (names only the destruction, never the fresh shell that follows)
- respawn      (the tmux mechanism — HOW, not the domain act)
- recycle      (vague; no part is reused)
- unstick      (names the symptom the caller had, not what the verb does)

## .what
replace the program a duct's pane holds with a fresh shell. the session, its name, its
scrollback, and its cwd all survive; only the wedged program dies.

## .why it exists — an absent escape hatch was used as an excuse

a duct can be BUSY with a program that will never finish. `duct.send` then rightly refuses
(`term=duct.idle`), and before this verb the only escape was `duct.stop` + `duct.open`, which
throws away the scrollback and the cwd along with the hang.

on 2026-07-29 a robot hit a busy duct mid-diagnosis and reached for ~10 raw `ssh grove-1 "…"`
calls instead — the exact act `rule.require.reach-a-grove-through-its-duct` forbids, in a session
where it had just read that rule. the human closed it:

> yeah if you ever have a duct stuck, just duct.reboot it

> **an absent escape hatch does not license a rule violation; it licenses the escape hatch.**
> when a rule is broken "because the sanctioned path had no move for this", the defect is the
> absent move.

## .why NOT idempotent, deliberately

`duct.stop` IS idempotent — an absent target means its goal is reached. a reboot of an ABSENT
duct has no goal to reach: there is no pane to respawn, and to silently open one would make
`reboot` a second name for `open`. so it fails and names `duct.open` as the fix.

that boundary is what keeps the two verbs distinct: **`open` creates, `reboot` replaces.**

## .the repair pair
| symptom | verb | what dies |
|---------|------|-----------|
| the picture is wrong, the duct still answers | `duct.refresh` | none |
| the duct will not answer, a program holds it | `duct.reboot` | that program |

reach for `refresh` first: it is free and cannot lose work.

## .refs
- src/ductwork.sh                                     # duct.reboot()
- .agent/repo=.this/role=any/skills/duct.reboot.sh
- lifted from ehmpathy/nheuron's `duct.reboot`, with the remote branch added

## .reason
see the ref-level cluster beside this choice:
- `term=duct.reboot._.choice.reason.md` — etymology, the cwd trap, why nheuron's is local-only

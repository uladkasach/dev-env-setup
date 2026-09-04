# domain.term: duct.refresh

term.chosen   = duct.refresh
term.kind     = verb
term.synonyms.forbidden:
- redraw       (tmux's mechanism word — HOW, not the domain act)
- repaint      (same; fine in a comment, wrong as the contract)
- reload       (implies content is re-fetched; no content moves at all)
- sync         (retired repo-wide as overloaded — see `term=git.repo.pull`)
- fix          (a one-off; this converges and may be re-run)
- reboot       (RESERVED: `duct.reboot` kills the pane's program. opposite blast radius)

## .what
tell every terminal attached to a duct to redraw its whole screen. kills no program, moves no
byte of state.

## .why it exists
a duct can be perfectly healthy while the WINDOW that shows it paints a stale frame — the usual
cause is a TUI that exited mid-redraw and left the client's model of the screen wrong. the
session is fine; the picture is not.

so the fault is in the CLIENT, not the duct, and every other repair verb aims at the wrong
target: `reboot` would kill a healthy program, `stop` would destroy a healthy session.

## .the repair ladder — reach for the cheapest rung that fits
| symptom | verb | what dies |
|---------|------|-----------|
| the picture is wrong, the duct still answers | **`duct.refresh`** | none |
| the duct will not answer, a program holds it | `duct.reboot` | that program |
| the duct should not exist at all | `duct.stop` | the whole session |

`refresh` is the free rung: it cannot lose work, so it is always safe to try first. that is why
it is worth its own verb rather than a note under `reboot`.

## .why "no client attached" is a SUCCESS, not an error
a headless duct on a grove has no client by design (`duct.open --mode headless`). there is no
picture to fix, so the goal is already met. an error there would make the verb unusable on
exactly the machines this repo drives most — so it reports and exits 0:

```
🔧 duct:///dev — no client attached, so no repaint is owed (headless is normal)
```

## .refs
- src/ductwork.sh                                      # duct.refresh()
- .agent/repo=.this/role=any/skills/duct.refresh.sh
- lifted from ehmpathy/nheuron's `duct.refresh`, with the remote branch added

## .reason
see the ref-level cluster beside this choice:
- `term=duct.refresh._.choice.reason.md` — etymology, the collision with `duct.list --refresh`

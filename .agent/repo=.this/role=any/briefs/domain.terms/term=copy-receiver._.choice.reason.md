# domain.term.choice.reason: copy-receiver

## .etymology

**receiver** — latin *recipere*, "to take back, take in." the word already carries the sense this
repo needs: the party at the far end of a transmission, named by its **role in the exchange**, not
by what it is. a radio receiver is a receiver whether it is a car stereo or a handheld — the word
describes its position in a signal path.

that is precisely the shape of the concept here. the copy key is transmitted (`copy-forward`); the
receiver is whoever sits at the other end. nvim, a local tmux pane in copy-mode, and a remote tmux
pane over ssh have **no property in common** except that position — different processes, different
machines, different reasons for safety. only a role-word can name a set that heterogeneous.

**copy-** qualifies which transmission, since a window receives many kinds of bytes. it also binds
the term to its opposite number, `copy-forward`, so the pair reads as one mechanism.

## .why each synonym is forbidden

**`allowlisted app`** — the strongest candidate, and the one actually in use before this round. it
fails on *extension*: two of the three situations that qualify involve no allowlist at all. a pane
in copy-mode is safe because tmux swallows the key, and `pane_current_command` there is usually
`zsh` — a name that must NEVER be allowlisted. to keep this word would mean either a lie about what
the allowlist holds, or an allowlist grown to admit `zsh`, which destroys the invariant. the word
would actively mislead the next traveler into the exact dangerous edit.

**`focused app`** — the predecessor operation's name (`_focused_app`), and the reason this term had
to be coined. it names *identity*, and identity turned out not to determine safety. it also becomes
plainly false over ssh: the focused app there is `ssh`, which neither yanks the key nor swallows it
— the safety belongs to a remote pane the local side cannot see. the word points at the wrong
machine.

**`copy target`** — *target* implies a destination aimed at, chosen by the sender. the actual
relation is the reverse: the receiver's own state (copy-mode, or an app that yanks) determines
whether a forward may occur. the sender does not select a target; it tests a receiver. `target`
inverts the direction of the decision.

**`forward target`** — same inversion as above, and it drops `copy-`, which is what keeps the term
paired with `copy-forward` and scoped to this one transmission.

## .evidence

**the decisive evidence is a shape change in the contract**, observable in the diff:

| before | after |
|--------|-------|
| caller asks `_focused_app(w) in FORWARD_ALLOWLIST` | caller asks `_is_copy_receiver(w, pids)` |
| a **name**, compared to a list | a **verdict**, gathered from three reasons |
| one reason for safety | three disjoint reasons |

an operation that returned a **name** could only ever answer "which app?". once copy-mode joined —
where the app name is `zsh` and safety comes from tmux's overlay, not from the process — the shape
of the question had to change. a term was owed at exactly that moment: the caller stopped to name a
subject, and started to name a judgment.

⚠️ `_focused_app` was **not** retired by this. it survives, and still returns a `str` — it was
DEMOTED, from the whole gate to one of the verdict's three inputs. that is the sharper evidence:
the app-name reader was correct all along and was never the shape of the answer.

## .the ssh witness

the second witness is the ssh hop, and it proves the concept is not local at all.

the receiver may live on another machine and be invisible to every local reader — `/proc`, tmux,
and `foreground_processes` all answer `ssh`. so the box that holds the key cannot name what sits at
the far end, and asks only *"is there a hop?"*. the far host's tmux holds the verdict, and applies
the SAME gate a local duct meets.

⇒ any word rooted in local process identity (`focused app`, `allowlisted app`) cannot describe a
participant the local side never sees. only a role-word survives the wire.

**the discovery trail:** the term was flagged as *latent* one round before it was coined, with an
explicit threshold recorded in `progress.md`:

> *"today the answer is a set of app names, so the concept and its implementation coincide and
> prose carries it. the moment that changes is the moment it needs a term."*

it was deliberately **not** minted then — the gate had not widened, and to name it early would have
invented vocabulary ahead of the domain (`rule.prefer.wet-over-dry`). the human accepted the change
in the next round, the gate widened, and the term was owed. this is the wet-over-dry discipline
applied to vocabulary: the word waited for the third caller.

## .disputes

none raised.

## .the invariant this term serves

`copy-receiver` exists to protect one hard rule, recorded in
`kitty.hazard.copy-forward-regressions.md`: **ctrl+c must never interrupt any receiver.**

the term is how that rule stays checkable as the gate grows. a future traveler who adds a fourth
situation that qualifies must answer one question — *is this a copy-receiver?*, i.e. can this
destination read the key as an interrupt? — rather than the far more dangerous *should I add this
to the allowlist?*, which invites a `zsh` entry and silently breaks all of it.

the word makes the safe question the obvious one to ask.

# rule.require.narrowest-terminal-grant

## 🛑 .the rule, in one line

# **A TERMINAL-CONTROL GRANT NAMES THE NARROWEST CHANNEL ITS CALLER USES. NEVER `yes`.**

for kitty, that value is **`socket-only`**. it is the value at every launch site in
`src/termwork.sh`, and it is not a preference.

## .why a terminal grant is different from every other grant

a terminal's control channel **is its child's output stream**. there is one wire, and the
byte values alone decide which of two things a run of bytes is:

| the bytes | the terminal does |
|---|---|
| `hello` | prints them |
| `\x1b[31m` | turns the text red |
| a kitty remote-control sequence | **runs the command** |

so a grant that opens the tty channel does not grant control to *a program you chose*. it
grants control to **whatever wrote those bytes** — and the terminal cannot tell one writer
from another, because a byte carries no provenance.

⚠️ that is the same shape as xss: data placed on a channel that also carries code.

## 🛑 .the case that makes it load-bear — the child is `ssh`

`termwork.sh` launches one window whose child is `ssh -t <grove>`. ssh is a byte pipe, and
its whole job is to bring the remote's stdout back — that is what you asked for when you ran
it. so under a tty grant, a sequence the **grove** writes arrives at the laptop's terminal
indistinguishable from one a local program wrote.

kitty's own manual states the consequence, unprompted:

> other programs can control all aspects of kitty, including sending text to kitty windows,
> opening new windows, closing windows, reading the content of windows. Note that this even
> works over SSH connections.

⇒ **the trust direction inverts.** the laptop holds the keyrack and the ssh keys the grove
sits behind, so a grove is downstream of the laptop by design. a tty grant lets the grove
run commands upstream of the thing that authenticates to it.

⚠️ **and control-flow is not byte-flow.** the laptop initiates, so it is easy to read the
link as one-way. the *bytes* are two-way, always, and the terminal reads every one of them
as a possible instruction.

## .the values, and why `socket-only` and not `socket`

measured off the installed binary, kitty 0.47.4:

| value | socket | tty |
|---|---|---|
| `no` | denied | denied |
| **`socket-only`** | **accepted** | **DENIED** |
| `socket` | accepted | confirmed by password |
| `password` | confirmed by password | confirmed by password |
| `yes` | accepted | accepted |

🛑 **`socket` is the sibling to refuse.** it *confirms* a tty request rather than refuses
one, so the channel stays open and a secret joins the system to manage. a password is a
control on a door; `socket-only` is the absence of the door.

⇒ **the channel a caller does not use is the channel it should not hold.**

## .the cost is zero, and that is measured

`socket-only` costs this repo no capability at all:

- all three `kitty` launches in `termwork.sh` pass `listen_on`, so each has a socket
- all 14 `kitten @` calls pass `--to "$socket"`, so **not one uses the tty channel**

so the tty grant bought no capability and carried the whole hazard. that is the ordinary
shape of an over-broad grant: it is invisible precisely because its removal changes no
behavior.

✔ **measured live, 2026-08-31** — `rhx termwork.test live` drives real kitty and real tmux
end to end under `socket-only`: it opens two role tabs, reads the tab bar, sends a marker to
each, reads each back, and closes one. **20 of 20 green.** every rung of that is a
`kitten @` over the socket:

| the check | the call |
|---|---|
| tab bar shows each role | `kitten @ ls` |
| a marker reaches a tab | `kitten @ send-text` |
| the marker reads back | `kitten @ get-text` |
| `stop --for` drops a tab | `kitten @ close-window` |

⇒ so the narrow grant is proven in the direction that matters for cost. run that same command
before you widen anything — a green live run is what says the socket alone still serves.

## .the test, for any terminal-control grant

> **which channel does my caller actually use — and does this value grant a second one?**

- it uses the socket, and the value grants the socket alone → correct
- it uses the socket, and the value also grants the tty → **over-broad**; narrow it
- it genuinely needs the tty → say which caller, and why the socket cannot serve it

⚠️ and ask it at the **launch site**. an `-o` at launch outranks `kitty.conf`, so a conf
that reads `allow_remote_control no` says no word about the policy a duct window runs under
(`4.3.2.emulator/configure.verify.sh`, `.the corollary`).

## .the clamp is THIS BRIEF, plus the reasoning at the launch site

no tracked check guards this, on purpose. a sweep over `allow_remote_control=` is one grep,
and a play that holds it would live in the gitignored scratch dir — so it would reach no
other box and no other reader.

what survives instead is a pair:

| artifact | holds |
|---|---|
| this brief | the rule, the values table, and the measurement |
| `src/termwork.sh`, above the launches | the same reasoning, where the edit happens |

⇒ so the reader who reaches to widen the grant meets the argument at the keyboard, and the
free sweep is one line whenever you want it:

```sh
rhx grepsafe --pattern 'allow_remote_control' --glob 'src/**'
```

## .the neighbour that widens the blast radius

`src/tmux.conf` sets `allow-passthrough on`, which relays a child's escape sequences to the
outer terminal unexamined. `2.8.tmux` carries no server gate, so a grove holds it too.

that is correct for its stated purpose (image.nvim renders pngs through it) and it is a
**relay**, so it grants no power by itself. it matters here only as an amplifier: it carries
a sequence across a tmux hop that would otherwise absorb it. narrow the grant and the relay
carries a sequence to a terminal that refuses it.

## .enforcement

- `allow_remote_control=yes` at any launch site = **blocker**
- `allow_remote_control=socket` where the caller reaches the socket by `--to` = **blocker**
  (a password is a door where none is needed)
- a terminal-control grant widened without a named caller that needs the wider channel =
  **blocker**
- a check that reads `kitty.conf` cited as proof of the policy in force = **blocker**; the
  launch site outranks it

## .see also

- `rule.require.security-paramount` — the general form
- `rule.prefer.prevent-over-correct` — rung 1 of its ladder: make the wrong action
  impossible rather than gate it
- `src/termwork.sh` — the three launch sites, with this reasoning inline
- `src/grove.provision/4.terminal/4.3.kitty/4.3.2.emulator/configure.verify.sh` — why the
  conf's value is not the policy in force

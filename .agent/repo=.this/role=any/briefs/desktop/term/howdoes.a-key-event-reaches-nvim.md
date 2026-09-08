# howdoes: a key event reaches nvim — and which events cannot

## .what

the route a keystroke takes from the keyboard to `vim.on_key`, and the **two walls** on it
that no nvim-side code can move.

it is written because a design was proposed against this route — *"diffnav stays live while
ctrl is held"* — and the route decides whether that design is reachable at all.

## .the route

```
keyboard → kitty → tmux → nvim
```

each hop re-encodes. so a capability exists only where **every** hop carries it.

## 🛑 .the two walls, measured 2026-09-06

| # | the wall | consequence |
|---|---|---|
| 1 | **tmux SWALLOWS an app's `CSI > <flags> u`** | nvim cannot negotiate the keyboard protocol with kitty. tmux is the negotiator |
| 2 | **nvim DROPS event-type 3 (release)** | even a release that arrives intact produces no key at all |

⇒ **a key RELEASE is unreachable at nvim.** wall 2 is decisive on its own: wall 1 has an
escape hatch (below), and wall 2 has none short of an nvim patch.

## .the measured matrix

every row is a probe result, not a doc quote.

| hop | what was fed | verdict |
|---|---|---|
| tmux **outbound**, bare `CSI > 1 u` | nvim's own request | ✋ swallowed |
| tmux **outbound**, bare `CSI > 11 u` | flags 1\|2\|8 | ✋ swallowed |
| tmux **outbound**, DCS-wrapped, `allow-passthrough off` | same payload | ✋ swallowed |
| tmux **outbound**, DCS-wrapped, `allow-passthrough on` | same payload | ✔ **arrives verbatim** |
| tmux **inbound**, `CSI 100;5:1u` | ctrl+d press | ✔ relayed verbatim |
| tmux **inbound**, `CSI 100;5:3u` | ctrl+d RELEASE | ✔ relayed verbatim |
| tmux **inbound**, `CSI 57442;1:1u` | bare left-ctrl press | ✔ relayed verbatim |
| tmux **inbound**, `CSI 57442;1:3u` | bare left-ctrl RELEASE | ✔ relayed verbatim |
| nvim decode, `CSI 100;5:1u` | ctrl+d press | ✔ → `0x04` |
| nvim decode, `CSI 57442;1:1u` | bare left-ctrl press | ✔ → `U+E062` (`ee 81 a2`) |
| nvim decode, **any `:3u`** | a release | ✋ **no key at all** |

⚠️ **tmux is innocent of the release problem.** it relays every release form byte for byte.
the drop is nvim's, and it is silent — the stream stays in sync, so a `j` fed afterward still
arrives as `6a`. a reader who watched only for corruption would call this route healthy.

## .the versions these hold for

`nvim 0.12.3` · `tmux 3.4` · `kitty 0.47.4`. wall 1 is a tmux property and wall 2 an nvim
one, so **re-measure before you trust either across an upgrade**.

## .why nvim cannot ask for more

`tui.txt:164-174` states it:

> at startup nvim will query your terminal … by writing `CSI ? u CSI c`. if your terminal
> emulator responds … nvim will tell your terminal to enable it by writing `CSI > 1 u`

**flag 1 only**, and hardcoded. so even with wall 1 removed, nvim asks for no event types.

⚠️ the request is also **conditional on a reply**. a probe whose pty never answered the query
saw nvim emit no request at all — which reads as *"nvim does not use the protocol"* and is
false. the request is withheld, never absent.

## .the one escape hatch for wall 1

tmux's `allow-passthrough` — the same hatch kitty GRAPHICS ride through:

```
DCS tmux ; <payload, every ESC doubled> ST
```

measured: `off` swallows it, `on` delivers `CSI > 11 u` to the outer terminal verbatim.

⚠️ **`swallow`, never `eat`** — and the split is load-bear here, because BOTH words come up on
this route, in opposite directions:

| direction | who consumes | the word |
|---|---|---|
| nvim → kitty, the flag request | tmux, **in transit** as the channel | **swallow** |
| kitty → nvim, a `:3u` release | **nvim**, the receiver that awaits it | near `eat` — see below |

⚠️ and the second row is a NEAR miss, not a match. `eat` requires a message *addressed to
someone else*; a release IS addressed to nvim, and nvim declines it. so neither verb fits, and
this brief says **drops** rather than stretch one (`rule.forbid.domain-term-synonyms` — adhere
or dispute, never drift).

🛑 **the hatch is a security decision, never a convenience.** with it on, ANY program that
writes to the terminal can send arbitrary escape sequences to kitty — a `cat` of a hostile
file, or a remote host at the far end of an ssh hop. weigh it against
`rule.require.security-paramount` before you turn it on.

## ⚠️ .what kitty CANNOT do — measured, not assumed

`map <key> --release <action>` looks like it binds a release. it does not:

```
map ctrl+d          send_text all X   →  trigger (SingleKey(mods=4, key=100),)
map ctrl+d --release send_text all X  →  trigger (SingleKey(mods=4, key=100),)   ← IDENTICAL
```

`--release` lands in the bind's `definition` string — the ACTION half — and `KeyMapOptions`
carries no release field at all. so the parse succeeds, the bind count is 1, and the trigger
is a plain press.

⇒ **a bind that parses is not a bind that is honored.** the count says one thing and the
parsed object says another; only the object is evidence
(`gotcha.a-check-that-cries-wolf-gets-silenced`, m.8).

and kitty exposes **no config option** for the protocol flags: of its 470 options, the only
two that name a keyboard concern are `kitty_mod` and `modify_font`.

## ✔ .what kitty CAN do

```
map left_control send_text all X   →  trigger (SingleKey(key=57442),)
```

the **bare physical modifier** is bindable, and `57442` is the same code nvim decoded to
`U+E062`. two independent readers agree on the number.

`--when-focus-on` is a real `KeyMapOptions` field, so such a bind can be scoped to one app
rather than fired into every shell.

## 🛑 .the consequence for any hold-while-pressed design

a hold has two edges. only one is observable:

| edge | observable at nvim? |
|---|---|
| ctrl **down** | ✔ — as `U+E062`, given flag 8 or a kitty bind |
| ctrl **up** | ✋ — never |

⇒ so **do not build on the release.** build on the *next* press instead: a hold cannot begin
without one, so *"a bare ctrl press arrived"* carries the same information as *"the prior hold
ended"* for any state that only a ctrl-modified key can read.

⚠️ and note what is NOT distinguishable while both mechanisms are absent. these two produce an
**identical** byte stream:

```
ctrl↓ d j j j ctrl↑          →  <C-d> <C-j> <C-j> <C-j>
ctrl↓ d ctrl↑ … ctrl↓ j      →  <C-d> <C-j>
```

a timer is a proxy for the gap in the second. that is what a timer IS here — not laziness,
but the only discriminator left once both mechanisms are ruled out.

## .the probes

all four were scratch, under the gitignored `.temp/`, and are gone
(`rule.forbid.repair-plays` — a probe answers one question, then is discarded). each carried a
**setup guard**, and two of them fired:

| draft defect | what it would have reported |
|---|---|
| the payload reached the inner shell as the literal text `\x1b[>11u` | three arms of `relayed: NO` about a world that never built |
| the payload raced tmux's own startup draw | a false ✋ on `allow-passthrough` |

⇒ both are `gotcha.a-check-that-cries-wolf-gets-silenced` m.5, met head-on. **a probe with no
setup guard reports a verdict about whatever it happened to build.**

## .see also

- `gotcha.kitty-rewrites-ctrl-j` — why every ctrl+j bind needs an `<S-CR>` twin
- `define.kitty-tmux-nvim-copy` — the copy path, which rides this same route
- `gotcha.tmux-carries-no-super-modifier` — a neighbour case of one hop that drops a capability
- `inventory.of=behaviors.via=nvim.case=diff-boundary-nav` — the design this route bounds
- `rule.require.security-paramount` — weigh `allow-passthrough` against it

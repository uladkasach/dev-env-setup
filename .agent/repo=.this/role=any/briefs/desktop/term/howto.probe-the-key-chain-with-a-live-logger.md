# howto: probe the key chain with a live logger

## .what

put a **key logger in front of the chain**, open it in a real window, and ask the human to
press the physical keys. read the bytes it captures.

```
keyboard → kitty → tmux → nvim
                          └─ the logger sits HERE, and prints what arrived
```

it answers one question, and no other instrument answers it:

> **what does nvim actually receive when a human presses this?**

## 🛑 .why no source read can answer it

a keybind defect has two candidate causes, and they look identical from the config:

| cause | what a source read sees |
|---|---|
| the map is wrong | the map |
| the map is right and **the bytes never arrive in that shape** | the map |

a config read, a `:verbose map`, a `cmp` of the live file against the checkout, a `timeoutlen`
check — every one of them reports on **nvim's side of the wire**. each can be green while the
chord is dead, because the chain upstream rewrote, degraded, or dropped the event before nvim
saw it.

⇒ **the chain is the one component with no source of truth in this repo.** kitty rewrites keys
(`4.3.2.emulator/kitty.conf`), tmux refuses the enhanced-keyboard negotiation, and nvim drops
event types it did not ask for (`howdoes.a-key-event-reaches-nvim`). the composition of those
three is a fact about a running system, so only a running system reports it.

## 🛑 .a clamp that FEEDS a keystream proves no part of this

this is the sharp edge, and it is why the tactic earns a brief rather than a note.

📜 measured 2026-09-16. the diff-boundary chord had a tracked clamp, green, and a brief that
recorded it as *"proven to bite"* on 2026-09-06. the behavior was broken in the human's hands
the whole time.

the clamp fed nvim the keystream its author **believed** the chain delivers, then asserted the
map fired. it did. the map was correct. the chain delivered a different keystream, and no arm
of the clamp could see that — so the clamp was a false ✔ about the one link that was broken.

⇒ **a clamp keyed on an assumed input measures the map. a probe measures the CHAIN.** they are
not substitutes, and a green clamp is no evidence at all about the hop the probe reads.

⚠️ this is `gotcha.a-check-that-cries-wolf-gets-silenced` q5 at one remove: the fixture took
exactly as written, and the world it built was not the world the human types into.

## .the procedure

### 1. write the logger — scratch, under `.temp/`

```lua
vim.o.timeoutlen = 1000

local function hex(s)
  local out = {}
  for i = 1, #s do out[#out + 1] = string.format('%02x', s:byte(i)) end
  return table.concat(out, ' ')
end

vim.on_key(function(_, typed)
  if not typed or typed == '' then return end
  -- append `hex(typed)` + `vim.fn.keytrans(typed)` + the ms gap since the last key
end)
```

three fields, and each is load-bear:

| field | what it settles |
|---|---|
| **hex** | the ONLY unambiguous record. `0d` and `80 fc 02 0d` both render as an enter-ish name |
| **`keytrans`** | nvim's own name for the bytes, so you read its interpretation beside the truth |
| **ms gap** | parts a chord from two keys, and shows whether `timeoutlen` had a chance to fire |

🛑 **read `typed`, never `key`.** `vim.on_key`'s second argument is the raw byte stream; the
first is post-mapping, and a Lua keymap renders there as `80 fd 67` (`K_LUA`) — which tells you
a map fired and tells you no part of what arrived.

🛑 **name the bytes you expect, up front.** build a lookup from
`vim.api.nvim_replace_termcodes('<S-CR>', true, false, true)` and friends, so the log reads
`<S-CR>` rather than four hex pairs you must decode by eye at the moment of the measurement.

### 2. print the instructions INTO the buffer

the human presses keys in a window you cannot see. put the forms in the buffer, one per line,
numbered — so their press and your read agree on which form is which.

```
  form 1:  ctrl+d, ctrl+j   ctrl+d, ctrl+j     (ctrl lifted between)
  form 2:  ctrl+( d j d j )                    (ctrl HELD, d+j re-tapped)
  form 3:  ctrl+( d j j j )                    (ctrl HELD, j repeats)
```

### 3. open a real window and hand it over

```sh
rhx term.open --name keyprobe --what 'nvim -u .temp/keyprobe/probe.lua'
```

a **real kitty window**, because the chain under test IS kitty. a headless nvim, a `--embed`
nvim, or a send over a duct each replace the very hop the probe exists to read.

then say so plainly: *"the window is open — press the three forms, then tell me."*

### 4. read it

```sh
rhx term.read --pid <pid> --lines 60
```

## ⚠️ .the traps — each one cost a round

| trap | what happens | the repair |
|---|---|---|
| 🔴 the logger writes **only to a buffer** | every key appends a line AND jumps the cursor to the bottom, so `gg` is self-defeating: the `g`,`g` are themselves keys that scroll it back. earlier forms become unreadable | **append to a FILE too.** read the file, never the pane |
| `term.send --on 'term://<name>'` | `no terminal for duct` | address it by `--pid` |
| reach for `duct.*` | it tries to ssh to a host by that name | `duct.*` is remote-only. a local window is `term.*` |
| send the keys yourself | you replay your own assumption, which is the defect | **a human's finger on a physical key is the instrument.** there is no substitute |
| keep the probe | it is scratch. it answers one question | `.temp/`, and discard it after |

⚠️ the first row is the one that bites hardest, because the probe looks like it worked — the
log is right there, and the part you need has scrolled past a cursor you cannot move.

## .when to reach for it

| when… | then… |
|---|---|
| a keybind is correct in source and dead under a finger | 🔴 this. every other read is about nvim's side |
| a chord works in one form and not another | the forms differ in BYTES. measure which |
| a clamp is green and the human says it is broken | the clamp fed an input. the probe reads one |
| you would write *"kitty rewrites X to Y, so nvim gets Y"* | that is a claim about a chain. one press settles it |
| a terminal, multiplexer, or nvim version moved | the negotiation may have moved with it |

## .what a run yields

a byte string per form, which turns an argument into arithmetic:

```
  form 3:   04 0d 0d 0d 0d 0d
  form 2:   04 0d 04 0d 04 0d
```

⇒ from there, a `grep` of the map table is a **decision**, not a guess: is `<C-d><CR>` mapped?
is `<CR>` in the repeat vocabulary? each answer is yes or no, and the defect names itself.

## .see also

- `howdoes.a-key-event-reaches-nvim` — the chain this probes, and the two measured walls
- `gotcha.kitty-rewrites-ctrl-j` — the rewrite whose DELIVERED shape this measures
- `gotcha.a-check-that-cries-wolf-gets-silenced` — q5, the fixture that took and built the wrong world
- `rule.require.clamp-edge-cases` — a clamp must bite; this brief names what a keystream clamp cannot reach
- `howto.terminal-window-management` — `term.open` / `term.read` / `term.send`

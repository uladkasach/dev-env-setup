# gotcha: a docked 4k monitor at 150% taxes the iGPU, and the dock adds no gpu

## .what

the laptop felt fast on its own panel and sluggish once docked to the 4k monitor. the cause is
**pixels, not the dock**: a 4k panel at a fractional scale makes the one Iris Xe iGPU render
~8.3M pixels per frame, then composite a 1.5× pass, for every window that changes.

- the dock (dell WD19TB, thunderbolt) carries the laptop's own displayport. it holds **no gpu**
  and lends none. a monitor on it is driven by the iGPU, same as a direct cable
- the link itself is healthy: native DP, no link-train errors

## .the signals that mark it — and the ones that mislead

| signal | reads as | what it is |
|---|---|---|
| load 21–33 on 12 cores, cpu ~77% idle, no iowait | "cpu starved" | ✋ wrong. tasks parked in D state inflate load |
| `kworker …+i915_flip` in D state, again and again | — | ✔ the gpu's page-flip queue backs up. short D waits are normal; a recurrent one marks a busy iGPU |
| `tmux: server` at ~57% of a core | "a spinner, kill it" | ✋ **never.** it is a host — its burn is the sum of its tenants, and a kill ends every terminal. `machine_resource_procs_find_spinner` now marks hosts 🏠 and offers no kill |

the second axis is the TENANT count, measured on the same box: ~35 claude sessions, ~57 kitty
processes (termwork runs one kitty process per terminal), ~430 zsh, 340–860 forks/s, memory
88–93%, 17–18G in swap. each visible kitty window is its own gpu context and repaint loop.

## .the display trials — settled, do not re-run

| trial | verdict | why |
|---|---|---|
| 4k @ 150% | ✔ **kept** | sharp text at the wanted size (2560x1440 logical) |
| 4k @ 200% | ✋ rejected | sharp, but all of it too large |
| 2560x1440 @ 100% | ✋ rejected | felt faster, but the panel upscales a non-native mode — text fuzzy, hard on the eyes |
| 30Hz | ✋ rejected unrun | it halves the frame rate and adds up to ~33ms per frame — latency is the very complaint |

⇒ **no other mode hits the target better.** sharp text needs the native 3840x2160; the wanted size
needs 150%. every non-native mode is fuzzy, and every other scale is the wrong size. the only
sharp, cheaper option is 4k @ 100% with per-app font size up — the cosmic shell itself gets small.

## .what does reduce the load, ranked

1. **fewer live tenants.** close idle claude sessions and terminal windows you do not watch.
   this cuts memory, swap and fork churn — the largest lever measured. close them yourself; an
   agent must never kill a terminal or a host
2. **kitty render delays.** `repaint_delay` (default 10ms) and `input_delay` (default 3ms) set
   each instance's repaint rate; raised values cut per-instance cost at a small latency price
3. **fewer kitty processes.** one kitty process holds one gpu context and one glyph cache across
   its windows; termwork's process-per-terminal multiplies both. a termwork change, not a config
4. cosmic transparency (frosted glass) is a known lag source on 4k — **already off** here

## .an external gpu

possible only as a thunderbolt eGPU enclosure (a desktop card in a box), and only helps if:

- the monitor plugs into the **eGPU's own** port, never the dock's
- cosmic-comp renders on it: `COSMIC_RENDER_DEVICE=renderD<n>` in
  `~/.config/environment.d/`, the bare node name, never a full path, then log out and in
- ⚠️ undocumented, and reported to steer client gpu choice more reliably than the compositor's
- ⚠️ an nvidia eGPU unplugged while it drives a display can hang the box; amd is the safer card

⇒ cost, fragility, and a second power brick, against what fewer tenants buys for free.

## .refs

- [cosmic-comp #2857 — pointer motion costs 18–32% of the gpu on 4k](https://github.com/pop-os/cosmic-comp/issues/2857)
- [cosmic-epoch #2985 — frosted glass as a 4k lag source](https://github.com/pop-os/cosmic-epoch/issues/2985)
- [niri #4557 — i915_flip workers in D state](https://github.com/niri-wm/niri/issues/4557)
- [kitty performance](https://sw.kovidgoyal.net/kitty/performance/) · [kitty.conf](https://sw.kovidgoyal.net/kitty/conf/)
- [egpu.io — linux eGPUs and wayland in 2026](https://egpu.io/forums/thunderbolt-linux-setup/linux-egpus-and-wayland-in-2026/)
- [cosmic-comp #2232 — COSMIC_RENDER_DEVICE](https://github.com/pop-os/cosmic-comp/issues/2232)

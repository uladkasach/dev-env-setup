# gotcha: a pct override sets WHERE compaction fires, never WHETHER it fires

## .what

`CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=50` lowers the auto-compact threshold. it does not switch
threshold compaction on. a context whose compaction window resolves to source `auto` skips the
threshold check entirely and grows until the api pushes back — the percentage never applies.

⇒ declare the WINDOW beside the percentage. the env source opens the gate for every context,
subagents included, and the percentage then scales it:

```json
"CLAUDE_AUTOCOMPACT_PCT_OVERRIDE": "50",
"CLAUDE_CODE_AUTO_COMPACT_WINDOW": "1000000"
```

- a 1M model: window `min(1M, 1M)`, threshold `min(1M × 50%, 1M − 13k)` = **500k**
- a smaller model: the window clamps to the model's own, so it compacts at half of that
- 🟡 a 500k window with the 50% kept would compact at 250k — the two multiply

## .measured — 2026-10-22

the main session compacted near 500k. its subagents (`claude-sonnet-5-5[1m]`) were seen at
**800k** context. same process, same env, same `PCT_OVERRIDE=50`.

## .the mechanism — claude-code 2.1.280, read from the binary

minified names are version-bound; re-derive them with `rhx brains.claude.strings` after a bump.

1. **the gate.** the per-turn autocompact check (`jcr`) returns early on
   `uB() && !q9(model, window)`. `q9` is true only when the window's source is not `auto`.
   source `auto` ⇒ no threshold compaction for that context.
2. **the source order** (`ok(model, window)`), first hit wins:

   | # | source | from |
   |---|---|---|
   | 1 | `env` | `process.env.CLAUDE_CODE_AUTO_COMPACT_WINDOW` — read per call, process-wide |
   | 2 | `settings` | the context's `options.autoCompactWindow` (`/autocompact`, `--autocompact`, settings) |
   | 3 | `clientdata`, `experiment` | server-side |
   | 4 | `model-default` | a per-model table, or a native-1m model the model table knows (`Bh`) |
   | 5 | `unknown-model` / `auto` | none of the above |

3. **the percentage.** `D8(window)` = `min(window × pct, window − 13000)` — it scales a threshold
   the gate already admitted. the gate never consults it.
4. **subagents inherit the parent's window option unchanged** (`ugn` is the identity in 2.1.280).
   so a subagent lands on `auto` exactly when its parent has no `settings` window and its MODEL
   earns no `model-default` — rows 2 and 4 are the only ones that differ per context.

📌 unverified: which row the main opus session hit, and that `claude-sonnet-5-5[1m]` misses row 4.
the 800k measurement is consistent with it; no debug log was read. row 1 sidesteps the question
for every model, which is why it is the fix.

## .the trap inside the fix

the env var takes a plain integer. `1m` is not `1000000` — per a secondary source (relayed,
unverified here), a suffixed value misreads and clamps to the 100k floor. write the digits.

## .the upstream record

`anthropics/claude-code#83355` (open, `area:agents`): subagent autocompaction sizes off the
coordinator's context, so a subagent on another window never compacts. its reporter names
`CLAUDE_CODE_AUTO_COMPACT_WINDOW` as the workaround — the same lever as the fix above.

## .what the public docs say, and where they mislead

relayed from the web, 2026-10-22:

- the docs say the pct override "applies to subagents as well" — true of the arithmetic, and
  silent on the gate. one secondary source adds the absent half: it "only applies in sessions
  that compact before the model's context limit."
- `autoCompactWindow` in an agent's frontmatter sets a per-subagent window — **2.1.296+**. the
  pin here is 2.1.280, so that lever is absent.
- `CLAUDE_CODE_AUTO_COMPACT_WINDOW` outranks every frontmatter window. once declared, a
  per-agent window has no effect.

## .see also

- `define.5-3-brains.declared-keys` — the env flag table
- `5.3.brains/configure.upsert.sh` — the one home for the key
- https://startdebugging.net/2026/10/how-to-give-each-claude-code-subagent-its-own-compaction-threshold-with-autocompactwindow/
- https://www.turboai.dev/blog/claude-autocompact-pct-override-guide

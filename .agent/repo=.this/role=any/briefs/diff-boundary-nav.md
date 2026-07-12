# diff boundary navigation

## .what

ctrl+d j/k navigates diff boundaries, not just chunks. behavior:
- inside chunk → jump to chunk edge (top/bottom)
- at chunk edge → jump to next/prev chunk

## .why better than chunk-to-chunk

standard `]c`/`[c` jumps to top of next chunk. problem: if chunk is 50 lines, you land at line 1 and must scroll to see the rest.

boundary nav solves this:
1. first press → bottom of current chunk (see full context)
2. second press → top of next chunk (ready to review)

result: never land mid-chunk unsure where it ends. always at a boundary with full visibility.

## .flow example

```
chunk A (lines 10-25)
chunk B (lines 40-60)
chunk C (lines 80-85)
```

cursor at line 15 (inside chunk A):
- ctrl+d j → line 25 (bottom of A)
- ctrl+d j → line 40 (top of B)
- ctrl+d j → line 60 (bottom of B)
- ctrl+d j → line 80 (top of C)

cursor at line 50 (inside chunk B):
- ctrl+d k → line 40 (top of B)
- ctrl+d k → line 25 (bottom of A)
- ctrl+d k → line 10 (top of A)

## .implementation

uses `navigate_diff_boundary(direction, get_chunks_fn, fallback_fn)`:
- get_chunks_fn returns `[{start, fin}, ...]` for each chunk
- checks cursor position relative to chunk boundaries
- moves to boundary or next chunk accordingly
- fallback_fn called if cursor not in any chunk

two chunk detection methods:
- `get_gitsigns_chunks()` - for normal buffers via gitsigns hunks
- `get_diff_hl_chunks()` - for diff buffers via vim's diff_hlID()

## .keybinds

| context | key | action |
|---------|-----|--------|
| normal buffer | ctrl+d j | next boundary (gitsigns) |
| normal buffer | ctrl+d k | prev boundary (gitsigns) |
| codediff buffer | ctrl+d j | next boundary (diff hl) |
| codediff buffer | ctrl+d k | prev boundary (diff hl) |

## .gotcha: ctrl-held ctrl+j → shift+enter

kitty remaps `ctrl+j` to `shift+enter` (`map ctrl+j send_key shift+enter` in
install_env.pt4). so when ctrl stays down the whole time for `ctrl+d ctrl+j`,
nvim never receives `<C-j>` (= `<NL>`, byte 0x0a) — it arrives as `<S-CR>`.

fix: each boundary_down bind also covers `<C-d><S-CR>`, so ctrl-held next-diff
works. `ctrl+k` is untouched by kitty, so prev needs no equivalent.

- `<C-j>` keytrans → `<NL>` (why the plain bind cannot catch the kitty case)
- `<S-CR>` is a distinct keycode in nvim 0.10+ with the kitty keyboard protocol

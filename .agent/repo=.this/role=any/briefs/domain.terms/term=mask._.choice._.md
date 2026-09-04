# domain.term: mask

term.chosen   = mask
term.kind     = verb
term.synonyms.forbidden:
- escape       (the OPPOSITE direction. to escape a character is to make a reader treat it as
                literal; the input here is ALREADY literal, and the mask is what tells the
                reader so)
- strip        (says the character is REMOVED. it is not — the line keeps its length, and the
                column a caller reports must still point at the right place)
- sanitize     (a security word, and this is no security operation. no input is made safe; a
                separator is merely declared inert)
- neutralize   (names the effect and not the mechanism, and it is already spoken for by prose
                about what the mask ACHIEVES — a word that names its own outcome cannot then
                describe it)
- quote        (a mask is what HANDLES quotes; to name it for its subject is to say
                "the quote-quoter")

## .what
to replace each separator that sits inside a quoted string with an inert byte, so a later cut
does not fall there.

```sh
echo "run: a && b"          # in the file
echo "run: a \001\001 b"    # after mask_quoted() — same length, no cut point
```

`mask_quoted(s)` in `_.shell-tokenize.lib.sh` returns the masked line. it is the operation
`segments()` runs FIRST, and it is also public on its own — `prove.early-exit-readers-are-safe`
matches a pattern rather than a command word, so it masks and never cuts.

## 🛑 .the mask is what makes a segment a segment
without it, `segments()` is a `gsub` — and a `gsub` tears prose in half
(`term=prose._.choice._.md`). the whole difference between "the text after a separator" and
"the text after a separator SHELL WOULD HONOR" is this one operation.

| line | a plain split reads | a masked split reads |
|---|---|---|
| `echo "read why: a && b"` | two commands | one command |
| `grep -vE '^(Hit\|Ign)'` | two commands | one command |
| `echo "the acct is $(aws sts …)"` | two commands | two commands ✔ |

the third row is the one that surprises: `$(` is **not** masked, because shell starts a real
command there even inside a quote.

## ⚠️ .BOTH quote kinds, and the toggles are mutually exclusive
a `"` inside single quotes is literal, and a `'` inside double quotes is literal. so each
toggle is gated on the other being closed:

```awk
if (c == "\"" && prev != "\\" && ins == 0) { inq = 1 - inq; … }
if (c == "\047" && inq == 0)               { ins = 1 - ins; … }
```

without the gate, an apostrophe in ordinary prose — `# the seats own PATH` — flips the state
and masks every separator to the end of the line, so the reader goes blind from that column on.

## .reason
see the ref-level cluster beside this choice:
- `term=mask._.choice.reason.md` — etymology, the rejected synonyms, and the measurements
  where an unmasked cut condemned correct code

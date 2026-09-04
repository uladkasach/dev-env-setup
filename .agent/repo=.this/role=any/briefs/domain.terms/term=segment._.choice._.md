# domain.term: segment

term.chosen   = segment
term.kind     = noun
term.synonyms.forbidden:
- token        (lexer vocabulary. a token is ONE lexical unit — a word, an operator. a segment
                is a whole command with its arguments, so the word understates it by an order)
- command      (what a segment HOLDS, not what a segment IS. a reader that says "the command at
                position 3" cannot then say which command word it peeled to)
- statement    (shell has no statement. `a | b` is one line, two segments, and no statement)
- part / chunk (say where a cut fell and no word about why it fell there. the whole content of
                this term is that the cut is where SHELL says a new command may begin)
- clause       (grammar vocabulary, and already spoken for by the review rubrics)

## .what
one command position within a shell line — cut at every place shell says a new command may
begin, and peeled to its command word.

```sh
printf '%s\n' "$x" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
└──── segment 1 ────┘ └──────────────── segment 2 ─────────────────────────┘
```

`segments(line, arr)` in `_.shell-tokenize.lib.sh` fills `arr[1..n]` and returns `n`. four
plays judge segments; not one of them judges lines.

## 🛑 .why the concept is kept at all — a LINE is the wrong unit
a reader that anchors on the first word of a LINE makes a claim it cannot support: that a
command it cares about always opens its line. measured 2026-08-14, twice in one hour:

| reader | anchored on | what it could not see |
|---|---|---|
| `prove.sudo-is-gated-or-nonintera` | `^sudo` | 13 live `\| sudo tee` sites, across ten bundles |
| `prove.apt-is-never-interactive` | `^(apt-get\|apt\|dpkg\|…)` | `yes \| sudo apt-get install`, which FEEDS a prompt |

the first read **51** sites and reported it as the count of bare sudo in the tree. it was the
count of the forms its pattern matched (`gotcha.a-check-that-cries-wolf-gets-silenced`, m.12).

## .the four cut points, and the one that surprises
`|`, `&&`, `;` — and **`$(`**. a command substitution starts a real command even inside a
quoted string, so it is the one place a cut happens within a quote.

## ⚠️ .a segment is defined by a QUOTE-AWARE cut, never a plain split
this is the whole load-bear half. within quotes — either kind — `|`, `&&`, and `;` are literal
text, so a plain `gsub` tears prose in half and hands the tail on as if it were a call:

```sh
echo "      read why: fnm use <version> && corepack install -g pnpm@$want" >&2
#                                          └─ NOT a segment. no corepack runs on this line
```

that exact line was condemned as an unbounded `corepack` call on 2026-08-14
(`gotcha.a-check-that-cries-wolf-gets-silenced`, m.8). so a text that merely NAMES a command
is `prose` (`term=prose._.choice._.md`), and the cut is what tells the two apart.

## .reason
see the ref-level cluster beside this choice:
- `term=segment._.choice.reason.md` — etymology, the rejected synonyms, and the two
  measurements that earned the word

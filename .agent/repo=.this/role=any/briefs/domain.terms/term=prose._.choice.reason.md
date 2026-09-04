# domain.term.choice.reason: prose

## .etymology
the ordinary literary sense, narrowed: prose is what a text IS when it is read rather than
executed. the word was already in use across the readers before it was a term — every one of
them carries the sentence *"a comment is prose, never a command"* — so this cluster records a
choice the repo had already made and never wrote down.

that is worth its own note. a word used identically in four files, in the same position, with
the same consequence, is a term whether or not anybody itemized it — and an unitemized term is
one a later author may drift from with no signal
(`rule.require.domain-term-itemization`).

## .why not `comment`
`comment` was the first word the readers used, and it is a MEMBER of the set rather than the
set. the members that are not comments are the ones that actually bite:

- a **fix-text** is a live `echo` — real code, whose ARGUMENT names a command
- a **heredoc body** is data a play writes on purpose, and every fixture in this repo is one
- a **quoted argument** may hold a whole pipeline, separators and all

a reader that skipped `^[ \t]*#` and called itself prose-aware would still have condemned
every fix-text in the tree. that is precisely what happened
(`gotcha.a-check-that-cries-wolf-gets-silenced`, m.8).

## .disputes
### dispute: comment — raised 2026-08-14 — status: RESOLVED (keep `prose`)
- raised.by  = the author of `_.shell-tokenize.lib.sh`
- claim      = every reader already says "a comment is prose, never a command", so `comment`
               is the word in use and the shorter one
- counter    = the sentence quoted uses BOTH words, and it uses them at two levels: a comment
               is one KIND of prose. three of the four members are not comments, and those
               three are the ones a reader gets wrong. to collapse the two would leave the set
               with no name at all
- resolution = keep `prose` for the set; `comment` stays the ordinary word for its one member,
               and is a forbidden synonym of the set.

## .evidence

### measurement 1 — prose read as code, 2026-08-14
`prove.offbox-reads-are-bounded` cut a line at every `&&`. this line is an `echo`:

```sh
echo "      read why: fnm use <version> && corepack install -g pnpm@$pnpm_want" >&2
```

the cut fell inside the quotes, the tail became a segment whose first word was `corepack`, and
the play reported `5.devtools/5.1.node/provision.upsert.sh:438` as an unbounded registry call —
with a `fix:` that said "wrap each in `timeout <n>`", for a call already routed through
`web_corepack`. the real calls sit twelve lines above and were bounded the whole time.

### measurement 2 — the arm that passed for the wrong reason
that same play carried `_fix_text` from its first day:

```sh
_fix_text() {
  echo "      fix: gh auth login" >&2
}
```

it passed, and it always had — but the line holds no separator, so the splitter left it whole,
its first word was `echo`, and `echo` is in no tool set. it was spared **incidentally**. the
reader had no notion of prose at all, and the arm stood as the play's stated guarantee.

⇒ **an arm that passes incidentally is indistinguishable from an arm that passes on purpose.**
the repair is a second arm whose prose HOLDS a separator, and that arm is the red-capable one.

### measurement 3 — the heredoc member
`prove.early-exit-readers-are-safe` must write a fixture that contains a real `| grep -q`, and
must not then flag its own fixture. so its reader tracks heredoc bodies as data. that is the
member no quote-mask can reach, and it is why the set needs a name broader than "a quoted
argument".

## .see also
- `term=segment._.choice._.md` — what prose is cut into when a reader gets it wrong
- `term=mask._.choice._.md` — the operation that keeps a quoted separator from a cut
- `term=fixture._.choice._.md` — where the incidental-pass trap lives
- `gotcha.a-check-that-cries-wolf-gets-silenced` — m.8, both measurements above

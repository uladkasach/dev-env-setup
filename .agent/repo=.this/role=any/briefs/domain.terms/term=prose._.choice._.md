# domain.term: prose

term.chosen   = prose
term.kind     = noun
term.synonyms.forbidden:
- comment      (ONE member of the set, taken for the whole. a fix-text sent to `>&2` is prose
                and is no comment — it is a live `echo` whose ARGUMENT names a command)
- text         (says no word about the distinction that matters, which is text-vs-code)
- string       (a shell fact, not a domain one. a heredoc body is prose and is no string)
- documentation (names the purpose, not the property. a fixture body is prose and documents
                 nobody — its job is to be READ by a reader under test)
- noise        (a judgement, and a wrong one: prose is where this repo keeps its reasons)

## .what
text that **names** a command without a run of it. the set has four members, and each has bitten
a reader in this repo:

| member | example |
|---|---|
| a comment | `# this line read sudo curl -fsSL <url> -o /etc/apt/keyrings/docker.asc` |
| a fix-text | `echo "      read why: sudo apt-get install zsh" >&2` |
| a heredoc body | a play's `cat <<FIXTURE` — which must hold the shape it forbids |
| an argument that quotes a call | `echo "fix: printf '%s' x \| sudo tee /etc/widget.conf"` |

## 🛑 .prose is the SPARE half of every reader in this repo
each of the four tokenizer consumers judges a `segment` (`term=segment._.choice._.md`), and
each must spare prose:

| play | refuses | and must spare |
|---|---|---|
| `prove.offbox-reads-are-bounded` | an unbounded wire call | a `fix:` that names one |
| `prove.sudo-is-gated-or-nonintera` | an ungated `sudo` | `read why: sudo apt-get install zsh` |
| `prove.apt-is-never-interactive` | a bare apt write | the same fix-texts, a dozen of them |
| `prove.early-exit-readers-are-safe` | a live `\| grep -q` | a fix-text that NAMES that shape |

⚠️ the last row is the sharpest: that play's whole subject is a shape it must also SPEAK, in a
dozen header blocks and in every arm of its own fixture.

## ⚠️ .the trap — an arm that spares prose INCIDENTALLY
a reader with no notion of prose still spares the easy case, because the first word of
`echo "… gh auth login"` is `echo` and `echo` is in no tool set. so an arm that plants only
that shape passes on a reader that has no notion of prose at all.

`prove.offbox-reads-are-bounded` carried exactly such an arm — `_fix_text` — from the day it
was written, and it stood as the play's stated guarantee for as long as the play existed. it
was satisfied by luck, and the property it named was implemented by nobody
(`gotcha.a-check-that-cries-wolf-gets-silenced`, m.8).

⇒ so the arm that counts is the one whose prose holds a **separator**: `_fix_text_chain`,
`_prose_sudo_piped`, `_prose_apt`. those are the ones a naive cut fails.

## .the boundary — where prose STOPS
`$(` starts a real command even inside a quoted string. so this is prose:

```sh
echo "run: a && b"
```

and this is not:

```sh
echo "the account is $(aws sts get-caller-identity --query Account --output text)"
```

## .reason
see the ref-level cluster beside this choice:
- `term=prose._.choice.reason.md` — etymology, the rejected synonyms, and the measurements
  where a reader took prose for code

# domain.term.choice.reason: segment

## .etymology
from the cut itself: a line is *segmented* at the points shell would start a new command, and
each piece that results is a segment. the word is chosen for what it names — a PIECE OF A
LINE — rather than for what the piece contains, because the containment is the reader's
question and the cut is the tokenizer's.

`token` was the first reach and is wrong by a whole level: a lexer's token is one word or one
operator, so `sudo tee /etc/x` is three tokens and one segment. a reader that said "token"
would have to say "the first token of the token", which is where the word was abandoned.

`command` is the near miss, and the one worth a record. a segment usually HOLDS exactly one
command — but it holds its arguments and redirections too, and the whole point of `peel()` is
that the command WORD is derived from the segment rather than equal to it. two names for the
two levels is what lets a reader say "the segment at position 2, whose command word is sudo".

## .disputes
### dispute: token — raised 2026-08-14 — status: RESOLVED (keep `segment`)
- raised.by  = the author of `_.shell-tokenize.lib.sh`
- claim      = "token" is the established word for a piece of parsed source, so a reader who
               knows lexers reads it with no gloss
- counter    = a lexer's token is ONE lexical unit; this concept is a whole command with its
               arguments. the mismatch is not stylistic — it makes the first-word peel
               unspeakable, since "the first token of the token" is incoherent. and this repo
               already burned an hour on a word that named the wrong level
               (`term=entry._.choice.reason.md`)
- resolution = keep `segment`; record `token` as a forbidden synonym.

## .evidence

### the measurements that earned the word — 2026-08-14
two readers, both green, both short of their own claim, and both by the same cause: each
anchored a pattern at the start of a LINE.

1. **`prove.sudo-is-gated-or-nonintera`** reported `51 bare sudo call site(s)` and reported it
   as a fact about the tree. a sweep for `sudo` NOT at the start of its line returned live
   sites in `1.1.keybinds`, `1.2.power`, `1.4.sysctl`, `1.5.swap`, `4.3.3.launcher`, `5.4.gh`,
   `5.8.docker`, `6.2.codium`, `6.3.dropbox`, and `6.5.onepassword` — every one a
   `| sudo tee` into `/etc`. the count is **64** once segments are the unit.

   ⚠️ all 13 turned out gated, so the VERDICT was right the whole time. that is what makes the
   defect expensive rather than loud: a wrong verdict gets read and argued; a right verdict
   over two thirds of its subject gets trusted (`gotcha…cries-wolf`, m.12 / q11).

2. **`prove.apt-is-never-interactive`** could not have seen `yes | sudo apt-get install x` —
   the classic way to FEED a prompt rather than suppress it, and the exact hazard that play
   exists to forbid. no such site is in the tree, which is precisely the condition under which
   a short reach stays quiet: a row nobody can match produces no row.

### the counter-measurement — why the cut must be quote-aware
the opposite defect is equally real and was measured first. `prove.offbox-reads-are-bounded`
split at every `&&`, quoted ones among them, so this line —

```sh
echo "      read why: fnm use <version> && corepack install -g pnpm@$pnpm_want" >&2
```

— produced a tail whose first word was `corepack`, and the play condemned the most carefully
bounded loop in the tree, with a `fix:` that named a bound the call already carried
(`gotcha…cries-wolf`, m.8).

⇒ so a segment is not merely "the text after a separator". it is the text after a separator
**that shell would honor**, and the two differ on every fix-text in the repo.

### the ARM that proves it both ways
a fixture with only the piped-call arm is satisfied by a reader that flags every line with a
pipe in it — which would condemn every fix-text. so each consumer carries the pair:

| play | must REFUSE | must SPARE |
|---|---|---|
| sudo-is-gated | `_piped_ungated` | `_prose_sudo_piped` |
| apt-is-never-interactive | `_piped_bare` | `_prose_apt` |
| offbox-reads-are-bounded | `_chained_real` | `_fix_text_chain` |

### the live plant
a fixture is written by whoever wrote the reader, so it inherits that author's blind spot
(`term=floor._.choice._.md`, the precondition). so the widened sudo reader was also planted
into the LIVE tree: one ungated `printf … | sudo tee /etc/probe.conf` at the head of
`1.6.3.earlyoom`, above its gate. the count moved 64 → 65, the row typed `V`, the site was
named. removed the same session (`rule.forbid.repair-plays` EXCEPTION 2).

## .see also
- `term=prose._.choice._.md` — what a segment is NOT, and the reason the cut is quote-aware
- `term=mask._.choice._.md` — the operation that makes the cut quote-aware
- `gotcha.a-check-that-cries-wolf-gets-silenced` — m.8 (tokenizer input) and m.12 (reach)

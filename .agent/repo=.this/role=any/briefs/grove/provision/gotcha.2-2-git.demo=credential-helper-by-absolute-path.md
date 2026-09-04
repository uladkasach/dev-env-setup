# gotcha.2-2-git.demo=credential-helper-by-absolute-path

## .what

the dated measurement behind `2.2.git/configure.upsert.sh`'s absolute-path credential helper
declaration — why it is never named by the bare word `keyrack`.

## m1 — one file, five callers, one absent every time but the human's

measured 2026-08-10, `grove-ahbode-v20260810`. the helper file was present and correct;
`~/.local/bin` reached PATH from `~/.zshrc` alone:

| caller | helper found? |
|---|---|
| a human's interactive zsh | ✔ |
| `ssh grove 'git fetch'` | ✋ absent |
| a cron, a ci step, a jest run | ✋ absent |

git never reports "the helper is not on PATH" — it reports only that it could not
authenticate. the symptom names no cause. a PATH fix needs `~/.local/bin` declared in
`.zshrc`, `.zshenv`, `.profile`, `.bash_profile`, and cron — five declarations of one fact,
each able to drift. an absolute path is the one declaration every caller obeys.

a rename of the helper FILE still breaks this silently, so `configure.verify` diffs the
installed copy against the checkout.

## .see also

- `gotcha.a-tool-found-by-path-answers-only-a-human` — the general form of m1
- `rule.require.reach-credentials-through-keyrack`

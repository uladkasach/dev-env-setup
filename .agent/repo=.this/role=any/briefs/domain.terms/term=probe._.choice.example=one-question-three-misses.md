# domain.term.choice.example: probe — one question, three misses

## .what

three probes, all asking the SAME question — *"does this box export `AWS_PROFILE`?"* — and each
wrong in a different way. measured on grove-1 across 2026-08-06 → 2026-08-08.

one artifact, one question, three distinct failure shapes. this is the cluster's clearest
illustration because the question never changes: every difference is in the probe.

## .why this pair earns a file

the term's say-file names four hazards in prose. those four were each measured on a different
subject, so a reader must trust that they are one family. here they are one subject, so the
family is visible: **a probe can be bounded, honest, and relevant and still answer about
something other than what you asked.**

## ── miss 1: it could not reach its subject, and answered anyway

the first probe asked a LOGIN shell whether it exported the variable:

```sh
ssh grove-1 'echo "${AWS_PROFILE:-}"'
```

a non-login, non-interactive ssh shell sources no rc file. so the probe measured a shell that
reads none of the four files in question, and reported its silence as *"the box exports no
value"* — about a box on which every duct pane carried `ambient`.

⇒ **the probe never reached the subject.** it did not decline; it answered.

this is the say-file's remote hazard (1) in its purest form: the shell was part of the
question, and the probe took the shell's answer for the machine's.

## ── miss 2: it reached the WRONG subject

the fix for miss 1 was to ask a real zsh. the probe became:

```sh
zsh -c 'printf "%s" "${AWS_PROFILE:-}"'
```

which is correct in shape and wrong in scope, because **`zsh -c` INHERITS the caller's
environment.** so when the play ran from a pane that already carried `AWS_PROFILE=ambient`,
the probe printed `ambient` — and the play reported

```
✋ a fresh non-interactive zsh exports AWS_PROFILE='ambient'
```

about a box whose `~/.zshenv` had been proven, one step earlier in the same run, byte-identical
to a checkout that exports none.

⇒ **the probe asked about a FILE and answered about a SESSION.** both facts were true; the
probe joined them and produced a falsehood.

the fix is one word:

```sh
env -u AWS_PROFILE zsh -c 'printf "%s" "${AWS_PROFILE:-}"'
```

`env -u` is what makes the question be about the file. without it the probe cannot distinguish
"no file sets this" from "the caller happens not to".

⚠️ note the asymmetry that makes this hazard mean: miss 2 produced a FALSE ALARM, where miss 1
produced a false ✔. a probe that cries wolf gets silenced
(`gotcha.a-check-that-cries-wolf-gets-silenced`), so a false alarm is not the safe failure it
looks like.

## ── miss 3: it asked a complete question about an incomplete set of writers

with `env -u` in place the probe was, at last, correct: it asked the files, it answered the
files, and it went green —

```
• a fresh NON-INTERACTIVE zsh exports NO AWS_PROFILE ✔ (the rack is not shadowed)
```

and every duct pane on that box STILL carried `ambient`.

because **tmux keeps its own environment**, captured once and copied into every pane it spawns
thereafter:

```
$ tmux show-environment -g | grep -i aws
AWS_PROFILE=ambient
AWS_SDK_LOAD_CONFIG=1
```

the server had captured the value back when `~/.zshenv` still exported it. the file was
corrected; the server's copy was not, and it outlives a pane reboot — a rebooted pane inherits
the SERVER's environment, so the reboot re-injects the very value it was run to clear.

⇒ **the probe enumerated the writers it knew, not the writers there were.** four zsh files
were asked. a fifth writer existed and was never in the question.

the fix is a second claim beside the first, not a change to it — the file check was never
wrong, only incomplete:

```sh
tmuxenv="$(tmux show-environment -g 2>/dev/null | grep '^AWS_PROFILE=' | head -1)"
```

## .the shape the three share

| miss | the probe was | it answered about | the tell |
|---|---|---|---|
| 1 | out of reach of its subject | a shell that reads no rc file | a ✔ on a box that fails |
| 2 | in reach of the wrong subject | the caller's session, not the file | a ✋ on a box that is fine |
| 3 | in reach of an incomplete subject | 4 of 5 writers | a ✔ that survives the fix |

each passes the say-file's third test — *"if the defect were present, would this probe go
red?"* — for the defect it was aimed at. each fails the fourth — *"is the defect reachable from
here, right now?"*

## .the discipline this leaves

before you trust a probe about an environment variable, ask it in this order:

1. **who can write this?** enumerate every writer, then ask about each. an unenumerated writer
   is a silent ✔ (miss 3)
2. **is my caller one of them?** if the answer could be inherited, clear it — `env -u` (miss 2)
3. **does my probe's context read what I am asking about?** a shell kind that sources no rc
   file cannot answer a question about rc files (miss 1)

⇒ and the general form, which is the one worth carrying: **a probe answers about whatever it
actually touched.** the question you meant is not a property of the probe; it is a property of
what the probe reached.

## .refs

- `src/grove.provision/5.devtools/5.6.aws/configure.verify.sh` — claims 4 and 4b, the two-writer form
- `.agent/repo=.this/role=any/briefs/creds/howdoes.a-box-reach-an-aws-account.md` — the writers, enumerated
- `rule.require.trust-but-verify` — the general rule all three break. ⚠️ it is a SHIPPED
  brief of the `ehmpathy/mechanic` role, so it has NO path in this checkout. this line
  gave one under this repo's own briefs dir until 2026-08-14, and a reader who followed
  it found no file — from which the only available conclusion is that the rule does not
  exist. cite a shipped brief by NAME, never by path.

  ⚠️ and the first correction of this line kept the bad path in BACKTICKS, to show what
  was wrong — which `prove.see-alsos-point-somewhere` read as a fresh pointer, because a
  quoted path under `.refs` is indistinguishable from a live one. a correction that
  QUOTES a dead path inside a pointer section re-creates the defect it records.
- `.agent/repo=.this/role=any/briefs/evidence/gotcha.a-check-that-cries-wolf-gets-silenced.md` — why miss 2 is not the safe failure

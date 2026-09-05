# domain.term: hazard

term.chosen   = hazard
term.kind     = noun
term.synonyms.forbidden:
- gotcha        # ⚠️ NOT a synonym — a distinct kind. see `.the split` below
- risk
- pitfall
- caveat
- warn
- footgun

## .what
a brief that names a property of a subject which **HOLDS RIGHT NOW** and will bite whoever
forgets it — stated in the present tense, and true whether or not it has ever fired.

`src/bash_aliases.sh` IS sourced rather than executed, so a parse error anywhere kills every
alias silently. that was true before anybody was bitten, is true today, and stays true after
the fix. a hazard names the shape of the trap, never the day it closed.

## 🛑 .the split — `hazard` vs `gotcha`

they are the two halves of one axis, and the axis is **has it fired?**

| | `hazard.` | `gotcha.` |
|---|---|---|
| tense | present — it holds | past — it bit |
| evidence | a property of the subject | a MEASUREMENT, with a date and an output |
| subject | the trap | the day it closed |
| lifespan | until the property changes | forever, as a record |

⇒ a hazard can EARN a gotcha: the day one fires, you own a measurement, and that measurement
is a `gotcha.` beside it. **a gotcha can never become a hazard** — a measurement does not
un-happen. so the pair is one-directional, which is what makes it a real split rather than a
mood.

⚠️ **a hazard with a measurement inside it is a `gotcha.` misfiled**, and it is the easy
mistake: you find the property BECAUSE it bit you, so the two arrive together. file the
measurement as the gotcha, and keep a hazard beside it only where the property outlives the fix.

## .refs
- `.agent/repo=.this/role=any/briefs/creds/hazard.secrets-in-argv.md`
- `.agent/repo=.this/role=any/briefs/creds/hazard.claude-oauth-one-holder-per-token.md`
- `.agent/repo=.this/role=any/briefs/creds/hazard.claude-oauth-refresh-rotation.md`
- `.agent/repo=.this/role=any/briefs/creds/hazard.claude-oauth-user-agent-429.md`
- `.agent/repo=.this/role=any/briefs/creds/hazard.claude-usage-endpoint-is-undocumented.md`
- `.agent/repo=.this/role=any/briefs/evidence/hazard.a-clamp-can-lie-the-same-way-code-can.md`
- `.agent/repo=.this/role=any/briefs/evidence/hazard.a-clamp-for-a-hang-needs-a-timeout.md`
- `.agent/repo=.this/role=any/briefs/evidence/hazard.route-cached-reviews-go-stale.md`
- `.agent/repo=.this/role=any/briefs/shell/hazard.bash-aliases-parse-silently.md`
- `.agent/repo=.this/role=any/briefs/desktop/nvim/nvim.hazard.async-refresh-on-quit.md`   # infix
- `.agent/repo=.this/role=any/briefs/desktop/term/kitty.hazard.copy-forward-regressions.md`  # infix
- `.agent/repo=.this/role=any/briefs/creds/howto.review-public-repo-hazards.md`  # the word as a plain noun

⚠️ the last three predate the 9 above and were authored on this branch, so **`hazard` is not a
word the port introduced** — the port only made its absence from `briefs/.readme.md`'s prefix
table visible.

## .reason
see the ref-level cluster beside this choice:
- `term=hazard._.choice.reason.md` — etymology, the `gotcha` dispute, the prefix-vs-infix
  question, evidence

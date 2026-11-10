# domain.term.choice.reason: unjudged-hook

## .etymology
the word names what the bundle does with the hook: it declines to judge it. the hook stays, and a
human decides. `foreign` named where the author came from, which the bundle cannot know, and it
collided with the "foreign write" of the wish (a write from outside dev-env-setup), a different
concept on the same page.

## .disputes
### dispute: foreign — raised 2026-10-20 — status: RESOLVED (keep `unjudged hook`)
- raised.by  = peer review r11 (arch-defects), concern 3
- claim      = `foreign hook` is short, and the code already said it
- counter    = `foreign write` already names a write from outside this repo. two senses on one word
               is an overload (`rule.forbid.domain-term-ambiguity`)
- resolution = `unjudged hook` for the hook; `foreign write` stays for the write

## .evidence
- the three cases an `author` field can hold: `repo=…` → a role hook, stripped · absent → a
  commander hook, kept · any other value → an unjudged hook, kept and named ✋
- invariant: an apply never strips an unjudged hook, and never goes green while one stands

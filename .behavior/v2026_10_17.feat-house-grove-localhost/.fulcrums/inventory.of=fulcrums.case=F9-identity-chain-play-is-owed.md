# F9 — `prove.grove-aws-identity-chain` is owed, not extended

## .the premise
the wish lists, under *verified facts*: *"`prove.grove-aws-identity-chain` already exists as the
regression clamp for the identity chain … extension looks cheaper than a new clamp"*.

## .what was measured
- `rhx play.run --list` → 38 tracked plays; neither `prove.grove-aws-identity-chain` nor
  `prove.aws-reach-set` is among them
- `git log --all -S 'grove-aws-identity-chain'` → only commits that ADD the name to two briefs
  (`howdoes.a-box-reach-an-aws-account.md:220`, `howto.give-a-box-an-aws-account.md:168`) and a
  route yield. no play file under that name has ever been committed

⇒ both plays were run on grove-1 in august as transient plays, and their names outlived them
in the briefs (`gotcha.my-own-note-became-my-evidence` — a claim whose every reference is prose).

## .taken
write `prove.grove-aws-identity-chain` as a permanent play in this tree, from the questions the
briefs say it asked: a bare `aws` call finds a region + the box badge; the rack name resolves to
a profile; sts through it lands in the account asked for. it must pass on EC2 and on a house
grove alike.

## .rework
clean.

## .confidence 95%

## .where
case=4 `[t6]`; yield `.groundwork`.

## .risk: risky
the play exercises the live badge: it signs a session from the cert and hops roles in the prep account. it writes nothing in AWS, but it reads and uses a credential on every run, so its output must never echo one.
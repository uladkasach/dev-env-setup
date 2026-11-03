# F017 — where a hetzner grove's github token lives (for the commander)

- **the point:** r11 (i007) reports that `5.4.gh` assumes every cloud box is ec2, a miss of the
  F006 tier-gate audit. 📌 relayed from r11, unverified here — `5.4.gh` was not read this round
  (director's spend cap)
- **the question, for the commander:** where does a hetzner grove's github token live?
  - **a. `os.secure` on the grove** — the shape `rule.forbid.aws-params-off-ec2` already sets for
    every box off ec2; `5.4.gh` gates its `aws.params` read on `*@aws.ec2`. **lean**
  - b. a second ec2-backed store the hetzner box reaches by credential — forbidden by that rule
    unless it is amended
- **taken here:** none. the gate is a change to a bundle this pr leaves untouched, and it is
  proven only on a hetzner grove. it follows the commander's answer, as its own change
- **rework:** clean — one gate in `5.4.gh`
- **confidence 70%:** the lean follows an extant rule, but the defect is relayed, not read
- **verdict — ruled by the director, 2026-10-29: (a) `os.secure`.** built in this pr:
  - `5.4.gh/configure.upsert.sh` picks the vault by platform: `aws.params` on `*@aws.ec2`, `os.secure` on every other box. the read names no vault, so only the fix-texts follow it
  - `5.4.gh/configure.verify.sh` names the same vault in its fix
  - the interim halt (no vault named off ec2) is gone
  - clamp: `prove.gh-names-no-aws-params-off-ec2`. on hetzner and a house box, no call and no fix names aws.params, and the fix names `--vault os.secure`. the ec2 control still names aws.params
  - `rule.forbid.aws-params-off-ec2`'s row now reads `aws.params on ec2; os.secure off it`
  - open proof: a run on a hetzner grove. that grove is not reachable from this pr; it rides on infra's platform file

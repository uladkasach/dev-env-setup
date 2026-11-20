# fulcrums — summary

| case | title | rework | status | confidence |
|---|---|---|---|---|
| F1 | `ambient` on hetzner mirrors `[default]`'s endpoint | clean | best-guessed, open | 65% |
| F2 | `1.14.updates` applies on every box, the laptop included (re-taken from cloud-only on peer review) | clean | best-guessed, open | 80% |
| F3 | grove reach (ssh alias, tailnet, no ssm) is out of this route's scope | clean | ruled — out of scope (S2) | 85% |
| F4 | a hand-laid unfenced hop is refused, never adopted or deleted | clean | best-guessed, open | 75% |
| F5 | hetzner hops carry ec2's body + an endpoint line, not the wish's `source_profile = default` | clean | settled by measurement — B fails live: `source profile "default" must have credentials` | 95% |
| F6 | the boot lays `/etc/grove/platform` from the registry, since #64 lays none | clean | closed — A holds; the bootstrap's write is handed to infra | 75% |
| F7 | reach is fixed in-route after all (S8 reopens F3: the boot cannot run without it) | clean | best-guessed, open | 85% |
| F8 | every box defaults to the `.nvmrc` node (22.21.0), not `lts-latest` — the laptop moves 24 → 22 on its next apply | clean | best-guessed, open | 70% |
| F9 | the box's own aws identity is read by `aws sts`, not keyrack (peer r1.b5) | clean | disputed; carve-out added to the keyrack brief | 85% |
| F10 | the vision names its contract and stays as approved (peer r8.b1) | dirty | disputed; the human holds the stone's shape | 80% |
| F11 | the vision's demos are present; the diff scope did not read them (peer r8.b3) | clean | disputed with a glob | 95% |
| F12 | a play's fixture account id stays a numeric dummy, never `<acct>` (peer r1.b1, i001) | clean | disputed; the five dummies are dox.verify's own allow-list, and the input is parsed | 95% |
| F13 | three extant-play edits change an input or a scope, never a claim (peer r2.b3, r4.n3, i001) | clean | disputed; each reason sits inline | 85% |
| F14 | the live contract test is the grove ladder, run on a real grove (peer r2.b4, r3.b1, r4.n5, i001) | clean | disputed; the tofu first contact awaits a fresh grove | 75% |

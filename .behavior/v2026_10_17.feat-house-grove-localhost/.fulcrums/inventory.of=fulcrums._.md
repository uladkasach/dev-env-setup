# inventory.of=fulcrums — 1.vision, house grove

every call below was best-guessed at vision time, itemized at the moment it was made. the
council sorts on `rework`.

| case | title | rework | status | confidence |
|---|---|---|---|---|
| F1 | the authority form: `house://<name>`, never `house://localhost` (Q4) | clean now; dirty once nheuron#18 parses it | best guess — commander's, S2; joint with nheuron#18, infra#36 | 75% |
| F2 | seat unix names: `<name>-camper` / `<name>-ground` | clean now; dirty once a seat is minted | open | 60% |
| F3 | the house ground holds NOPASSWD sudo on the host | clean | open — rides on F14 | 55% |
| F4 | reach: a dedicated loopback sshd unit; `ssh.service` + `ssh.socket` masked before `openssh-server` lands | clean | open | 75% |
| F5 | env: tier `house`, server `house@unix`, a declared marker probed before the desktop | clean | open | 80% |
| F6 | badge: Roles Anywhere via `credential_process`, cert + key 0600 in the camper home | clean on the box half; the CA choice is #36's | open — joint with infra#36 | 70% |
| F7 | ci clamp: two plays — box half in ci, aws half where the trust exists | clean | **ruled: C** — director, S1 | 75% |
| F8 | the badge sits on the camper seat only; ground gets none | clean | open | 60% |
| F9 | `prove.grove-aws-identity-chain` is written new — it does not exist | clean | settled by measurement | 95% |
| F10 | each house seat's slice pages first (`MemoryHigh`), kills only past a backstop (`MemoryMax`) | clean | **ruled: C, in this stone, values kept** — director, S1 | 65% |
| F12 | the house ground authorizes the human's yubikey-held key; no ground key file is minted | clean | open | 70% |
| F11 | the mint is an election + a host bundle; the skill writes no `/etc` itself | clean | open | 85% |
| F13 | Q1: the box half needs no AWS-side change; the identity play waits on #36's trust | clean | best guess — commander's, S2 | 80% |
| F14 | A: the house grove keeps its own ground seat | clean now; moderate once minted | best guess — commander's, S2 | 60% |
| F15 | B second half: record and accept the 7-day cert-copy risk; the key path stays one line | clean | best guess — commander's, S2 | 70% |

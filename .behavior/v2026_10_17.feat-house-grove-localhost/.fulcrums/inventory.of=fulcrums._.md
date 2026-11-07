# inventory.of=fulcrums — 1.vision, house grove

every call below was best-guessed at vision time, itemized at the moment it was made. the
council sorts on `rework`.

`risk` grades what the call touches, never how sure it is: **risky** = it touches a
credential (a key, a cert, a badge, a login, a root grant) or a prod write; **low** = neither.
"prod" is a live AWS account or a released artifact; a write to the laptop's `/etc` is graded
by what it writes — a sudo grant or an `authorized_keys` line is a credential, a slice cap or a
marker file is not. each entry's `.risk` holds its reason.

| case | title | rework | risk | status | confidence |
|---|---|---|---|---|---|
| F1 | the authority form: `house://<name>`, never `house://localhost` (Q4) | clean now; dirty once nheuron#18 parses it | low | **open — commander's**, S4; joint with nheuron#18, infra#36 | 75% |
| F2 | seat unix names: `<name>-camper` / `<name>-ground` | clean now; dirty once a seat is minted | low | open | 60% |
| F3 | the house ground holds NOPASSWD sudo on the host | clean | **risky** | **open — commander's**, S4 | 55% |
| F4 | reach: a dedicated loopback sshd unit; `ssh.service` + `ssh.socket` masked before `openssh-server` lands | clean | **risky** | **ruled: yes** — director, S4 | 75% |
| F5 | env: tier `house`, server `house@unix`, a declared marker probed before the desktop | clean | low | open | 80% |
| F6 | badge: Roles Anywhere via `credential_process`, cert + key 0600 in the camper home | clean on the box half; the CA choice is #36's | **risky** | **ruled: yes** — director, S4; the CA is infra#36's | 70% |
| F7 | ci clamp: two plays — box half in ci, aws half where the trust exists | clean | low | **ruled: C** — director, S1 | 75% |
| F8 | the badge sits on the camper seat only; ground gets none | clean | **risky** | **ruled: yes** — director, S4 | 60% |
| F9 | `prove.grove-aws-identity-chain` is written new — it does not exist | clean | **risky** | **ruled: yes** — director, S4 | 95% |
| F10 | each house seat's slice pages first (`MemoryHigh`), kills only past a backstop (`MemoryMax`) | clean | low | **ruled: C, in this stone, values kept** — director, S1 | 65% |
| F11 | the mint is an election + a host bundle; the skill writes no `/etc` itself | clean | **risky** | **ruled: yes** — director, S4 | 85% |
| F12 | the house ground authorizes the human's yubikey-held key; no ground key file is minted | clean | **risky** | **open — commander's**, S4 | 70% |
| F13 | Q1: the box half needs no AWS-side change; the identity play waits on #36's trust | clean | low | **ruled: yes** — director, S4 | 80% |
| F14 | A: the house grove keeps its own ground seat | clean now; moderate once minted | **risky** | **ruled: keep** — director, S4 | 60% |
| F15 | B second half: record and accept the 7-day cert-copy risk; the key path stays one line | clean | **risky** | **open — commander's**, S4 | 70% |
| F16 | the house election: `/etc/grove/house.d/<grove>`, root 0644, one `camper`/`ground <user>` line per seat | clean now; dirty once minted | low | open | 80% |

# rule.always.question-your-first-take.example.case=a-hand-step-the-box-could-answer

> 📍 2026-11-22 · uladkasach/dev-env-setup · bundle `5.26.commitorgs`, skill `git.grove.auth.commit.set`
> ⇧ parent: `rule.always.question-your-first-take`

## .the take that shipped

a crew on a cloud grove was refused at commit: `no org config for <org>`. the design:

- a hand-kept table in the bundle declares which orgs each grove commits for
- the bundle only reads the org commit meter, and names a grant
- a new laptop skill runs `ssh -t` to the grove and makes the grant, and it decides *"a human
  is here"* from the tty

## .the counter-take in view

- the grove already holds the answer: its github token reaches exactly the orgs it may work
  in. a table a human keeps in sync is a second copy of that fact
- a command the human types per grove is a hand step — a provision defect
  (`rule.forbid.deferred-provision-defects`)
- a tty proves no human (`rule.forbid.tty-as-a-proxy-for-a-human`); a clone can open one

## .the read that would have broken it

- `5.10.repos/provision.verify.sh` already reads which orgs the box's token can see
- `rule.forbid.tty-as-a-proxy-for-a-human`, in the same briefs dir the design cited

## .the cost

a table, a skill, a grant cwd with a pinned role, and a boot relay — all to keep a human in a
loop the box could close by itself. the human found it from the pr body.

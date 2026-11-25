# rule.always.question-your-first-take.example.case=a-fix-text-for-another-seat

> 📍 2026-11-22 · uladkasach/dev-env-setup · branch `beav/fix-hetzner-grove-org-commit-config`
> ⇧ parent: `rule.always.question-your-first-take`

## .the take that shipped

`rhx git.commit.push` failed on the human's laptop:

```
git-credential-keyrack: no readable @all.camp.GITHUB_TOKEN — declines
fatal: could not read Username for 'https://github.com/…': No such device or address
```

the take: *the camp key is locked or absent; the human must unlock it, set it, or push by hand.*
it was relayed to the human three times, with the helper's own fix lines.

## .the counter-take in view

the laptop is `local@unix`. no local grove holds an `@all.camp` key, by rule
(`rule.require.aws-params-on-camp-groves-only`). a fix-text that asks a local grove for a camp
key names a seat the box is not — so the push took a path a laptop never takes.

## .the read that would have broken it

- `define.github-auth-two-paths`: a laptop pushes over ssh; the keyrack helper is never called
  for an ssh remote
- the error line itself: `https://github.com/…` — the remote of this worktree is https

two reads, both cheap. the cause was the remote, never a credential.

## .the cost

the human was handed four steps that were his to never see, and a laptop unlock was run that
could not help.

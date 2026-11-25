# rule.always.question-your-first-take.example.case=a-grove-waits-on-main

> 📍 2026-11-22 · uladkasach/dev-env-setup · branch `beav/fix-hetzner-grove-org-commit-config`
> ⇧ parent: `rule.always.question-your-first-take`

## .the take that shipped

*the hetzner grove still cannot commit until the branch is pushed and merged, and the human
runs the grant.*

## .the counter-take in view

the same report said the new bundle had already been applied twice on that grove and
converged. a box that already runs the code cannot wait on a merge for it.

## .the read that would have broken it

`repo.overview` and `git.grove.push`: a cloud grove converges from the CHECKOUT — the worktree
is rsynced to the box, then `grove.provision --mode apply` runs there. github and main are no
part of that path.

## .the cost

a false dependency put a merge in front of the crews, and the human had to explain how his own
repo provisions a grove.

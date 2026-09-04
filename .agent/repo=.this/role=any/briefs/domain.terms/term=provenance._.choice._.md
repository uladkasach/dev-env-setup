# domain.term: provenance

term.chosen   = provenance
term.kind     = noun
term.values   = `cloned` | `pushed`
term.synonyms.forbidden:
- source (already names the `src/` dir in this repo — an overload)
- origin (git's own word for a remote; a pushed src has no origin at all)
- how (a bare question word, not a property of the src)
- state (says what it IS; provenance says where it CAME FROM)

## .what
how a tree src arrived on a machine — and therefore how it is refreshed.

| value | how it arrived | how it refreshes |
|-------|----------------|------------------|
| `cloned` | `git clone` from origin (anonymous https) | `git.repo.pull` |
| `pushed` | `grove.push` rsync from a laptop worktree | another `grove.push` |

both are legitimate. a `pushed` src has no `.git` **by design**: `grove.push` exists so a change
can be proven on a grove BEFORE it is merged, which is the whole value of a grove as a
verification surface.

## .why the term is needed
a machine's src looks the same either way — same files, same driver. the difference stays
invisible until a tool tries to refresh it, and then a tool that assumed the wrong provenance
either fails with a message that misdirects, or destroys work under test.

so a tool that touches a src must **name** the provenance it found, and act accordingly. it must
never treat one as a defective form of the other.

## .the invariant
> a pushed src is not a broken clone. never repair one into the other unasked.

## .refs
where the term is used:
- grove.bootstrap.sh                                       # names it, then acts on it
- .agent/repo=.this/role=any/skills/git.grove.push.sh       # the operation that creates a pushed src

## .reason
see the ref-level cluster beside this choice:
- `term=provenance._.choice.reason.md` — etymology, the defect that settled it, and why the
  values are a closed pair

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

## 🛑 .the ONE place provenance IS reported — and it read the wrong tree for months

`grove.env.sh` derives `$commit`, which every apply and plan prints in its header:

```
🌲 grove.provision done — access prep · server cloud@aws.ec2 · commit none@none
```

that line is this term, surfaced: `none@none` says **pushed**, a `ref@hash` says **cloned**. so
the difference is not invisible after all — a reader consults this line to learn it.

📜 measured 2026-09-08 on `grove-ahbode-v20260811`, camper seat. the derivation ran a **bare**
`git rev-parse`, which reads the CALLER's cwd. a duct pane sits wherever it was last left, and
that one sat in `$HOME/git/ehmpathy/rhachet-roles-ehmpathy` — so an apply of THIS repo reported
`commit v1.38.12@2ad9911`, another project's tag, over a checkout that holds no `.git` at all.

⚠️ **and the three seats that printed `none@none` were no better off.** their panes simply sat
somewhere with no repo overhead. all four answers were an accident of cwd; two were right by
luck. a `pushed` verdict that happens to be correct was still never read.

⇒ **so a tool that reports provenance must read the CHECKOUT, and must confirm the checkout IS
the repo root.** `git -C <dir>` alone is not enough — it walks up the parents, and a pushed
checkout has no `.git`, so an ancestor answers for it and the stamp is foreign again, one dir
over. `rev-parse --show-toplevel`, compared against the checkout, is the exact test.

⚠️ the repair keys on `${BASH_SOURCE[0]}`, never on cwd and never on `$GROVE_SRC`
(`grove.for.sh:49` calls the derivation with no `GROVE_SRC` set). the file lives in the
checkout's `src/`, so its own path names the tree that actually runs — which is the subject the
line claims.

## .refs
where the term is used:
- grove.bootstrap.sh                                       # names it, then acts on it
- .agent/repo=.this/role=any/skills/git.grove.push.sh       # the operation that creates a pushed src
- src/grove.env.sh                                          # `$commit` — the one place it is REPORTED, and the 2026-09-08 measurement

## .reason
see the ref-level cluster beside this choice:
- `term=provenance._.choice.reason.md` — etymology, the defect that settled it, and why the
  values are a closed pair

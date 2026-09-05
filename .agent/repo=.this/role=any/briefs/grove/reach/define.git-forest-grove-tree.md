# define: forest / grove / tree

## .what

the three-level vocabulary for where work happens, from widest to narrowest:

| term | what | scale | example |
|------|------|-------|---------|
| **forest** | all groves together — the full inventory of machines | many machines | your whole fleet |
| **grove** | one machine (a host) that holds trees | one machine | `localhost`, `ec2-user@grove-1` |
| **tree** | one git worktree + its session on a grove | one branch | `feat/auth` at `_worktrees/repo.feat-auth/` |

read it as containment: a **forest** contains **groves**; a **grove** contains **trees**.

## .why the distinction matters

**tree** and **grove** answer different questions, and to conflate them is the trap:

- **tree** answers *"which branch is checked out?"* — it is a worktree, a checkout of a
  branch into its own directory, with its own terminal/tmux session. many trees can live
  on one machine.
- **grove** answers *"which machine holds that work?"* — it is the host. a tree lives *in*
  exactly one grove.

`localhost` is a grove. an ec2 box is a grove. a tree named `feat/auth` might live in the
`localhost` grove today and a cloud grove tomorrow — the tree is the same concept, the
grove is where it is rooted.

> a tree is a branch workspace. a grove is a machine. a forest is every machine at once.

## .the tree level

```bash
git tree get                      # list worktrees for current repo
git tree set <branch> --from main # create/find a worktree (tree) for a branch
git tree del <branch>             # remove a worktree
git tree status --repo @all       # worktree status across all repos
```

- trees live at `@gitroot/../_worktrees/$reponame.$branch/`
- `git tree` carries no notion of grove — every tree it makes is on the local machine
- see `git_alias_tree` in `src/bash_aliases.sh`

## .the grove level

```bash
git grove set <name> --exid <tag> --env camp --account <id>   # register
git grove list                                                 # every registered grove
git grove get <name>                                           # one grove's record
git grove del <name>                                           # drop the record
git grove send <name> --what '<cmd>'                           # drive it through its duct
git grove read <name>                                          # read what the duct holds
```

- the dispatcher is `_git_grove` in `src/bash_aliases.sh`; the registry is one json file
  per grove under `~/.git.forest/groves`
- the richer operations are skills, not aliases —
  `.agent/repo=.this/role=any/skills/git.grove.*.sh` carries `wake`, `stop`, `push`,
  `push.verify`, `pull`, `trust.gen`, and `infra.operations` beside the six above
- a cloud grove is addressed by its **exid** (its Name tag), never by instance id, so
  `wake` finds the box by tag and the record survives a replacement (`term=exid`)

## .the forest level

`~/.git.forest/` IS the forest: the registry root that holds every grove record. it needs no
command of its own — `git grove list` is the forest view.

## .what is NOT built

- **a tree that names its grove** — `git tree set --grove <g>`. `git tree` and `git grove`
  are two flat namespaces, and no field joins a tree to the machine it lives on. so the
  forest view is a list of groves, never a tree of groves-with-their-trees.
- **a forest-view `git tree status`** — the cross-grove rollup. it waits on the join above,
  because a status that cannot say which grove a tree sits in is the one
  `git tree status --repo @all` already gives.

## .provenance

the grove and forest levels are built. the dreams hold why the shape is what it is:

- `.dream/2026_06_17.git-forest.dream.md` — the three-level model
- `.dream/2026_06_14.cloud-agent-host.dream.md` — groves as hibernatable ec2 hosts,
  woken via declastruct, reached over ssh-over-ssm
- `.dream/2026_06_17.ductwork-hosts.dream.md` — the ductwork parallel: a duct lives on a
  host (grove); `duct.list` groups ducts by host

what the JOIN above would look like, and the only part still unbuilt:

```bash
git tree set --grove grove-1 --as feat-auth   # a tree that names its grove
git tree status                                # forest view: groves, each with its trees
```

## .how it relates to ductwork / termwork

these layers each own one slice, and must not absorb the others (see
`termwork.scope-boundary.md`):

| layer | owns | knows about grove? |
|-------|------|--------------------|
| **termwork** | terminals + tabs by slug | no — a caller may map one terminal per tree, but termwork never reasons about tree or grove |
| **ductwork** | ducts (headless tmux sessions), addressable `user@host:name` | yes, at the transport level — a duct lives on a host |
| **git tree / grove / forest** | worktrees and the machines that hold them | yes — this is the layer that names groves |

the grove is the shared idea of "a machine that holds work"; ductwork calls it a *host*
in `user@host:name`, and git-forest calls it a *grove*. they are the same physical
machine, seen from two vantage points — keep the correspondence explicit, do not merge
the layers.

## .the test

- to name a **branch workspace** → say **tree**
- to name a **machine / host** → say **grove**
- to name **all machines at once** → say **forest**

if a design says "tree" but means "the machine", or "grove" but means "the branch
checkout", stop — the level is wrong.

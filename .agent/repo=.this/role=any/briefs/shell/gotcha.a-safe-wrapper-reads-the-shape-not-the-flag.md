# gotcha: a `*safe` wrapper branches on the SHAPE of its input, not on what the flag says

## .what

`mvsafe`, `rmsafe`, `cpsafe` read like declarations — `--into <dir>`, `--path <p>`. they are
not. each branches on the **shape** of what it was handed, and each prints the same success
line for every branch.

two measured instances, 2026-09-02, one hour apart, on the briefs reorg.

## .instance 1 — `mvsafe --into` means DIR or NEW NAME, by shape

| `--from` matches | `--into` dir exists | what happens |
|---|---|---|
| many files (a glob) | no | dir is created, filenames kept ✔ |
| many files (a glob) | yes | files placed inside ✔ |
| **one file** | yes | file placed inside ✔ |
| **one file** | **no** | 🛑 the file is **RENAMED TO THE DIR PATH** |

so a cluster move done one file at a time, into a dir that does not exist yet, makes the dir
name a **file** — and every later move into that "dir" **overwrites** it.

⚠️ **it prints success every time.** the only tell is in the arrow:

```
👍 …/rule.forbid.repair-plays.md -> …/grove/play/rule.forbid.repair-plays.md   ← dest ends in a FILENAME
👎 …/rule.forbid.repair-plays.md -> …/grove/play                               ← dest ends in the DIR
```

⇒ **measured cost: 7 clusters collapsed to 7 files, 60+ briefs off disk.** every one was
recoverable from the git index, and the ~21 that carried **unstaged** edits lost those edits
for good.

## .instance 2 — `rmsafe` honors only the LAST `--path`

```sh
rhx rmsafe --path a.md --path b.md --path c.md
#   ✔ prints success
#   ✔ deletes c.md
#   🛑 a.md and b.md are untouched, and no row says so
```

`mkdirsafe` accepts repeated `--path` and honors all of them, so the shape is inconsistent
ACROSS the family — which is what makes it invisible: the habit generalizes and the tool does
not.

## .why both are the corrosive kind

each is a **false ✔** (`evidence/gotcha.a-check-that-cries-wolf-gets-silenced`): the operation
reports success and did something other than what it said. no verdict flickers, so the defect
surfaces only when a later reader finds the tree wrong — which for a move is a
**reader-scope** event, and those go unnoticed for weeks.

## .the rule

> **create the target dir FIRST, then move. one `--path` per `rmsafe` call.**

```sh
rhx mkdirsafe --parents --path '<dir>'          # ← this line is the whole fix
rhx mvsafe --from '<file>' --into '<dir>/'
```

with the dir extant, the single-file branch places INSIDE it, and the footgun cannot fire.

## .the test

> **does the destination in the output end with the FILENAME, or with the DIR?**

read the arrow, never the ✔. a dest that ends at the dir name is a rename, and the next move
into that name destroys it.

## ⚠️ .and stage before a bulk move

`git add` the tree before any bulk move. the index is then a full snapshot, and
`git ls-files --deleted | git checkout-index -f --stdin` restores every file the move loses.
that is what made this recoverable — the unstaged deltas are what it could not reach.

## .see also

- `evidence/gotcha.a-check-that-cries-wolf-gets-silenced` — the false-✔ family this joins
- `evidence/gotcha.a-partial-write-discards-what-it-never-read` — its near twin: a writer that
  destroys what it never read, and prints success
- `.readme.md` — why a move is a reader-scope event, and the clamp that catches it

# diff boundary navigation

## .what

criteria for ctrl+d j/k navigation in diff buffers.

## usecases

### usecase.1 = jump to chunk edge from inside

given('cursor is inside a diff chunk')
  when('user presses ctrl+d j')
    then('cursor moves to bottom edge of current chunk')
  when('user presses ctrl+d k')
    then('cursor moves to top edge of current chunk')

### usecase.2 = jump to next chunk from edge

given('cursor is at bottom edge of a chunk')
  when('user presses ctrl+d j')
    then('cursor moves to top of next chunk')

given('cursor is at top edge of a chunk')
  when('user presses ctrl+d k')
    then('cursor moves to bottom of previous chunk')

### usecase.3 = wrap at file boundaries

given('cursor is at last chunk')
  when('user presses ctrl+d j at bottom edge')
    then('cursor wraps to top of first chunk')

given('cursor is at first chunk')
  when('user presses ctrl+d k at top edge')
    then('cursor wraps to bottom of last chunk')

### usecase.4 = works in both vimdiff and codediff

given('buffer is in vimdiff mode')
  when('user presses ctrl+d j/k')
    then('navigation uses vim diff_hlID for chunk detection')

given('buffer is a codediff pane')
  when('user presses ctrl+d j/k')
    then('navigation uses extmarks for chunk detection')

### usecase.5 = directory edges in the codediff explorer tree

given('cursor is on a row inside a directory in the codediff explorer')
  when('user presses ctrl+d j')
    then('cursor moves to the bottom row of the current directory')
  when('user presses ctrl+d k')
    then('cursor moves to the top row of the current directory')

given('cursor is at the bottom row of a directory')
  when('user presses ctrl+d j')
    then('cursor moves to the top row of the next directory')

given('cursor is at the top row of a directory')
  when('user presses ctrl+d k')
    then('cursor moves to the bottom row of the previous directory')

given('cursor is in the last directory, at its bottom row')
  when('user presses ctrl+d j')
    then('cursor wraps to the top row of the first directory')

- a directory's rows = a maximal run of consecutive rows that share one parent node
- a group header (no parent) belongs to no directory
- same navigator as the diff panes, so edge, next, and wrap behave identically
- clamp: `prove.codediff-explorer-dir-nav`

## .why

standard `]c`/`[c` jumps to top of next chunk. problem: if chunk is 50 lines, you land at line 1 and must scroll to see the rest.

boundary nav solves this:
1. first press: bottom of current chunk (see full context)
2. second press: top of next chunk (ready to review)

result: never land mid-chunk unsure where it ends.

## boundaries

- chunks detected via diff_hlID (vimdiff) or extmarks (codediff)
- fallback to ]c/[c if no chunks found
- works in both normal buffers (gitsigns) and diff panes

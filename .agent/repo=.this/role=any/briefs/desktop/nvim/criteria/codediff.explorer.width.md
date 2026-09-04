# codediff explorer width preservation

## .what

criteria for explorer panel width behavior in codediff.

## usecases

### usecase.1 = initial layout

given('codediff tab opens')
  when('explorer and diff panes render')
    then('explorer has fixed width (30 columns)')
    then('diff panes split rest of width')
    then('old pane gets 1/3, new pane gets 2/3')

### usecase.2 = width preserved on file select

given('explorer has width of 30 columns')
  when('user selects a file')
    then('explorer width remains 30 columns')
    then('diff panes resize to fill rest of space')

### usecase.3 = width preserved on refresh

given('explorer has width of 30 columns')
  when('git status changes trigger refresh')
    then('explorer width remains 30 columns')

### usecase.4 = width preserved on window resize

given('terminal window is resized')
  when('neovim recalculates layout')
    then('explorer width remains fixed')
    then('diff panes absorb size change')

## boundaries

- explorer width: fixed at configured value (default 30)
- diff pane ratio: old 1/3, new 2/3 of rest
- layout.arrange handles all resize scenarios

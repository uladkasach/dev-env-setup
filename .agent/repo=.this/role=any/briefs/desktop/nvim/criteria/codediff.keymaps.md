# codediff keymaps

## .what

criteria for keybindings in codediff tab.

## usecases

### usecase.1 = toggle codediff tab

given('user is in any buffer')
  when('user presses ctrl+g')
    then('codediff tab opens if not open')
    then('focus moves to codediff tab if open but not focused')
    then('focus returns to previous tab if codediff is focused')
    then('the tab shows staged + unstaged + untracked changes')

given('user is in any buffer')
  when('user presses ctrl+shift+g')
    then('a since-main codediff tab opens, toggles, and focuses the same way')
    then('the tab shows every change since merge-base(origin/main, HEAD): our commits + staged + unstaged + untracked')
    then('commits on origin/main that we are behind on do not show')

given('user is in one scope\'s codediff tab')
  when('user presses the other scope\'s key')
    then('the other scope\'s tab opens or focuses')
    then('the current scope\'s tab stays open')

### usecase.2 = open file from explorer

given('cursor is on file node in explorer')
  when('user presses Enter')
    then('diff loads in diff panes')
    then('focus stays in explorer')

given('cursor is on file node in explorer')
  when('user presses o')
    then('file opens in new tab')
    then('codediff tab closes')

### usecase.3 = open file from diff pane

given('cursor is in diff pane')
  when('user presses o')
    then('file opens in new tab')
    then('codediff tab stays open')

### usecase.4 = stage/unstage

given('cursor is on file in explorer or in diff pane')
  when('user presses ctrl+d s or ctrl+d a')
    then('file is staged')
  when('user presses ctrl+d u')
    then('file is unstaged')
  when('user presses ctrl+d x')
    then('unstaged changes are discarded')

### usecase.5 = navigation

given('user is in codediff tab')
  when('user presses ctrl+h/j/k/l')
    then('focus moves between explorer and diff panes')

## boundaries

- ctrl+g: toggle/focus codediff tab (staged + unstaged)
- ctrl+shift+g: toggle/focus codediff tab (all changes since origin/main)
- Enter: load diff (explorer) or default action (panes)
- o: open file (new tab from pane, close from explorer)
- ctrl+d [s|a|u|x]: git operations
- ctrl+h/j/k/l: window navigation

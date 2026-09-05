# codediff explorer collapse/expand

## .what

criteria for directory collapse/expand behavior in codediff explorer tree.

## usecases

### usecase.1 = toggle directory

given('a directory node in explorer')
  when('user presses Enter')
    then('directory toggles between collapsed and expanded')
    then('children are hidden when collapsed')
    then('children are visible when expanded')

### usecase.2 = sync collapse across groups

given('same directory path exists in multiple groups (e.g., src/ in staged and unstaged)')
  when('user collapses directory in one group')
    then('same directory collapses in all groups')
  when('user expands directory in one group')
    then('same directory expands in all groups')

### usecase.3 = groups remain independent

given('multiple groups exist (staged changes, changes, conflicts)')
  when('user collapses a group')
    then('only that group collapses')
    then('other groups remain unchanged')

### usecase.4 = persist state across refresh

given('user has collapsed some directories')
  when('explorer refreshes (git status change, BufEnter)')
    then('collapsed directories remain collapsed')
    then('expanded directories remain expanded')
    then('sync across groups is preserved')

### usecase.5 = manual toggle overrides refresh

given('explorer refresh is in progress')
  when('user manually toggles a directory')
    then('user toggle takes precedence')
    then('refresh does not override user action')

## boundaries

- groups: collapse state stored by group name (independent)
- directories: collapse state stored by path (synced across groups)
- files: not collapsible (Enter selects file)

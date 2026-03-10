# rule.require.solve-at-cause

## .what

solve problems at the root cause, not by workaround of symptoms.

## .why

- workarounds fight the system; source-level solutions work with it
- workarounds accumulate complexity and break when the system changes
- source-level solutions use intended APIs and extension points

## .pattern

| approach | description | stability |
|----------|-------------|-----------|
| symptom reaction | observe behavior, counteract it | fragile |
| root cause | understand cause, address directly | stable |

## .questions to ask

1. what causes this behavior?
2. is there an intended API to control it?
3. can we configure it at the source?

## .example

### symptom reaction (fragile)

```lua
-- codediff resizes explorer, so we restore width after
vim.api.nvim_create_autocmd('BufEnter', {
  callback = function()
    vim.defer_fn(function()
      -- guess time, restore width
    end, 60)
  end,
})
```

### root cause (stable)

```lua
-- codediff has config + event for this
require('codediff').setup({
  explorer = { width = 30 },
})

vim.api.nvim_create_autocmd('User', {
  pattern = 'CodeDiffFileSelect',  -- plugin's own event
  callback = function()
    -- restore at the right moment
  end,
})
```

## .enforcement

before you implement a workaround, ask: "can we solve this at the source?"

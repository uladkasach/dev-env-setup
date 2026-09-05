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

## ⚠️ .a bulk failure is ONE cause repeated, not N causes

when a run fails at scale, the count itself is evidence. measured 2026-08-10: a fresh
grove's first `grove.provision --mode apply` closed 6 of 78 claims.

**72 claims do not have 72 causes.** a box that new has had no time to acquire 72
independent faults, so the right first move is to sort the claims by SHAPE and find the
one fact they share — never to work them one at a time from the top of the list.

that run's 72 sorted into four shapes, and 68 of them read `<binary> is absent from PATH`,
which was a single cause (`gotcha.a-tool-found-by-path-answers-only-a-human`). to have
repaired the first claim on the list would have fixed one row and left 67.

⚠️ and the plan's own output cannot tell you which: a plan reports the STATE, and a bulk
cause is a fact about the RUN. so sort the claims yourself, and let the largest group
name the cause.

⇒ the heuristic: **when a failure count is large, find what the failures have in common
before you read any one of them.**

## .enforcement

before you implement a workaround, ask: "can we solve this at the source?"

- a bulk failure worked one claim at a time, with no sort by shape first = **nitpick**

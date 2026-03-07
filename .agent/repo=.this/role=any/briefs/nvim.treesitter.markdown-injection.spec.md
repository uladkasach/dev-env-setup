# nvim treesitter markdown injection

## .what

syntax colors for fenced code blocks in markdown files (e.g., ```ts, ```lua, ```sh).

## .why

code in markdown without syntax colors is painful. language injection makes code blocks readable.

## .requirements

| req | description |
|-----|-------------|
| parsers | markdown, markdown_inline, and target language parsers installed |
| highlight | treesitter highlight enabled |
| injection | automatic via markdown parser's built-in injection queries |

## .setup

### install parsers

```vim
:TSInstall markdown markdown_inline typescript lua bash
```

### enable highlight

```lua
require('nvim-treesitter.configs').setup({
  highlight = { enable = true },
})
```

## .how it works

treesitter uses `injections.scm` queries to detect code blocks. the markdown parser ships with built-in injection queries that:

1. detect fenced code block nodes (` ``` `)
2. read the language identifier (e.g., `ts`, `lua`)
3. apply the matched language parser for syntax colors

## .verify

check parser status:
```vim
:TSModuleInfo
```

all needed parsers should show `[+]` for highlight.

## .custom injections

for unsupported languages or custom mappings, create:
`~/.config/nvim/after/queries/markdown/injections.scm`

example — map `tsx` to typescript:
```scheme
((fenced_code_block
  (info_string) @language
  (code_fence_content) @injection.content)
  (#match? @language "^tsx$")
  (#set! injection.language "typescript"))
```

## .diagnostics

| symptom | fix |
|---------|-----|
| no colors in code blocks | `:TSInstall markdown markdown_inline` |
| specific language not colored | `:TSInstall <language>` |
| colors flicker or break | check for conflict with syntax plugins |

## .refs

- [nvim-treesitter issue #4915](https://github.com/nvim-treesitter/nvim-treesitter/issues/4915)
- [neovim discourse: highlight code blocks](https://neovim.discourse.group/t/highlighting-code-blocks-in-markdown/4936)

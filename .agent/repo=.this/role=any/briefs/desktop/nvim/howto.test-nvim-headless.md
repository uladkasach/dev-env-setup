# howto: test nvim config + lua headlessly

## .what

run nvim's lua logic (config, plugin glue, utils) without a human at a terminal —
for CI, agent loops, and fast feedback. two levels: **parse** (syntax only) and
**run** (real nvim runtime, real `vim.*` api).

## .why

- nvim config is lua; lua bugs otherwise surface only when a human opens the
  editor. headless testing catches them in seconds.
- `nvim --headless` boots a full nvim (real `vim.api`, `vim.system`, `vim.fn`),
  so tests exercise the true runtime, not a mock.
- pairs with the repo skill `nvim.test.headless` (see below) so an agent can
  verify nvim-side changes via `rhx`.

## .the skill (preferred path)

```sh
rhx nvim.test.headless --check src/init.lua        # parse only (loadfile, no exec)
rhx nvim.test.headless --run tests/foo.test.lua    # run a lua test file
rhx nvim.test.headless --run tests/foo.test.lua --clean  # -u NONE (no user config)
rhx nvim.test.headless --lua "print(1+1)"          # inline snippet
```

exit codes: `0` pass, `1` malfunction (nvim errored / test failed / syntax
error), `2` constraint (bad args, file absent, nvim absent).

## .the raw commands (what the skill wraps)

### parse only — no execution

`loadfile` compiles the chunk but does NOT run it, so it needs no plugins and
catches pure syntax errors:

```sh
nvim --headless -c "lua local ok,err=loadfile('src/init.lua'); print(ok and 'SYNTAX OK' or ('ERR: '..vim.inspect(err)))" -c "qa"
```

use this on a full `init.lua` — it will NOT trigger the plugin `require`s, so it
is safe even when plugins are absent.

### run a lua test file

`-l FILE` runs FILE as a lua chunk in a real nvim, then exits. `os.exit(code)`
sets the process exit code — make failures authoritative:

```sh
nvim --headless -l tests/foo.test.lua
```

### run against a clean config

`-u NONE` skips the user's `init.lua` so a test does not inherit local config:

```sh
nvim --headless -u NONE -l tests/foo.test.lua
```

## .how to write a headless lua test

a good test prints clear `PASS`/`FAIL` lines and exits non-zero on any failure:

```lua
local fails = 0
local function check(name, cond)
  print((cond and 'PASS ' or 'FAIL ') .. name)
  if not cond then fails = fails + 1 end
end

-- pure logic
check('adds', (1 + 1) == 2)

-- real vim.* api is available
check('cwd is a string', type(vim.fn.getcwd()) == 'string')

-- real subprocess via vim.system (nvim 0.10+); text=false keeps bytes intact
local res = vim.system({ 'git', 'rev-parse', '--show-toplevel' }):wait()
check('git ok', res.code == 0)

os.exit(fails > 0 and 1 or 0)  -- authoritative exit code
```

## .gotchas

- **byte-safe subprocess**: for binary output (e.g. `git show HEAD:image.png`)
  use `vim.system({...}, { text = false })` and write with `io.open(path,'wb')`.
  lua strings are byte arrays, so this preserves bytes; `systemlist` /
  `vim.split` on `\n` will corrupt binary.
- **image.nvim warning**: headless prints `image.nvim: cannot query terminal
  size (non-terminal environment?)`. harmless — headless has no tty. it is NOT a
  test failure; the skill's fail-scan ignores it.
- **what headless CANNOT test**: anything that needs a real tty or the kitty
  graphics protocol — actual image render, window pixel layout, true keypress
  routing. those stay manual-verify in a live kitty nvim. headless proves the
  *logic* (path detection, git extraction, branch decisions); the human proves
  the *pixels*.
- **`-l` vs `-c "lua ..."`**: `-l FILE` runs a file and respects `os.exit`;
  `-c "lua ..."` runs an inline chunk then you must `-c "qa"` to quit. prefer
  `-l` for test files.
- **avoid full-config side effects**: `-l` does NOT load your `init.lua`, but
  `-c "lua ..."` (without `-u NONE`) DOES. use `--check`/loadfile or `-u NONE`
  when you only want to test a snippet in isolation.

## .see also

- skill: `.agent/repo=.this/role=any/skills/nvim.test.headless.sh`
- brief: `howto.diagnose-nvim-hang.md` (runtime diagnosis, not testing)

-- headless functional test for the image-diff core mechanisms
-- run: nvim --headless -l .behavior/.../verify.image-diff.lua
--
-- MIRROR PATTERN (maintenance hazard): nvim --headless cannot require() the
-- non-module src/init.lua, so IMAGE_DIFF_EXTS / is_image_diff_path / the
-- has_old,has_new status logic are RE-DECLARED below to match init.lua. if you
-- change either side, update BOTH. on promotion to main, extract these into a
-- lua/image_diff_utils.lua that init.lua requires and this file imports, to
-- retire the mirror.

local fails = 0
local function check(name, cond)
  if cond then
    print('PASS ' .. name)
  else
    fails = fails + 1
    print('FAIL ' .. name)
  end
end

-- 1. is_image_diff_path logic (mirror of init.lua helper)
local IMAGE_DIFF_EXTS = {
  png = true, jpg = true, jpeg = true, gif = true, webp = true, avif = true,
}
local function is_image_diff_path(path)
  if not path then return false end
  local ext = path:match('%.([%w]+)$')
  if not ext then return false end
  return IMAGE_DIFF_EXTS[ext:lower()] == true
end

check('png is image', is_image_diff_path('assets/kitty-icon.png') == true)
check('JPG upper is image', is_image_diff_path('a/b.JPG') == true)
check('webp is image', is_image_diff_path('x.webp') == true)
check('ts is not image', is_image_diff_path('src/init.ts') == false)
check('lua is not image', is_image_diff_path('src/init.lua') == false)
check('no ext is not image', is_image_diff_path('README') == false)
check('nil is not image', is_image_diff_path(nil) == false)

-- 2. byte-safe old-blob extraction: git show HEAD:<path> -> temp file
--    must byte-match the on-disk committed asset (proves no text decode)
local git_root = vim.fn.getcwd()
local rel = 'assets/kitty-icon.png'
local spec = 'HEAD:' .. rel
local res = vim.system({ 'git', '-C', git_root, 'show', spec }, { text = false }):wait()
check('git show exit 0', res.code == 0)
check('git show has bytes', res.stdout ~= nil and #res.stdout > 0)

local tmp = vim.fn.tempname() .. '.png'
local fh = io.open(tmp, 'wb')
fh:write(res.stdout)
fh:close()

-- read both files raw and compare
local function read_bytes(p)
  local f = io.open(p, 'rb')
  if not f then return nil end
  local d = f:read('*a')
  f:close()
  return d
end
local disk = read_bytes(git_root .. '/' .. rel)
local extracted = read_bytes(tmp)
check('extracted size matches disk', disk ~= nil and extracted ~= nil and #disk == #extracted)
check('extracted bytes match disk', disk == extracted)
-- PNG magic bytes: 89 50 4E 47
check('extracted is valid PNG header', extracted ~= nil and extracted:sub(1, 4) == '\137PNG')

os.remove(tmp)

-- 3. absent-side logic: status -> has_old / has_new
local function sides(status)
  local has_old = not (status == 'A' or status == '??')
  local has_new = not (status == 'D')
  return has_old, has_new
end
local mo, mn = sides('M'); check('modified has both', mo == true and mn == true)
local ao, an = sides('A'); check('added has no old', ao == false and an == true)
local uo, un = sides('??'); check('untracked has no old', uo == false and un == true)
local do_, dn = sides('D'); check('deleted has no new', do_ == true and dn == false)

if fails == 0 then
  print('ALL PASS')
else
  print('FAILURES: ' .. fails)
end

-- authoritative exit code: fail loud via the process exit, not only the
-- printed marker, so a caller cannot mistake a failed run for a pass
os.exit(fails > 0 and 1 or 0)

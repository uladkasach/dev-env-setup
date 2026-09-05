#!/usr/bin/env bash
######################################################################
# .what = prove the installed init.lua is THIS checkout's, and that nvim loads it
#
# .why
#   - presence is not currency: only a `cmp` against $GROVE_SRC separates current from stale
#   - a lua syntax error copies perfectly; the load test (howto.test-nvim-headless) is the
#     cheapest read that separates "the bytes arrived" from "it starts"
#   - READ-ONLY throughout; `-n` disables the swapfile, so a concurrent nvim is safe
######################################################################

# .what = print one ✋ (a headline plus optional detail lines); caller sets `failed`
_nvim_verify_say() {
  printf '   ✋ %s\n' "$1" >&2
  shift
  local line
  for line in "$@"; do
    [[ -n "$line" ]] && printf '      %s\n' "$line" >&2
  done
}

grove_provision_4_5_nvim_configure_verify() {
  local bundle_dir="$GROVE_SRC/grove.provision/4.terminal/4.5.nvim"
  local src="$bundle_dir/init.lua"
  local dst="$HOME/.config/nvim/init.lua"
  local failed=0
  # 1. the config is on the box AND matches this checkout
  if [[ ! -r "$dst" ]]; then
    _nvim_verify_say "no nvim config at $dst" \
      "⇒ nvim starts with its defaults: not one keybind, plugin, or theme this repo declares is in effect" \
      "fix: rhx grove.provision --what 4.5.nvim --mode apply"
    failed=1
  elif [[ ! -r "$src" ]]; then
    echo "   🌙 a config is installed, but this checkout has no init.lua to compare it against ($src)"
  elif cmp -s "$src" "$dst"; then
    echo "   • the installed init.lua matches this checkout ✔"
  else
    _nvim_verify_say "the installed init.lua DIFFERS from this checkout" \
      "⇒ the box runs a stale config; an edit made here is not what nvim loads" \
      "read what differs: diff $src $dst" \
      "fix: rhx grove.provision --what 4.5.nvim --mode apply"
    failed=1
  fi
  # .what = 1b. the plugin lockfile is on the box AND matches this checkout
  # .why lazy-lock.json is the only pin on 14 unpinned repos; nvim-treesitter's
  #   `build = ':TSUpdate'` EXECUTES whatever tip an unpinned clone lands on
  local lock_src="$bundle_dir/lazy-lock.json"
  local lock_dst="$HOME/.config/nvim/lazy-lock.json"
  if [[ ! -r "$lock_dst" ]]; then
    _nvim_verify_say "no nvim plugin lockfile at $lock_dst" \
      "⇒ init.lua gives its 14 plugin repos no ref, so this file is the only pin; without it they clone at default-branch TIP, and nvim-treesitter EXECUTES it" \
      "⇒ the current init.lua refuses to fetch with no lockfile, so a box here has no plugins rather than unpinned ones" \
      "fix: rhx grove.provision --what 4.5.nvim --mode apply"
    failed=1
  elif [[ ! -r "$lock_src" ]]; then
    echo "   🌙 a plugin lockfile is installed, but this checkout has no lazy-lock.json to compare it against ($lock_src)"
  elif cmp -s "$lock_src" "$lock_dst"; then
    echo "   • the installed plugin lockfile matches this checkout ✔"
  else
    _nvim_verify_say "the installed plugin lockfile DIFFERS from this checkout" \
      "⇒ this box pins its 14 plugin repos to commits this checkout no longer names, so two boxes run different plugin code" \
      "read what differs: diff $lock_src $lock_dst" \
      "⇒ if the BOX is newer (a ':Lazy update' ran here), carry it back instead of overwriting it: cp $lock_dst $lock_src" \
      "fix: rhx grove.provision --what 4.5.nvim --mode apply"
    failed=1
  fi
  # .what = 2. nvim can actually LOAD it (skipped if absent; provision.verify claims that)
  # .why the BINARY, never the name — `2.7.aliases` exports a `nvim` function
  #   (the memory cap), so the bare name would load-test the WRAPPER
  local bin
  bin="$(bundle.bin.of nvim)"
  if [[ -z "$bin" ]]; then
    echo "   🌙 nvim is absent, so the config cannot be load-tested. provision.verify names that defect and its fix"
    return $failed
  fi
  # .why wrapped in `timeout`: a headless start bootstraps lazy.nvim, which on a box with
  #   no plugins clones from github — a dead network raises no error (rule.require.bounded-probes-in-verifies)
  # .why 60s, not zero-tolerance: a first plugin sync takes tens of seconds on a healthy
  #   network, so a timeout here is a 🌙, never a fail; claim 3 shares this one start
  # 🛑 a bound on DURATION is not a bound on what CODE arrives — claim 3b reads that at cause
  local out rc
  out="$(timeout -k 10 60 "$bin" -n --headless \
    -c 'lua io.write(("GUARDOPTS modeline=%s modelineexpr=%s exrc=%s lazypin=%s\n"):format(vim.o.modeline, vim.o.modelineexpr, vim.o.exrc, vim.g.lazy_pinned))' \
    +q 2>&1)" && rc=0 || rc=$?
  if [[ "$rc" -eq 0 ]]; then
    echo "   • nvim starts clean with this config ✔"
  elif [[ "$rc" -eq 124 ]]; then
    echo "   🌙 nvim did not finish its start within 60s, so the config is unproven"
    echo "      ⇒ USUALLY a first plugin sync (github clone); read it by hand, unbounded: $bin -n --headless +q"
  else
    _nvim_verify_say "nvim could NOT start with the installed config" \
      "⇒ the bytes copied fine and the editor still fails to open — a content match alone would have reported this box healthy" \
      "it said: $(printf '%s' "$out" | head -10 | tr '\n' ' ')" \
      "fix: correct the error in $src, then re-drive — rhx grove.provision --what 4.5.nvim --mode apply"
    failed=1
  fi
  # .what = 3. 🛑 a FILE may not configure the editor that opens it
  # .why modeline/modelineexpr/exrc are remote-chosen config applied on OPEN, and
  #   git.grove.pull writes a tree a grove named — one keystroke is the whole trigger
  # .why asked of a RUNNING editor, never grepped from the file: a checkout can drop the
  #   guard on a LATER line where a `cmp` above still agrees
  # .refs = gotcha.4-5-nvim.demo=configure-verify-measurements, m1-m2
  local guard_line
  guard_line="$(printf '%s\n' "$out" | grep -o 'GUARDOPTS .*' | tail -1 || true)"
  if [[ -z "$guard_line" ]]; then
    echo "   🌙 nvim did not report its modeline/exrc options, so whether a FILE can configure this editor is unproven — read the start's verdict above"
  elif [[ "$guard_line" == *"modeline=false"* \
       && "$guard_line" == *"modelineexpr=false"* \
       && "$guard_line" == *"exrc=false"* ]]; then
    echo "   • a file cannot configure the editor that opens it ✔ (modeline, modelineexpr, exrc all off)"
  else
    # 🛑 TWO causes, one symptom, opposite fixes — grepped HERE and only here, since a later line can undo the guard
    local cause
    if grep -q '^vim\.o\.modeline = false$' "$src" 2>/dev/null; then
      cause="⇒ the checkout DOES pin it, so this box runs a stale config
fix: rhx grove.provision --what 4.5.nvim --mode apply"
    else
      cause="⇒ the checkout does not pin it, so an apply changes none of this
fix: pin all three off near the top of $src — vim.o.modeline = false / modelineexpr = false / exrc = false"
    fi
    _nvim_verify_say "nvim lets a FILE configure the editor that opens it" \
      "it reports: ${guard_line#GUARDOPTS }" \
      "⇒ a modeline is a directive the file's AUTHOR wrote, applied on open — git.grove.pull writes a tree a GROVE named, one keystroke the trigger" \
      "⇒ exrc is wider: it sources a .nvimrc from wherever nvim was started" \
      "$cause"
    failed=1
  fi
  # .what = 3b. 🛑 no plugin is fetched without a pin
  # .why an unpinned start clones all 14 repos at tip, and nvim-treesitter's
  #   `build = ':TSUpdate'` executes that tip — the trigger needs only `nvim`, on the laptop
  # .why `false` is the SAFE state (declined, no pin), never a ✋; the arm that matters is
  #   `nil` — a config that predates this pin sets no such variable, and clones at tip
  if [[ -z "$guard_line" ]]; then
    : # claim 3 already reported the absent report, and named its cause
  elif [[ "$guard_line" == *"lazypin=true"* ]]; then
    echo "   • nvim took its plugin pin ✔ (no plugin is fetched without one)"
  elif [[ "$guard_line" == *"lazypin=false"* ]]; then
    echo "   🌙 nvim started with its plugins OFF — it had no pin, so it fetched none. that is the safe outcome, not a healthy one — the lockfile claim above names the cause and its fix"
  else
    _nvim_verify_say "the installed config predates the plugin pin" \
      "it reports: ${guard_line#GUARDOPTS }" \
      "⇒ a config with no pin flag does not DECLINE to fetch — it clones 14 repos at tip on the next start, and nvim-treesitter executes that tip" \
      "⇒ the trigger is \`nvim\`, on this box; no grove is needed" \
      "fix: rhx grove.provision --what 4.5.nvim --mode apply"
    failed=1
  fi
  # .what = 4-6. 🛑 imagemagick may not hand a grove's bytes to another program
  # .why debian's default policy declares no coder rule, and an absent rule is PERMITTED —
  #   PS/EPS/PDF/XPS reach ghostscript on a tree git.grove.pull wrote
  # .why three claims: currency (cmp), effect (an eps is refused), cost (a png still reads)
  # .why none of the three set `failed` — provision.upsert treats imagemagick as non-fatal,
  #   so a hard-fail verify here would contradict its own upsert; they still PRINT
  # .refs = gotcha.4-5-nvim.demo=configure-verify-measurements, m3-m5
  local pol_src="$bundle_dir/imagemagick.policy.xml"
  local pol_dst="${XDG_CONFIG_HOME:-$HOME/.config}/ImageMagick/policy.xml"
  # ── 4. currency
  if [[ ! -r "$pol_dst" ]]; then
    echo "   🌙 no imagemagick policy at $pol_dst — the box runs debian's default, which declares no coder rule at all"
    echo "      fix: rhx grove.provision --what 4.5.nvim --mode apply"
  elif [[ ! -r "$pol_src" ]]; then
    echo "   🌙 a policy is installed, but this checkout has no imagemagick.policy.xml to compare it against ($pol_src)"
  elif cmp -s "$pol_src" "$pol_dst"; then
    echo "   • the installed imagemagick policy matches this checkout ✔"
  else
    echo "   🌙 the installed imagemagick policy DIFFERS from this checkout"
    echo "      read what differs: diff $pol_src $pol_dst — fix: rhx grove.provision --what 4.5.nvim --mode apply"
  fi
  # ── 5-6. effect and cost, asked of the LIVE tool — a grep of policy.xml would green on a path imagemagick never consults
  local im=""
  for c in identify magick convert; do
    command -v "$c" >/dev/null 2>&1 && { im="$c"; break; }
  done
  if [[ -z "$im" ]]; then
    echo "   🌙 imagemagick is absent, so its policy cannot be exercised — provision.verify reports that, and treats it as no failure"
    return $failed
  fi
  local imwork
  imwork="$(mktemp -d 2>/dev/null)" || imwork=""
  if [[ -z "$imwork" ]]; then
    echo "   🌙 could not make a temp dir, so the imagemagick policy is unproven"
    return $failed
  fi
  # a benign postscript file, its `%%` header the EPS format's own mandated syntax —
  # the question is only whether the CODER is reached
  printf '%s\n' \
    '%!PS-Adobe-3.0 EPSF-3.0' \
    '%%BoundingBox: 0 0 8 8' \
    '0 0 moveto 8 8 lineto stroke' > "$imwork/probe.eps"
  # bounded: an UNPOLICED read execs ghostscript (rule.require.bounded-probes-in-verifies)
  local eps_out
  eps_out="$(timeout -k 5 20 "$im" identify "$imwork/probe.eps" 2>&1 | head -1)"
  if printf '%s' "$eps_out" | grep -qi 'not authorized\|security policy'; then
    echo "   • imagemagick refuses the ghostscript coder class ✔"
  elif printf '%s' "$eps_out" | grep -qi 'no .*delegate\|unable to open'; then
    echo "   🌙 this build cannot reach the PS coder at all — the policy has no subject here; correct to keep, unprovable on this box"
  else
    local extra
    if [[ -r "$pol_dst" ]]; then
      extra="⇒ a policy IS installed at $pol_dst; imagemagick does not consult it — read where it does: $im -list policy | grep '^Path:'"
    else
      extra="fix: rhx grove.provision --what 4.5.nvim --mode apply"
    fi
    _nvim_verify_say "imagemagick hands a postscript file to ghostscript" \
      "it said: $(printf '%s' "$eps_out" | sed "s|$imwork/||")" \
      "⇒ PS/EPS/PDF/XPS exec \`gs\`; git.grove.pull writes a tree a GROVE named, and image.nvim converts what nvim opens" \
      "$extra"
  fi
  # .what = 6. the cost half — a policy that bites the render set breaks a silent draw
  # .why the render set is DERIVED from init.lua's IMAGE_DIFF_EXTS, never typed here — one
  #   hand-written copy already drifted from it (m4)
  # .why a SKIPPED format is not a PASSED one — each row `continue`s when the build cannot
  #   write it, separating "cost is zero" from "no format was measured" (rule.forbid.failhide)
  local cost_exts cost_n=0 cost_ok=0 png_fail=""
  cost_exts="$(awk '/IMAGE_DIFF_EXTS = \{/,/\}/' "$src" 2>/dev/null | grep -oE '[a-z0-9]+ = true' | cut -d' ' -f1 | sort -u || true)"
  if [[ -z "$cost_exts" ]]; then
    echo "   🌙 this checkout declares no IMAGE_DIFF_EXTS this reader can see, so the cost of the policy is UNMEASURED"
    echo "      ⇒ read why: grep -n 'IMAGE_DIFF_EXTS = {' $src"
  else
    for ext in $cost_exts; do
      cost_n=$(( cost_n + 1 ))
      timeout -k 5 20 "$im" -size 8x8 xc:red "$imwork/cost.$ext" >/dev/null 2>&1 || true
      [[ -s "$imwork/cost.$ext" ]] || continue   # the build cannot make it — no verdict
      cost_ok=$(( cost_ok + 1 ))
      local cost_out
      cost_out="$(timeout -k 5 20 "$im" identify "$imwork/cost.$ext" 2>&1 | head -1)"
      printf '%s' "$cost_out" | grep -qi 'not authorized\|security policy' && png_fail="${png_fail}${png_fail:+ }$ext"
    done
  fi
  if [[ -n "$cost_exts" && "$cost_ok" -eq 0 ]]; then
    echo "   🌙 this build wrote NONE of the $cost_n declared format(s), so the policy's cost is UNMEASURED — never zero"
  elif [[ -z "$png_fail" && -n "$cost_exts" ]]; then
    echo "   • and it costs the declared render set zero ✔ ($cost_ok of $cost_n read)"
    [[ "$cost_ok" -eq "$cost_n" ]] || echo "      ⚠️ $(( cost_n - cost_ok )) format(s) this build cannot write were NOT read"
  elif [[ -n "$png_fail" ]]; then
    # the set is echoed from `$cost_exts`, the SAME value the loop read, so a hand-typed list is never a second holder of the fact
    _nvim_verify_say "the imagemagick policy REFUSES a format this repo renders: $png_fail" \
      "⇒ init.lua's IMAGE_DIFF_EXTS declares $(printf '%s' "$cost_exts" | tr '\n' ' ')renderable" \
      "⇒ likely routed through a DELEGATE, closed wholesale by \`delegate rights=none pattern=*\`" \
      "fix: narrow that line in $pol_src, then re-drive — rhx grove.provision --what 4.5.nvim --mode apply"
  fi
  rm -rf "$imwork"
  return $failed
}

#!/usr/bin/env bash
# .what = firefox — the flatpak build, the `browser` launcher, its prefs, and
#   its three extensions, force-installed by policy
# .why
#   - flatpak, never apt: ubuntu's apt firefox is a slow snap wrapper with no
#     `~/.mozilla`, so it is REMOVED (two firefoxes make `xdg-open` guess)
#   - EVERY box, headless too: the flatpak and profile are plain files a grove
#     can hold (rule.require.identical-bundle-composition)
#   - the three extensions arrive by POLICY, with no human click:
#     `firefox/policies.json` force-installs 1password, firefox-color and vimium
#     through `ExtensionSettings`. flatpak firefox ignores the host's
#     `/etc/firefox/policies` and reads `/app/etc/firefox/policies/policies.json`,
#     the SAME systemconfig channel the ctrl+N rebind rides, so it needs no root
#   - the profile is resolved by `[Install…] Default=`, never by its name: a
#     "Profile 1" dir is common, and a grep on `default-release` found none
#   - the ctrl+N tab rebind ships via the flatpak systemconfig extension point,
#     so it converges before firefox ever starts
# .refs = gotcha.1-3-1-firefox.demo=flatpak-user-scope-and-holds-everywhere ·
#   howto.firefox-ctrl-tab-keys · howto.firefox-extensions-by-policy
# usage: rhx grove.provision --what 1.3.browser --mode apply

# .what = the declared 1password options, in its storage.local `config` key;
#   the one declaration both phases pass through
# .why inline fill and the save offer ON; "universal sign in" and its autofocus
#   OFF (one combined prompt that grabs focus). labels: the extension's own
#   options page, v8.12.41
# usage: grove_provision_1_3_1_firefox_onepassword_options <profile> plan|apply
grove_provision_1_3_1_firefox_onepassword_options() {
  python3 "$GROVE_SRC/grove.provision/1.system/1.3.browser/1.3.1.firefox/firefox/addon.storage.local.py" \
    --profile "$1" --addon-id '{d634138d-c276-4fc8-924b-40a0ea21d284}' --key config \
    --set inlineEnabled=true \
    --set inlineShowAutomatically=true \
    --set inlineSaveEnabled=true \
    --set autoSaveEnabled=true \
    --set universalSignOnEnabled=false \
    --set universalSignOnAutoFocus=false \
    --mode "$2"
}

grove_provision_1_3_1_firefox() {
  bundle.upgrade 1.3.1.firefox.provision.upsert
  bundle.upgrade 1.3.1.firefox.provision.verify
  bundle.upgrade 1.3.1.firefox.configure.upsert
  bundle.upgrade 1.3.1.firefox.configure.verify
}

# .what = print the dir name of the profile firefox LAUNCHES, or naught
# .why  = one lookup for both phases, so the upsert and the verify cannot
#         disagree about which profile is live
#   - first: the `[Install…]` section's `Default=` — the profile this install
#     opens, whatever its name
#   - else: the profile marked `Default=1` (an old profiles.ini has no
#     Install section)
grove_provision_1_3_1_firefox_profile_dir() {
  local ini="$HOME/.var/app/org.mozilla.firefox/config/mozilla/firefox/profiles.ini"
  [[ -r "$ini" ]] || return 0
  local dir
  dir="$(awk -F= '/^\[Install/ { on = 1; next } /^\[/ { on = 0 } on && $1 == "Default" { print $2; exit }' "$ini")"
  [[ -n "$dir" ]] || dir="$(awk -F= '/^\[/ { p = "" } $1 == "Path" { p = $2 } $1 == "Default" && $2 == "1" { print p; exit }' "$ini")"
  printf '%s' "$dir"
}

# .what = print the path of one extension's `storage.local` sqlite, or naught
# .why  = one lookup for every reader, so they cannot reach two files
#   - id → internal uuid: prefs.js `extensions.webextensions.uuids`
#   - uuid → `storage/default/moz-extension+++<uuid>^userContextId=4294967295/idb/*.sqlite`
# .exit = 0 printed · 2 no such file here, the reason on stderr
grove_provision_1_3_1_firefox_addon_storage_db() {
  local addon_id="$1"
  local ff_root="$HOME/.var/app/org.mozilla.firefox/config/mozilla/firefox"
  local profile_dir profile uuid_map uuid f

  profile_dir="$(grove_provision_1_3_1_firefox_profile_dir)"
  [[ -n "$profile_dir" ]] || { echo "no firefox profile" >&2; return 2; }
  profile="$ff_root/$profile_dir"

  command -v node >/dev/null 2>&1 || { echo "node is not on PATH, so the storage cannot be decoded" >&2; return 2; }
  command -v jq >/dev/null 2>&1 || { echo "jq is not on PATH" >&2; return 2; }

  # the pref's value is a json string with escaped quotes: unescape, then jq
  uuid_map="$(awk -F'"extensions.webextensions.uuids", "' 'NF > 1 { v = $2; sub(/"\);[[:space:]]*$/, "", v); gsub(/\\"/, "\"", v); print v; exit }' "$profile/prefs.js" 2>/dev/null)"
  uuid="$(jq -r --arg id "$addon_id" '.[$id] // empty' <<<"$uuid_map" 2>/dev/null)"
  [[ -n "$uuid" ]] || { echo "firefox has not started with $addon_id installed yet" >&2; return 2; }

  for f in "$profile/storage/default/moz-extension+++${uuid}^userContextId=4294967295/idb/"*.sqlite; do
    [[ -f "$f" ]] && { printf '%s' "$f"; return 0; }
  done
  echo "the extension has stored no value on this profile yet" >&2
  return 2
}

# .what = print one extension's `storage.local` as json, key → value
# .why  = the firefox color theme cannot be SET by policy, but it lands in the
#         extension's own storage — so the verify can READ whether it was applied
#   - a COPY of the sqlite is decoded by `firefox/addon.storage.decode.cjs`
#     (snappy + structured clone), so a live firefox's lock is never touched
#   - 1password's options are NOT read here: `onepassword_options` above owns
#     that store, read and write, so the two cannot disagree
# .exit = 0 printed · 2 not readable here, the reason on stderr · 1 the decode broke
grove_provision_1_3_1_firefox_addon_storage() {
  local addon_id="$1"
  local decoder="$GROVE_SRC/grove.provision/1.system/1.3.browser/1.3.1.firefox/firefox/addon.storage.decode.cjs"
  local db tmp json

  db="$(grove_provision_1_3_1_firefox_addon_storage_db "$addon_id")" || return 2

  tmp="$(mktemp -d)" || return 1
  cp "$db" "$tmp/db.sqlite" && { [[ ! -f "$db-wal" ]] || cp "$db-wal" "$tmp/db.sqlite-wal"; } \
    && json="$(timeout 20 node --no-warnings "$decoder" "$tmp/db.sqlite")"
  local rc=$?
  rm -rf "$tmp"
  [[ "$rc" -eq 0 ]] || { echo "the decode of $db failed (exit $rc)" >&2; return 1; }
  printf '%s' "$json"
}

# .what = say whether the theme hand step is done: `done`, `owed`, or `unknown: <why>`
# .why  = the upsert prints the one click only while it is owed, and the verify
#         reports it ✔ or 🌙 — one reader for both, so they cannot disagree
#   - firefox color's `theme.colors` equals `firefox/color.theme.colors.json`
#     (that file is the decoded palette of the share url the upsert prints; the
#     two must change together)
grove_provision_1_3_1_firefox_theme_state() {
  local json why rc errfile
  local want="$GROVE_SRC/grove.provision/1.system/1.3.browser/1.3.1.firefox/firefox/color.theme.colors.json"

  errfile="$(mktemp)" || { echo "unknown: mktemp failed"; return 0; }
  json="$(grove_provision_1_3_1_firefox_addon_storage 'FirefoxColor@mozilla.com' 2>"$errfile")"; rc=$?
  why="$(<"$errfile")"; rm -f "$errfile"
  if [[ "$rc" -ne 0 ]]; then
    echo "unknown: ${why:-the storage read failed}"
    return 0
  fi

  jq -e --slurpfile w "$want" '.theme.colors == $w[0]' <<<"$json" >/dev/null && { echo done; return 0; }
  echo owed
}

# howto: firefox ctrl+N tab switching

## .what

rebind firefox tab-switch keys from the linux default (alt+1..8) to ctrl+1..8
(+ ctrl+9 = last tab), for parity with kitty's `goto_tab` binds.

## .why

- **linux firefox uses alt+N, not ctrl+N** for tab switch — ctrl+N is the
  windows binding. this is baked into the firefox binary, not an about:config
  pref. so ctrl+2 has no effect on linux until rebound.
- kitty binds ctrl+1..8 = tab N, ctrl+9/ctrl+0 = last tab
  (src/install_env.pt4.terminal.kitty.sh). the rebind makes firefox match.

## .the mechanism

three layers, because flatpak firefox seals `/app` read-only:

1. **autoconfig** — the only no-extension way to rewrite firefox's `<keyset>`.
   an `autoconfig.js` pointer + a `firefox.cfg` js payload that mutates the
   `key_selectTab1..8` + `key_selectLastTab` modifiers to `accel` (= ctrl).

2. **the flatpak door** — firefox.cfg normally must live in the binary dir
   (`/app/lib/firefox`, read-only in flatpak). the sanctioned bypass is the
   `org.mozilla.firefox.systemconfig` extension point (declared in the flatpak
   metadata as `directory=etc/firefox`). files placed at
   `~/.local/share/flatpak/extension/org.mozilla.firefox.systemconfig/x86_64/stable/`
   surface inside the sandbox at `/app/etc/firefox/`, which firefox reads at
   startup. no third-party flatpak remote needed — we ship our own files.

3. **the payload** — `firefox.cfg` runs in the autoconfig sandbox where
   `Services` is already a global. it rebinds every open + future browser
   window's keyset, then re-appends the keyset node to force gecko to rebuild
   its shortcut table.

## .the skill

managed by `rhx firefox.systemconfig`:

| subcommand | what |
|------------|------|
| `probe` | verify a bare extension dir mounts into the sandbox |
| `install` | write autoconfig.js + firefox.cfg (the rebind) |
| `status` | show installed files + whether sandbox sees firefox.cfg |
| `doctor` | kill+relaunch firefox, capture autoconfig stderr for diagnosis |
| `uninstall` | remove the channel (reverts to alt+N) |

wired into install via `configure_firefox_ctrltab_keys` in
src/install_env.pt1.system.basics.sh, and re-appliable via the
`sync.devenv.firefox` alias (part of the `sync.devenv` chain).

note: the sync alias writes the config files (idempotent), but a live
firefox must be fully quit to re-read them (see gotchas). for an
immediate reload, use `rhx firefox.systemconfig doctor`.

## .gotchas

- **must fully quit firefox to apply.** a live flatpak does not re-read
  autoconfig; a plain window-close is insufficient. use `ctrl+q` or
  `flatpak kill org.mozilla.firefox`, then relaunch.
- **do not import `Services.jsm`.** that module was removed from modern firefox
  (~130). in the autoconfig sandbox `Services` is already a global; importing
  it throws, and the autoconfig error is easy to miss. this was the original
  bug — the config loaded but the payload threw silently.
- **ctrl+0 stays reset-zoom.** kitty maps ctrl+0 = last tab, but ctrl+0 is a
  genuinely reserved firefox shortcut (zoom reset) and is left unbound. use
  ctrl+9 for last tab (the standard firefox convention).

## .extending

the systemconfig channel is reusable for any firefox system config that
`user.js` cannot do (locked prefs, enterprise `policies.json`, chrome-level
tweaks). drop files under the same extension dir:
- `defaults/pref/*.js` — pref pointers / locked prefs
- `policies/policies.json` — enterprise policies

for ordinary about:config prefs, prefer `configure_firefox_prefs` (user.js) —
it is simpler and needs no autoconfig.

## .sources

- [firefox alt vs ctrl tab keys on linux](https://support.mozilla.org/en-US/questions/1263764)
- [customizing firefox using autoconfig](https://support.mozilla.org/en-US/kb/customizing-firefox-using-autoconfig)
- [autoconfig in flatpak (bugzilla 1785278)](https://bugzilla.mozilla.org/show_bug.cgi?id=1785278)
- [pocketblue/firefox-systemconfig (reference for the extension-point trick)](https://github.com/pocketblue/firefox-systemconfig)

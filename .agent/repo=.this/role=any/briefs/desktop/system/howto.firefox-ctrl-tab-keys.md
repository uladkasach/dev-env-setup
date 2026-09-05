# howto: firefox ctrl+N tab switching

## .what

rebind firefox tab-switch keys from the linux default (alt+1..8) to ctrl+1..8
(+ ctrl+9 = last tab), for parity with kitty's `goto_tab` binds.

## .why

- **linux firefox uses alt+N, not ctrl+N** for tab switch — ctrl+N is the
  windows binding. this is baked into the firefox binary, not an about:config
  pref. so ctrl+2 has no effect on linux until rebound.
- kitty binds ctrl+1..8 = tab N, ctrl+9/ctrl+0 = last tab
  (`src/grove.provision/4.terminal/4.3.kitty/4.3.2.emulator/configure.upsert.sh`).
  the rebind makes firefox match.

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

## .who owns what

the two files are **declared assets** under `src/firefox/`, and the BUNDLE is
their one writer:

| artifact | owner |
|----------|-------|
| `src/firefox/autoconfig.js` | this repo — the pointer |
| `src/firefox/firefox.cfg` | this repo — the js payload |
| the copy into the extension dir | `1.3.1.firefox`'s `configure.upsert` |
| the proof that the copy is CURRENT | `1.3.1.firefox`'s `configure.verify` |

```sh
rhx grove.provision --what 1.3.browser --mode apply
```

⚠️ .why the payload is an ASSET and not a heredoc in the skill

🛑 never let a skill write these files from its own heredocs. that shape carries
two defects at once:

1. **two writers on one artifact** (`rule.forbid.two-writers-on-one-artifact`) —
   the skill's heredoc and the repo's intent are free to drift, and a `grep`
   verify cannot tell which one is live.
2. **the payload sits outside `src/`** — `src/` is the deployable unit, so a grove
   provisioned by a `--from src` push could not converge. it failed exactly that way:

   ```
   ✋ firefox.systemconfig.sh is absent or unreadable
      looked at: …/dev-env-setup.wip/.agent/…/firefox.systemconfig.sh
   ```

as assets, the two files also buy what a `skill install` never could: the verify
can `cmp` the live files against the checkout and prove **currency**, not merely
presence. a stale copy from an older revision passes a grep and silently runs
last month's rebind; it fails a `cmp`.

## .the skill — a diagnostic, not an installer

`rhx firefox.systemconfig` keeps the verbs a bundle cannot give: the ones that
look INSIDE the live sandbox.

| subcommand | what |
|------------|------|
| `probe` | verify a bare extension dir mounts into the sandbox |
| `install` | ✋ writes no file — it names the bundle above, and exits 2 |
| `status` | show installed files + whether the sandbox sees firefox.cfg |
| `doctor` | kill+relaunch firefox, capture autoconfig stderr for diagnosis |
| `uninstall` | remove the channel (reverts to alt+N) |

⚠️ the rebind phase runs BEFORE that bundle reads the firefox profile. the
channel lives in a flatpak extension dir, not in the profile, so it converges
on a box firefox has never been started on — and the profile lookup returns
early on exactly that box.

⚠️ the verify asserts the two HOST files, not `firefox.systemconfig status`.
that subcommand answers by `flatpak run --command=cat` into the sandbox — a
real sandbox launch on every plan, which is a live-state probe of a claim the
host files already settle (`rule.require.judge-declared-state-not-live-state`,
`rule.require.bounded-probes-in-verifies`).

note: an apply writes the config files (idempotent), but a live firefox must be
fully quit to re-read them (see gotchas). for an immediate reload, use
`rhx firefox.systemconfig doctor`.

## .gotchas

- **must fully quit firefox to apply.** a live flatpak does not re-read
  autoconfig; a plain window-close is insufficient. use `ctrl+q` or
  `flatpak kill org.mozilla.firefox`, then relaunch.
- **do not import `Services.jsm`.** that module was removed from modern firefox
  (~130). in the autoconfig sandbox `Services` is already a global; an import
  throws, and the autoconfig error is easy to miss — the config loads and the
  payload dies silently.
- **ctrl+0 stays reset-zoom.** kitty maps ctrl+0 = last tab, but ctrl+0 is a
  genuinely reserved firefox shortcut (zoom reset) and is left unbound. use
  ctrl+9 for last tab (the standard firefox convention).

## .extending

the systemconfig channel is reusable for any firefox system config that
`user.js` cannot do (locked prefs, enterprise `policies.json`, chrome-level
tweaks). drop files under the same extension dir:
- `defaults/pref/*.js` — pref pointers / locked prefs
- `policies/policies.json` — enterprise policies

for ordinary about:config prefs, prefer the `user.js` block in the same
`1.3.1.firefox/configure.upsert.sh` — it is simpler and needs no autoconfig.

## .sources

- [firefox alt vs ctrl tab keys on linux](https://support.mozilla.org/en-US/questions/1263764)
- [customizing firefox using autoconfig](https://support.mozilla.org/en-US/kb/customizing-firefox-using-autoconfig)
- [autoconfig in flatpak (bugzilla 1785278)](https://bugzilla.mozilla.org/show_bug.cgi?id=1785278)
- [pocketblue/firefox-systemconfig (reference for the extension-point trick)](https://github.com/pocketblue/firefox-systemconfig)
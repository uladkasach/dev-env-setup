# howto.firefox-extensions-by-policy

## .what

the flatpak firefox gets its extensions from a **policy file**, not from a human click.
`1.3.1.firefox` writes `policies.json` into the flatpak systemconfig channel, and firefox
force-installs each listed extension at its next start, with no permission prompt.

```sh
rhx grove.provision --what 1.3.1.firefox --mode apply   # then fully quit + reopen firefox
```

then `about:policies` in firefox lists `ExtensionSettings` as active.

## .where the policy must live — the flatpak trap

| path | flatpak firefox reads it? |
|---|---|
| `/etc/firefox/policies/policies.json` (host) | ✋ no — the sandbox never sees the host `/etc` |
| `~/.local/share/flatpak/extension/org.mozilla.firefox.systemconfig/x86_64/stable/policies/policies.json` | ✔ yes — mounted inside as `/app/etc/firefox/policies/policies.json` |

⇒ the second path is the same channel the ctrl+N rebind rides
(`howto.firefox-ctrl-tab-keys`). it needs no root, and it exists before firefox has ever
started, so the policy lands on a fresh box.

## .the shape of an entry

```json
"<addon-id>": {
  "installation_mode": "force_installed",
  "install_url": "https://addons.mozilla.org/firefox/downloads/latest/<amo-slug>/latest.xpi"
}
```

- the **id** is the addon's own id, not its name. read it off a box that holds it:
  `rhx firefox.addon.get --name <part of name>`
- `force_installed` also stops a human from uninstall of it. `normal_installed` would allow that.

## 🛑 .what a policy can NOT set — the 1password autofill menu

the ask was to turn off 1password's "universal autofill" popup by bundle. no policy can.

- firefox passes `3rdparty.Extensions.<id>` policy values to an extension only through
  `storage.managed`, and only for the keys that extension reads
- measured 2026-10-25, 1password 8.12.41.1, via `rhx firefox.addon.get --name 1password --grep 'storage\.managed'`:
  it reads ONE managed key, `CredentialIntelligence`, a strict schema of account identity
  (`userEmail`, `accountUuid`, `signInDomain`, keys). no autofill field exists
- 1password's own docs agree: the extension takes no registry, GPO, or MDM config. the
  Business admin policies (autofill access by item kind, autofill confirmation, autosave,
  autosubmit) control WHAT may fill, never whether the menu shows on focus
- ⇒ the toggle stays a hand step, once per profile:
  1password → Settings → Autofill & save → **"Show autofill suggestions when a form field is in focus"**
  (older label: "Show autofill menu on field focus")

the same holds for the firefox-color desert theme. it is applied by a click on a share url.

⇒ the test before you promise "configure extension X by policy": grep its package for
`storage.managed` and read which keys it takes. no key → no policy.

## ✔ .but the result CAN be read — so the bundle knows whether the step was done

an extension's options live in its `storage.local`, and that storage is a plain sqlite file:

```
<profile>/storage/default/moz-extension+++<uuid>^userContextId=4294967295/idb/*.sqlite
```

- `<uuid>` is the extension's internal id. map the addon id to it via the prefs.js pref
  `extensions.webextensions.uuids`
- each row of the `object_data` table is one key. its `data` column is a **snappy**-compressed
  **structured clone**, so no text read of it works. `1.3.1.firefox/firefox/addon.storage.decode.cjs`
  decodes it (node ≥ 22.5, built-in `node:sqlite`)
- read a COPY of the file, never the live one, so a live firefox's lock stays untouched

```sh
rhx firefox.addon.storage.get --id FirefoxColor@mozilla.com                  # the map, no values
rhx firefox.addon.storage.get --id FirefoxColor@mozilla.com --key theme      # one value, redacted
```

what each option leaves behind, measured 2026-10-25:

| option | where it lands | declared |
|---|---|---|
| 1password's options | key `config`, a json STRING of flags | inline fill + save offer on, universal sign in off |
| desert palette | key `theme`, field `colors` | equals `firefox/color.theme.colors.json` |

⇒ the upsert WRITES the 1password flags (below). the theme it cannot write, so it prints the
url only while owed, and the verify reports it ✔ or 🌙.

⚠️ `color.theme.colors.json` is the decoded palette of the share url the upsert prints. the
two are one fact in two encodings: change them together, or the verify reports a theme the
url never sets.

⚠️ the option's key was found in the package, never guessed:
`rhx firefox.addon.get --name 1password --grep 'inlineShowAutomatically'` shows the options
page entry `configKey:"inlineShowAutomatically"` beside the label. after an extension update,
re-run that grep before you trust the read.

## ✔ .and 1password's flags can be WRITTEN — so they converge

a write to that row is what 1password's own options page does. `1.3.1.firefox/firefox/addon.storage.local.py`
sets the declared flags inside the `config` json string, and leaves every other byte as found:

```sh
rhx firefox.addon.storage.set --id '{d634138d-c276-4fc8-924b-40a0ea21d284}' --key config \
  --set inlineSaveEnabled=true                                  # plan (default)
rhx firefox.addon.storage.set ... --mode apply                  # firefox fully quit
```

- apply refuses while any firefox process lives (exit 4): the extension holds its config in
  memory and saves it back over a write made under it
- it handles ONE shape, a top-level string that holds a json object; any other is refused
  with its tag, never guessed at
- it prints only the named flags, never the json around them — the same store holds
  account secrets

⇒ on a box where firefox is open at apply time, the upsert names the quit that is owed; the
next apply with firefox quit converges it.

the firefox-color theme stays a click: its value is a structured-clone OBJECT, not a json
string, so the writer refuses it.

## ⚠️ .the profile is NOT the one named `default-release`

the bundle once found the profile by a grep for a `Path=` that ended in `default-release`.
on a box where the live profile was `<id>.Profile 1`, that grep matched naught. so user.js
was never written, and the verify reported "firefox never started" on a box that used firefox
every day.

- the profile firefox LAUNCHES is the `[Install<hash>]` section's `Default=`
- fallback: the `[Profile*]` with `Default=1` (old profiles.ini)
- one function in `1.3.1.firefox/_.sh` does this for both phases, so they cannot disagree

## .see also

- `howto.firefox-ctrl-tab-keys` — the systemconfig channel this rides
- `rule.forbid.failhide` — why a hand step is printed, never reported ✔

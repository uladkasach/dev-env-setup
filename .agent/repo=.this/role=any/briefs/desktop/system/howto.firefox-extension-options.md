# howto: declare a firefox extension's options

## .what

an extension's options page writes to its **storage.local**, and no pref, file, or
`policies.json` reaches it. 1password's managed schema, for one, accepts a single key
(`CredentialIntelligence`). so a declared option is written into the store itself, by
`1.3.1.firefox/firefox/addon.storage.local.py`.

## .where the options live

| layer | value |
|---|---|
| file | `<profile>/storage/default/moz-extension+++<uuid>^userContextId=4294967295/idb/*.sqlite` |
| uuid | `prefs.js` → `extensions.webextensions.uuids`, keyed by addon id |
| db / store | `webExtensions-storage-local` / `storage-local-data` |
| row key | firefox idb key encode: `0x30` then each char + 1 |
| row data | a snappy block over a spidermonkey structured clone |

1password (`{d634138d-c276-4fc8-924b-40a0ea21d284}`) keeps every option in ONE key,
`config`: a top-level **string** that holds compact json. the patcher handles exactly that
shape and refuses any other by its clone tag.

| options-page label (v8.12.41) | `config` field |
|---|---|
| show autofill suggestions when a field is selected | `inlineShowAutomatically` |
| show a "save in 1password" button below fields | `inlineSaveEnabled` |
| offer to save logins | `autoSaveEnabled` |
| offer to fill and save logins and other items in fields | `inlineEnabled` |
| use universal sign in for logins | `universalSignOnEnabled` |
| autofocus 1password sign in prompts when they appear | `universalSignOnAutoFocus` |

🟡 the two `universalSignOn*` rows render only when the account carries the
`b5x-universal-sign-on` feature flag. both default ON, so a box that never showed the
toggle still runs the combined prompt.

the declaration sits in `1.3.1.firefox/_.sh` (`…_onepassword_options`); both phases call it.

## .gotchas

- **a write needs firefox QUIT.** the extension holds its config in memory and saves it back
  over a write made under it. the upsert declines while firefox lives; the verify reports
  that drift as 🌙 owed a quit, and as ✋ only when firefox is down and the apply could have
  written it.
- **the profile's other idb holds account secrets.** 1password's own db sits beside
  storage.local. so the patcher and `rhx firefox.addon.storage.get` print only named keys
  and flags, never a whole value set.
- **a label is not a field name.** web answers name options that do not exist in this
  version; read the labels from the extension's own bundle
  (`rhx firefox.addon.source.get --grep`).

## .skills

- `rhx firefox.addon.storage.get --id <id>` — map the stores and keys, no values
- `rhx firefox.addon.storage.set --id <id> --key config --set k=false [--mode apply]` — the
  same patcher the bundle uses, by hand

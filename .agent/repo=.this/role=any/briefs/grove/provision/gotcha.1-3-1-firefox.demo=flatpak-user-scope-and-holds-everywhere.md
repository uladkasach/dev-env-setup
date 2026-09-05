# gotcha.1-3-1-firefox.demo=flatpak-user-scope-and-holds-everywhere

## .what

the dated measurements behind `1.3.1.firefox`'s self-installed flatpak, its `--user` remote
scope, its bounded fetch, and why the bundle applies to every box, headless boxes too.

## m1 — a debian cloud image ships no flatpak, and the bundle's own fix line named it

measured grove-1, 2026-07-30. this leaf's premise — "the flatpak build installs on a
grove" — was false: the box had no `flatpak` binary. the bundle failed with `flatpak:
command not found`; its own fix line named `flatpak install flathub
org.mozilla.firefox`. an error that states a fix the box cannot execute is a dead end in a
fix's costume. `1.6.1.finders` closed the same shape of defect when it declared `bc` — a
dependency you do not install is a dependency you ASSUME.

## m2 — a system-wide flatpak remote hangs forever on a swallowed polkit prompt

measured grove-1, 2026-07-30. a system-wide `flatpak remote-add` asks polkit for
`…Flatpak.configure-remote`, and polkit asks a HUMAN for a password. the run hung on:

```
==== AUTHENTICATING FOR org.freedesktop.Flatpak.configure-remote ====
Password:
```

the prompt was swallowed because stdout was a pipe. the root dispatch's `CI=1` /
`DEBIAN_FRONTEND` block never reaches polkit. `--user` writes under
`~/.local/share/flatpak` and needs no polkit — the prompt revealed the scope was wrong
(`rule.require.solve-at-cause`). `--user` is the right scope regardless: this repo
installs a box for one human.

## m3 — a bare `flatpak` opened ten connections and never returned

measured 2026-08-14 (`prove.tool-defaults-are-bounded`, `src/grove.web.sh`). against a
silent remote a bare `flatpak` opened ten connections and had still not returned at 240s,
the most persistent of six tools measured. this bundle is not laptop-only. an unbounded
`flatpak` here holds a duct with no human on it to notice — the fix is `web_flatpak`,
never a bare `flatpak`.

## why the bundle applies to every box, headless boxes too

"a gui browser needs a display" is true of RUNNING firefox and false of HOLDING this
bundle — the flatpak installs on a grove; the profile and its prefs are plain files
(`rule.require.identical-bundle-composition`). "but a grove would never USE it" is not an
argument against this: it is the blocker the rule names verbatim, "unused here" instead of
"cannot be held here". `4.3.1.terminfo` proved the same shape wrong once already — the box
that NEEDED that entry was the headless one. its absence there read as three unrelated
bugs for a day.

## .see also

- `rule.require.solve-at-cause` — m2's fix
- `prove.tool-defaults-are-bounded` — m3's clamp
- `rule.require.identical-bundle-composition` — the EFFECT-vs-HOLD principle
- `rule.require.one-command-provision` — why the extension-accept half declines off `local@unix`

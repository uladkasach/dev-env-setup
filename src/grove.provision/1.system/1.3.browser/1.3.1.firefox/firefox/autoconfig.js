// .what = the autoconfig POINTER. firefox reads this at start and it names the
//         payload beside it (firefox.cfg, in the same dir).
//
// .why  = tab-switch keys on linux firefox are bound to alt+N, in the binary,
//         not in any about:config pref. autoconfig is the only no-extension way
//         to rewrite the <keyset>, and this pointer is what turns it on.
//
// .where it lands = the flatpak systemconfig extension dir, which the sandbox
//         mounts read-only at /app/etc/firefox — see
//         briefs/desktop/system/howto.firefox-ctrl-tab-keys.md
//
// ⚠️ sandbox_enabled MUST stay false. with it true, firefox.cfg runs in a
//    restricted scope where Services is undefined, and the rebind silently
//    does no work — the worst shape, since the file loads and reports success.
pref("general.config.filename", "firefox.cfg");
pref("general.config.obscure_value", 0);
pref("general.config.sandbox_enabled", false);

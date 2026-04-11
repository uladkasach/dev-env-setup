# self review: has-questioned-assumptions (r2)

## artifact reviewed

`.behavior/v2026_04_07.flatpak-isolate/3.3.1.blueprint.product.v1.i1.md`

---

## assumptions identified

### assumption 1: `install_env.pt1.system.security.sh` exists

**status**: FALSE — file does not exist.

**evidence**: glob of `src/install_env*.sh` shows:
- `install_env.pt1.system.basics.sh`
- `install_env.pt1.system.keybinds.sh`
- `install_env.pt1.system.performance.sh`

no `install_env.pt1.system.security.sh`.

**fix required**: update blueprint to either:
1. create new file `install_env.pt1.system.security.sh`, or
2. add procedures to an extant file (e.g., `pt1.system.basics.sh`)

**decision**: create new file. security procedures are distinct from basics/keybinds/performance. the name convention supports this.

**change made**: updated blueprint filediff tree to mark file as `[+] create` instead of `[~] update`.

---

### assumption 2: yama ptrace_scope=2 applies to flatpak processes

**status**: valid assumption.

**evidence**: research phase documented that yama is a kernel-level LSM that applies regardless of namespace. the verify_isolation.sh procedure will confirm empirically.

**why it holds**: yama operates at syscall level, before namespace filter. even if flatpak uses user namespaces, the ptrace syscall is still mediated by yama.

---

### assumption 3: flatpak override --user is sufficient

**status**: valid assumption.

**evidence**: flatpak documentation confirms user overrides take precedence over system defaults. `~/.local/share/flatpak/overrides/` is the user override location.

**why it holds**: flatpak reads overrides in order: system, then user. user overrides are additive and can revoke system permissions.

---

### assumption 4: xdg-desktop-portal is installed

**status**: assumption needs guard.

**evidence**: blueprint says "installed by default" but doesn't verify.

**fix**: add prerequisite check to `configure_firefox_isolation()` that verifies portal packages are present. if not, warn user.

**change made**: updated codepath tree to include portal prerequisite check.

---

### assumption 5: cosmic uses standard portal backend

**status**: valid with caveat.

**evidence**: cosmic uses `xdg-desktop-portal-cosmic` as its portal backend, not `-gnome` or `-gtk`. however, this is compatible with standard portal interfaces.

**why it holds**: xdg-desktop-portal is a dbus interface standard. the backend (cosmic, gnome, gtk) implements the same interface. firefox calls the interface, not the backend directly.

**change made**: updated portal dependencies section to mention cosmic backend.

---

### assumption 6: strace is installed

**status**: assumption needs guard.

**evidence**: verify_isolation.sh uses strace but doesn't check for it.

**fix**: verify_isolation.sh should check for strace and fail gracefully if not present, with instructions to install.

**change made**: updated codepath tree for verify_isolation.sh to include prerequisite check.

---

### assumption 7: firefox flatpak app id is org.mozilla.firefox

**status**: valid assumption.

**evidence**: this is the official flatpak app id from flathub. can verify with `flatpak info org.mozilla.firefox`.

**why it holds**: flathub name convention is standardized. mozilla maintains this app id.

---

### assumption 8: --nofilesystem=home and --nofilesystem=host block all unwanted access

**status**: valid assumption.

**evidence**: `--nofilesystem=host` blocks `/` access. `--nofilesystem=home` blocks `~/` access. together they prevent direct filesystem access.

**why it holds**: firefox still needs some filesystem access (downloads via portal, cache in `~/.var/app/`). the portal provides mediated access without direct filesystem= override.

**caveat**: `~/.var/app/org.mozilla.firefox/` remains host-visible by design. this is documented in the blackbox criteria (usecase.3).

---

## changes made to blueprint

| section | before | after |
|---------|--------|-------|
| filediff tree | `[~] install_env.pt1.system.security.sh` | `[+] install_env.pt1.system.security.sh` |
| file responsibilities | "update" | "create" |
| codepath: configure_firefox_isolation | no prereq check | added portal prerequisite check |
| codepath: verify_isolation.sh | no prereq check | added strace prerequisite check |
| portal dependencies | "gnome or -gtk" | "cosmic, gnome, or gtk" |

---

## reflection

the most significant discovery was that the target file doesn't exist. this was a copy-paste assumption from similar procedures in the repo. always verify file existence before you declare updates.

the portal backend assumption was also refined — cosmic has its own backend but this is compatible with the standard interface.

**rule applied**: question every assumption, especially "obvious" ones about file paths and system state.


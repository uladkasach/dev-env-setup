# system.power.howto

## .what

how to implement system.power.spec on cosmic pop!_os.

## .systemd-logind

`/etc/systemd/logind.conf` handles hardware events:

```ini
[Login]
HandlePowerKey=ignore
HandleSuspendKey=ignore
HandleHibernateKey=ignore
HandleRebootKey=ignore
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
HandleLidSwitchDocked=ignore
IdleAction=ignore
IdleActionSec=infinity
```

## .systemd-sleep

`/etc/systemd/sleep.conf` disables suspend/hibernate system-wide:

```ini
[Sleep]
AllowSuspend=no
AllowHibernation=no
AllowSuspendThenHibernate=no
AllowHybridSleep=no
```

## .cosmic

cosmic uses logind under the hood. check for inhibitors:

```sh
systemd-inhibit --list
```

if cosmic-comp holds a low-level lid-switch inhibitor, logind settings may be bypassed.

### cosmic-idle (screen timeout)

`~/.config/cosmic/com.system76.CosmicIdle/v1/` controls screen timeout:

```sh
echo "None" > ~/.config/cosmic/com.system76.CosmicIdle/v1/screen_off_time
echo "None" > ~/.config/cosmic/com.system76.CosmicIdle/v1/suspend_on_ac_time
echo "None" > ~/.config/cosmic/com.system76.CosmicIdle/v1/suspend_on_battery_time
```

### cosmic keybinds (power/logout)

override `~/.config/cosmic/com.system76.CosmicSettings.Shortcuts/v1/system_actions`:

```ron
PowerOff: "true",
Suspend: "true",
LogOut: "true",
```

🛑 **`LockScreen` is absent on purpose — do not add it.** the three above end a
session, so a stray press costs unsaved work. a lock costs a password, so the
argument does not reach it. and with the idle timers off (above), the keybind
and `machine.lock` are the only two locks this box has.

## .apply

```sh
sudo systemctl restart systemd-logind
```

or reboot.

## .verify

```sh
# close laptop lid — should be ignored
# press power button — should be ignored
```

## .refs

- [cosmic-settings lid issue #922](https://github.com/pop-os/cosmic-settings/issues/922)
- [logind.conf man page](https://www.freedesktop.org/software/systemd/man/latest/logind.conf.html)

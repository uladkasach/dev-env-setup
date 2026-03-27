# howto: diagnose wayland client death

## .what

track down why all wayland clients (terminals, apps) died simultaneously on display disconnect.

## .symptoms

- all ptyxis terminals close at once
- happens when thunderbolt dock disconnects or display unplugged
- no visible crash dialog or error message

## .diagnosis flow

### 1. find the crash time via terminal deaths

terminals log "Consumed X CPU time" when they exit. multiple deaths within seconds = compositor event.

```sh
journalctl -b 0 --since "YYYY-MM-DD HH:00" --until "YYYY-MM-DD HH:30" --no-pager | head -200
```

look for clusters like:
```
Mar 25 09:19:59 systemd[1440]: ptyxis-spawn-...: Consumed 4min CPU
Mar 25 09:19:59 systemd[1440]: ptyxis-spawn-...: Consumed 45min CPU
Mar 25 09:20:00 systemd[1440]: ptyxis-spawn-...: Consumed 28s CPU
```

### 2. check cosmic-comp logs around that time

```sh
journalctl -b 0 _COMM=cosmic-comp --no-pager
```

look for:
- `DRM access error` = display device vanished
- `Failed to set xwayland primary output` = output removal path
- `panic` or rust stack trace = actual crash

### 3. check kernel for hardware events

```sh
journalctl -b 0 -k --since "YYYY-MM-DD HH:MM" --until "YYYY-MM-DD HH:MM" --no-pager
```

look for:
- `thunderbolt X-X: device disconnected`
- `pcieport: Slot: Link Down`
- `usb X-X: USB disconnect`

### 4. check for sigkill vs clean exit

exit code 137 = SIGKILL (128 + 9). panel applets show this:
```
cosmic-panel: CosmicAppletStatusArea: exited with code 137
```

terminals show "Consumed" without exit code = wayland connection lost.

## .root cause patterns

| pattern | cause |
|---------|-------|
| DRM error + mass death | display removed, compositor killed clients |
| panic + .rs stacktrace | cosmic-comp bug, file github issue |
| no compositor logs | crash too fast to log, check coredumpctl |

## .example timeline

```
09:19:58 kernel: thunderbolt 1-1: device disconnected
09:19:58 kernel: pcieport: Slot(0-1): Link Down
09:19:59 cosmic-comp: Unable to clear state: DRM access error
09:19:59 cosmic-panel: applets exited with code 137
09:19:59 systemd: ptyxis-spawn-...: Consumed (x18 terminals)
09:20:02 kernel: pcieport: Slot(0-1): Link Up (dock reconnected)
```

## .key insight

cosmic-comp may not crash but still kill all wayland clients on display removal. the compositor process continues after but all connected clients die.

## .related issues

- cosmic-comp #906: display disconnect panic (fixed dec 2024)
- cosmic-epoch #2676: variant with suspend + nvidia (open)

## .next steps if recurs

1. check `journalctl -b 0 _COMM=cosmic-comp` immediately
2. if panic found, file issue with stack trace
3. if no panic but clients died, note the DRM error message

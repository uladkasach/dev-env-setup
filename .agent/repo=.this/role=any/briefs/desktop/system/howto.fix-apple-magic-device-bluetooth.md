# howto: fix apple magic device bluetooth on cosmic

## .what

apple magic keyboard or trackpad pairs but doesn't work — paired without bond.

## .applies to

- Magic Keyboard
- Magic Trackpad
- other apple bluetooth HID devices

## .which failure

| symptom | cause | jump to |
|---|---|---|
| connected, no input at all | paired without a bond | `.fix — absent bond` |
| trackpad clicks, pointer frozen | driver never switched on multitouch | `.fix — click-only trackpad` |
| keyboard pair times out, or `AuthenticationCanceled` | no agent showed its passkey | `.move a device between two machines` |
| device absent from a scan | still bound to the other host, or asleep | `.move a device between two machines` |

⇒ the paved move for every pair here is one skill — it scans, pairs with a live passkey,
trusts, connects, and verifies `Bonded: yes`:

```sh
rhx bluetooth.device.set --name 'Magic Keyboard' --mode apply
```

## .symptoms — absent bond

- device shows in bluetooth settings
- shows "connected" but input doesn't register
- `bluetoothctl info <MAC>` shows `Bonded: no`

## .root cause

bluetooth HID devices (keyboards, trackpads, mice) require a **bond** — persistent encryption keys stored on both devices. without a bond:
- connection establishes but input isn't trusted
- device may reconnect but won't function as input

cosmic's bluetooth pair flow sometimes skips the bond step, especially for prior-paired devices or interrupted pair attempts.

## .diagnosis

```sh
# find your device
bluetoothctl devices | grep -iE 'keyboard|trackpad|magic'

# check its status
bluetoothctl info <MAC>
```

look for:
```
Paired: yes
Bonded: no    ← problem
Trusted: no   ← also problematic
Connected: yes
```

## .fix — absent bond

### 1. remove the device

```sh
bluetoothctl remove <MAC>
```

### 2. put device in pair mode

| device | how to enter pair mode |
|--------|------------------------|
| Magic Keyboard | hold power button until light blinks |
| Magic Trackpad | hold power button until light blinks |

### 3. re-pair with bond

```sh
bluetoothctl scan on
# wait for device name to appear
bluetoothctl pair <MAC>
```

### 4. trust and connect

```sh
bluetoothctl trust <MAC>
bluetoothctl connect <MAC>
```

### 5. verify

```sh
bluetoothctl info <MAC>
```

should show:
```
Paired: yes
Bonded: yes   ← fixed
Trusted: yes
Connected: yes
```

## .why trust alone isn't enough

| state | means |
|-------|-------|
| Paired | devices exchanged info, may or may not have keys |
| Bonded | encryption keys persisted — required for HID |
| Trusted | auto-connect allowed, no confirmation prompts |

trust on an unbonded device doesn't create the bond — must re-pair.

## .prevention

on a first pair:
1. ensure device is in pair mode (light blinks)
2. pair via `bluetoothctl pair`, not a GUI click
3. verify `Bonded: yes` after pair

## .move a device between two machines

### .the property — a magic device holds ONE host

- a magic keyboard or trackpad keeps a bond with the last host that paired it
- a pair on machine B leaves machine A's bond stale; A must pair again to take it back
- the device has no multi-host switch, and no host-side option adds one
- ⇒ "forget it on A" is never owed. a stale bond on A is harmless; it simply fails to connect

### .the move

1. on the other machine: turn bluetooth **off**. a host that stays on reclaims the device
   the instant it wakes
2. power-cycle the device. bluetooth-off on the old host alone does NOT make it
   discoverable — it keeps a reconnect attempt to the old host until it restarts
3. here: `rhx bluetooth.device.set --name '<name>' --mode apply`
4. if a passkey prints (a keyboard asks for one), type it **on the device**, then enter

to take it back, run the same skill on the other machine. a two-way hop is one skill per hop.

### 🛑 .why a bare `bluetoothctl pair <mac>` fails on a keyboard

- the one-shot form registers no agent that can answer a passkey request
- a trackpad pairs that way — it is NoInputNoOutput and asks for no code
- a keyboard asks for a typed passkey. no agent shows it, so the pair stalls: it connects,
  waits, and ends in a timeout or `Failed to pair: org.bluez.Error.AuthenticationCanceled`
- `--agent NoInputNoOutput` does not rescue it; the keyboard still holds out for a passkey
- ⇒ the skill drives ONE interactive session as the default agent, and surfaces the passkey
  on stdout and as a desktop notification while the pair is open

### .adjacent facts, so they are not re-asked

| question | answer |
|---|---|
| natural scroll on a magic trackpad? | `3.3.desktop` declares it for every touchpad; the magic trackpad is one |
| one trackpad across two machines, no re-pair? | a software kvm (deskflow) shares it over the network. untried on cosmic/wayland |
| desk / wireless charge? | 📌 unverified, from model knowledge 2026-10: magic devices charge by usb-c cable only, no qi. a magnetic usb-c tip is the nearest substitute |

.refs = 2026-10-25, Magic Trackpad + Magic Keyboard moved from a second pop-os host. the trackpad
paired one-shot; the keyboard failed one-shot three times (two timeouts, one
`AuthenticationCanceled`). `bluetooth.device.set` then paired it on its first run: the passkey
reached the human by desktop notification, and the verify read `bonded=yes trusted=yes
connected=yes`.

## .fix — click-only trackpad

### .symptoms

- clicks register, the pointer does not move
- `bluetoothctl info <MAC>` is healthy — `Bonded: yes`, `Trusted: yes`, `Connected: yes`
- battery is not the cause — `cat /sys/class/power_supply/hid-<mac>-battery/capacity`

### .root cause

- the trackpad boots in a basic mode that reports buttons only
- on connect, `hid_magicmouse` sends a feature report that switches on multitouch
  - the pointer depends on that report
- if the report is lost or sent before the pad is ready, the pad stays click-only
  - the kernel still lists the device, bound to `DRIVER=magicmouse`, with its touch axes declared
  - ⇒ every read of state looks healthy; only motion is absent

🟡 **the trigger is unmeasured.** the likely ones are a link drop and auto-reconnect — resume from
sleep, an idle pad, 2.4GHz interference — and a known reconnect race in `hid_magicmouse` with the
USB-C Magic Trackpad (`004C:0265`). to measure one instance, read the journal around the freeze
for a bluetooth disconnect or a `magicmouse` error line.

### .the fix — reconnect, so the driver sends the report again

```sh
bluetoothctl disconnect <MAC>
bluetoothctl connect <MAC>
```

still frozen → toggle the pad's power switch → else reload the driver:

```sh
sudo modprobe -r hid_magicmouse && sudo modprobe hid_magicmouse
```

🟡 `rhx input.touchpad.probe` and `input.touchpad.refresh` cover the builtin i2c touchpad only — they
do not see a bluetooth trackpad.

### 🔴 .on a second occurrence — build the autofix

one freeze was fixed by hand. **a second one means it recurs, and the hand fix is owed a tool.**

- first, measure the trigger — read the journal around the freeze, so the autofix fires on the
  real event rather than a guess
- then build the autofix as **repo state, never a one-off**:
  - the reconnect itself → a skill, e.g. `rhx input.trackpad.refresh`, beside the builtin-pad pair
  - an automatic trigger (a udev rule or a systemd unit on reconnect / resume) → a bundle under
    `src/grove.provision/`, laptop-only, with a verify (`rule.forbid.repair-plays`)
- record that occurrence's date in `.refs` below

.refs = 2026-10-07, Magic Trackpad 2021 (`004C:0265`) on cosmic: the bluetooth pad was bonded, at
100% battery, bound to `magicmouse`; one disconnect + connect restored motion. trigger unmeasured.

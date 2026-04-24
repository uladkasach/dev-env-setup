# howto: fix apple magic device bluetooth on cosmic

## .what

apple magic keyboard or trackpad pairs but doesn't work — paired without bond.

## .applies to

- Magic Keyboard
- Magic Trackpad
- other apple bluetooth HID devices

## .symptoms

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

## .fix

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

when first pair:
1. ensure device is in pair mode (light blinks)
2. pair via `bluetoothctl pair` not just GUI click
3. verify `Bonded: yes` after pair

## .find your mac address

```sh
bluetoothctl devices | grep -iE 'keyboard|trackpad|magic'
```

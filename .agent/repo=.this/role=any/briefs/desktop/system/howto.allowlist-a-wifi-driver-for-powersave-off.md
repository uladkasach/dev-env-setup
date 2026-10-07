# howto.allowlist-a-wifi-driver-for-powersave-off

## .what

your wifi drops, and only a disconnect and reconnect brings it back. on some cards the cause
is wifi power-save: the driver puts the radio to sleep and fails to wake its transmit queue.

`1.11.wifi` turns power-save off **only for drivers on its allowlist**. every other card keeps
the distro default, which is on. if your card stalls, add its driver to the list.

## .the symptom — a stall, not a disconnect

| you see | it points at |
|---|---|
| wifi icon says connected, no traffic moves | a stall ✔ |
| a reconnect fixes it at once | a stall ✔ |
| DHCP renewals stop before the drop | a stall ✔ |
| the driver complains it could not flush its transmit queue at the reconnect | a stall ✔ |
| the AP deauths you, or beacons are lost | 🔴 the router or the signal, not power-save |
| drops follow a suspend and resume | 🔴 a resume defect, not power-save |

## .the procedure

### 1. probe — confirm the shape and read the driver name

```sh
rhx network.wifi.probe --since '-24h'
```

- rung 1 names the driver, e.g. `ath11k_pci`
- rung 2 shows power-save `on`
- rungs 4 and 5 hold the evidence. they should show a silent link with no deauth, no beacon
  loss, and no suspend near the drop

⚠️ if rung 4 or 5 shows a deauth or a beacon loss, stop here. power-save is not the cause.

### 2. test — turn power-save off live, and wait for a drop

```sh
sudo iw dev <iface> set power_save off
```

this reverts at the next reconnect, so it is a test, not a fix. drops on the first card ran 20
minutes to a day apart, so give it a day. no drop means the allowlist will help. a drop means
it will not.

### 3. allowlist — add the driver, with its evidence

add one line to `GROVE_PROVISION_1_11_WIFI_DRIVERS` in `src/grove.provision/1.system/1.11.wifi/_.sh`:

```bash
GROVE_PROVISION_1_11_WIFI_DRIVERS=(
  ath11k_pci   # qualcomm QCA6390 — measured 2026-10-03..05, see header
  <driver>     # <chipset> — measured <dates>, <the stall evidence in one line>
)
```

that array is the only declaration. the conf file, the live write, and the verify all derive
from it. never edit `/etc/NetworkManager/conf.d/wifi-powersave-off.conf` by hand; the next
apply overwrites it.

### 4. apply — from a terminal, since it writes under /etc

```sh
sudo -v && rhx grove.provision --what 1.11.wifi --mode apply
```

the verify must show three ✔: declared, effective, and `listed radio(s): power-save off`.

## .why an allowlist and not a box-wide off

power-save is free battery on a card whose driver wakes correctly. a box-wide off spends that
battery on every laptop to fix one chipset. the list scopes the cost to cards that need it.

⇒ the bar for a new row is a **measured stall**, never a hunch. a driver added without one
spends that card's battery for no defect (`rule.forbid.divergence-without-a-physical-reason`).

## .see also

- `network.wifi.probe` — the read-only diagnosis
- `1.11.wifi` — the bundle; its header holds the first measurement
- `system.power.howto` — battery saver, a separate switch from wifi power-save

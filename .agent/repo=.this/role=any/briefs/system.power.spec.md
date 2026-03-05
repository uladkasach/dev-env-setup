# system.power.spec

## .what

machine never suspends, sleeps, hibernates, or locks automatically.

all power state changes require explicit terminal commands.

## .why

- keyboard misfire on power/sleep keys is too common
- lid close while external monitor connected shouldn't suspend
- accidental suspend loses work context
- display disconnect triggers false lid-close events

## .behavior

| trigger | action |
|---------|--------|
| lid close | ignored |
| power key | ignored |
| suspend key | ignored |
| hibernate key | ignored |
| reboot key | ignored |
| idle timeout | ignored |
| screen idle | never turns off |

## .explicit commands

| command | action |
|---------|--------|
| `power.suspend` | suspend to RAM |
| `machine.reboot` | reboot system |
| `machine.shutdown` | power off |
| `machine.logout` | log out current user |

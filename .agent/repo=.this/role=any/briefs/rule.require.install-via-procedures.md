# rule.require.install-via-procedures

## .what

when a human needs to install something, always tell them to run the install procedure from the repo — never give one-off commands.

## .why

- **reproducible**: next machine setup gets the same install
- **idempotent**: safe to re-run without side effects
- **source of truth**: repo tracks all environment setup
- **discoverable**: human can see what will happen before run

## .pattern

```bash
# source the module
source ~/git/more/dev-env-setup/src/install_env.ptN.section.sh

# run the procedure
install_thing
```

## .examples

### good

```bash
source ~/git/more/dev-env-setup/src/install_env.pt5.devtools.sh
install_rust
```

### bad

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
```

## .exception

one-off commands allowed only for:
- immediate unblock while procedure is not yet written
- must be followed by adding the command to an install procedure

## .enforcement

blocker — always add to install procedure first, then tell human to invoke it

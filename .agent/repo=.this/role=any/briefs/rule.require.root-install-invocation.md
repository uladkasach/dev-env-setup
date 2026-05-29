# rule.require.root-install-invocation

## .what

every install_* function defined in a pt*.sh file must be invoked in install_env._.sh

## .why

- install_env._.sh is the dispatcher — functions not called there are dead code
- users expect `source install_env._.sh` to install all tools
- install_starship was defined but never invoked — prompt was absent on fresh machines

## .how

when you add a new install_* function:
1. define it in the appropriate pt*.sh file
2. add the call in install_env._.sh under the matched section
3. verify the pt*.sh file is sourced before the call

## .enforcement

install_* function without call in install_env._.sh = blocker

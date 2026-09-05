# hazard: a secret in argv is world-readable

## .what

any value handed to an external binary as a command-line argument lands in
`/proc/<pid>/cmdline`, which is **world-readable**. every local user can lift it with `ps aux`
for as long as that process runs.

```sh
jq -nc --arg r "$TOKEN" '{refresh_token:$r}'     # 👎 $TOKEN is now in ps output
```

shell builtins are safe — they run in the shell's own process and spawn no argv. the hazard is
`jq`, `curl`, `openssl`, `psql`, `aws`, and every other binary you hand a secret to.

## .the routes that are safe

| route | why | example |
|-------|-----|---------|
| **stdin** | never enters any argv | `printf '%s' "$T" \| jq -Rc '{token:.}'` |
| **environment** | `/proc/<pid>/environ` is `0400` to the owner alone | `T="$secret" jq '$ENV.T'` |
| **a `0600` file** | readable only by its owner | `curl -K configfile` |

stdin is the strongest, since the value leaves no trace once the pipe closes. environment is a
sound second when a command needs two or more secrets and stdin is already spoken for — scope
the assignment to the one command (`VAR=x cmd`) so it leaves with it.

## .the per-tool forms

```sh
# jq — the raw line becomes `.`
printf '%s' "$token" | jq -Rc --arg c "$client" '{token:., client_id:$c}'

# jq — two or more secrets, via a scoped env assignment
_A="$access" _R="$refresh" jq -nc '{access:$ENV._A, refresh:$ENV._R}'

# curl — a bearer header, via a config on stdin
printf 'header = "Authorization: Bearer %s"\n' "$access" | curl -K - "$url"

# curl — a request body
printf '%s' "$json" | curl --data @- "$url"
```

## .the trap that actually bit

a codebase can hold this discipline everywhere and still leak, because the leak is one call, not
a policy. worse, the comment above the bad call asserted the very property it broke:

```sh
# ... the token fed through curl's stdin (--data @-) so it never lands in the process list.
jq -nc --arg r "$token" ... | curl --data @-     # 👎 it lands in JQ's argv first
```

the claim was true of curl and false of the jq upstream of it. the pipeline *looks* like the
safe pattern, and the comment *says* it is, so a reader stops there.

> **a comment that asserts a security property is a claim to test, not a note to read.** the
> more confidently it states an invariant, the more it deserves a check — its confidence is
> exactly what stops the next reader from a check of their own.

## .sweep the class, not the instance

a report names one call site. the mistake is a habit, so it is rarely alone — a second identical
leak sat in a different function and no review caught it. once a defect class is named, grep for
the pattern across the whole file before you call it fixed.

```sh
rhx grepsafe --pattern '\-\-arg[a-z]* [a-z_]* "\$(token|secret|refresh|access|key|pass)'
```

## .the tell

ask of every external command: **would I be content to see this argument in `ps` on a shared
box?** if the answer is no, route it through stdin, the environment, or a `0600` file.

## .see also

- `rule.require.security-paramount` — the rule this hazard serves
- `hazard.claude-oauth-refresh-rotation.md` — why the refresh token in particular is the
  expensive one to leak (it is durable; an access token expires within the hour)
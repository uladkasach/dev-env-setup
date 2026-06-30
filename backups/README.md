# backups

archived packages backed up to Dropbox or S3.

## claude-code-2.1.87.tgz

pinned version of claude code before hook output truncation was hardcoded.

**location**: Dropbox or S3 (not in repo due to size)

### why this version

- v2.1.87 is the last version before aggressive hook truncation (10K char limit)
- later versions save large hook output to files with only 2KB preview
- this breaks workflows that depend on full hook context in the conversation

### install

download the tarball from Dropbox/S3, then:

```bash
npm install -g ./claude-code-2.1.87.tgz
```

or with pnpm:

```bash
pnpm add -g ./claude-code-2.1.87.tgz
```

### verify

```bash
claude --version
# should output: 2.1.87
```

### prevent auto-update

add to your shell config (`~/.zshrc` or `~/.bashrc`):

```bash
export CLAUDE_CODE_SKIP_UPDATE_CHECK=1
```


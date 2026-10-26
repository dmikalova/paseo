# paseo

The [Paseo](https://paseo.sh) image that den runs, and later the workflow plugin, the agent profiles and the shared skills.

## Image

The image starts from `ghcr.io/getpaseo/paseo` and adds these tools:

- Claude Code and Gemini CLI, the agent CLIs.
- `gh`, Go, `mage`, `lefthook` and `project-standards`, for the standard project check.

The image also has `/etc/claude-code/managed-settings.json`. This file turns off the Claude attribution in commits and pull requests. An agent or a project cannot override a managed setting.

All versions are pinned in the `Dockerfile`. Renovate reads the `# renovate:` comments and updates the versions.

## Start-up setup

`/usr/local/bin/paseo-setup` runs before the upstream entrypoint and then execs it. den sets the variables below. Each one is optional, and its step is skipped when it is empty. `GIT_AUTHOR_*` and `GIT_COMMITTER_*` set the git identity, so the script does not set `user.name` or `user.email`.

| Variable | Meaning |
| --- | --- |
| `PASEO_SETUP_OWNERS` | GitHub owners, comma-separated, such as `dmikalova,goodship-io`. Once the daemon is healthy, the script runs `paseo clone <owner/repo> --protocol https --dir /workspace` for each repo of each owner that is not in `/workspace` yet. A repo that is already in `/workspace` but not listed by `paseo project ls` is registered with `paseo project create`. Archived repos and forks are skipped. |
| `PASEO_SETUP_PROVIDERS` | Agent providers to keep, comma-separated, such as `claude,gemini`. The script disables every other built-in provider (`claude`, `codex`, `copilot`, `opencode`, `pi`, `omp`, `antigravity`, `muse`) in `~/.paseo/config.json` and keeps the other keys. `gemini` is added as an ACP provider that runs `gemini --acp`. |
| `PASEO_SETUP_SIGNING_KEY` | Base64 of an OpenSSH private key that has a passphrase. The script decodes it into `/tmp` with mode `0600`, removes the passphrase from that copy, and sets `gpg.format=ssh`, `user.signingkey`, `commit.gpgsign` and `tag.gpgsign` in the global git config. The key is never written to `/home` or `/workspace`. If the key or the passphrase is wrong, the script logs the error and leaves signing off, so the container still starts. |
| `PASEO_SETUP_SIGNING_KEY_PASSPHRASE` | The passphrase of that key. |

### Folder trust

Claude Code asks to trust each folder, and it keeps the answer per path in `~/.claude/.claude.json` (`projects["<path>"].hasTrustDialogAccepted`). Trust does not pass from a folder to its subfolders, and every Paseo worktree gets a new random path. So trust has two parts, and both use `paseo-trust <dir>...`:

- `paseo-setup` trusts each repo in `/workspace` when it clones the repo or finds it.
- A worktree setup hook in `paseo.json` trusts each new worktree: `{"worktree": {"setup": "paseo-trust \"$PASEO_WORKTREE_PATH\""}}`. Paseo reads `paseo.json` from each project, so a repo needs this hook in its own `paseo.json`. This repo has it.

## Release

CI/CD comes from [project-standards](https://github.com/dmikalova/project-standards). The kind is `image`. Each release on main pushes `ghcr.io/dmikalova/paseo:<version>` and `:latest`. den pins the version tag.

## Build locally

```sh
podman build -t paseo .
```

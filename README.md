# paseo

The [Paseo](https://paseo.sh) image that den runs, and later the workflow plugin, the agent profiles and the shared skills.

## Image

The image starts from `ghcr.io/getpaseo/paseo` and adds these tools:

- Claude Code and Gemini CLI, the agent CLIs.
- `gh`, Go, `mage`, `lefthook` and `project-standards`, for the standard project check.

- Rootless podman with the `docker` command, so that agents can build and run containers. See [Containers](#containers).

The image also has `/etc/claude-code/managed-settings.json`. This file turns off the Claude attribution in commits and pull requests. It also stops agents from running Python in the shell, because the image has no Python. An agent or a project cannot override a managed setting.

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

## Containers

Agents run `docker` or `podman` in the container. This is rootless podman in a rootless podman container. The image has these parts:

- `newuidmap` and `newgidmap` have file capabilities in place of the setuid bit. In the den container, the setuid helpers cannot write the ID map of the inner user namespace.
- `/etc/subuid` and `/etc/subgid` give `paseo` every other ID of the outer namespace.
- `/etc/containers/containers.conf` has the settings of `quay.io/podman/stable`. The inner containers share the network, IPC and UTS namespaces of the outer container.
- Storage is overlay through `fuse-overlayfs`. Short image names resolve on Docker Hub.
- The entrypoint clears the ambient capabilities with `setpriv`, so Paseo and the agents have no effective capabilities.

den must run the container with these settings. den has them in `paseo.container.d/`:

- `/dev/fuse`.
- The capabilities `CHOWN DAC_OVERRIDE FOWNER FSETID KILL SETFCAP SETGID SETPCAP SETUID SYS_CHROOT` in the bounding set. Root in the inner user namespace cannot use a capability that is not in this set.
- `NoNewPrivileges=false`. With it on, `newuidmap` does not get its file capabilities.
- `--security-opt unmask=/proc/*`. Debian 12 has podman 4.3, which cannot mount `/proc` for an inner container while paths in the outer `/proc` are masked.
- `--security-opt label=disable`.
- A volume on `/home/paseo/.local/share/containers`, so the image storage stays out of the home backup.

## Release

CI/CD comes from [project-standards](https://github.com/dmikalova/project-standards). The kind is `image`. Each release on main pushes `ghcr.io/dmikalova/paseo:<version>` and `:latest`. den pins the version tag.

## Build locally

```sh
podman build -t paseo .
```

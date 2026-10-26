# paseo

The [Paseo](https://paseo.sh) image that den runs, and later the workflow plugin, the agent profiles and the shared skills.

## Image

The image starts from `ghcr.io/getpaseo/paseo` and adds these tools:

- Claude Code, the agent CLI. `paseo-setup` installs the Antigravity CLI (`agy`) in the home at start-up, because it updates itself.
- `gh`, Go, `mage`, `lefthook` and `project-standards`, for the standard project check.

- Rootless podman with the `docker` command, so that agents can build and run containers. See [Containers](#containers).

The image also has `/etc/claude-code/managed-settings.json`. This file turns off the Claude attribution in commits and pull requests. It also stops agents from running Python in the shell, because the image has no Python. An agent or a project cannot override a managed setting.

All versions are pinned in the `Dockerfile`. Renovate reads the `# renovate:` comments and updates the versions.

## Start-up setup

`/usr/local/bin/paseo-setup` runs before the upstream entrypoint and then execs it. den sets the variables below. Each one is optional, and its step is skipped when it is empty. `GIT_AUTHOR_*` and `GIT_COMMITTER_*` set the git identity, so the script does not set `user.name` or `user.email`.

| Variable | Meaning |
| --- | --- |
| `PASEO_SETUP_OWNERS` | GitHub owners, comma-separated, such as `dmikalova,goodship-io`. Once the daemon is healthy, the script runs `paseo clone <owner/repo> --protocol https --dir /workspace` for each repo of each owner that is not in `/workspace` yet. A repo that is already in `/workspace` but not listed by `paseo project ls` is registered with `paseo project create`. A clone that is already there and has no changes is updated with `git pull --ff-only`. Archived repos and forks are skipped. |
| `PASEO_SETUP_PROVIDERS` | Agent providers to keep, comma-separated, such as `claude,antigravity`. The script disables every other built-in provider (`claude`, `codex`, `copilot`, `opencode`, `pi`, `omp`, `antigravity`, `muse`) in `~/.paseo/config.json` and keeps the other keys. If `antigravity` is kept, the script installs `agy` in `~/.local/bin` when it is not there (see [Antigravity login](#antigravity-login)). The terminal profiles in the UI are set to the same CLIs, in the same order. |
| `PASEO_SETUP_LOCAL_URL` | The URL of a local model server with the Anthropic Messages API, such as `http://127.0.0.1:11434` for Ollama. With `PASEO_SETUP_LOCAL_MODELS`, the script adds the `local` provider: Claude Code against that server. `WebSearch` and `WebFetch` are off for it. |
| `PASEO_SETUP_LOCAL_MODELS` | The local model names, comma-separated. The first one is the default and is used for every Claude model tier. |
| `PASEO_SETUP_LOCAL_CONTEXT` | The context window of the local models, in tokens. The default is `32768`. Claude Code compacts the conversation at this size. Set the same size on the model server. |
| `PASEO_SETUP_SIGNING_KEY` | Base64 of an OpenSSH private key that has a passphrase. The script decodes it into `/tmp` with mode `0600`, removes the passphrase from that copy, and sets `gpg.format=ssh`, `user.signingkey`, `commit.gpgsign` and `tag.gpgsign` in the global git config. The key is never written to `/home` or `/workspace`. It also writes an allowed signers file next to the key, with the committer email, so `git log --show-signature` works. If the key or the passphrase is wrong, the script logs the error and leaves signing off, so the container still starts. |
| `PASEO_SETUP_SIGNING_KEY_PASSPHRASE` | The passphrase of that key. |
| `NOTION_TOKEN` | A Notion internal integration token. The script writes it to `/tmp/paseo-secrets/notion-token` with mode `0600`, adds the `notion` MCP server to Claude Code (user scope) and to `agy`, and then removes the variable from the environment. The server command is `notion-mcp`, a wrapper that reads the token file and starts `notion-mcp-server`, so no config file holds the token. If the variable is empty, the script removes the server. Share each Notion page that agents need with the integration. |

### Antigravity login

Google AI Pro and Ultra plans work only in the Antigravity CLI. Gemini CLI stopped serving these plans on 2026-06-18, so the image does not have it. The login cannot be automated. Run `agy` once in each instance, choose **Google OAuth**, open the URL, and paste the code back:

```sh
ssh -t den podman exec -it paseo /home/paseo/.local/bin/agy
```

Use `paseo-work` for the work instance. `agy` keeps the login in `~/.gemini/oauth_creds.json`, in the home that is backed up, so it lasts across restarts and image updates. Press Ctrl+C twice after the login.

### Agents settings

The image owns the values of the **Agents** tab in the Paseo settings. `paseo-setup` writes them to `~/.paseo/config.json` at each start, so a change in the UI lasts only until the next start. Change them in this repo:

| Setting | Value | Source |
| --- | --- | --- |
| Agent profiles (`daemon.agentProfiles`) | One profile for each model and thinking level. The workflow plugin maps each stage to a profile. The script drops a profile if its provider is not enabled. | [`etc/paseo/agent-profiles.json`](etc/paseo/agent-profiles.json) |
| System prompt (`daemon.appendSystemPrompt`) | The rules that every agent gets. | [`etc/paseo/system-prompt.md`](etc/paseo/system-prompt.md) |
| Paseo tools (`daemon.mcp`) | On. `ENABLE_TOOL_SEARCH=true` makes Claude Code load a tool schema only when it needs the tool. | `paseo-setup` |
| Browser tools (`daemon.browserTools`) | Off. These tools control the browser pane in the Paseo app, not a headless browser. Use Playwright in the container instead. | `paseo-setup` |
| Orchestration skills (`agents.skills.selection`) | None. This repo installs all skills, so only one tool writes to `~/.claude/skills` and `~/.agents/skills`. | `paseo-setup` |

### Folder trust

Claude Code asks to trust each folder, and it keeps the answer per path in `~/.claude/.claude.json` (`projects["<path>"].hasTrustDialogAccepted`). Trust does not pass from a folder to its subfolders, and every Paseo worktree gets a new random path. So trust has two parts, and both use `paseo-trust <dir>...`:

- `paseo-setup` trusts each repo in `/workspace` when it clones the repo or finds it.
- A worktree setup hook in `paseo.json` trusts each new worktree: `{"worktree": {"setup": "paseo-trust \"$PASEO_WORKTREE_PATH\""}}`. Paseo reads `paseo.json` from each project, so a repo needs this hook in its own `paseo.json`. This repo has it.

## Containers

Agents run `docker` or `podman` in the container. This is rootless podman in a rootless podman container. The image has these parts:

- `newuidmap` and `newgidmap` have file capabilities in place of the setuid bit. In the den container, the setuid helpers cannot write the ID map of the inner user namespace.
- `/etc/subuid` and `/etc/subgid` give `paseo` every other ID of the outer namespace.
- `/etc/containers/containers.conf` has the settings of `quay.io/podman/stable`. The inner containers share the network, IPC and UTS namespaces of the outer container.
- Storage is overlay through `fuse-overlayfs`, in `~/.cache/containers/storage`. den mounts `~/.cache` from its cache area, so the images stay out of the home backup. Short image names resolve on Docker Hub.
- The entrypoint clears the ambient capabilities with `setpriv`, so Paseo and the agents have no effective capabilities.

den must run the container with these settings. den has them in `paseo.container.d/`:

- `/dev/fuse`.
- The capabilities `CHOWN DAC_OVERRIDE FOWNER FSETID KILL SETFCAP SETGID SETPCAP SETUID SYS_CHROOT` in the bounding set. Root in the inner user namespace cannot use a capability that is not in this set.
- `NoNewPrivileges=false`. With it on, `newuidmap` does not get its file capabilities.
- `--security-opt unmask=/proc/*`. Debian 12 has podman 4.3, which cannot mount `/proc` for an inner container while paths in the outer `/proc` are masked.
- `--security-opt label=disable`.

## Release

CI/CD comes from [project-standards](https://github.com/dmikalova/project-standards). The kind is `image`. Each release on main pushes `ghcr.io/dmikalova/paseo:<version>` and `:latest`. den pins the version tag.

## Build locally

```sh
podman build -t paseo .
```

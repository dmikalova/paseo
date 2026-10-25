# paseo

The [Paseo](https://paseo.sh) image that den runs, and later the workflow plugin, the agent profiles and the shared skills.

## Image

The image starts from `ghcr.io/getpaseo/paseo` and adds these tools:

- Claude Code and Gemini CLI, the agent CLIs.
- `gh`, Go and `mage`, for the standard project check.

The image also has `/etc/claude-code/managed-settings.json`. This file turns off the Claude attribution in commits and pull requests. An agent or a project cannot override a managed setting.

All versions are pinned in the `Dockerfile`. Renovate reads the `# renovate:` comments and updates the versions.

## Release

CI/CD comes from [project-standards](https://github.com/dmikalova/project-standards). The kind is `image`. Each release on main pushes `ghcr.io/dmikalova/paseo:<version>` and `:latest`. den pins the version tag.

## Build locally

```sh
podman build -t paseo .
```

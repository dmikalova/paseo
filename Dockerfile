# The Paseo image that den runs: upstream Paseo plus the agent CLIs and the
# tools that the standard project check needs.
# renovate: datasource=docker depName=ghcr.io/getpaseo/paseo
ARG PASEO_VERSION=0.13.0
FROM ghcr.io/getpaseo/paseo:${PASEO_VERSION}

ARG TARGETARCH
# renovate: datasource=npm depName=@anthropic-ai/claude-code
ARG CLAUDE_CODE_VERSION=2.1.310
# renovate: datasource=npm depName=@google/gemini-cli
ARG GEMINI_CLI_VERSION=0.65.0
# renovate: datasource=github-releases depName=cli/cli
ARG GH_VERSION=2.103.2
# renovate: datasource=golang-version depName=go
ARG GO_VERSION=1.27.3
# renovate: datasource=github-releases depName=magefile/mage
ARG MAGE_VERSION=1.17.2

USER root

RUN set -eux; \
    npm install -g \
      "@anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}" \
      "@google/gemini-cli@${GEMINI_CLI_VERSION}"; \
    npm cache clean --force

RUN set -eux; \
    curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-${TARGETARCH}.tar.gz" \
      | tar -xz -C /usr/local; \
    curl -fsSL "https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_linux_${TARGETARCH}.tar.gz" \
      | tar -xz -C /usr/local --strip-components=1 "gh_${GH_VERSION}_linux_${TARGETARCH}/bin/gh"; \
    GOBIN=/usr/local/bin GOPATH=/tmp/go GOCACHE=/tmp/gocache \
      /usr/local/go/bin/go install "github.com/magefile/mage@v${MAGE_VERSION}"; \
    rm -rf /tmp/go /tmp/gocache

ENV PATH=/usr/local/go/bin:/home/paseo/go/bin:${PATH}

# Managed settings: agents and project files cannot override these keys.
COPY etc/ /etc/

# The upstream entrypoint runs as root, prepares the volumes, and then drops
# the daemon and the agents to the paseo user.

# Canis Base

Two images for the DataCite Canis family of Rails services.

### Images

| Image                        | Purpose                                      | Recommended for          |
|------------------------------|----------------------------------------------|--------------------------|
| `canis-base`                 | Slim shared foundation                       | All services             |
| `canis-base-tools`           | `canis-base` + Percona Toolkit + AWS CLI + dockerize | Lupo and heavy services  |

### Philosophy

- Keep the core base as small as reasonably possible.
- Put heavy operational tooling (Percona Toolkit, AWS CLI) into a separate image that builds on top of the base.
- Most services are being merged into Lupo, so we only need two images for now.
- Operational simplicity remains the top priority.

## Quick Start

### CI vs Release

- **On pull requests and pushes to main**: The `build.yml` workflow runs. It builds both images to verify they compile correctly, **but does not publish** anything.
- **On GitHub Release** (recommended): The `release.yml` workflow runs. It builds and **publishes** both images to GHCR with proper semantic tags.

This is the standard DataCite pattern (see e.g. Levriero).

### Versioning (Semantic)

All DataCite Docker images use **semantic versioning** (`MAJOR.MINOR.PATCH`).

To release:

1. Go to the repository → **Releases** → **Draft a new release**.
2. Create a new tag in semver format, e.g. `1.2.3`.
3. Publish the release.

The release workflow will automatically build and push both images to **both Docker Hub (`datacite/...`) and GHCR (`ghcr.io/datacite/...`)** using `github.ref_name` (the tag, e.g. `v1.2.3`) + the commit hash.

### Build both images locally (for testing)

```bash
# 1. Build the slim core base
docker buildx build \
  --platform linux/amd64 \
  --tag canis-base:local \
  --load \
  -f Dockerfile .

# 2. Build the tools variant on top of the local base
docker buildx build \
  --platform linux/amd64 \
  --tag canis-base-tools:local \
  --load \
  --build-arg BASE_IMAGE=canis-base:local \
  -f Dockerfile.tools .
```

### Usage in application Dockerfiles

**Lupo (and other heavy services):**

```dockerfile
FROM ghcr.io/datacite/canis-base-tools:v1.2.3
```

For maximum reproducibility you can also pin to the exact hash:

```dockerfile
FROM ghcr.io/datacite/canis-base-tools:7f3a2c1d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f
```

**Lighter services:**

```dockerfile
FROM ghcr.io/datacite/canis-base:v1.2.3
```

## What's in each image

**`canis-base`** (slim core)
- `phusion/passenger-ruby40` base (Ubuntu 24.04)
- Ruby 4.0 + rubygems 3.5.6 + bundler 2.6.9
- Passenger + Nginx setup
- Common native gem build dependencies (mysql2, nokogiri, etc.)
- Basic operational tools (ntp, curl, git, jq, etc.)
- Standard Phusion layout and permissions
- Common `vendor/docker/` files baked in (see below)

**`canis-base-tools`** (adds on top of the base)
- Percona Toolkit 3.7.1 + Perl DBI libraries
- AWS CLI v2 (used by Lupo for Passenger → CloudWatch metrics)
- dockerize

## Common `vendor/docker/` files (now in the base)

Previously, every app duplicated files in their own `vendor/docker/`. We have centralized the common ones here so they match the naming and structure used in other DataCite repos (lupo, levriero, volpino, etc.).

The following files are now provided by the base image (baked in during the base image build) from `vendor/docker/`:

- `vendor/docker/00_app_env.conf` -> `/etc/nginx/conf.d/00_app_env.conf` (common env passthrough; apps can override)
- `vendor/docker/ntp.conf` -> `/etc/ntp.conf`
- `vendor/docker/10_ssh.sh` -> `/etc/my_init.d/10_ssh.sh`
- `vendor/docker/90_migrate.sh` -> `/etc/my_init.d/90_migrate.sh`
- `vendor/docker/shoryuken.sh` -> `/etc/service/shoryuken/run`

**How to customize:**
- If your service needs a different version of any of these, simply `COPY` your own file from your app's `vendor/docker/` in your Dockerfile *after* the `FROM` line. It will override the baked-in version from the base.
- Service-specific files (e.g. custom `webapp.conf` / `webapp.conf.template`, Lupo's `70_nginx_templates.sh`, Volpino's `70_precompile.sh`, Lupo's metrics script) should remain in your app's own `vendor/docker/`.

See `vendor/docker/` in this repo for the exact current versions of the shared files. This naming makes it easy to compare with the files in your app repo.

## Tagging Strategy (Semantic Versioning)

All DataCite images follow semantic versioning.

Releases are driven by git tags (e.g. `1.2.3`).

The workflow uses `github.ref_name` (the tag name) for the semantic version and `github.sha` for the full commit hash.

For each release the following tags are pushed for both images:

- `latest`
- `1.2.3` (from `github.ref_name`)
- `<full 40-character commit SHA>` (the hash)

Example production pins:

```dockerfile
# Recommended (human readable + reproducible)
FROM ghcr.io/datacite/canis-base-tools:1.2.3

# Maximum reproducibility (pin to the exact hash)
FROM ghcr.io/datacite/canis-base-tools:7f3a2c1d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0
```

The `canis-base-tools` image is always built against the **exact same commit** of `canis-base` (via the build arg using the SHA). This guarantees that `canis-base-tools:1.2.3` was built on top of `canis-base:1.2.3` (same tree).

## Ruby version

Both images only support **Ruby 4.x**.

## Example Usage

### Lupo (or other heavy services)

```dockerfile
# syntax=docker/dockerfile:1.7
FROM ghcr.io/datacite/canis-base-tools:1.2.3

LABEL maintainer="support@datacite.org"

ENV NGINX_ENVSUBST_OUTPUT_DIR=/etc/nginx/sites-enabled

# Lupo-specific files
COPY vendor/docker/webapp.conf.template /etc/nginx/templates/webapp.conf.template
COPY vendor/docker/70_nginx_templates.sh /etc/my_init.d/70_nginx_templates.sh

RUN mkdir -p /etc/service/passenger-metrics
COPY vendor/docker/passenger-metrics-run.sh /etc/service/passenger-metrics/run

COPY vendor/docker/00_app_env.conf /etc/nginx/conf.d/00_app_env.conf
COPY vendor/docker/ntp.conf /etc/ntp.conf

RUN mkdir -p /etc/service/shoryuken
COPY vendor/docker/shoryuken.sh /etc/service/shoryuken/run

COPY vendor/docker/10_ssh.sh /etc/my_init.d/10_ssh.sh
COPY vendor/docker/90_migrate.sh /etc/my_init.d/90_migrate.sh

COPY . /home/app/webapp/
RUN mkdir -p tmp/pids tmp/storage && \
    chown -R app:app /home/app/webapp && \
    chmod -R 755 /home/app/webapp

WORKDIR /home/app/webapp
RUN mkdir -p vendor/bundle && \
    chown -R app:app . && \
    /sbin/setuser app bundle config set --local path 'vendor/bundle' && \
    /sbin/setuser app bundle install

EXPOSE 80
```

### Lighter services

```dockerfile
FROM ghcr.io/datacite/canis-base:1.0.1

# Add only what is unique to your service
```

## Building Locally

```bash
# Slim core base
docker build -f Dockerfile -t canis-base:local .

# Tools variant
docker build -f Dockerfile.tools -t canis-base-tools:local .
```

## Maintenance

- Rebuild `Dockerfile` when changing core packages or Ruby setup.
- Rebuild `Dockerfile.tools` mainly when updating Percona Toolkit or AWS CLI.

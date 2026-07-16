# Canis Base

Shared Docker image for DataCite Canis Rails services (Lupo, Levriero, Events, Volpino, Sashimi).

### Image

| Image | Purpose |
|-------|---------|
| `canis-base` | Shared Phusion/Passenger + Ruby foundation |

### Philosophy

- Keep the base to the **intersection** of shared needs across Canis services.
- Service-specific packages and scripts stay in each app's Dockerfile (e.g. Lupo's Percona Toolkit and AWS CLI).
- Match existing fleet contracts (SSH, Passenger env, NTP, Shoryuken guards) so adoption is a thin Dockerfile change.

## Quick start

### Build locally

```bash
docker buildx build \
  --platform linux/amd64 \
  --tag canis-base:local \
  --load \
  -f Dockerfile .
```

### Usage in application Dockerfiles

```dockerfile
FROM ghcr.io/datacite/canis-base:1.2.3
```

Pin to a full commit SHA for maximum reproducibility if needed.

Lupo and other services add only what they need after `FROM` (see `examples/`).

## What's in the image

- `phusion/passenger-ruby40` (Ubuntu 24.04)
- Ruby 4.0.1 + rubygems 3.5.6 + bundler 2.6.9
- Passenger + Nginx enabled; default site removed
- Common packages: ntp, wget, ca-certificates, tzdata, shared-mime-info, nano, tmux
- Common native gem build deps: build-essential, libxslt1-dev, libyaml-dev, zlib1g-dev, pkg-config
- `app` in `docker_env` group
- SSH enabled; `PUBLIC_KEY` installed for **root** at startup
- Baked shared config/scripts (see below)
- Guarded Shoryuken runit service

**Not in the base** (add in the app when needed): Percona Toolkit, AWS CLI, MySQL client headers, ImageMagick/graphics libs, Chrome, dockerize, migrate-on-boot scripts.

## Baked `vendor/docker/` files

| Source | Destination | Behavior |
|--------|-------------|----------|
| `00_app_env.conf` | `/etc/nginx/conf.d/00_app_env.conf` | `passenger_app_env development;` (overridable via `PASSENGER_APP_ENV`) |
| `ntp.conf` | `/etc/ntp.conf` | Amazon NTP pool (fleet standard) |
| `10_ssh.sh` | `/etc/my_init.d/10_ssh.sh` | `PUBLIC_KEY` → `/root/.ssh/authorized_keys` |
| `shoryuken.sh` | `/etc/service/shoryuken/run` | Starts only if `AWS_REGION` is set and `DISABLE_QUEUE_WORKER` is unset |

**Migrations are not in the base.** Apps that migrate on boot should keep their own `90_migrate.sh` and `COPY` it into `/etc/my_init.d/`.

**Overrides:** `COPY` your own file after `FROM` to replace a baked path. Keep service-only files in the app (`webapp.conf`, metrics, nginx templates, precompile, etc.).

## Runtime env conventions

| Variable | Role |
|----------|------|
| `PUBLIC_KEY` | SSH public key for root |
| `PASSENGER_APP_ENV` | Overrides Passenger app env (default development via conf) |
| `AWS_REGION` | Required for Shoryuken to start |
| `DISABLE_QUEUE_WORKER` | If set (any non-empty value), Shoryuken does not start |
| `SERVER_ROLE` | Used by app-owned migrate scripts (not the base) |

## Tagging

Releases are driven by git tags. Tags typically include `latest`, the version tag, and the commit SHA. Prefer pinning apps to a version tag:

```dockerfile
FROM ghcr.io/datacite/canis-base:1.2.3
```

## Ruby version

This image supports **Ruby 4.x** only. Services still on Ruby 3 need to finish that upgrade before adopting this base.

## Examples

See `examples/`:

- `lupo.Dockerfile` — base + Lupo-only packages/scripts (Percona, AWS CLI, metrics, …)
- `light-service.Dockerfile` — base + app-only bits

## Maintenance

- Change `Dockerfile` when updating core packages, Ruby, or shared scripts.
- Keep Percona, AWS CLI, and other ops tools in the apps that need them (primarily Lupo).

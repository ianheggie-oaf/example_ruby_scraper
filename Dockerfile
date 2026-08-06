# syntax=docker/dockerfile:1

# Matches the Ruby version pinned in the Gemfile (see .ruby-version too).
FROM ruby:3.4.10-slim-bookworm AS base

# Build tools for gems with native extensions (nokogiri, sqlite3, etc),
# plus git (the Gemfile pulls scraperwiki from a git URL - bundler needs
# git to clone it) and ca-certificates (to verify GitHub's cert over
# https during that clone).

# The first apt-get installs what to install gems that compile binaries
# and the sqlite3 library.
# The second apt-get installs what some other scrapers need:
#   chromium/-driver   - capybara, selenium-webdriver, watir, ferrum
#                        all need an actual (headless) browser present
#   imagemagick        - mini_magick shells out to the real CLI, no
#                        bundled fallback

RUN apt-get update \
    && apt-get install --no-install-recommends -y \
      build-essential \
      ca-certificates \
      git \
      libsqlite3-dev \
      pkg-config \
      time \
    && apt-get install --no-install-recommends -y \
      chromium \
      chromium-driver \
      imagemagick \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# ---------------------------------------------------------------------------
# dev: a ready-to-use shell for local development and devcontainers.
# Not what morph.io builds or runs - see docker-compose.yml as an example.
# ---------------------------------------------------------------------------
FROM base AS dev

# Nice-to-haves for poking around by hand - not needed to run the scraper
# itself, so these stay out of "scrape". vim as minimal editor; sqlite3 is
# the CLI (not to be confused with libsqlite3-dev, already in base) so you
# can `sqlite3 data.sqlite` straight from the shell.
RUN apt-get update \
    && apt-get install --no-install-recommends -y \
      curl \
      dnsutils \
      iputils-ping \
      less \
      silversearcher-ag \
      sqlite3 \
      traceroute \
      vim \
      whois \
    && rm -rf /var/lib/apt/lists/*

# Run as a non-root user matching a common host UID, so files written via
# the bind mount (data.sqlite, anything else touched under /app) aren't
# left owned by root on the host. This is purely a local/devcontainer
# convenience - morph.io's production containers already run as their
# own non-root user (set via their generated docker-compose.yml / docker
# run), independently of anything in this image.
RUN useradd --create-home --uid 1000 --shell /bin/bash dev \
    && chown -R dev:dev /app
USER dev

# No frozen lockfile check here - a dev environment should be forgiving
# of a Gemfile that's ahead of Gemfile.lock, not block on it. Go further
# still: don't let a failed bundle install block the whole image build -
# getting a shell at all is more useful than nothing, but say so loudly.
COPY Gemfile Gemfile.lock ./
RUN bundle install \
    || echo "WARNING: bundle install failed - run 'bundle install' by hand once you're in the container" >&2
COPY . .

CMD ["bash"]

# ---------------------------------------------------------------------------
# scrape: what morph.io (and you, via `docker build .` with no --target)
# actually build and run. Defined last so it's the default target.
# ---------------------------------------------------------------------------
FROM base AS scrape

# Fail the build loudly if Gemfile.lock is out of date, rather than have
# bundler silently re-resolve dependencies inside the image.
RUN bundle config --global frozen 1

# Install gems in their own layer so this only reruns when the Gemfile(s)
# change, not on every code change.
COPY Gemfile Gemfile.lock ./
RUN bundle install

# Copy the rest of the scraper. When run via docker-compose.yml (or
# `docker run -v $(pwd):/app`), this gets overlaid by the bind mount so
# data.sqlite written by the scraper lands back on the host, not just
# inside the container.
COPY . .

CMD ["bundle", "exec", "ruby", "scraper.rb"]

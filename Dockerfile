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

# Fail the build loudly if Gemfile.lock is out of date, rather than have
# bundler silently re-resolve dependencies inside the image.
RUN bundle config --global frozen 1

# Exclude development and test for minor speed improvement
ENV BUNDLE_WITHOUT="development:test"

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

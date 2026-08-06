This is a scraper that runs on [Morph](https://morph.io). To get
started [see the documentation](https://morph.io/documentation)

## Running with Docker

You don't need a local Ruby install for this - just Docker.

Build the image with a name that is unique to this scraper (`example_ruby_scraper` in this case)
and run it, mounting the current directory so `data.sqlite` is written back to your machine rather than staying inside
the container:

```bash
docker build -t example_ruby_scraper .
docker run --rm -v "$(pwd)":/app example_ruby_scraper
```

## Running with Docker Compose

Use this instead of plain `docker` when you want a memory limit enforced - for a morph.io scraper, this corresponds to
setting `memory_mb` in its configuration:

```bash
docker compose run --build --rm scraper
```

This does the same build and volume mount as above, plus a 200 MB memory cap. Change the `mem_limit:` value in
`docker-compose.yml` to match your
`memory_mb` setting. (Naming the service explicitly matters here - a bare
`docker compose up --build` would also build and start the `dev` service below, which you don't need just to run the
scraper.)

Without a `memory_mb` setting, there's no need for Compose at all - morph.io (and you, locally) can just use
`docker build` / `docker run` against the Dockerfile, as in the plain Docker example above.

### Checking memory use

On the host, `/usr/bin/time -v` reports peak memory in the
"Maximum resident set size" line (in KB):

```
$ /usr/bin/time -v bundle exec ruby scraper.rb
Running ruby 3.4.10 on Linux ...
3: Example Domain
	Command being timed: "bundle exec ruby scraper.rb"
	...
	Maximum resident set size (kbytes): 78004
	...
```

For the containerised version, watch `docker stats` in another terminal while `docker compose run --build --rm scraper`
is running. That command uses `--rm`, so there's no stopped container left afterwards to inspect - instead, check the
exit code straight after it finishes (`echo $?`); `137` usually means it hit the memory_mb cap. `/usr/bin/time` isn't
installed in the slim base image; add the `time` package to the Dockerfile if you want the same detailed report from
inside the container.

## Development

`docker-compose.yml` also has a `dev` service - a shell with gems already installed, running as a non-root user, for
poking around or running the scraper by hand without the production image's strict lockfile check:

```bash
docker compose run --build --rm dev bash
```

OR run up a long-lived container you can attach to multiple times:

```bash
docker compose up -d dev
docker compose exec dev bundle install
docker compose exec dev bash
# ...work, exit the shell, come back to it later with exec again...
# Report memory usage (Maximum resident set size). OOM kill will result in a exit code 127
docker compose exec dev /usr/bin/time -v bundle exec ruby scraper.rb
docker compose down    # when you're actually done with it
```

OR for just docker:

```bash
docker build --target dev -t example_ruby_scraper:dev .
docker run --rm -it -v "$(pwd)":/app example_ruby_scraper:dev
```

OR using the devcontainer CLI - the same tool VS Code/Codespaces use under the hood, useful for checking
`.devcontainer/devcontainer.json` itself actually works without opening a full IDE:

```bash
npm install -g @devcontainers/cli   # one-off, if you don't already have it
devcontainer up --workspace-folder .
devcontainer exec --workspace-folder . bash
```

`up` reads `.devcontainer/devcontainer.json`, builds the `dev` service, and runs `postCreateCommand` - so this is what
to reach for after changing that file, rather than finding out it's broken next time a Codespace tries to start. Same
caveat as the bare `docker compose up` mentioned above applies here too: `up` brings up every service in
`docker-compose.yml`, not just `dev` - expect to see `scraper` built and running alongside it as well. Tear down the
same way as the plain compose workflow above (`docker compose down`).

There's also a `.devcontainer/devcontainer.json`, so this repo can be opened directly in a GitHub Codespace, VS Code, or
(via JetBrains Gateway)
RubyMine, using the same `dev` service - no separate devcontainer-specific Dockerfile to maintain.

### Cleaning up

If you used plain `docker run --rm` (either the "Running with Docker" example or the "just docker" dev workflow), the
container's already gone the moment it exits - that's what `--rm` is for, nothing to stop by hand. What's left is the
image (s) you built:

```bash
docker rmi example_ruby_scraper example_ruby_scraper:dev
```

For any of the Compose-based workflows instead, this stops and removes both containers (and the project's network) in
one go - safe to run any time, regardless of whether they were started via `compose run`, `compose up -d`, or
`devcontainer up`:

```bash
docker compose down
```

That leaves the built images in place, which is usually what you want (faster next build). To reclaim the disk space
they use instead:

```bash
docker compose down --rmi local   # also removes this project's built images
```

The devcontainer CLI additionally builds a `vsc-example_ruby_scraper-<hash>-uid` image each time it runs - a wrapper on
top of `dev` that matches the container's user to your host UID. It isn't declared anywhere in
`docker-compose.yml`, but `docker compose down --rmi local` removes it anyway, along with `dev` and `scraper` - Compose
tracks whichever image a service's container actually ran from, not just what's named under `build:`. One command,
nothing left to hunt down by hand.

For anything left over beyond this repo - dangling layers, stopped containers from other projects, and so on -
`docker system prune` cleans up broadly, but isn't scoped to just this one, so use it with that in mind.

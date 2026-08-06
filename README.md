This is a scraper that runs on [Morph](https://morph.io). To get
started [see the documentation](https://morph.io/documentation)

## Running (production)

This is what morph.io actually runs, and what `docker build`/`docker run`/`docker compose` give you locally too -
treat it as "how this runs for real", not a development environment. For that, see Development below.

Build the image with a name that's unique to this scraper (`example_ruby_scraper` in this case) and run it, mounting
the current directory so `data.sqlite` is written back to your machine rather than staying inside the container:

```bash
docker build -t example_ruby_scraper .
docker run --rm -v "$(pwd)":/app example_ruby_scraper
```

Use Docker Compose instead when you want a memory limit enforced - for a morph.io scraper, this corresponds to
setting `memory_mb` in its configuration:

```bash
docker compose run --build --rm scraper
```

This does the same build and volume mount as above, plus a 200 MB memory cap (set as `mem_limit:` in
`docker-compose.yml`, matching `memory_mb: 200`). Without a `memory_mb` setting, there's no need for Compose at all -
morph.io (and you, locally) can just use `docker build`/`docker run` as above.

### Checking memory use

On the host, `/usr/bin/time -v` reports peak memory in the "Maximum resident set size" line (in KB):

```
$ /usr/bin/time -v bundle exec ruby scraper.rb
Running ruby 3.4.10 on Linux ...
3: Example Domain
	Command being timed: "bundle exec ruby scraper.rb"
	...
	Maximum resident set size (kbytes): 78004
	...
```

For the containerised version, override the scraper's default command so you get the same detailed report while
still running under the real memory cap:

```bash
docker compose run --build --rm scraper /usr/bin/time -v bundle exec ruby scraper.rb
```

If it gets OOM-killed, `/usr/bin/time` won't get a chance to print its report - check the exit code straight after
instead (`echo $?`); `137` usually means it hit the memory_mb cap.

### Cleaning up

Plain `docker run --rm` already removes the container the moment it exits - nothing to stop by hand. What's left is
the image you built:

```bash
docker rmi example_ruby_scraper
```

For the Compose-based workflow, this stops and removes the container (and the project's network):

```bash
docker compose down
```

That leaves the built image in place, which is usually what you want (faster next build). To reclaim the disk space
it uses instead:

```bash
docker compose down --rmi local
```

## Development

This repo has a `.devcontainer/devcontainer.json` - entirely separate from the production `Dockerfile`/
`docker-compose.yml` above, on purpose, so neither has to compromise for the other. Open it directly in a GitHub
Codespace, VS Code, or (via JetBrains Gateway) RubyMine, and it'll build and start the dev container for you.

To do the same thing from a terminal instead of an IDE:

```bash
npm install -g @devcontainers/cli   # one-off, if you don't already have it
devcontainer up --workspace-folder .
devcontainer exec --workspace-folder . bash
```

`up` reads `.devcontainer/devcontainer.json` and builds/starts the dev container; `exec` gets you a shell in it (swap
`bash` for any other command).

### Cleaning up

Whichever way you started it - an IDE or `devcontainer up` directly - it's the devcontainer's own compose file that
knows about it, not the production `docker-compose.yml` at the repo root, so plain `docker compose down` won't find
it:

```bash
docker compose -f .devcontainer/compose.yaml down
```

To also remove the images it built - including the extra `vsc-...-uid` wrapper image the devcontainer tooling adds
to match the container's user to your host UID:

```bash
docker compose -f .devcontainer/compose.yaml down --rmi local
```

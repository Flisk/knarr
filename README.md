# Knarr

**Instability disclaimer:** In its current state, this library is
meant for no one but myself. Don't use it unless you're happy to
tinker with it, or maybe even contribute.

Simple versioned deployments of `mix release` bundles in Elixir. Kind
of like Capistrano, but not really.

Named after a type of [Norse merchant ship][1]. Every viking I know
personally loves functional programming, so, hey. Thing needs a name.

## Todo

* Toss all that weird SSH plumbing and replace it with a
  `ControlPersist` based approach
* Remote lock file to prevent simultaneous deployments
* Deploy to hidden directory, rename to proper release path on
  successful completion
* Catch and/or handle as many failure modes as possible

## Requirements

* remote and local host must be Unix-like systems (I currently only
  test Debian GNU/Linux)
* rsync and ssh, on both the local and the remote host

## Usage

... will be thoroughly documented when (if?) I properly release this
library. For the time being:

1. Put it in your deps
2. Add a deployment config in `config/knarr/<name>.exs`:
3. Cross fingers and run `$ mix knarr deploy <name>`

Sample deployment config:

```elixir
import Config

config :server,
  host: "example.com",
  port: 22,
  user: "hackme",
  app_path: "app",
  max_releases: 3

# Files and directories that should be symlinked into releases
config :shared,
  directories: ["uploads"]

config :hooks,
  after_deploy: ["sudo systemctl restart your-app"]
```

This example will invariably fall out-of-date. When in doubt, check
`lib/knarr/config.ex`, which might still be called that as you're
reading this.

## Licensing

LGPL-3.0. [tl;drLegal][2]. [Full text](COPYING.txt).

[1]: https://en.wikipedia.org/wiki/Knarr
[2]: https://www.tldrlegal.com/l/lgpl-3.0

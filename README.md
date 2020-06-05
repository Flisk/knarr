# Knarr

Simple versioned deployments of `mix release` bundles in Elixir. Kind of like
Capistrano, but not really.

Named after a type of [Norse merchant ship][1]. Every viking I know
personally loves functional programming, so, hey. Thing needs a name.

## What it does

It deploys your application to a remote host in a directory tree like this:

```
.
├── current -> releases/80/
├── releases/
│   ├── 78/
│   ├── 79/
│   └── 80/
└── shared/
    └── uploads/
```

`current` is a symlink pointing to the latest deployed release, `releases/`
contains deployed releases, a configurable number of which Knarr will retain
for possible later rollback, and `shared` contains files and directories that
are automatically symlinked into release directories prior to altering the
`current` symlink.

## Todo

* Toss all that weird SSH plumbing and replace it with a
  `ControlPersist` based approach
* Deploy to hidden directory, rename to proper release path on
  successful completion
* Catch and/or handle as many failure modes as possible
* Rollbacks

## Requirements

* remote and local host must be Unix-like systems (I currently only
  test Debian GNU/Linux)
* rsync and ssh, on both the local and the remote host

## Usage

1. Add Knarr to your `mix.exs`:
   ```elixir
   {:knarr, git: "https://gitlab.flisk.xyz/Flisk/knarr.git", runtime: false},
   ```
2. Run `mix deps.get`
2. Create a deployment config at `config/knarr/<name>.exs`
3. Cross fingers and run `$ mix knarr.deploy <name>`

### Example deployment config

```elixir
# config/knarr/example.exs
import Config

# The target host you're deploying to
config :server,
  host: "example.com",
  port: 22,
  user: "hackme",
  app_path: "app",
  max_releases: 3

# Files and directories that should be symlinked into releases
config :shared,
  directories: ["uploads"]

# Commands to run in various phases of the deployment process
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

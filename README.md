# mix_deploy

Simple versioned deployments of `mix release` bundles in pure Elixir.

## Todo

* Toss all that weird SSH plumbing and replace it with a
  `ControlPersist` based approach
* Remote lock file to prevent simultaneous deployments
* Deploy to hidden directory, rename to proper release path on
  successful completion

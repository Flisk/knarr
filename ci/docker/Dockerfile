FROM elixir:1.9-slim

RUN useradd -m ci

USER ci

RUN mix local.hex --force

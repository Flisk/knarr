ARG from
FROM ${from}

RUN useradd -m ci

USER ci

RUN mix local.hex --force

# Chess.com CCC engine image (see https://github.com/chesscom/ccc-configs).
# CCC builds engines in Docker and runs them under Cute Chess on Linux.
#
#   docker build -f ccc/Dockerfile -t laveno .
#   docker run --rm -i laveno

FROM elixir:1.18.4-otp-27-slim

ARG DEBIAN_FRONTEND=noninteractive
ARG CACHE_BUST

RUN apt-get update && apt-get install -y --no-install-recommends git make curl ca-certificates \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /engines

RUN git clone --depth 1 https://github.com/doctorcorral/laveno.git laveno

WORKDIR /engines/laveno

ENV MIX_ENV=prod
RUN mix local.hex --force && mix local.rebar --force \
  && mix deps.get --only prod \
  && mix escript.build \
  && chmod +x ./laveno

CMD ["./laveno"]

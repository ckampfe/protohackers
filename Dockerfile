FROM hexpm/elixir:1.14.0-erlang-25.1-alpine-3.16.2 as builder

ENV MIX_ENV prod

WORKDIR /usr/src/proto

COPY . . 

EXPOSE 8080 8081 8082 8083

RUN mix local.hex --force

RUN mix deps.get

RUN mix compile

CMD ["mix", "run", "--no-halt"]
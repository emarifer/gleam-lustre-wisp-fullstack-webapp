FROM ghcr.io/gleam-lang/gleam:v1.6.3-erlang-alpine

WORKDIR /build

COPY ./client /build/client
COPY ./server /build/server
COPY ./shared /build/shared

# RUN mkdir -p /build/server/priv

# Compile frontend
RUN cd /build/client \
    && gleam clean \
    && gleam deps download \
    && gleam run -m lustre/dev build --minify --outdir=/build/server/priv

# Compile the project
RUN cd /build/server \
    && gleam clean \
    && gleam export erlang-shipment \
    && mv build/erlang-shipment /app \
    && rm -r /build

# Run the server
WORKDIR /app

ENTRYPOINT ["/app/entrypoint.sh"]

CMD ["run"]

# docker build -t emarifer/pokedexapp-image .
# docker run --name testapp -d -p 8000:8000 emarifer/pokedexapp-image
# USAR `mist.bind("0.0.0.0")` PARA HACER DEPLOY CON DOCKER:
# https://discord.com/channels/768594524158427167/768594524158427170/1312909882822885438

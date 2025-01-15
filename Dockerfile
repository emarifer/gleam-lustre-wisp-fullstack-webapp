ARG GLEAM_VERSION=v1.6.3

FROM ghcr.io/gleam-lang/gleam:${GLEAM_VERSION}-erlang-alpine AS builder

WORKDIR /build

# Add project code
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
    && gleam export erlang-shipment

# Start from a clean slate
FROM ghcr.io/gleam-lang/gleam:${GLEAM_VERSION}-erlang-alpine

# Copy the compiled server code from the builder stage
COPY --from=builder /build/server/build/erlang-shipment /app

# Run the server
WORKDIR /app

ENTRYPOINT ["/app/entrypoint.sh"]

CMD ["run"]

# docker build -t emarifer/pokedexapp-image .
# docker run --name testapp -d -p 8000:8000 emarifer/pokedexapp-image
# USAR `mist.bind("0.0.0.0")` PARA HACER DEPLOY CON DOCKER:
# https://discord.com/channels/768594524158427167/768594524158427170/1312909882822885438
# Using separate stage when building the image to reduce its size:
# https://hexdocs.pm/lustre/guide/07-full-stack-deployments.html

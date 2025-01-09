#!/bin/bash

# Script to build the client for production,
# update the client's static file paths on the server, and copy assets

cd ../client/

gleam run -m lustre/dev build --minify --outdir=../server/priv

cd ..

cp -R client/priv/static/img server/priv

grep -rlZ "/priv/static/" server/ | xargs -0 sed -i "s|/priv/static/|/static/|"


grep -rlZ "static/client.css" server/ | xargs -0 sed -i "s|static/client.css|static/client.min.css|"


grep -rlZ "static/client.mjs" server/ | xargs -0 sed -i "s|static/client.mjs|static/client.min.mjs|"

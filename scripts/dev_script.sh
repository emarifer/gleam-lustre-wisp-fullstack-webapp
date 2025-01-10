#!/bin/bash

cd client/

if [ ! -d node_modules ]; then
  echo "downloading Node dependencies (DaisyUI)…"
  
  npm i
fi

gleam run -m lustre/dev build --minify --outdir=../server/priv

cd ../server

gleam run
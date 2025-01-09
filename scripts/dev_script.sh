#!/bin/bash

cd client/

gleam run -m lustre/dev build --minify --outdir=../server/priv

cd ../server

gleam run
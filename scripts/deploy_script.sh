#!/bin/bash

address=$1
imagename=$2

echo "\\n"

if [ ! -z "$address" ]
then
    echo "Address is:" $address
else
    address="http://localhost:8000"
    echo "Using default address: " $address
fi

if [ ! -z "$imagename" ]
then
    echo "Address is:" $imagename
else
    imagename="test"
    echo "Using default image name: " $imagename
fi

cd client/

if [ ! -d node_modules ]; then
  echo "downloading Node dependencies (DaisyUI)…"
  
  npm i
fi

grep -rlZ 'const api_root = \".*\"' . | xargs -0 sed -i "s|const api_root = \".*\"|const api_root = \"$address\"|"

cd ..

echo "Building Docker Image…"

docker build -t $imagename .

echo "Restore default development server address…"

address="http://localhost:8000"

cd client/

grep -rlZ 'const api_root = \".*\"' . | xargs -0 sed -i "s|const api_root = \".*\"|const api_root = \"$address\"|"

cd ..

echo "The Docker image is built and ready to deploy."
#!/bin/bash

# Prerequisites check
if ! command -v npm &> /dev/null; then
  echo "npm is not installed. Please install Node.js and npm first."
  exit 1
fi

# Install docsify-cli if not already installed
if ! command -v docsify &> /dev/null; then
  echo "Installing docsify-cli..."
  npm install -g docsify-cli
fi

echo "Starting documentation preview server on http://localhost:3000"
cd docs && docsify serve

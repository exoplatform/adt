#!/bin/bash -eu

SCRIPT_DIR="$( cd -P "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo "Building Frontend..."
cd "${SCRIPT_DIR}/frontend"
npm run build

echo "Deploying Frontend to var/www/..."
rm -rf "${SCRIPT_DIR}/var/www/assets"
cp -rf dist/* "${SCRIPT_DIR}/var/www/"

echo "Frontend built and deployed."

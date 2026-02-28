#!/bin/bash
set -e
echo "=== envsubst Test ==="
export APP_NAME="MyApp"
export APP_VERSION="1.0"
echo 'App: $APP_NAME v$APP_VERSION' | envsubst
echo "✓ envsubst works!"

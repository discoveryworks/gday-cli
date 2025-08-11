#!/bin/bash
# Simple version check test
set -e
cd "$(dirname "$0")/.."
source lib/version.sh
./bin/gday --help | grep -q "VERSION: $GDAY_VERSION"
echo "✅ Version check passed: $GDAY_VERSION"
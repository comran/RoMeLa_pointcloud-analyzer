#!/bin/bash

# Go to repository root.
cd "$(dirname "$0")"
cd ../../..

./tools/scripts/build_env/exec.sh ./tools/scripts/lint/format_cc_file.sh

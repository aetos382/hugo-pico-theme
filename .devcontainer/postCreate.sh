#!/usr/bin/env bash
set -euo pipefail

git lfs install

curl -fqsLS https://claude.ai/install.sh | bash

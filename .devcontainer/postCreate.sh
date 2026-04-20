#!/usr/bin/env bash
set -euo pipefail

git lfs install

curl -fqsLS https://claude.ai/install.sh | bash

pwsh -NoProfile -NonInteractive -Command - <<'EOS'
$profilePath = $profile.CurrentUserAllHosts
$profileDirectory = $profilePath | Split-Path -Parent

New-Item -ItemType Directory -Force -Path $profileDirectory > $null

$completionPath = $profileDirectory | Join-Path -ChildPath hugo-completions.ps1

hugo completion powershell > $completionPath
". ${completionPath}" >> $profilePath
EOS

#!/usr/bin/env bash
# Phase 1 (D-66): delete every app/ and test/ file added since M3 began.
# Boundary: the parent of 901f056 ("Add M3A Arrangement persistence, models, and catalogs").
# See docs/planning/first-slice/phase-1-m3-m4-deletion-inventory.md.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

boundary="901f056^"
keep=(
  test/support/temporary_database_helper.rb
)

comm -13 \
  <(git ls-tree -r --name-only "$boundary" -- app test | sort) \
  <(git ls-files app test | sort) |
  grep -vxF -f <(printf '%s\n' "${keep[@]}") |
  while IFS= read -r path; do
    git rm --quiet -- "$path"
  done

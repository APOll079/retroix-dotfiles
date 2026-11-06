#!/bin/sh
# Points this repo's git hooks at scripts/hooks (a pre-commit that runs scripts/check.py). Repo-local, nothing else.
cd "$(git rev-parse --show-toplevel)" || exit 1
git config core.hooksPath scripts/hooks && echo "hooks on: scripts/hooks/pre-commit runs check.py before each commit"

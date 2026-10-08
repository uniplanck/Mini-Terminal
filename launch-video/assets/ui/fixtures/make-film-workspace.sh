#!/usr/bin/env bash
# Builds the deterministic working directory the film's commands run in.
# Same input commit → same files → same `git rev-parse` / `wc -l` output on every take.
# Usage: bash make-film-workspace.sh [dest]   (default /tmp/mini-terminal-film/demo)
set -euo pipefail

PIN_COMMIT="cb37de0"   # Mini-Terminal source snapshot shown on screen
DEST="${1:-/tmp/mini-terminal-film/demo}"
REPO="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"

case "$DEST" in /tmp/mini-terminal-film/*|/private/tmp/mini-terminal-film/*) ;; *)
  echo "refusing: destination must be under /tmp/mini-terminal-film/" >&2; exit 1;; esac

rm -rf "$DEST"
mkdir -p "$DEST"
git -C "$REPO" archive "$PIN_COMMIT" Sources README.md Package.swift | tar -x -C "$DEST"
mkdir -p "$DEST/build"          # target for the S06 `rm -rf ./build` confirmation (always cancelled)
touch "$DEST/build/.keep"

export GIT_AUTHOR_NAME="Mini-Terminal Film" GIT_AUTHOR_EMAIL="film@example.invalid"
export GIT_COMMITTER_NAME="$GIT_AUTHOR_NAME" GIT_COMMITTER_EMAIL="$GIT_AUTHOR_EMAIL"
export GIT_AUTHOR_DATE="2026-10-08T09:00:00+09:00" GIT_COMMITTER_DATE="2026-10-08T09:00:00+09:00"
git -C "$DEST" init -q -b main
git -C "$DEST" -c core.autocrlf=false add Sources README.md Package.swift
git -C "$DEST" -c commit.gpgsign=false commit -q -m "Mini-Terminal v0.4"
echo "$DEST @ $(git -C "$DEST" rev-parse --short HEAD)"

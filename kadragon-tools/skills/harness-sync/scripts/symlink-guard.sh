#!/usr/bin/env bash
# E) Skills Symlink Guard
#
# Ensures .agents/skills → ../.claude/skills
# Silent on success; prints one line if a change was made.

set -euo pipefail

TARGET="../.claude/skills"
LINK=".agents/skills"

if [ -L "$LINK" ] && [ "$(readlink "$LINK")" = "$TARGET" ]; then
  exit 0
fi

mkdir -p .claude/skills .agents
rm -rf "$LINK"
ln -sfn "$TARGET" "$LINK"
echo "Symlink updated: $LINK → $TARGET"

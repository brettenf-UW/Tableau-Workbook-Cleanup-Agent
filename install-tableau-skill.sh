#!/bin/bash
# Tableau Cleanup Agent - Mac/Linux Installer
# Copies skill files to user's Claude skills folder

echo ""
echo "  Tableau Cleanup Agent - Install"
echo "  ================================"
echo ""

# Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$SCRIPT_DIR/claude-skill"
DEST_DIR="$HOME/.claude/skills/tableau-cleanup"

# Check source exists
if [ ! -d "$SOURCE_DIR" ]; then
    echo "  ERROR: claude-skill/ folder not found"
    echo "  Make sure you're running from the project root"
    exit 1
fi

# Create destination
mkdir -p "$DEST_DIR"
echo "  Created: $DEST_DIR"

# Copy files
echo "  Copying skill files..."
cp -R "$SOURCE_DIR"/* "$DEST_DIR/"

echo ""
echo "  SUCCESS! Skill installed to:"
echo "  $DEST_DIR"
echo ""
echo "  Next steps:"
echo "  1. Run 'tableau-setup' to configure watch folders"
echo "  2. Run 'tableau-clean' to clean workbooks"
echo ""
echo "  See README.md for full documentation"
echo ""

#!/bin/bash
# Tableau Workbook Scrubber - Mac Installer
# Installs the CLI tool and Claude skill

set -e

# Colors
GREEN="\033[32m"
YELLOW="\033[33m"
RED="\033[31m"
DIM="\033[90m"
RESET="\033[0m"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo ""
echo -e "${YELLOW}TABLEAU WORKBOOK SCRUBBER - INSTALLER${RESET}"
echo -e "${DIM}Setting up for Mac/Linux...${RESET}"
echo ""

# Check prerequisites
echo -e "${DIM}Checking prerequisites...${RESET}"

# Check for Python
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}[X] Python 3 not found${RESET}"
    echo -e "    Install from: https://www.python.org/downloads/"
    exit 1
fi
echo -e "${GREEN}[OK]${RESET} Python 3 found"

# Check for jq
if ! command -v jq &> /dev/null; then
    echo -e "${YELLOW}[!] jq not found - installing...${RESET}"
    if command -v brew &> /dev/null; then
        brew install jq
    elif command -v apt-get &> /dev/null; then
        sudo apt-get install -y jq
    else
        echo -e "${RED}[X] Cannot install jq automatically${RESET}"
        echo -e "    Install manually: brew install jq (Mac) or apt-get install jq (Linux)"
        exit 1
    fi
fi
echo -e "${GREEN}[OK]${RESET} jq found"

# Check for Claude
if ! command -v claude &> /dev/null; then
    echo -e "${RED}[X] Claude Code not found${RESET}"
    echo -e "    Install from: https://claude.com/code"
    exit 1
fi
echo -e "${GREEN}[OK]${RESET} Claude Code found"

echo ""

# Create directories
echo -e "${DIM}Creating directories...${RESET}"

CONFIG_DIR="$HOME/.iw-tableau-cleanup"
SKILL_DIR="$HOME/.claude/skills/tableau-cleanup"

mkdir -p "$CONFIG_DIR/logs"
mkdir -p "$SKILL_DIR/scripts"
mkdir -p "$SKILL_DIR/resources"
mkdir -p "$SKILL_DIR/rules"

echo -e "${GREEN}[OK]${RESET} Directories created"

# Copy skill files
echo -e "${DIM}Installing Claude skill...${RESET}"

SKILL_SOURCE="$PROJECT_ROOT/claude-skill"

if [[ -d "$SKILL_SOURCE" ]]; then
    cp -f "$SKILL_SOURCE/SKILL.md" "$SKILL_DIR/" 2>/dev/null || true
    cp -f "$SKILL_SOURCE/scripts/"*.py "$SKILL_DIR/scripts/" 2>/dev/null || true
    cp -f "$SKILL_SOURCE/resources/"*.md "$SKILL_DIR/resources/" 2>/dev/null || true
    cp -f "$SKILL_SOURCE/rules/"*.json "$SKILL_DIR/rules/" 2>/dev/null || true
    echo -e "${GREEN}[OK]${RESET} Skill files installed to $SKILL_DIR"
else
    echo -e "${YELLOW}[!]${RESET} Skill source not found at $SKILL_SOURCE"
fi

# Make scripts executable
echo -e "${DIM}Setting permissions...${RESET}"

chmod +x "$SCRIPT_DIR/tableau-scrubber.sh"
chmod +x "$SCRIPT_DIR/run-cleanup.sh"
chmod +x "$SCRIPT_DIR/configure.sh"

echo -e "${GREEN}[OK]${RESET} Scripts made executable"

# Create symlink in /usr/local/bin (optional)
echo ""
read -p "Create 'tableau-scrubber' command in PATH? (Y/n) " create_symlink

if [[ -z "$create_symlink" ]] || [[ "$create_symlink" =~ ^[Yy]$ ]]; then
    INSTALL_PATH="/usr/local/bin/tableau-scrubber"

    # Check if we need sudo
    if [[ -w "/usr/local/bin" ]]; then
        ln -sf "$SCRIPT_DIR/tableau-scrubber.sh" "$INSTALL_PATH"
    else
        echo -e "${DIM}Requires sudo to create symlink...${RESET}"
        sudo ln -sf "$SCRIPT_DIR/tableau-scrubber.sh" "$INSTALL_PATH"
    fi

    echo -e "${GREEN}[OK]${RESET} Command installed: tableau-scrubber"
else
    echo -e "${DIM}Skipped - run directly with: $SCRIPT_DIR/tableau-scrubber.sh${RESET}"
fi

# Copy banner asset
if [[ -f "$PROJECT_ROOT/automation/windows/assets/banner.png" ]]; then
    cp "$PROJECT_ROOT/automation/windows/assets/banner.png" "$SCRIPT_DIR/assets/" 2>/dev/null || true
fi

echo ""
echo -e "${GREEN}========================================${RESET}"
echo -e "${GREEN}  INSTALLATION COMPLETE!${RESET}"
echo -e "${GREEN}========================================${RESET}"
echo ""
echo -e "${DIM}Next steps:${RESET}"
echo -e "  1. Run ${YELLOW}tableau-scrubber${RESET} to start"
echo -e "  2. Configure your watch folders"
echo -e "  3. Run cleanup on your workbooks"
echo ""
echo -e "${DIM}Optional: Install chafa for ASCII banner art:${RESET}"
echo -e "  brew install chafa"
echo ""

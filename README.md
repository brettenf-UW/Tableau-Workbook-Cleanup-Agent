# Tableau Cleanup Agent

An automated tool for cleaning up Tableau workbooks. Uses Claude AI to standardize captions, add meaningful comments, and organize calculations into folders.

## What Gets Installed

This project installs **two components globally**:

| Component | Location | Purpose |
|-----------|----------|---------|
| **CLI Tool** (`tableau-scrubber`) | Added to PATH | Automated scrubber that runs in a loop until all errors are fixed |
| **Skill Files** | `~/.claude/skills/tableau-cleanup/` | Enhances any Claude Code session for Tableau work |

```
┌─────────────────────────────────────────────────────────────┐
│                    TABLEAU CLEANUP AGENT                    │
├─────────────────────────────┬───────────────────────────────┤
│      CLI TOOL               │      SKILL FILES              │
│      (tableau-scrubber)     │      (auto-activates)         │
├─────────────────────────────┼───────────────────────────────┤
│ • Fully automated           │ • Use in any Claude Code chat │
│ • Runs validation loop      │ • Just mention "Tableau"      │
│ • Finds latest workbook     │                               │
│ • Creates backups           │ • Manual control over edits   │
│ • Multiple passes until 0   │                               │
└─────────────────────────────┴───────────────────────────────┘
```

## Prerequisites

| Requirement | Installation |
|-------------|--------------|
| Python 3.x | [python.org/downloads](https://www.python.org/downloads/) |
| Claude Code | [claude.ai/code](https://claude.ai/code) |
| jq (Mac only) | `brew install jq` |

## Installation

**Windows:**
```cmd
cd automation\windows
setup.bat
```

**Mac / Linux:**
```bash
cd automation/mac
chmod +x install.sh
./install.sh
```

After installation, you'll have:
- `tableau-scrubber` command available globally
- Skill files installed at `~/.claude/skills/tableau-cleanup/`

---

## Usage Option 1: CLI Tool (Automated)

The CLI tool runs a fully automated loop that validates, fixes, and re-validates until all errors are resolved.

### Interactive Mode
```bash
tableau-scrubber
```

Opens a menu to:
1. **Clean Workbooks** - Run cleanup on configured folders
2. **Configure Folders** - Add/edit/remove watch folders
3. **View Logs** - Check recent cleanup history

### Command Line Mode
```bash
# Clean all configured folders
tableau-scrubber --action clean

# Clean a specific workbook
tableau-scrubber --action clean --workbook "/path/to/workbook.twb"

# View logs
tableau-scrubber --action logs
```

### How the CLI Works
```
tableau-scrubber
     │
     ├── Find latest workbook in folder
     ├── Create backup (timestamped)
     ├── Create _cleaned.twb working copy
     │
     └── Loop until 0 errors:
         ├── validate_cleanup.py (27 rules)
         ├── Claude fixes errors
         └── Re-validate
```

---

## Usage Option 2: Skill Files (Manual Claude Code)

The skill files enhance **any Claude Code session** - no CLI needed. When you mention a Tableau workbook, Claude automatically knows:
- The 27 validation rules
- How to write quality comments
- Proper folder organization
- XML safety rules

### How to Use
Just open Claude Code and ask:
```
Clean up this Tableau workbook: /path/to/workbook.twb
```

Or for specific tasks:
```
Add comments to the calculations in /path/to/workbook.twb
```

### When to Use Skill Files vs CLI

| Use **Skill Files** when... | Use **CLI Tool** when... |
|----------------------------|--------------------------|
| You want manual control | You want full automation |
| Cleaning one workbook | Cleaning multiple workbooks |
| You want to review each change | You want hands-off processing |
| Working on a complex workbook | Batch processing folders |

---

## What It Fixes

| Feature | Description |
|---------|-------------|
| **Captions** | Removes `c_` prefixes, converts to Title Case, preserves acronyms |
| **Comments** | Adds purpose-driven comments explaining WHY each calculation exists |
| **Folders** | Organizes into categories: Metrics, Dates, Filters, Display, etc. |
| **Validation** | 27 rules catching lazy comments, XML errors, organization issues |
| **Backups** | Automatic timestamped backups before any changes |

## Validation Rules

### Captions (C1-C5)
- Title Case with spaces
- No `c_` prefix
- Preserve acronyms (ID, YTD, KPI, etc.)

### Comments (M1-M4)
- Must start with `//`
- Minimum 15 characters
- Must explain PURPOSE (not just describe formula)
- No lazy patterns ("Calculated field", "Sum", etc.)

### Folders (F1-F11)
- Maximum 10 folders
- All calculations must be assigned to a folder
- Ambiguous calcs stay in current folder if valid

---

## Project Structure

```
Tableau Cleanup Agent/
│
├── automation/
│   ├── windows/                    # Windows scripts
│   │   ├── tableau-scrubber.ps1    # Main CLI entry point
│   │   ├── run-cleanup.ps1         # Cleanup loop
│   │   ├── configure.ps1           # Folder configuration
│   │   ├── setup.bat               # Windows installer
│   │   └── lib/ui-helpers.ps1      # Shared UI functions
│   │
│   └── mac/                        # Mac/Linux scripts
│       ├── tableau-scrubber.sh     # Main CLI entry point
│       ├── run-cleanup.sh          # Cleanup loop
│       ├── configure.sh            # Folder configuration
│       ├── install.sh              # Mac installer
│       └── lib/ui-helpers.sh       # Shared UI functions
│
├── claude-skill/                   # Claude Code skill files
│   ├── SKILL.md                    # AI instructions for cleanup
│   ├── scripts/
│   │   ├── validate_cleanup.py     # 27-rule validator
│   │   └── apply_changes.py        # Safe XML editor
│   └── resources/
│       ├── comment-guide.md        # How to write good comments
│       └── good-comments.md        # 50+ example comments
│
└── README.md
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Python not found | Install from [python.org](https://www.python.org/downloads/) |
| jq not found (Mac) | `brew install jq` |
| Claude not found | Install from [claude.ai/code](https://claude.ai/code) |
| Validation script not found | Re-run the install script |
| No folders configured | Run `tableau-scrubber` → Configure Folders |
| Skill not activating | Check `~/.claude/skills/tableau-cleanup/SKILL.md` exists |

## Support

Found a bug or have a feature request? Contact **bretten.farrell@interworks.com**

## License

MIT License - feel free to use, modify, and distribute.

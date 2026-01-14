# Tableau Cleanup Agent

An automated tool for cleaning up Tableau workbooks. Uses Claude AI to standardize captions, add meaningful comments, and organize calculations. Works on **Windows** and **Mac/Linux** (beta).

**What it does:**
- Standardizes calculation captions (Title Case, no prefixes)
- Adds meaningful comments explaining the PURPOSE of each calculation
- Organizes calculations into logical folders
- Validates against 27 quality rules
- Runs iteratively until all errors are fixed

## Quick Start

### Prerequisites

| Requirement | Installation |
|-------------|--------------|
| Python 3.x | [python.org/downloads](https://www.python.org/downloads/) |
| Claude Code | [claude.ai/code](https://claude.ai/code) |
| jq (Mac only) | `brew install jq` |

### Installation

**Windows**
```cmd
cd automation\windows
setup.bat
```

**Mac / Linux** *(Beta)*
```bash
cd automation/mac
chmod +x install.sh
./install.sh
```

*Mac/Linux support is in beta. Report issues to bretten.farrell@interworks.com*

This installs:
- Claude skill files to `~/.claude/skills/tableau-cleanup/`
- `tableau-scrubber` command (optional, added to PATH)

## Usage

### Interactive Mode

```bash
tableau-scrubber
```

This opens a menu to:
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

### Manual Cleanup (Claude Direct)

You can also invoke the skill directly in Claude Code:

```
Clean up this Tableau workbook: /path/to/workbook.twb
```

## How It Works

```
tableau-scrubber
     │
     ├── Find latest workbook in folder
     ├── Create backup (timestamped)
     ├── Create _cleaned.twb working copy
     │
     └── Loop until 0 errors:
         ├── validate_cleanup.py (27 rules)
         ├── Claude fixes errors in batches of 10
         └── Re-validate
```

**Two-layer validation:**
1. **Script validation** - Catches obvious issues (length, lazy patterns)
2. **Claude validation** - Reviews all comments for quality and purpose

## Features

| Feature | Description |
|---------|-------------|
| **Captions** | Removes `c_` prefixes, converts to Title Case, preserves acronyms |
| **Comments** | Adds purpose-driven comments explaining WHY each calculation exists |
| **Folders** | Organizes into categories: Metrics, Dates, Filters, Display, etc. |
| **Validation** | 27 rules catching lazy comments, XML errors, organization issues |
| **Backups** | Automatic timestamped backups before any changes |
| **Logging** | Full logs with preview feature to see Claude's work |

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

## Project Structure

```
Tableau Cleanup Agent/
│
├── automation/
│   ├── windows/                    # Windows scripts
│   │   ├── tableau-scrubber.ps1    # Main CLI entry point
│   │   ├── run-cleanup.ps1         # Cleanup loop (validate → fix → repeat)
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
├── claude-skill/                   # Claude Code skill
│   ├── SKILL.md                    # AI instructions for cleanup
│   ├── scripts/
│   │   ├── validate_cleanup.py     # 27-rule validator
│   │   ├── batch_comments.py       # Batch processor
│   │   └── ...
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

## Contributing

1. Edit files in `claude-skill/` directory
2. Run the install script to deploy changes
3. Test with `tableau-scrubber`

## Support

Found a bug or have a feature request? Contact **bretten.farrell@interworks.com**

## License

MIT License - feel free to use, modify, and distribute.

# Tableau Cleanup Agent

An automated tool for cleaning up Tableau workbooks. Includes a Claude Code skill for AI-powered fixes, Python validation scripts, and PowerShell orchestration for batch processing.

**What it does:**
- Standardizes calculation captions (Title Case, no prefixes)
- Adds meaningful comments explaining the PURPOSE of each calculation
- Organizes calculations into 6 standard folders
- Validates against 27 quality rules
- Runs iteratively until all errors are fixed

## Get started

### Prerequisites

| Requirement | Installation |
|-------------|--------------|
| Python 3.x | [python.org/downloads](https://www.python.org/downloads/) |
| Claude Code | [github.com/anthropics/claude-code](https://github.com/anthropics/claude-code) |

### Install the skill

**Windows (Command Prompt)**
```cmd
install-tableau-skill.bat
```

**Windows (PowerShell)**
```powershell
.\install-tableau-skill.ps1
```

**macOS / Linux**
```bash
chmod +x install-tableau-skill.sh
./install-tableau-skill.sh
```

This copies the skill files to `~/.claude/skills/tableau-cleanup/`

### Configure watch folders

```bash
tableau-setup
```

This opens an interactive menu to add folders containing your Tableau workbooks.

## Usage

### Automated cleanup

```bash
tableau-clean
```

This will:
1. Find the latest workbook in each configured folder
2. Create a backup
3. Create a `*_cleaned.twb` working copy
4. Run validation and fix errors iteratively until complete

### Manual cleanup

You can also invoke the skill directly in Claude Code:

```
Clean up this Tableau workbook: C:\path\to\workbook.twb
```

## What it does

| Feature | Description |
|---------|-------------|
| **Captions** | Removes `c_` prefixes, converts to Title Case, preserves acronyms |
| **Comments** | Adds purpose-driven comments explaining WHY each calculation exists |
| **Folders** | Organizes into 6 categories: Metrics, Dates, Filters, Display, Projections, Security |
| **Validation** | Catches lazy comments, ensures proper XML encoding |

## How it works

```
tableau-clean
     │
     ├── Find latest workbook
     ├── Create backup
     ├── Create _cleaned copy
     │
     └── Loop until 0 errors:
         ├── validate_cleanup.py (27 rules)
         ├── Claude fixes errors in batches of 10
         └── Re-validate
```

The system uses two-layer validation:
1. **Script validation** catches obvious issues (length, lazy patterns)
2. **Claude validation** reviews all comments for quality and purpose

## Validation rules

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
- Maximum 6 folders
- Required categories: Metrics, Dates, Filters, Display, Projections, Security
- All calculations must be assigned

## Project structure

```
Tableau Cleanup Agent/
│
├── install-tableau-skill.bat      # Windows installer (CMD)
├── install-tableau-skill.ps1      # Windows installer (PowerShell)
├── install-tableau-skill.sh       # macOS/Linux installer
│
├── claude-skill/                  # Claude Code skill (installed to ~/.claude/skills/)
│   ├── SKILL.md                   # AI instructions for cleanup
│   ├── scripts/                   # Python validation & batch processing
│   │   ├── validate_cleanup.py    # 27-rule validator
│   │   ├── batch_comments.py      # Processes calcs in groups of 10
│   │   └── ...                    # Backup, extract, repackage utilities
│   └── resources/                 # Reference guides for Claude
│       ├── comment-guide.md       # How to write good comments
│       └── good-comments.md       # 50+ example comments
│
└── automation/                    # PowerShell orchestration
    └── windows/
        ├── run-cleanup.ps1        # Main cleanup loop (validate → fix → repeat)
        └── configure.ps1          # Watch folder configuration
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Python not found | Install from [python.org](https://www.python.org/downloads/) |
| Validation script not found | Re-run the install script |
| No folders configured | Run `tableau-setup` |

## Contributing

1. Edit files in `claude-skill/` directory
2. Run the install script to deploy changes
3. Test with `tableau-clean`

## License

Internal use only.

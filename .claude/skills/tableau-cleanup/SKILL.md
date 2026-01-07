---
name: tableau-cleanup
description: Clean up Tableau workbooks by standardizing captions, adding comments, and organizing into folders.
---

# Tableau Workbook Cleanup

Clean up Tableau workbooks (.twb/.twbx) by editing XML. Run validation, fix errors, repeat until clean.

## Scratchpad

Use `.cleanup/` directory. Track progress in `.cleanup/status.json`.

## Scripts

| Script | Purpose |
|--------|---------|
| `scripts/backup_workbook.py <input>` | Backup before editing |
| `scripts/extract_twbx.py <input.twbx>` | Unzip packaged workbook |
| `scripts/list_calculations.py <file.twb>` | List all calcs as JSON |
| `scripts/validate_cleanup.py <file.twb>` | **Check all rules, output errors** |
| `scripts/validate_xml.py <file.twb>` | Check XML validity |
| `scripts/repackage_twbx.py <dir> <output.twbx>` | Repackage to .twbx |

## Safety Rules

1. **Backup first** - Always run backup_workbook.py
2. **Never modify `name` attributes** - Only edit `caption`
3. **Escape XML**: `&` -> `&amp;`, `'` -> `&apos;`
4. **Create `_cleaned` copy** - Don't overwrite original

## Workflow

1. Backup workbook
2. Extract if .twbx
3. Run `validate_cleanup.py` to see all errors
4. Fix errors one category at a time
5. Run validation again
6. Repeat until 0 errors
7. Repackage if .twbx
8. Report changes

## Caption Rules

- Title Case with spaces (no underscores)
- No `c_` prefix
- Preserve acronyms: ID, YTD, MTD, KPI, ROI, YOY, MOM, WOW, LOD
- No double parentheses `()()`

## Comment Rules

Add `//` comment explaining PURPOSE at start of formula:
```xml
formula='// Flags at-risk accounts for dashboard highlight&#13;&#10;[Score] < 50'
```

Use `&#13;&#10;` for newlines. Escape `&` as `&amp;`.

## Folder Rules

Insert `<folders-common>` BEFORE `<layout>` with max 9 emoji-prefixed folders:

```xml
<folders-common>
  <folder name='📊 Core Metrics'>
    <folder-item name='[Calculation_XXX]' type='field' />
  </folder>
</folders-common>
```

Folders (use relevant emoji, no duplicates):
- 📊 Core Metrics: sum, avg, total, margin, revenue, profit
- 📈 Time Series: yoy, mom, wow, trend, rolling, change
- 🚦 Filters and Flags: filter, flag, is_, has_, include, exclude
- 📅 Date Calculations: date, year, month, quarter, fiscal
- 🏆 Rankings: rank, top, bottom, index
- 🎨 UI and Tooltips: label, tooltip, display, format
- 🔗 LOD Expressions: contains FIXED, INCLUDE, EXCLUDE
- 🔮 Projections: forecast, projection, target, goal
- 🔒 Security: rls, security, user, permission

## Report

```
=== Tableau Cleanup Complete ===
Workbook: <name>
Errors fixed: X
Output: <path>_cleaned.twbx
```

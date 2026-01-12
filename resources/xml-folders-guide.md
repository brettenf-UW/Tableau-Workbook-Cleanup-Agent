# How to Create Folders in Tableau via XML Editing

## Overview

This guide explains how to organize calculated fields into folders by directly editing a Tableau workbook's XML. This is useful for:

- Organizing large numbers of calculated fields for handoff
- Bulk-creating folder structures that would be tedious in the UI
- Standardizing folder organization across workbooks

> **Warning**: XML editing is unsupported by Tableau. Always work on a backup copy.

## Prerequisites

1. **Backup your workbook** - Copy your `.twb` file before editing
2. **Close Tableau Desktop** - The file must not be open while editing
3. **Text editor** - Use VS Code, Notepad++, or any XML-friendly editor

## File Types

| Extension | Description | How to Edit |
|-----------|-------------|-------------|
| .twb | Unpackaged workbook (XML) | Edit directly |
| .twbx | Packaged workbook (ZIP) | Rename to .zip, extract, edit the .twb inside |

## XML Structure for Folders

### Key Concepts

1. **Folders must be inside `<folders-common>`** - Individual `<folder>` elements cannot stand alone
2. **Location matters** - `<folders-common>` must appear in a specific position in the XML schema
3. **Field names must match exactly** - Use the internal `name` attribute from `<column>` tags

### Schema Position

The `<folders-common>` element must appear in this order within `<datasource>`:

```xml
...
<drill-paths>...</drill-paths>                           (if present)
<unlinked-server-hierarchies>...</unlinked-server-hierarchies>  (if present)
<folders-common>                                         <-- YOUR FOLDERS GO HERE
  <folder>...</folder>
</folders-common>
<folders-parameters>...</folders-parameters>             (if present)
<actions>...</actions>                                   (if present)
<extract>...</extract>                                   (if present)
<layout ... />                                           <-- MUST BE AFTER folders-common
<style>...</style>
...
```

### Basic Syntax

```xml
<folders-common>
  <folder name='Folder Name'>
    <folder-item name='[InternalFieldName]' type='field' />
    <folder-item name='[AnotherFieldName]' type='field' />
  </folder>
</folders-common>
```

## Step-by-Step Instructions

### Step 1: Find Your Calculated Field Names

Each calculated field has an internal name (not the display name). To find it:

1. Open the `.twb` file in a text editor
2. Search for your field's display name (the `caption` attribute)
3. Note the `name` attribute value

**Example:**
```xml
<column caption='Attendance Rate'
        datatype='real'
        name='[Calculation_1234567890123456]'
        role='measure'
        type='quantitative'>
  <calculation class='tableau' formula='SUM([Present])/SUM([Total])' />
</column>
```

The internal name is: `[Calculation_1234567890123456]`

### Step 2: Find the Insertion Point

Search for `<layout` in your file. Your `<folders-common>` block goes **immediately before** the `<layout` tag.

**Look for this pattern:**
```xml
    </group>
    <layout common-percentage='...' ... />
```

**You will insert between `</group>` and `<layout`:**
```xml
    </group>
    <folders-common>
      <!-- folders go here -->
    </folders-common>
    <layout common-percentage='...' ... />
```

### Step 3: Create the Folder Structure

Add your `<folders-common>` block with folders:

```xml
<folders-common>
  <folder name='Sales Metrics'>
    <folder-item name='[Calculation_1111111111111111]' type='field' />
    <folder-item name='[Calculation_2222222222222222]' type='field' />
  </folder>
  <folder name='Date Filters'>
    <folder-item name='[Calculation_3333333333333333]' type='field' />
    <folder-item name='[Calculation_4444444444444444]' type='field' />
  </folder>
</folders-common>
```

### Step 4: Verify show-structure is Enabled

Find the `<layout>` tag and ensure it has `show-structure='true'`:

```xml
<layout ... show-structure='true' ... />
```

If this attribute is missing or set to `false`, add/change it to `true`.

### Step 5: Save and Test

1. Save the file
2. Open in Tableau Desktop
3. In the Data pane, right-click and select **Group by Folder**

## Complete Example

### Before (No Folders)
```xml
    </group>
    <layout common-percentage='0.5' dim-ordering='alphabetic'
            measure-ordering='alphabetic' show-structure='true' />
    <style>
```

### After (With Folders)
```xml
    </group>
    <folders-common>
      <folder name='Core Metrics'>
        <folder-item name='[Calculation_1234567890123456]' type='field' />
        <folder-item name='[Calculation_2345678901234567]' type='field' />
        <folder-item name='[Calculation_3456789012345678]' type='field' />
      </folder>
      <folder name='Risk Flags'>
        <folder-item name='[Calculation_4567890123456789]' type='field' />
        <folder-item name='[Calculation_5678901234567890]' type='field' />
      </folder>
      <folder name='UI Elements'>
        <folder-item name='[Calculation_6789012345678901]' type='field' />
        <folder-item name='[Calculation_7890123456789012]' type='field' />
      </folder>
    </folders-common>
    <layout common-percentage='0.5' dim-ordering='alphabetic'
            measure-ordering='alphabetic' show-structure='true' />
    <style>
```

## Special Characters

### CRITICAL: XML Character Escaping

Special characters **MUST** be escaped in ALL XML attribute values, including:
- Folder names
- Formula comments (text after `//` in formulas)
- Any other attribute text

**Failure to escape will cause Tableau to fail to open the workbook.**

| Character | Must Use | Example |
|-----------|----------|---------|
| `&` | `&amp;` | `Config &amp; Security` displays as "Config & Security" |
| `'` | `&apos;` | `Owner&apos;s goal` displays as "Owner's goal" |
| `"` | `&quot;` | |
| `<` | `&lt;` | |
| `>` | `&gt;` | |

### Common Errors:
- `"expected entity name for reference"` - Unescaped `&` character
- `"whitespace expected"` - Unescaped `'` (apostrophe) inside single-quoted attribute

### Folder Name Example:
```xml
<!-- WRONG -->
<folder name='Config & Security'>

<!-- CORRECT -->
<folder name='Config &amp; Security'>
```

### Formula Comment Example (same rules apply):
```xml
<!-- WRONG - apostrophe breaks the attribute -->
formula='// Individual owner's margin goal&#13;&#10;...'

<!-- CORRECT -->
formula='// Individual owner&apos;s margin goal&#13;&#10;...'
```

## Common Errors and Solutions

### Error: "element 'folder' is not allowed"

**Cause:** `<folder>` elements are not wrapped in `<folders-common>`

**Solution:** Wrap all folders:
```xml
<folders-common>
  <folder name='...'>...</folder>
</folders-common>
```

### Error: "attribute 'role' is not declared for element 'folder'"

**Cause:** Using `role='measures'` or `role='dimensions'` attribute

**Solution:** Remove the `role` attribute. Inside `<folders-common>`, folders only need the `name` attribute:
```xml
<!-- WRONG -->
<folder name='Sales' role='measures'>

<!-- CORRECT -->
<folder name='Sales'>
```

### Error: "no declaration found for element 'folder'"

**Cause:** `<folders-common>` is in the wrong location in the XML

**Solution:** Move `<folders-common>` to appear BEFORE `<layout>` and AFTER `</group>` or other allowed elements

### Error: "element 'folders-common' is not allowed"

**Cause:** `<folders-common>` is placed after elements that must come after it (like `<layout>` or `<object-graph>`)

**Solution:** Check the schema order and move `<folders-common>` to the correct position

### Error: "expected entity name for reference"

**Cause:** Unescaped `&` character in folder name or other attribute

**Solution:** Replace all `&` with `&amp;` in folder names and other attribute values

### Folders Don't Appear in Tableau

**Cause:** Data pane is not set to folder view

**Solution:** In Tableau, right-click in the Data pane -> **Group by Folder**

## Folder Organization Best Practices

| Folder Type | Purpose | Example Fields |
|-------------|---------|----------------|
| Core Metrics | Main KPIs and measures | Attendance %, GPA, Completion Rate |
| Risk Flags | Warning indicators | At-Risk Flag, Low Attendance Flag |
| Trends | Week-over-week, rolling calcs | WoW Change, 4-Week Average |
| Dates & Filters | Date logic, filter helpers | Current Week, Is Active |
| UI & Tooltips | Display formatting | Button Labels, Tooltip Text |
| Security | RLS, user-based logic | User Email, Row Access |

## Limitations

1. **One folder per field** - A field can only belong to one folder
2. **No nested folders** - Tableau doesn't support subfolders
3. **Relational sources only** - OLAP/cube sources don't support folders
4. **Server publishing** - Folders may not persist when publishing data sources separately

## Quick Reference

```xml
<!-- Minimum required structure -->
<folders-common>
  <folder name='Folder Name'>
    <folder-item name='[Calculation_XXXXX]' type='field' />
  </folder>
</folders-common>

<!-- Must appear BEFORE <layout> tag -->
<!-- Must appear AFTER </group>, </drill-paths>, etc. -->
<!-- Do NOT use role attribute -->
<!-- Field names must match exactly (case-sensitive, with brackets) -->
```

## Checklist Before Saving

- [ ] All `<folder>` elements are inside `<folders-common>`
- [ ] `<folders-common>` is positioned before `<layout>`
- [ ] No `role` attribute on `<folder>` elements
- [ ] All field names match exactly (including brackets)
- [ ] No unescaped `&` in folder names (use `&amp;`)
- [ ] No unescaped `'` in formula comments (use `&apos;`)
- [ ] `show-structure='true'` is set in `<layout>`
- [ ] File is saved and Tableau Desktop is closed

---

*Document created: December 2024*
*Updated: December 2025 - Added prominent XML escaping warning based on real-world errors*
*Based on Tableau Desktop XML schema*

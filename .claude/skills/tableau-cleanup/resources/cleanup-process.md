# Tableau Workbook Cleanup Process for Handoff

A 2-phase process for standardizing Tableau workbooks before client handoff.

## Overview

This process ensures calculated fields are:
- **Well-documented** - Comments explain purpose/logic
- **Organized** - Grouped into logical folders

---

## Phase 1: Adding Comments

### What You're Doing

Adding a comment line at the top of each calculated field's formula to explain its purpose. This helps future developers understand the logic without having to decode the formula.

### Comment Format

Comments in Tableau use `//` syntax, just like many programming languages.

### Step-by-Step Process

#### Step 1: Analyze Each Calc

For each calculated field, determine:
- What does this calc do?
- Why does it exist?
- Are there special cases or parameter dependencies?

#### Step 2: Write Concise Comments

Good comments explain the **purpose**, not just restate the formula:

| Bad Comment | Good Comment |
|-------------|--------------|
| `// Returns 1 or 2` | `// Red for decline, black for flat/growth` |
| `// Case statement` | `// Routes to metric source based on parameter` |
| `// Date calculation` | `// Reference date for YoY comparisons (most recent data date)` |

#### Step 3: Add Comments in XML

In the XML, find the `formula=` attribute and prepend the comment.

**XML Encoding Required:**
- Newline = `&#13;&#10;`
- This goes between the comment and the formula

```xml
<!-- Before -->
<calculation class='tableau' formula='CASE [Parameter] WHEN 1 THEN...' />

<!-- After -->
<calculation class='tableau' formula='// Routes to metric source based on parameter&#13;&#10;CASE [Parameter] WHEN 1 THEN...' />
```

### CRITICAL: Escaping Special Characters in Comments

Comments are inside the XML `formula` attribute, so special characters in comment text **MUST** be escaped:

| Character | Must Use | Example in Comment |
|-----------|----------|-------------------|
| `&` | `&amp;` | `// AE &amp; CM roles` displays as "AE & CM roles" |
| `'` | `&apos;` | `// Owner&apos;s goal` displays as "Owner's goal" |
| `"` | `&quot;` | `// Filter for &quot;All&quot;` |

**Common Errors:**
- `"expected entity name for reference"` - Unescaped `&` in comment
- `"whitespace expected"` - Unescaped `'` in comment (breaks the attribute delimiter)

**Examples:**
```xml
<!-- WRONG - Will cause XML error -->
formula='// Individual owner's margin goal&#13;&#10;...'
formula='// Won & Closed opps&#13;&#10;...'

<!-- CORRECT -->
formula='// Individual owner&apos;s margin goal&#13;&#10;...'
formula='// Won &amp; Closed opps&#13;&#10;...'
```

#### Step 4: Handle Multiple Datasources

If the workbook has multiple datasources, the same formula may appear multiple times. Use find-and-replace with "Replace All" to update all instances.

#### Step 5: Verify

1. Save the file
2. Open in Tableau Desktop
3. Click on a calculated field to view its formula
4. Confirm comment appears at the top

### Comment Examples by Field Type

| Field Type | Example Comment |
|------------|-----------------|
| Boolean filter | `// True when Wages metric selected (parameter = 4)` |
| Date reference | `// Reference date for YoY comparisons (most recent data date)` |
| Metric routing | `// Routes to Hiring, Job Openings, or Employment based on parameter` |
| Color coding | `// Red for negative YoY change, black otherwise` |
| Top N filter | `// Filters to top 5 ranked skills` |
| Aggregation | `// Aggregates track metric; wages uses AVG, others use SUM` |

---

## Phase 2: Folder Grouping

### What You're Doing

Organizing calculated fields into logical folders within Tableau's Data pane. This makes it much easier to find fields when there are dozens of calcs.

### CRITICAL: XML Character Escaping

Special characters in folder names **MUST** be escaped or Tableau will fail to open the workbook:

| Character | Must Use | Example |
|-----------|----------|---------|
| `&` | `&amp;` | `Config &amp; Security` displays as "Config & Security" |
| `<` | `&lt;` | |
| `>` | `&gt;` | |
| `"` | `&quot;` | |
| `'` | `&apos;` | |

**Common Error:** `"expected entity name for reference" at position (line, col)`
- **Cause:** Unescaped `&` character in folder name
- **Fix:** Replace `&` with `&amp;` in the XML

### Step-by-Step Process

#### Step 1: Categorize Your Calcs

Review all calculated fields and group them by function:

| Category | What Goes Here |
|----------|----------------|
| Core Metrics | Primary KPIs, main measures |
| Time Series/Trends | YoY calcs, trend arrows, rolling averages |
| Projections | Forecasts, future-looking calcs |
| Filters and Flags | Boolean filters, flag indicators |
| Rankings | Top N filters, RANK() calcs |
| UI/Tooltips | Display formatting, tooltip text |
| Security | RLS filters, user-based calcs |

#### Step 2: Gather Internal Names

For each calc, you need the internal name (not the caption). Find it in the XML:

```xml
<column caption='Anchor Date' name='[Calculation_1458603337042436098]' ...>
```

The internal name is: `[Calculation_1458603337042436098]`

Create a mapping table:

| Caption | Internal Name | Folder |
|---------|---------------|--------|
| Anchor Date | [Calculation_1458603337042436098] | Time Series |
| Is Most Recent Date | [Calculation_1217660758139621380] | Filters and Flags |

#### Step 3: Find the Insert Location

In the XML, search for `<layout`. The `<folders-common>` block must be placed **immediately before** this tag.

```xml
    </group>              <!-- Some element ends here -->
    <folders-common>      <!-- INSERT FOLDERS HERE -->
      ...
    </folders-common>
    <layout ... />        <!-- Layout tag comes after -->
```

#### Step 4: Build the XML Structure

Create the folder structure:

```xml
<folders-common>
  <folder name='Core Metrics'>
    <folder-item name='[Calculation_1458603337029099520]' type='field' />
    <folder-item name='[Calculation_2696530285372162049]' type='field' />
  </folder>
  <folder name='Time Series and Trends'>
    <folder-item name='[Calculation_1458603337042436098]' type='field' />
    <folder-item name='[Calculation_1502231959450402818]' type='field' />
  </folder>
  <folder name='Projections'>
    <folder-item name='[Calculation_2696530285393555459]' type='field' />
  </folder>
  <folder name='Filters and Flags'>
    <folder-item name='[Calculation_1217660758139621380]' type='field' />
  </folder>
  <folder name='Top 5 Rankings'>
    <folder-item name='[Calculation_2638546445126889473]' type='field' />
  </folder>
</folders-common>
```

#### Step 5: Verify in Tableau

1. Save the XML file
2. Open workbook in Tableau Desktop
3. Right-click in the Data pane
4. Select **Group by Folder**
5. Confirm all calcs appear in their assigned folders

---

## Common Errors and Fixes

### "Attribute not declared" Error

**Cause:** Using `role` attribute inside `<folders-common>`

**Fix:** Remove any `role` attributes from folder elements

### "expected entity name for reference" Error

**Cause:** Unescaped `&` character in folder name

**Fix:** Replace all `&` with `&amp;` in folder names

```xml
<!-- WRONG -->
<folder name='Config & Security'>

<!-- CORRECT -->
<folder name='Config &amp; Security'>
```

### Folder Not Appearing

**Cause:** `<folders-common>` placed after `<layout>` tag

**Fix:** Move `<folders-common>` block before `<layout>`

### Field Not in Folder

**Cause:** Wrong internal name in `<folder-item>`

**Fix:** Verify the `name` attribute matches the `[Calculation_...]` from the column definition exactly

### Workbook Won't Open

**Cause:** Malformed XML (missing quote, unclosed tag)

**Fix:** Use a text editor with XML validation, check for syntax errors near your edits

### "whitespace expected" Error

**Cause:** Unescaped apostrophe `'` in a comment or other attribute

**Fix:** Replace `'` with `&apos;` in comment text. Common culprits:
- Possessives: `owner's` -> `owner&apos;s`
- Contractions: `don't` -> `don&apos;t`
- Quoted words: `'All'` -> `&apos;All&apos;`

---

## Complete Checklist

### Phase 1: Comments

- [ ] Analyzed each calc's purpose
- [ ] All calcs have header comments
- [ ] Comments explain purpose/logic (not just "what")
- [ ] Special cases documented (parameter values, edge cases)
- [ ] Used `&#13;&#10;` for newlines in XML
- [ ] No unescaped `&` in comments (use `&amp;`)
- [ ] No unescaped `'` in comments (use `&apos;`)
- [ ] Verified comments appear in Tableau

### Phase 2: Folders

- [ ] Categorized all calcs by function
- [ ] Gathered internal names for each calc
- [ ] Created `<folders-common>` structure
- [ ] Placed before `<layout>` tag
- [ ] All calcs assigned to folders
- [ ] No unescaped `&` in folder names (use `&amp;`)
- [ ] Verified folders appear in Tableau (Group by Folder)

---

## XML Escaping Quick Reference

**Before saving, search for these patterns and fix them:**

| Search For | Replace With | Common In |
|------------|--------------|-----------|
| `& ` (ampersand + space) | `&amp; ` | Folder names, comments with "X & Y" |
| `'s` (apostrophe-s) | `&apos;s` | Comments like "owner's goal" |
| `'` in comments | `&apos;` | Quoted words like 'All' or 'Current' |

**Common words that need escaping in comments:**
- `AE & CM` -> `AE &amp; CM`
- `Won & Closed` -> `Won &amp; Closed`
- `owner's` -> `owner&apos;s`
- `'All'` -> `&apos;All&apos;`
- `'Current'` -> `&apos;Current&apos;`

---

*Document created: December 2024*
*Updated: December 2025 - Added prominent XML escaping warning based on real-world errors*

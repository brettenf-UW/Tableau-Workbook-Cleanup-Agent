# Comment Guide for Tableau Calculations

This guide explains how to write meaningful comments for Tableau calculated fields.

## Why Comments Matter

Comments help future developers (including yourself) understand:
- **WHY** this calculation exists (business purpose)
- **WHEN** it's used (which dashboard, what scenario)
- **HOW** to interpret it (if not obvious from the formula)

## What Makes a GOOD Comment

### Must Have:
- **15+ characters** of actual explanation
- Explains **PURPOSE**, not just what the formula does
- Uses **business context** (not technical jargon)

### Good Comment Examples:

```
// Flags accounts with <50% attendance for manager review
[Attendance Rate] < 0.5

// Revenue split for AE & CM shared deals based on parameter selection
IF [Deal Type] = 'Shared' THEN [Revenue] * [Split Param] ELSE [Revenue] END

// Rolling 4-week average for trend line smoothing on exec dashboard
WINDOW_AVG(SUM([Sales]), -3, 0)

// Identifies at-risk renewals for CSM outreach prioritization
[Days to Renewal] <= 30 AND [Health Score] < 70

// Fiscal quarter based on July 1 start (company standard)
DATETRUNC('quarter', DATEADD('month', -6, [Date]))
```

## What Makes a BAD Comment (Fails M3 Validation)

### Fails M3 - Too Generic:
```
// Calculated field          ❌ Says nothing
// Calculation               ❌ Says nothing
// Formula                   ❌ Says nothing
// Field                     ❌ Says nothing
```

### Fails M3 - Too Short (<15 chars):
```
// Sum                       ❌ Only 3 chars
// Total                     ❌ Only 5 chars
// Count of rows             ❌ Only 13 chars
```

### Fails M3 - Just Restates the Caption:
```
// Total Revenue             ❌ If caption is "Total Revenue"
// YTD Sales                 ❌ If caption is "YTD Sales"
```

### Fails M3 - Describes WHAT, not WHY:
```
// Returns 1 or 0            ❌ Describes output, not purpose
// Case statement            ❌ Describes technique, not purpose
// Date calculation          ❌ Describes type, not purpose
// Sum of Sales              ❌ Describes formula, not purpose
// If statement              ❌ Describes technique, not purpose
```

## The Comment Formula

**Structure:** `// [Action verb] [what] for [purpose/context]`

| Instead of... | Write... |
|--------------|----------|
| `// Calculation` | `// Calculates quota attainment for rep scorecards` |
| `// Filter` | `// Filters to active customers only for renewal forecasting` |
| `// Date` | `// Converts to fiscal year for quarterly reporting alignment` |
| `// Sum` | `// Aggregates revenue by region for territory comparison` |
| `// Flag` | `// Flags overdue accounts for collections team priority list` |

## Comment Process

When adding comments to calculations:

1. **READ the formula** - Understand what it actually does
2. **FIND where it's used** - Check which sheets/dashboards reference it
3. **ASK "Why does this exist?"** - What business question does it answer?
4. **WRITE the purpose** - Start with an action verb, include context

## Batch Processing

Use the batch_comments.py script to process calculations methodically:

```bash
# Initialize batches (10 calcs per batch)
python batch_comments.py workbook.twb init

# Get next batch to work on
python batch_comments.py workbook.twb next

# Mark batch complete (verifies comments were added)
python batch_comments.py workbook.twb done 1

# Check progress
python batch_comments.py workbook.twb status
```

The script shows you the full formula for each calculation, so you can understand it before commenting.

## XML Encoding

When adding comments in XML:
- Use `&#13;&#10;` for newlines (not literal newlines)
- Use `&amp;` for ampersands
- Use `&apos;` for single quotes in the comment

Example in XML:
```xml
<calculation formula='// Flags at-risk accounts for manager review&#13;&#10;[Score] &lt; 50' />
```

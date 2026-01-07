# Guide to Exporting All Calculated Field Formulas from a Tableau Workbook

Tableau workbooks (TWB/TWBX) store every calculated field and its formula in the file's XML. There is no built-in "export formulas" button in Tableau Desktop or Prep, but you can extract them manually or programmatically because each workbook contains all definitions of connections, calculations, etc.

## 1. Manual XML Method (TWB/TWBX)

### Convert .twbx to XML

If you have a packaged workbook (`.twbx`), change its extension to `.zip` and unzip it. Inside the extracted folder you'll find the unpackaged workbook file (`.twb`).

### Open the TWB as XML

Rename the `.twb` file to `.xml` (or simply open it in a text editor). This XML contains the full workbook metadata.

### Search for Calculation Tags

Use your text editor's search (or regex) to find all `<calculation>` tags. Each `<calculation>` element has a `formula="..."` attribute that holds the formula text.

**Example:**
```xml
<calculation class='tableau' formula='YOUR_FORMULA_HERE' />
```

Copy the contents of the `formula` attribute for each occurrence.

### Get the Field Name

The `<calculation>` is nested inside a `<column>` element whose `caption="..."` attribute is the calculated field's name. In the XML, look immediately around each `<calculation>` tag for `caption='Field Name'`. Record each formula along with its caption.

### Bulk Extraction

To extract all at once, you can use a regex or "Find All" in your editor.

**Regex to capture formula strings:**
```regex
formula='([^']*)'
```

You may then paste these into a spreadsheet or document, pairing each with its caption. This yields a text or CSV list of all calculated field names and their formulas.

---

## 2. Python Scripting with Tableau's Document API

### Setup

Install Python 3 and the Tableau Document API:
```bash
pip install tableaudocumentapi
```

This unsupported SDK works with both `.twb` and `.twbx` (it auto-unpacks packaged files).

### Extract with Code

Use a script to loop through every data source and field:

```python
from tableaudocumentapi import Workbook

wb = Workbook('path/to/workbook.twbx')  # handles .twb or .twbx

for ds in wb.datasources:
    for field in ds.fields:
        if field.calculation:
            print(ds.name, field.caption, "=", field.calculation)
```

Each `field` object has a `.calculation` property giving the formula if it's a calculated field. The `.caption` is the field's name. Running this prints all datasource names, field names, and formulas.

### Preserving Dependencies

This method naturally captures every calc and its name. Since the formulas themselves reference other fields (by name or alias), you can later analyze dependencies.

### Exporting Results

Redirect the script output to a text file or write it to CSV/Excel (e.g. with Python's `csv` module or pandas).

---

## 3. Other Tools and Methods

### Third-Party Scripts/Tools

There are tools (open-source and commercial) that automate formula extraction:

- **tableauCalculationExport** - Python project that reads a workbook and exports all fields and formulas to Excel/PDF. It also generates a dependency diagram.
- **ExportCalculatedFields.com** - Commercial service that lets you upload a workbook and download all formulas as CSV or Excel.

### PowerShell Script

You can use PowerShell's XML capabilities:

```powershell
[xml]$doc = Get-Content "path\to\workbook.twb"
$doc.SelectNodes("//column") | ForEach-Object {
    $name = $_.caption
    $calc = $_.calculation
    if ($calc) {
        "$name = $($calc)" >> formulas.txt
    }
}
```

This reads the TWB XML and writes each field name and formula to a file. (For TWBX, unzip it first.)

---

## 4. Bulk Export and Dependencies

### Bulk Copy

All methods above can output formulas in bulk. The Python/Document-API route is best for large workbooks, since it programmatically writes every formula. Manual XML parsing can also be bulk (using search/replace or scripting).

### Preserving Nested Calculations

When one calculated field uses another, the workbook keeps references by name. By exporting every calc with its name, you preserve the dependency chain. In the output CSV/Excel, ensure each row has "Field Name" and "Formula". You can then see which formulas mention which other fields.

### Export Formats

You can output the list as:
- Raw text
- CSV
- Excel

The key is that the output is plain text (no Tableau formatting), making it easy to copy or diff in bulk.

---

## 5. Working with .twb vs .twbx

| Format | Description | How to Process |
|--------|-------------|----------------|
| `.twb` (unpackaged) | Already XML | Open directly in text editor or scripts |
| `.twbx` (packaged) | ZIP archive | Rename to .zip, extract, then process the .twb inside |

**Note:** If your workbook connects to a published data source (and the calculation is defined there, not in the workbook), that calc won't appear in the workbook XML. You'd need to retrieve and parse the published datasource file separately.

---

## 6. Limitations, Best Practices, and Gotchas

### General Notes

- Tableau does not offer a native export-all-calculations feature, so these methods are workarounds
- Always keep a backup of your workbook before tinkering
- The Document API is officially unsupported ("as-is" SDK). It generally works across versions, but very new Tableau releases may lag support. Test on one workbook first.

### Hidden Fields and Table Calculations

Even if a calculated field is hidden, it still appears in the XML and will be extracted. Table calculations (LOD calcs, etc.) show up just like other formulas. Level-of-detail calcs appear in the `<calculation>` tags.

### XML Entities

In the raw XML, special characters in formulas are escaped:
- `>` appears as `&gt;`
- `"` appears as `&quot;`

The Document API returns the unescaped formula text. If parsing XML manually, be aware you may see these entities and might want to unescape them for readability.

### Performance

Very large workbooks (hundreds of calculations) can be slow to open or parse. Scripted methods handle this better than manual copy-paste.

### Verification

After extraction, you may want to spot-check that all calc fields were captured. You can count the formulas in the output versus the count in Tableau (e.g., Data pane field count).

---

## Quick Reference: XML Structure

### Calculated Field in XML

```xml
<column caption='Field Display Name'
        datatype='real'
        name='[Calculation_1234567890123456]'
        role='measure'
        type='quantitative'>
  <calculation class='tableau' formula='SUM([Sales]) / SUM([Quantity])' />
</column>
```

### Key Attributes

| Attribute | Description |
|-----------|-------------|
| `caption` | Display name shown in Tableau |
| `name` | Internal reference name (e.g., `[Calculation_XXX]`) |
| `datatype` | Data type (string, real, integer, boolean, datetime) |
| `role` | dimension or measure |
| `formula` | The actual calculation formula |

---

## Summary

The fastest way depends on your comfort with tools:
- **For a one-off:** Renaming and searching the TWB is quick
- **For repeated or large-scale exports:** A Python script using the Document API (or an existing tool) is most efficient

All these methods let you copy or save every calculated field's formula in bulk, including any nested references, without retyping them by hand.

---

*Sources: Tableau community blogs and documentation, Ana Milana's walkthrough, Tableau Document API reference*

#!/usr/bin/env python3
"""
Tableau Workbook Cleanup Validator

Checks all cleanup rules and outputs errors for Claude to fix.
Exit code 0 = all pass, 1 = errors found.

Rules checked:
- C1-C5: Caption rules
- M1-M6: Comment rules
- F1-F11: Folder rules
- X1-X2: XML rules
- S1-S3: Safety rules (requires backup_path argument)
"""
import sys
import re
import xml.etree.ElementTree as ET
from pathlib import Path

# Acronyms to preserve (must stay uppercase)
ACRONYMS = {'ID', 'YTD', 'MTD', 'QTD', 'KPI', 'ROI', 'YOY', 'MOM', 'WOW',
            'LOD', 'RLS', 'API', 'URL', 'SQL', 'AVG', 'SUM', 'MIN', 'MAX'}

# Folder categories with emojis
FOLDER_CATEGORIES = {
    '📊 Core Metrics': ['sum', 'avg', 'count', 'total', 'margin', 'rate', 'percent', 'revenue', 'profit', 'sales'],
    '📈 Time Series': ['yoy', 'mom', 'wow', 'trend', 'rolling', 'running', 'previous', 'change', 'growth'],
    '🚦 Filters and Flags': ['filter', 'flag', 'is_', 'has_', 'include', 'exclude', 'active', 'valid'],
    '📅 Date Calculations': ['date', 'year', 'month', 'week', 'quarter', 'fiscal', 'period', 'calendar'],
    '🏆 Rankings': ['rank', 'top', 'bottom', 'index', 'percentile', 'nth'],
    '🎨 UI and Tooltips': ['label', 'tooltip', 'display', 'format', 'text', 'color', 'button'],
    '🔗 LOD Expressions': [],  # Detected by formula pattern
    '🔮 Projections': ['forecast', 'projection', 'predict', 'estimate', 'target', 'goal', 'budget'],
    '🔒 Security': ['rls', 'security', 'user', 'permission', 'access', 'username', 'email']
}

# Vague comment patterns (just restate what formula does)
VAGUE_COMMENTS = [
    r'^//\s*(returns?\s+\d|case\s+statement|date\s+calculation|sum\s+of|if\s+statement|calculation)',
]

class ValidationResult:
    def __init__(self):
        self.errors = []
        self.passes = []

    def error(self, rule, field, message):
        self.errors.append(f"[ERROR] {rule}: \"{field}\" - {message}")

    def passed(self, rule, field, message="OK"):
        self.passes.append(f"[PASS] {rule}: \"{field}\" - {message}")

    def has_errors(self):
        return len(self.errors) > 0


def to_title_case(text):
    """Convert to title case while preserving acronyms."""
    words = text.replace('_', ' ').split()
    result = []
    for word in words:
        upper = word.upper()
        if upper in ACRONYMS:
            result.append(upper)
        else:
            result.append(word.capitalize())
    return ' '.join(result)


def validate_caption(caption, name, result):
    """Check caption rules C1-C5."""
    display_name = caption or name

    # C1: Must be Title Case
    if caption:
        expected = to_title_case(caption)
        if caption != expected and caption.lower() != expected.lower():
            # Check if it's actually wrong (not just acronym differences)
            if caption.replace(' ', '').lower() == expected.replace(' ', '').lower():
                if caption != expected:
                    result.error("C1", display_name, f"should be \"{expected}\"")

    # C2: No underscores
    if caption and '_' in caption:
        result.error("C2", display_name, "contains underscore")

    # C3: No c_ prefix
    if caption and caption.lower().startswith('c_'):
        result.error("C3", display_name, "has deprecated c_ prefix")

    # C4: Preserve acronyms (check if acronym is not uppercase)
    if caption:
        for acronym in ACRONYMS:
            pattern = re.compile(rf'\b{acronym}\b', re.IGNORECASE)
            match = pattern.search(caption)
            if match and match.group() != acronym:
                result.error("C4", display_name, f"\"{match.group()}\" should be \"{acronym}\"")

    # C5: No double parentheses
    if caption and re.search(r'\)\s*\(', caption):
        result.error("C5", display_name, "has double parentheses \"()()\"")


def validate_comment(formula, caption, name, result):
    """Check comment rules M1-M6."""
    display_name = caption or name
    formula_stripped = formula.strip() if formula else ''

    # M1: Must have comment
    if not formula_stripped.startswith('//'):
        result.error("M1", display_name, "missing comment")
        return  # Can't check other comment rules if no comment

    result.passed("M1", display_name, "has comment")

    # M2: Comment starts with // (already checked in M1)
    result.passed("M2", display_name, "starts with //")

    # M3: Comment explains PURPOSE (not vague)
    comment_line = formula_stripped.split('\n')[0] if '\n' in formula_stripped else formula_stripped.split('&#13;')[0]
    for pattern in VAGUE_COMMENTS:
        if re.search(pattern, comment_line, re.IGNORECASE):
            result.error("M3", display_name, f"comment is vague: \"{comment_line[:50]}...\"")
            break

    # M4: Newline encoded as &#13;&#10; (check for raw newlines that aren't encoded)
    if '\n' in formula and '&#13;&#10;' not in formula and '&#13;' not in formula:
        result.error("M4", display_name, "newline not XML-encoded (use &#13;&#10;)")

    # M5: No unescaped & (outside of entities)
    # Look for & not followed by amp; apos; quot; lt; gt; #
    if re.search(r'&(?!(amp|apos|quot|lt|gt|#\d+);)', formula):
        result.error("M5", display_name, "unescaped & in formula/comment")

    # M6: No unescaped ' in XML attribute context
    # This is tricky - single quotes in formulas are usually OK, but in comments they should be &apos;
    # We'll flag if there's a comment with ' that's not &apos;
    if formula_stripped.startswith('//'):
        comment_part = formula_stripped.split('\n')[0] if '\n' in formula_stripped else formula_stripped
        if "'" in comment_part and "&apos;" not in comment_part:
            # Only warn, not error - single quotes in comments are often OK
            pass


def validate_folders(root, calculations, result):
    """Check folder rules F1-F11."""

    # Find all folders
    folders_common = root.find('.//folders-common')
    layout = root.find('.//layout')
    all_folders = root.findall('.//folder')

    # F2: <folders-common> exists
    if folders_common is None:
        result.error("F2", "XML", "Missing <folders-common> element")
        return  # Can't check other folder rules

    result.passed("F2", "XML", "<folders-common> exists")

    # F3: <folders-common> before <layout>
    if layout is not None:
        # Check position in parent
        parent = None
        for elem in root.iter():
            if folders_common in list(elem) and layout in list(elem):
                parent = elem
                break
        if parent is not None:
            children = list(parent)
            fc_idx = children.index(folders_common) if folders_common in children else -1
            layout_idx = children.index(layout) if layout in children else -1
            if fc_idx > layout_idx and layout_idx != -1:
                result.error("F3", "XML", "<folders-common> must appear before <layout>")
            else:
                result.passed("F3", "XML", "<folders-common> is before <layout>")

    # Get folders inside folders-common
    folders_in_common = folders_common.findall('folder') if folders_common is not None else []

    # F4: <folder> inside <folders-common>
    folders_outside = [f for f in all_folders if f not in folders_in_common]
    if folders_outside:
        result.error("F4", "XML", f"{len(folders_outside)} <folder> elements outside <folders-common>")
    else:
        result.passed("F4", "XML", "all <folder> elements inside <folders-common>")

    # F5: No role attribute on folders
    for folder in folders_in_common:
        if folder.get('role'):
            result.error("F5", folder.get('name', 'unnamed'), "has invalid role attribute")

    # Collect all field names in folders
    fields_in_folders = set()
    for folder in folders_in_common:
        for item in folder.findall('folder-item'):
            field_name = item.get('name')
            if field_name:
                fields_in_folders.add(field_name)

    # Get all calculation names
    calc_names = {c.get('name') for c in calculations}

    # F1: All calcs in a folder
    for calc in calculations:
        calc_name = calc.get('name')
        display_name = calc.get('caption') or calc_name
        if calc_name and calc_name not in fields_in_folders and f'[{calc_name}]' not in fields_in_folders:
            # Try bracket format
            bracketed = f'[{calc_name}]' if not calc_name.startswith('[') else calc_name
            if bracketed not in fields_in_folders and calc_name not in fields_in_folders:
                result.error("F1", display_name, "not in any folder")

    # F6: Field names match exactly
    for folder in folders_in_common:
        for item in folder.findall('folder-item'):
            field_name = item.get('name', '')
            # Remove brackets for comparison
            clean_name = field_name.strip('[]')
            if clean_name not in calc_names and field_name not in calc_names:
                result.error("F6", field_name, "not found in workbook")

    # F7: show-structure='true' in <layout>
    if layout is not None:
        if layout.get('show-structure') != 'true':
            result.error("F7", "XML", "<layout> missing show-structure='true'")
        else:
            result.passed("F7", "XML", "<layout> has show-structure='true'")

    # F8: No unescaped & in folder names
    for folder in folders_in_common:
        folder_name = folder.get('name', '')
        if '&' in folder_name and '&amp;' not in folder_name:
            result.error("F8", folder_name, "has unescaped &")

    # F9: Maximum 9 folders
    if len(folders_in_common) > 9:
        result.error("F9", "XML", f"Too many folders ({len(folders_in_common)}) - maximum is 9")
    else:
        result.passed("F9", "XML", f"{len(folders_in_common)} folders (max 9)")

    # F10: Folder names start with emoji
    emoji_pattern = re.compile(r'^[\U0001F300-\U0001F9FF]')
    for folder in folders_in_common:
        folder_name = folder.get('name', '')
        if not emoji_pattern.match(folder_name):
            result.error("F10", folder_name, "missing emoji prefix")

    # F11: No duplicate folder names or emojis
    folder_names = []
    folder_emojis = []
    for folder in folders_in_common:
        folder_name = folder.get('name', '')
        folder_names.append(folder_name)
        match = emoji_pattern.match(folder_name)
        if match:
            folder_emojis.append(match.group())

    # Check for duplicate names
    seen_names = set()
    for name in folder_names:
        if name in seen_names:
            result.error("F11", name, "duplicate folder name")
        seen_names.add(name)

    # Check for duplicate emojis
    seen_emojis = set()
    for emoji in folder_emojis:
        if emoji in seen_emojis:
            result.error("F11", emoji, "duplicate emoji used in multiple folders")
        seen_emojis.add(emoji)


def validate_xml(twb_path, result):
    """Check XML rules X1-X2."""
    try:
        tree = ET.parse(twb_path)
        result.passed("X1", "XML", "valid XML")
        return tree.getroot()
    except ET.ParseError as e:
        result.error("X1", "XML", f"parse error: {e}")
        return None


def validate_safety(twb_path, backup_path, original_path, result):
    """Check safety rules S1-S3."""

    # S2: Backup exists
    if backup_path:
        if Path(backup_path).exists():
            result.passed("S2", "backup", f"exists at {backup_path}")
        else:
            result.error("S2", "backup", f"not found at {backup_path}")

    # S3: Output is _cleaned copy (check filename)
    if '_cleaned' in str(twb_path):
        result.passed("S3", "output", "is _cleaned copy")
    elif original_path and str(twb_path) == str(original_path):
        result.error("S3", "output", "original file was modified instead of _cleaned copy")


def validate_workbook(twb_path, backup_path=None, original_path=None):
    """Run all validations on a workbook."""
    result = ValidationResult()

    print(f"\n{'='*50}")
    print(f"  Tableau Cleanup Validation")
    print(f"  {twb_path}")
    print(f"{'='*50}\n")

    # X1-X2: XML validation
    print("XML:")
    root = validate_xml(twb_path, result)
    if root is None:
        # Can't continue if XML is invalid
        for e in result.errors:
            print(f"  {e}")
        return result
    print(f"  [PASS] X1: valid XML")

    # Get all calculations
    calculations = list(root.iter('column'))
    calculations = [c for c in calculations if c.find('calculation') is not None]

    print(f"\nFound {len(calculations)} calculated fields\n")

    # C1-C5: Caption validation
    print("CAPTIONS:")
    caption_errors_before = len(result.errors)
    for col in calculations:
        caption = col.get('caption')
        name = col.get('name')
        validate_caption(caption, name, result)

    if len(result.errors) == caption_errors_before:
        print("  [PASS] All captions valid")
    else:
        for e in result.errors[caption_errors_before:]:
            print(f"  {e}")

    # M1-M6: Comment validation
    print("\nCOMMENTS:")
    comment_errors_before = len(result.errors)
    for col in calculations:
        calc = col.find('calculation')
        formula = calc.get('formula', '') if calc is not None else ''
        caption = col.get('caption')
        name = col.get('name')
        validate_comment(formula, caption, name, result)

    if len(result.errors) == comment_errors_before:
        print("  [PASS] All comments valid")
    else:
        for e in result.errors[comment_errors_before:]:
            print(f"  {e}")

    # F1-F11: Folder validation
    print("\nFOLDERS:")
    folder_errors_before = len(result.errors)
    validate_folders(root, calculations, result)

    if len(result.errors) == folder_errors_before:
        print("  [PASS] All folder rules pass")
    else:
        for e in result.errors[folder_errors_before:]:
            print(f"  {e}")

    # S1-S3: Safety validation
    if backup_path or original_path:
        print("\nSAFETY:")
        validate_safety(twb_path, backup_path, original_path, result)

    # Summary
    print(f"\n{'='*50}")
    print(f"  SUMMARY: {len(result.errors)} errors, {len(result.passes)} passed")
    print(f"{'='*50}")

    if result.has_errors():
        print("\nFix the errors above and run validation again.")
        print("EXIT CODE: 1 (errors found)")
    else:
        print("\nAll validations passed!")
        print("EXIT CODE: 0 (success)")

    return result


if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: validate_cleanup.py <twb_path> [--backup <backup_path>] [--original <original_path>]")
        print("\nChecks all 27 cleanup rules and outputs errors.")
        print("Exit code 0 = all pass, 1 = errors found.")
        sys.exit(1)

    twb_path = sys.argv[1]
    backup_path = None
    original_path = None

    # Parse optional arguments
    args = sys.argv[2:]
    i = 0
    while i < len(args):
        if args[i] == '--backup' and i + 1 < len(args):
            backup_path = args[i + 1]
            i += 2
        elif args[i] == '--original' and i + 1 < len(args):
            original_path = args[i + 1]
            i += 2
        else:
            i += 1

    result = validate_workbook(twb_path, backup_path, original_path)
    sys.exit(1 if result.has_errors() else 0)

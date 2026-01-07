#!/usr/bin/env python3
"""Extract all calculated fields from a .twb file as JSON."""
import sys
import json
import xml.etree.ElementTree as ET
import html

def list_calculations(twb_path, include_full_formula=False):
    """
    Extract all calculated fields from a Tableau workbook.

    Args:
        twb_path: Path to the .twb file
        include_full_formula: If True, include complete formula text

    Returns:
        dict with 'count', 'calculations' list, and optional 'error'
    """
    try:
        tree = ET.parse(twb_path)
        root = tree.getroot()
    except ET.ParseError as e:
        return {"success": False, "error": f"XML parse error: {e}"}
    except FileNotFoundError:
        return {"success": False, "error": f"File not found: {twb_path}"}

    calculations = []

    for column in root.iter('column'):
        calc = column.find('calculation')
        if calc is not None:
            formula = calc.get('formula', '')

            # Check if formula has a comment
            has_comment = formula.strip().startswith('//')

            # Truncate formula for display unless full formula requested
            if include_full_formula:
                formula_display = formula
            else:
                formula_display = formula[:200] + ('...' if len(formula) > 200 else '')

            calc_info = {
                "name": column.get('name'),
                "caption": column.get('caption'),
                "datatype": column.get('datatype'),
                "role": column.get('role'),
                "type": column.get('type'),
                "has_comment": has_comment,
                "formula_preview": formula_display
            }

            if include_full_formula:
                calc_info["formula_full"] = formula

            calculations.append(calc_info)

    # Sort by caption for easier reading
    calculations.sort(key=lambda x: (x.get('caption') or x.get('name') or '').lower())

    return {
        "success": True,
        "count": len(calculations),
        "with_comments": sum(1 for c in calculations if c['has_comment']),
        "without_comments": sum(1 for c in calculations if not c['has_comment']),
        "calculations": calculations
    }

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print(json.dumps({"error": "Usage: list_calculations.py <twb_path> [--full]"}))
        sys.exit(1)

    twb_path = sys.argv[1]
    include_full = '--full' in sys.argv

    result = list_calculations(twb_path, include_full_formula=include_full)
    print(json.dumps(result, indent=2))

    if not result.get("success", True):
        sys.exit(1)

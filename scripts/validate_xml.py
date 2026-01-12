#!/usr/bin/env python3
"""Validate that a .twb file is valid XML."""
import sys
import json
import xml.etree.ElementTree as ET

def validate(twb_path):
    """
    Validate that a Tableau workbook file is valid XML.

    Args:
        twb_path: Path to the .twb file

    Returns:
        dict with 'valid' (bool) and optional 'error'
    """
    try:
        tree = ET.parse(twb_path)
        root = tree.getroot()

        # Basic structural validation
        checks = {
            "has_root": root is not None,
            "root_tag": root.tag if root is not None else None,
            "has_datasources": root.find('.//datasource') is not None if root is not None else False,
            "has_worksheets": root.find('.//worksheet') is not None if root is not None else False,
        }

        return {
            "valid": True,
            "error": None,
            "checks": checks
        }
    except ET.ParseError as e:
        # Extract line and column from error message
        error_str = str(e)
        return {
            "valid": False,
            "error": error_str,
            "checks": None
        }
    except FileNotFoundError:
        return {
            "valid": False,
            "error": f"File not found: {twb_path}",
            "checks": None
        }
    except Exception as e:
        return {
            "valid": False,
            "error": f"Unexpected error: {e}",
            "checks": None
        }

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print(json.dumps({"error": "Usage: validate_xml.py <twb_path>"}))
        sys.exit(1)

    result = validate(sys.argv[1])
    print(json.dumps(result, indent=2))

    if not result.get("valid"):
        sys.exit(1)

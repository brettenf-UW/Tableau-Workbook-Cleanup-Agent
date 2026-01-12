#!/usr/bin/env python3
"""Repackage an extracted folder back into a .twbx file."""
import os
import sys
import zipfile
import json

def repackage(extract_dir, output_path):
    """
    Repackage an extracted folder back into a .twbx file.

    Args:
        extract_dir: Directory containing the extracted workbook contents
        output_path: Path for the output .twbx file

    Returns:
        dict with 'success', 'output_path', and optional 'error'
    """
    if not os.path.isdir(extract_dir):
        return {"success": False, "error": f"Directory not found: {extract_dir}"}

    if not output_path.lower().endswith('.twbx'):
        output_path += '.twbx'

    # Ensure output directory exists
    output_dir = os.path.dirname(output_path)
    if output_dir:
        os.makedirs(output_dir, exist_ok=True)

    try:
        files_added = []
        with zipfile.ZipFile(output_path, 'w', zipfile.ZIP_DEFLATED) as zf:
            for root, dirs, files in os.walk(extract_dir):
                for file in files:
                    file_path = os.path.join(root, file)
                    arcname = os.path.relpath(file_path, extract_dir)
                    zf.write(file_path, arcname)
                    files_added.append(arcname)

        return {
            "success": True,
            "output_path": output_path,
            "files_included": len(files_added),
            "source_dir": extract_dir
        }
    except Exception as e:
        return {"success": False, "error": f"Packaging failed: {e}"}

if __name__ == '__main__':
    if len(sys.argv) < 3:
        print(json.dumps({"error": "Usage: repackage_twbx.py <extract_dir> <output_path>"}))
        sys.exit(1)

    extract_dir = sys.argv[1]
    output_path = sys.argv[2]

    result = repackage(extract_dir, output_path)
    print(json.dumps(result, indent=2))

    if not result.get("success"):
        sys.exit(1)

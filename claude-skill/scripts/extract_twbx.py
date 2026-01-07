#!/usr/bin/env python3
"""Extract a .twbx file and return path to the .twb inside."""
import os
import sys
import zipfile
import tempfile
import json
import glob

def extract_twbx(twbx_path, extract_dir=None):
    """
    Extract a .twbx file and find the .twb inside.

    Args:
        twbx_path: Path to the .twbx file
        extract_dir: Optional directory to extract to (default: temp directory)

    Returns:
        dict with 'success', 'extract_dir', 'twb_path', and optional 'error'
    """
    if not os.path.exists(twbx_path):
        return {"success": False, "error": f"File not found: {twbx_path}"}

    if not twbx_path.lower().endswith('.twbx'):
        return {"success": False, "error": "Not a .twbx file"}

    if extract_dir is None:
        extract_dir = tempfile.mkdtemp(prefix='tableau_cleanup_')
    else:
        os.makedirs(extract_dir, exist_ok=True)

    try:
        with zipfile.ZipFile(twbx_path, 'r') as zf:
            zf.extractall(extract_dir)
    except zipfile.BadZipFile:
        return {"success": False, "error": "Invalid or corrupted .twbx file"}
    except Exception as e:
        return {"success": False, "error": f"Extraction failed: {e}"}

    # Find the .twb file inside
    twb_files = glob.glob(os.path.join(extract_dir, '**', '*.twb'), recursive=True)

    if not twb_files:
        return {"success": False, "error": "No .twb found in archive"}

    # Usually there's only one .twb, but return the first
    return {
        "success": True,
        "extract_dir": extract_dir,
        "twb_path": twb_files[0],
        "original_twbx": twbx_path,
        "contents": os.listdir(extract_dir)
    }

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print(json.dumps({"error": "Usage: extract_twbx.py <twbx_path> [extract_dir]"}))
        sys.exit(1)

    twbx_path = sys.argv[1]
    extract_dir = sys.argv[2] if len(sys.argv) > 2 else None

    result = extract_twbx(twbx_path, extract_dir)
    print(json.dumps(result, indent=2))

    if not result.get("success"):
        sys.exit(1)

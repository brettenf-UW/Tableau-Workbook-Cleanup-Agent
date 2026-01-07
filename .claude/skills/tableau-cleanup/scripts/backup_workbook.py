#!/usr/bin/env python3
"""Create a timestamped backup of a Tableau workbook."""
import os
import sys
import shutil
import json
from datetime import datetime

def backup(input_path, backup_dir=None):
    """
    Create a timestamped backup of a workbook.

    Args:
        input_path: Path to the workbook file
        backup_dir: Directory for backups (default: 'backups' folder in same directory)

    Returns:
        dict with 'success', 'backup_path', and optional 'error'
    """
    if not os.path.exists(input_path):
        return {"success": False, "error": f"File not found: {input_path}"}

    if backup_dir is None:
        backup_dir = os.path.join(os.path.dirname(input_path), 'backups')

    try:
        os.makedirs(backup_dir, exist_ok=True)
    except OSError as e:
        return {"success": False, "error": f"Could not create backup directory: {e}"}

    base, ext = os.path.splitext(os.path.basename(input_path))
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    backup_name = f"{base}_backup_{timestamp}{ext}"
    backup_path = os.path.join(backup_dir, backup_name)

    try:
        shutil.copy2(input_path, backup_path)
        return {
            "success": True,
            "backup_path": backup_path,
            "original": input_path,
            "timestamp": timestamp
        }
    except Exception as e:
        return {"success": False, "error": f"Copy failed: {e}"}

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print(json.dumps({"error": "Usage: backup_workbook.py <input_path> [backup_dir]"}))
        sys.exit(1)

    input_path = sys.argv[1]
    backup_dir = sys.argv[2] if len(sys.argv) > 2 else None

    result = backup(input_path, backup_dir)
    print(json.dumps(result, indent=2))

    if not result.get("success"):
        sys.exit(1)

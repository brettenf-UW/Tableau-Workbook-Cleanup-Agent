#!/usr/bin/env python3
"""Find the most recently modified .twb or .twbx file in a directory."""
import os
import sys
import glob
import json

def find_latest(directory, extensions=['.twb', '.twbx'], exclude_patterns=['_backup', '_cleaned', 'Archive', 'backups']):
    """
    Find the most recently modified Tableau workbook in a directory.

    Args:
        directory: Path to search
        extensions: List of file extensions to look for
        exclude_patterns: Patterns to exclude from results

    Returns:
        dict with 'latest' (path or None) and 'exists' (bool)
    """
    candidates = []

    for ext in extensions:
        pattern = os.path.join(directory, '**', f'*{ext}')
        for f in glob.glob(pattern, recursive=True):
            # Skip files matching exclude patterns
            if not any(p.lower() in f.lower() for p in exclude_patterns):
                try:
                    mtime = os.path.getmtime(f)
                    candidates.append((f, mtime))
                except OSError:
                    continue

    if not candidates:
        return {"latest": None, "exists": False, "count": 0}

    # Sort by modification time, most recent first
    candidates.sort(key=lambda x: x[1], reverse=True)
    latest = candidates[0][0]

    return {
        "latest": latest,
        "exists": True,
        "count": len(candidates),
        "all_workbooks": [c[0] for c in candidates[:10]]  # Return up to 10 most recent
    }

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print(json.dumps({"error": "Usage: find_latest_workbook.py <directory>"}))
        sys.exit(1)

    directory = sys.argv[1]

    if not os.path.isdir(directory):
        print(json.dumps({"error": f"Directory not found: {directory}"}))
        sys.exit(1)

    result = find_latest(directory)
    print(json.dumps(result, indent=2))

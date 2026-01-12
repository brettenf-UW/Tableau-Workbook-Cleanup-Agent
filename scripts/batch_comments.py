#!/usr/bin/env python3
"""
Batch Comment Processing for Tableau Cleanup

Forces Claude to process calculations in batches of 10, with full visibility
into each formula. Tracks progress to ensure 100% coverage.

Usage:
  python batch_comments.py <twb_file> init      # Create batches of 10
  python batch_comments.py <twb_file> next      # Show next pending batch
  python batch_comments.py <twb_file> done <N>  # Mark batch N complete
  python batch_comments.py <twb_file> status    # Show progress
  python batch_comments.py <twb_file> reset     # Start over
"""
import sys
import json
import re
import xml.etree.ElementTree as ET
from pathlib import Path
from datetime import datetime

BATCH_SIZE = 10


def get_cleanup_dir(twb_path):
    """Get or create .cleanup directory next to the workbook."""
    cleanup_dir = Path(twb_path).parent / '.cleanup'
    cleanup_dir.mkdir(exist_ok=True)
    return cleanup_dir


def get_batch_file(twb_path):
    """Get path to batch tracking file."""
    return get_cleanup_dir(twb_path) / 'comment_batches.json'


def extract_calculations(twb_path):
    """Extract all calculations from workbook with their formulas."""
    with open(twb_path, 'r', encoding='utf-8', errors='replace') as f:
        content = f.read()

    root = ET.fromstring(content)
    calculations = []

    for col in root.iter('column'):
        calc = col.find('calculation')
        if calc is None:
            continue

        # Skip bin/group calculations (no formula attribute possible)
        calc_class = calc.get('class')
        if calc_class in ('categorical-bin', 'quantitative-bin'):
            continue

        formula = calc.get('formula')
        if formula is None:
            continue

        name = col.get('name', '')
        caption = col.get('caption', '')

        # Extract current comment if any
        current_comment = None
        if formula.strip().startswith('//'):
            # Get first line as comment
            first_line = formula.strip().split('\n')[0]
            if first_line.startswith('//'):
                current_comment = first_line

        calculations.append({
            'name': name,
            'caption': caption,
            'formula': formula,
            'current_comment': current_comment
        })

    return calculations


def init_batches(twb_path):
    """Initialize batch tracking file with all calculations."""
    calcs = extract_calculations(twb_path)

    if not calcs:
        print("No calculations found in workbook.")
        return

    # Create batches of BATCH_SIZE
    batches = []
    for i in range(0, len(calcs), BATCH_SIZE):
        batch_calcs = calcs[i:i + BATCH_SIZE]
        batches.append({
            'num': len(batches) + 1,
            'status': 'pending',
            'calcs': [c['name'] for c in batch_calcs],
            'details': batch_calcs
        })

    data = {
        'workbook': str(Path(twb_path).name),
        'created': datetime.now().isoformat(),
        'total_calcs': len(calcs),
        'batch_size': BATCH_SIZE,
        'batches': batches
    }

    batch_file = get_batch_file(twb_path)
    with open(batch_file, 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=2)

    print(f"Created {len(batches)} batches ({len(calcs)} calculations, {BATCH_SIZE} per batch)")
    print(f"Tracking file: {batch_file}")
    print(f"\nRun: python batch_comments.py \"{twb_path}\" next")


def show_next_batch(twb_path):
    """Show the next pending batch with full formula details."""
    batch_file = get_batch_file(twb_path)

    if not batch_file.exists():
        print("No batches initialized. Run 'init' first.")
        return

    with open(batch_file, 'r', encoding='utf-8') as f:
        data = json.load(f)

    # Find first pending batch
    pending = [b for b in data['batches'] if b['status'] == 'pending']

    if not pending:
        print("All batches complete!")
        show_status(twb_path)
        return

    batch = pending[0]
    total_batches = len(data['batches'])

    print(f"\n{'='*60}")
    print(f"  BATCH {batch['num']} of {total_batches}")
    print(f"{'='*60}\n")

    # Re-read current state from workbook to get latest formulas
    current_calcs = {c['name']: c for c in extract_calculations(twb_path)}

    for i, calc_name in enumerate(batch['calcs'], 1):
        calc = current_calcs.get(calc_name, batch['details'][i-1])

        print(f"[{i}] Name: {calc['name']}")
        print(f"    Caption: {calc.get('caption', '(none)')}")

        # Format formula for display (decode XML entities)
        formula = calc.get('formula', '')
        formula_display = formula.replace('&#13;&#10;', '\n').replace('&amp;', '&')

        # Truncate very long formulas
        if len(formula_display) > 500:
            formula_display = formula_display[:500] + '...'

        print(f"    Formula: {formula_display}")

        # Check current comment status
        current = calc.get('current_comment')
        if current:
            # Check if it's a lazy comment
            lazy_patterns = [
                r'^//\s*(calculated\s+field|calculation|formula|field)\s*$',
                r'^//\s*\w{1,6}\s*$',
            ]
            is_lazy = any(re.match(p, current, re.IGNORECASE) for p in lazy_patterns)
            if is_lazy:
                print(f"    Current Comment: {current}  ← LAZY, needs improvement!")
            else:
                print(f"    Current Comment: {current}")
        else:
            print(f"    Current Comment: (none)")

        print()

    print(f"{'='*60}")
    print(f"Add a comment explaining the PURPOSE of each calculation above.")
    print(f"Comments must be 15+ characters and explain WHY, not just WHAT.")
    print(f"\nWhen done, run:")
    print(f"  python batch_comments.py \"{twb_path}\" done {batch['num']}")
    print(f"{'='*60}\n")


def mark_batch_done(twb_path, batch_num):
    """Mark a batch as complete after verifying comments were added."""
    batch_file = get_batch_file(twb_path)

    if not batch_file.exists():
        print("No batches initialized. Run 'init' first.")
        return

    with open(batch_file, 'r', encoding='utf-8') as f:
        data = json.load(f)

    # Find the batch
    batch = None
    for b in data['batches']:
        if b['num'] == batch_num:
            batch = b
            break

    if not batch:
        print(f"Batch {batch_num} not found.")
        return

    # Verify comments were actually added
    current_calcs = {c['name']: c for c in extract_calculations(twb_path)}

    missing = []
    lazy = []

    lazy_patterns = [
        r'^//\s*(calculated\s+field|calculation|formula|field)\s*$',
        r'^//\s*\w{1,6}\s*$',
        r'^//\s*(this|the|a|an)\s+\w+\s*$',
    ]

    for calc_name in batch['calcs']:
        calc = current_calcs.get(calc_name)
        if not calc:
            continue

        comment = calc.get('current_comment')
        if not comment:
            missing.append(calc_name)
        else:
            # Check comment quality
            comment_text = comment.replace('//', '').strip()
            if len(comment_text) < 15:
                lazy.append((calc_name, f"too short ({len(comment_text)} chars)"))
            elif any(re.match(p, comment, re.IGNORECASE) for p in lazy_patterns):
                lazy.append((calc_name, "generic/lazy pattern"))

    if missing or lazy:
        print(f"\n⚠️  Batch {batch_num} has issues:\n")

        if missing:
            print("Missing comments:")
            for name in missing:
                print(f"  - {name}")

        if lazy:
            print("\nLazy/short comments:")
            for name, reason in lazy:
                print(f"  - {name}: {reason}")

        print(f"\nFix these before marking batch complete.")
        return

    # Mark complete
    batch['status'] = 'complete'
    batch['completed_at'] = datetime.now().isoformat()

    with open(batch_file, 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=2)

    completed = len([b for b in data['batches'] if b['status'] == 'complete'])
    total = len(data['batches'])

    print(f"✓ Batch {batch_num} marked complete ({completed}/{total} batches done)")

    if completed < total:
        print(f"\nRun: python batch_comments.py \"{twb_path}\" next")
    else:
        print("\n🎉 All batches complete!")


def show_status(twb_path):
    """Show current progress."""
    batch_file = get_batch_file(twb_path)

    if not batch_file.exists():
        print("No batches initialized. Run 'init' first.")
        return

    with open(batch_file, 'r', encoding='utf-8') as f:
        data = json.load(f)

    completed = len([b for b in data['batches'] if b['status'] == 'complete'])
    total = len(data['batches'])
    pct = (completed / total * 100) if total > 0 else 0

    print(f"\n{'='*40}")
    print(f"  Comment Batch Progress")
    print(f"{'='*40}")
    print(f"  Workbook: {data['workbook']}")
    print(f"  Total calculations: {data['total_calcs']}")
    print(f"  Batch size: {data['batch_size']}")
    print(f"  Batches: {completed}/{total} ({pct:.0f}%)")
    print(f"{'='*40}")

    # Show batch breakdown
    print("\nBatch Status:")
    for batch in data['batches']:
        status_icon = "✓" if batch['status'] == 'complete' else "○"
        print(f"  {status_icon} Batch {batch['num']}: {batch['status']}")

    if completed < total:
        next_batch = next((b for b in data['batches'] if b['status'] == 'pending'), None)
        if next_batch:
            print(f"\nNext: python batch_comments.py \"{twb_path}\" next")


def reset_batches(twb_path):
    """Reset all batch tracking."""
    batch_file = get_batch_file(twb_path)

    if batch_file.exists():
        batch_file.unlink()
        print("Batch tracking reset.")
    else:
        print("No batch file to reset.")


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(1)

    twb_path = sys.argv[1]
    command = sys.argv[2].lower()

    if not Path(twb_path).exists():
        print(f"File not found: {twb_path}")
        sys.exit(1)

    if command == 'init':
        init_batches(twb_path)
    elif command == 'next':
        show_next_batch(twb_path)
    elif command == 'done':
        if len(sys.argv) < 4:
            print("Usage: batch_comments.py <file> done <batch_number>")
            sys.exit(1)
        batch_num = int(sys.argv[3])
        mark_batch_done(twb_path, batch_num)
    elif command == 'status':
        show_status(twb_path)
    elif command == 'reset':
        reset_batches(twb_path)
    else:
        print(f"Unknown command: {command}")
        print(__doc__)
        sys.exit(1)


if __name__ == '__main__':
    main()

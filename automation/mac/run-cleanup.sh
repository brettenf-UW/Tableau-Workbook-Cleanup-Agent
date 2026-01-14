#!/bin/bash
# Tableau Workbook Scrubber - Cleanup Runner
# Runs Claude Code in a loop until validation passes

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Import shared UI functions
source "$SCRIPT_DIR/lib/ui-helpers.sh"

# Configuration
CONFIG_DIR="$HOME/.iw-tableau-cleanup"
CONFIG_FILE="$CONFIG_DIR/config.json"
SKILL_DIR="$HOME/.claude/skills/tableau-cleanup"
VALIDATE_SCRIPT="$SKILL_DIR/scripts/validate_cleanup.py"

# Cost control settings (Sonnet 4.5: ~$3/M input, ~$15/M output)
CLAUDE_MODEL="sonnet"             # Use Sonnet 4.5
MAX_CLAUDE_TURNS=30               # Limit API calls (~$2-4 per run)
MAX_OUTPUT_TOKENS=8000            # Limit output per response

# Default values
MAX_ITERATIONS=10
DRY_RUN=false
VERBOSE=false
STANDALONE=false
WORKBOOK_PATH=""
FOLDER_NAME=""
SCHEDULE_TIME=""

write_log() {
    local message="$1"
    local level="${2:-INFO}"
    local log_file="$3"

    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    local log_entry="[$timestamp] [$level] $message"

    if [[ -n "$log_file" ]]; then
        echo "$log_entry" >> "$log_file"
    fi
}

write_structured_log() {
    local workbook_name="$1"
    local success="$2"
    local iterations="$3"
    local initial_errors="$4"
    local final_errors="$5"
    local start_time="$6"
    local end_time="$7"
    local log_folder="$8"

    local jsonl_file="$log_folder/runs.jsonl"
    local duration=$(( $(date -d "$end_time" +%s 2>/dev/null || date -j -f "%Y-%m-%d %H:%M:%S" "$end_time" +%s 2>/dev/null || echo 0) - $(date -d "$start_time" +%s 2>/dev/null || date -j -f "%Y-%m-%d %H:%M:%S" "$start_time" +%s 2>/dev/null || echo 0) ))

    local log_entry="{\"timestamp\":\"$start_time\",\"workbook\":\"$workbook_name\",\"success\":$success,\"iterations\":$iterations,\"initial_errors\":$initial_errors,\"final_errors\":$final_errors,\"duration_seconds\":$duration}"

    echo "$log_entry" >> "$jsonl_file"
}

get_validation_errors() {
    local output="$1"
    local caption=0 comment=0 folder=0 xml=0 total=0

    while IFS= read -r line; do
        if [[ "$line" =~ \[ERROR\] ]]; then
            ((total++))
            if [[ "$line" =~ C[1-5]: ]]; then
                ((caption++))
            elif [[ "$line" =~ M[1-6]: ]]; then
                ((comment++))
            elif [[ "$line" =~ F[1-9]:|F1[01]: ]]; then
                ((folder++))
            elif [[ "$line" =~ X[1-2]: ]]; then
                ((xml++))
            fi
        fi
    done <<< "$output"

    echo "$caption $comment $folder $xml $total"
}

get_configuration() {
    if [[ -f "$CONFIG_FILE" ]]; then
        cat "$CONFIG_FILE"
    else
        echo "null"
    fi
}

find_latest_workbook() {
    local directory="$1"
    local exclude_patterns=("_backup" "_cleaned" "Archive" "backups")

    local workbook=$(find "$directory" -type f \( -name "*.twb" -o -name "*.twbx" \) 2>/dev/null | while read -r file; do
        local skip=false
        for pattern in "${exclude_patterns[@]}"; do
            if [[ "$file" == *"$pattern"* ]]; then
                skip=true
                break
            fi
        done
        $skip || echo "$file"
    done | xargs ls -t 2>/dev/null | head -1)

    echo "$workbook"
}

run_cleanup_loop() {
    local workbook_path="$1"
    local backup_folder="$2"
    local log_file="$3"
    local log_folder="$4"
    local max_iterations="$5"

    local iteration=0
    local success=false
    local workbook_name=$(basename "$workbook_path")
    local backup_created=false
    local start_time=$(date "+%Y-%m-%d %H:%M:%S")
    local initial_errors=0
    local final_errors=0

    # Calculate paths ONCE before the loop
    local twb_path="$workbook_path"
    if [[ "$workbook_path" =~ \.twbx$ ]]; then
        local extract_dir="${workbook_path%.twbx}"
        local twb_file=$(find "$extract_dir" -name "*.twb" 2>/dev/null | head -1)
        [[ -n "$twb_file" ]] && twb_path="$twb_file"
    fi
    local cleaned_path="${twb_path%.twb}_cleaned.twb"
    local check_path="$cleaned_path"

    while [[ $iteration -lt $max_iterations ]]; do
        ((iteration++))

        show_pass_header "$iteration" "$max_iterations"
        write_log "=== Iteration $iteration of $max_iterations ===" "INFO" "$log_file"

        # AUTO-BACKUP and create _cleaned copy on first pass only
        if ! $backup_created; then
            write_step "PHASE: Creating backup and working copy..."

            # Ensure backup folder exists
            mkdir -p "$backup_folder"

            local timestamp=$(date "+%Y%m%d_%H%M%S")
            local backup_name="${timestamp}_${workbook_name}"
            local backup_path="$backup_folder/$backup_name"

            if cp "$workbook_path" "$backup_path" 2>/dev/null; then
                write_good "Backup saved: $backup_name"
                write_log "Backup created: $backup_path" "INFO" "$log_file"
            else
                write_fail "Could not create backup"
                write_log "Backup failed" "ERROR" "$log_file"
                return 1
            fi

            # Create _cleaned copy BEFORE Claude starts
            if [[ ! -f "$cleaned_path" ]]; then
                cp "$twb_path" "$cleaned_path"
                write_good "Created working copy: $(basename "$cleaned_path")"
                write_log "Created _cleaned copy: $cleaned_path" "INFO" "$log_file"
            else
                write_good "Using existing: $(basename "$cleaned_path")"
            fi

            backup_created=true
        fi

        # PHASE 1: Check current state
        write_step "PHASE: Checking current errors..."

        local previous_total=0
        if [[ -f "$VALIDATE_SCRIPT" ]]; then
            local validate_result=$(python3 "$VALIDATE_SCRIPT" "$check_path" 2>&1)
            echo "$validate_result" | while read -r line; do
                write_log "  $line" "INFO" "$log_file"
            done

            read caption comment folder xml total <<< $(get_validation_errors "$validate_result")

            # Track initial errors on first pass
            if [[ $iteration -eq 1 ]]; then
                initial_errors=$total
            fi
            final_errors=$total

            if [[ $total -eq 0 ]]; then
                if [[ $iteration -gt 1 ]]; then
                    # Pass 2+: 0 errors means we're done
                    show_success "All Checks Passed!" "Passes Required|$iteration"
                    write_log "Validation passed! Cleanup complete." "INFO" "$log_file"
                    success=true
                    break
                else
                    # Pass 1: Still run Claude for thorough review
                    write_good "Validation passed - running thorough review anyway (Pass 1)"
                fi
            fi

            show_error_table "$caption" "$comment" "$folder" "$xml" "$total"
            previous_total=$total
        else
            write_bad "Validation script not found at: $VALIDATE_SCRIPT"
            write_status "Install skill files first: run install.sh"
            break
        fi

        # Build error summary for the prompt
        local error_list=""
        [[ $caption -gt 0 ]] && error_list+="$caption caption errors, "
        [[ $comment -gt 0 ]] && error_list+="$comment comment errors, "
        [[ $folder -gt 0 ]] && error_list+="$folder folder errors, "
        [[ $xml -gt 0 ]] && error_list+="$xml XML errors, "
        error_list="${error_list%, }"  # Remove trailing comma
        [[ -z "$error_list" ]] && error_list="none detected"

        # Extract ACTUAL error details so Claude knows exactly what to fix (first 100 lines)
        local error_details=$(echo "$validate_result" | grep '\[ERROR\]' | head -100)
        [[ -z "$error_details" ]] && error_details="(no error details captured)"

        local pass_instruction
        if [[ $iteration -eq 1 ]]; then
            pass_instruction="FIRST PASS - BE EXTREMELY THOROUGH:
- You MUST fix ALL $total errors listed below
- Review EVERY calculation, even ones without errors
- This is your ONE CHANCE for comprehensive review
- Do NOT stop until all errors are addressed"
        else
            pass_instruction="PASS $iteration - Be CONSERVATIVE: Only fix items that STILL have errors. Do NOT touch passing items."
        fi

        local prompt="Clean up this Tableau workbook by standardizing captions, adding comments, and organizing calculations into folders.

WORKBOOK PATH: $cleaned_path

PASS NUMBER: $iteration of $max_iterations
$pass_instruction

=== VALIDATION FOUND $total ERRORS ===
Summary: $error_list

SPECIFIC ERRORS TO FIX:
$error_details

=== END OF ERRORS ===

FOLDER RULES:
- If a calc ALREADY has a valid folder, DO NOT move it
- Ambiguous calcs: KEEP in current folder unless clearly wrong
- Only move calcs with NO folder or obviously WRONG folder
- Max folders: 10

TWO-LAYER VALIDATION:
1. SCRIPT validation catches obvious issues (too short, lazy patterns)
2. YOU must also validate - review comments for quality, even \"passing\" ones

Use batch processing (scripts/batch_comments.py) to process calculations in groups of 10.

COMMENT RULES:
- Must explain WHY the calc exists (not just what it does)
- 15+ characters, specific to this formula
- BAD: \"// This calculation is used for tracking\"
- GOOD: \"// Identifies stale accounts needing follow-up for retention\"

SAFETY RULES:
- NEVER change name attributes, only caption
- NEVER add formula to bin/group calculations
- Keep &#13;&#10; in formulas (valid XML newlines)
- Edit ONLY the _cleaned file at the path above

Fix ALL errors above. Run validation when done."

        # PHASE 2: Ask Claude to fix
        write_step "PHASE: Asking Claude to fix errors..."
        write_status "This may take a few minutes"

        local claude_start=$(date +%s)

        # Set token limit for cost control
        export CLAUDE_CODE_MAX_OUTPUT_TOKENS=$MAX_OUTPUT_TOKENS

        echo ""
        echo -e "    ${COLOR_DIM}--- Claude Output (Sonnet 4.5, max $MAX_CLAUDE_TURNS turns) ---${COLOR_RESET}"

        local allowed_tools="Read,Edit,Write,Bash(python:*)"
        local claude_output_file=$(mktemp)
        claude -p "$prompt" --model "$CLAUDE_MODEL" --max-turns "$MAX_CLAUDE_TURNS" --allowedTools "$allowed_tools" 2>&1 | tee "$claude_output_file" | while read -r line; do
            echo -e "    ${COLOR_DIM}$line${COLOR_RESET}"
            write_log "  $line" "INFO" "$log_file"
        done

        echo -e "    ${COLOR_DIM}--- End Output ---${COLOR_RESET}"
        echo ""

        local claude_end=$(date +%s)
        local duration=$(( claude_end - claude_start ))
        local minutes=$(echo "scale=1; $duration / 60" | bc)

        # Check if turn limit was hit
        if grep -qi "max.*turn\|turn.*limit\|limit.*reached" "$claude_output_file" 2>/dev/null; then
            write_fail "COST LIMIT: Max turns ($MAX_CLAUDE_TURNS) reached"
            write_status "Some fixes may not have been applied. Increase MAX_CLAUDE_TURNS if needed."
            write_log "WARNING: Max turns limit reached" "WARN" "$log_file"
        fi
        rm -f "$claude_output_file"

        write_good "Claude finished ($minutes min)"

        # PHASE 3: Verify fixes
        write_step "PHASE: Verifying fixes..."

        if [[ -f "$VALIDATE_SCRIPT" ]]; then
            validate_result=$(python3 "$VALIDATE_SCRIPT" "$check_path" 2>&1)
            echo "$validate_result" | while read -r line; do
                write_log "  $line" "INFO" "$log_file"
            done

            read caption comment folder xml total <<< $(get_validation_errors "$validate_result")
            final_errors=$total

            if [[ $total -eq 0 ]]; then
                show_success "All Checks Passed!" "Passes Required|$iteration"
                write_log "Validation passed! Cleanup complete." "INFO" "$log_file"
                success=true
                break
            fi

            # Show what's left
            local fixed=$((previous_total - total))
            if [[ $fixed -gt 0 ]]; then
                write_good "$fixed errors fixed this pass"
            elif [[ $fixed -lt 0 ]]; then
                local increased=$(( -fixed ))
                write_fail "REGRESSION: $increased MORE errors than before!"
                write_status "Claude may have over-reorganized. Consider restoring backup."
                write_log "ERROR REGRESSION: $increased more errors after Claude's changes" "ERROR" "$log_file"
            fi
            show_error_table "$caption" "$comment" "$folder" "$xml" "$total"
            write_bad "$total errors remaining - running another pass..."
            write_log "Validation found $total errors, continuing..." "INFO" "$log_file"
        fi
    done

    if ! $success; then
        show_failure "Max Passes Reached" "Some issues may remain after $max_iterations passes"
        write_log "Max iterations ($max_iterations) reached without passing validation" "ERROR" "$log_file"
    fi

    # Write structured log entry
    if [[ -n "$log_folder" ]]; then
        local end_time=$(date "+%Y-%m-%d %H:%M:%S")
        write_structured_log "$workbook_name" "$success" "$iteration" "$initial_errors" "$final_errors" "$start_time" "$end_time" "$log_folder"
    fi

    $success && return 0 || return 1
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --workbook|-w)
            WORKBOOK_PATH="$2"
            shift 2
            ;;
        --folder|-f)
            FOLDER_NAME="$2"
            shift 2
            ;;
        --schedule|-s)
            SCHEDULE_TIME="$2"
            shift 2
            ;;
        --max-iterations|-m)
            MAX_ITERATIONS="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --standalone)
            STANDALONE=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Banner
if $STANDALONE; then
    show_banner
else
    show_banner "compact"
fi
echo -e "    ${COLOR_DIM}Press Ctrl+C to cancel at any time${COLOR_RESET}"
echo ""

# Check if Claude is installed
write_step "Checking setup..."

if ! command -v claude &> /dev/null; then
    write_fail "Claude Code not found"
    echo ""
    echo -e "  ${COLOR_WARNING}Please install Claude Code first:${COLOR_RESET}"
    echo -e "  ${COLOR_DIM}https://claude.com/code${COLOR_RESET}"
    echo ""
    exit 1
fi
write_good "Claude Code installed"

# Check for jq (required for JSON parsing)
if ! command -v jq &> /dev/null; then
    write_fail "jq not found (required for JSON parsing)"
    echo ""
    echo -e "  ${COLOR_WARNING}Install with: brew install jq${COLOR_RESET}"
    echo ""
    exit 1
fi
write_good "jq installed"

# Setup logging
log_folder="$CONFIG_DIR/logs"
mkdir -p "$log_folder"
log_file="$log_folder/cleanup_$(date '+%Y%m%d_%H%M%S').log"
write_log "=== Tableau Cleanup Run Started ===" "INFO" "$log_file"

# Handle direct workbook path
if [[ -n "$WORKBOOK_PATH" ]]; then
    if [[ ! -f "$WORKBOOK_PATH" ]]; then
        write_fail "Workbook not found: $WORKBOOK_PATH"
        exit 1
    fi

    workbook_name=$(basename "$WORKBOOK_PATH")
    write_good "Found workbook: $workbook_name"

    backup_folder="$(dirname "$WORKBOOK_PATH")/backups"

    if $DRY_RUN; then
        write_bad "DRY RUN - no changes will be made"
        exit 0
    fi

    run_cleanup_loop "$WORKBOOK_PATH" "$backup_folder" "$log_file" "$log_folder" "$MAX_ITERATIONS"
    exit_code=$?

    echo ""
    echo -e "  ${COLOR_DIM}Log: $log_file${COLOR_RESET}"
    echo ""
    exit $exit_code
fi

# Load configuration
config=$(get_configuration)

if [[ "$config" == "null" ]]; then
    write_fail "No folders configured"
    echo ""
    echo -e "  ${COLOR_WARNING}Run 'tableau-setup' to add a folder first${COLOR_RESET}"
    echo ""
    exit 1
fi
write_good "Configuration loaded"

# Get folders to process
if [[ -n "$FOLDER_NAME" ]]; then
    folders=$(echo "$config" | jq -c "[.folders[] | select(.name == \"$FOLDER_NAME\" and .enabled == true)]")
elif [[ -n "$SCHEDULE_TIME" ]]; then
    folders=$(echo "$config" | jq -c "[.folders[] | select(.schedule == \"$SCHEDULE_TIME\" and .enabled == true)]")
else
    folders=$(echo "$config" | jq -c "[.folders[] | select(.enabled == true)]")
fi

folder_count=$(echo "$folders" | jq 'length')

if [[ "$folder_count" -eq 0 ]]; then
    write_bad "No enabled folders to process"
    exit 0
fi

write_good "$folder_count folder(s) to process"
write_log "Processing $folder_count folder(s)" "INFO" "$log_file"

success_count=0
fail_count=0
skipped_count=0

for ((i=0; i<folder_count; i++)); do
    folder=$(echo "$folders" | jq -c ".[$i]")
    folder_name=$(echo "$folder" | jq -r '.name')
    folder_path=$(echo "$folder" | jq -r '.path')
    folder_backup=$(echo "$folder" | jq -r '.backup_folder // empty')

    echo ""
    echo -e "  ${COLOR_DIM}----------------------------------------${COLOR_RESET}"
    write_step "Folder: $folder_name"
    write_status "Looking for workbooks in: $folder_path"
    write_log "=== Processing: $folder_name ===" "INFO" "$log_file"

    # Find latest workbook in folder
    target_workbook=$(find_latest_workbook "$folder_path")

    if [[ -z "$target_workbook" ]]; then
        write_bad "No workbooks found in this folder"
        write_log "No workbooks found in: $folder_path" "INFO" "$log_file"
        ((skipped_count++))
        continue
    fi

    write_good "Found: $(basename "$target_workbook")"
    write_status "Last modified: $(stat -f '%Sm' -t '%b %d, %Y %I:%M %p' "$target_workbook" 2>/dev/null || date -r "$target_workbook" '+%b %d, %Y %I:%M %p' 2>/dev/null)"
    write_log "Found: $(basename "$target_workbook")" "INFO" "$log_file"

    # Check if already cleaned recently
    cleaned_path="${target_workbook%.*}_cleaned.${target_workbook##*.}"
    if [[ -f "$cleaned_path" ]]; then
        cleaned_time=$(stat -f '%m' "$cleaned_path" 2>/dev/null || stat -c '%Y' "$cleaned_path" 2>/dev/null || echo 0)
        current_time=$(date +%s)
        hours_since=$(( (current_time - cleaned_time) / 3600 ))

        if [[ $hours_since -lt 1 ]]; then
            write_bad "Already cleaned recently - skipping"
            write_log "Already cleaned within the last hour, skipping" "INFO" "$log_file"
            ((skipped_count++))
            continue
        fi
    fi

    # Determine backup folder
    backup_folder="${folder_backup:-$folder_path/backups}"

    if $DRY_RUN; then
        write_bad "DRY RUN - would clean this workbook"
        write_log "DRY RUN: Would clean $target_workbook" "INFO" "$log_file"
        continue
    fi

    # Run the cleanup loop
    if run_cleanup_loop "$target_workbook" "$backup_folder" "$log_file" "$log_folder" "$MAX_ITERATIONS"; then
        ((success_count++))
    else
        ((fail_count++))
    fi
done

# Final summary
echo ""
write_header "Cleanup Complete"

[[ $success_count -gt 0 ]] && echo -e "      ${COLOR_DIM}Cleaned:${COLOR_RESET}     ${COLOR_SUCCESS}$success_count workbook(s)${COLOR_RESET}"
[[ $fail_count -gt 0 ]] && echo -e "      ${COLOR_DIM}Failed:${COLOR_RESET}      ${COLOR_ERROR}$fail_count workbook(s)${COLOR_RESET}"
[[ $skipped_count -gt 0 ]] && echo -e "      ${COLOR_DIM}Skipped:${COLOR_RESET}     ${COLOR_WARNING}$skipped_count folder(s)${COLOR_RESET}"

echo ""
write_status "Log: $log_file"
echo ""

write_log "=== Completed: $success_count success, $fail_count failed, $skipped_count skipped ===" "INFO" "$log_file"

[[ $fail_count -gt 0 ]] && exit 1 || exit 0

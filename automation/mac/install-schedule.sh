#!/bin/bash
# Tableau Workbook Scrubber - Schedule Installation
# Creates launchd jobs (macOS) or cron jobs (Linux) for automated cleanup

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Import shared UI functions
source "$SCRIPT_DIR/lib/ui-helpers.sh"

# Configuration
PLIST_PREFIX="com.interworks.tableau-scrubber"
CONFIG_DIR="$HOME/.iw-tableau-cleanup"
CONFIG_FILE="$CONFIG_DIR/config.json"
LAUNCHD_DIR="$HOME/Library/LaunchAgents"
CLEANUP_SCRIPT="$SCRIPT_DIR/run-cleanup.sh"

# Parse arguments
UNINSTALL=false
LIST=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --uninstall|-u)
            UNINSTALL=true
            shift
            ;;
        --list|-l)
            LIST=true
            shift
            ;;
        *)
            shift
            ;;
    esac
done

get_configuration() {
    if [[ -f "$CONFIG_FILE" ]]; then
        cat "$CONFIG_FILE"
    else
        echo "null"
    fi
}

get_unique_schedules() {
    local config="$1"
    echo "$config" | jq -r '[.folders[] | select(.enabled == true) | .schedule] | unique | .[]' 2>/dev/null
}

get_plist_name() {
    local time="$1"
    local safe_time="${time//:/.}"
    echo "${PLIST_PREFIX}.${safe_time}"
}

get_plist_path() {
    local time="$1"
    echo "$LAUNCHD_DIR/$(get_plist_name "$time").plist"
}

create_launchd_plist() {
    local time="$1"
    local plist_path=$(get_plist_path "$time")
    local plist_name=$(get_plist_name "$time")

    # Parse time
    local hour="${time%%:*}"
    local minute="${time##*:}"

    # Remove leading zeros for launchd
    hour=$((10#$hour))
    minute=$((10#$minute))

    cat > "$plist_path" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$plist_name</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>$CLEANUP_SCRIPT</string>
        <string>--schedule</string>
        <string>$time</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key>
        <integer>$hour</integer>
        <key>Minute</key>
        <integer>$minute</integer>
    </dict>
    <key>StandardOutPath</key>
    <string>$CONFIG_DIR/logs/launchd_stdout.log</string>
    <key>StandardErrorPath</key>
    <string>$CONFIG_DIR/logs/launchd_stderr.log</string>
    <key>RunAtLoad</key>
    <false/>
</dict>
</plist>
EOF
}

install_launchd_job() {
    local time="$1"
    local plist_path=$(get_plist_path "$time")
    local plist_name=$(get_plist_name "$time")

    # Unload if exists
    launchctl unload "$plist_path" 2>/dev/null

    # Create plist
    create_launchd_plist "$time"

    # Load the job
    launchctl load "$plist_path"

    write_good "Created: $plist_name ($time daily)"
}

uninstall_all_jobs() {
    local count=0

    # Find and remove all our plist files
    for plist in "$LAUNCHD_DIR"/${PLIST_PREFIX}*.plist; do
        if [[ -f "$plist" ]]; then
            local name=$(basename "$plist" .plist)
            launchctl unload "$plist" 2>/dev/null
            rm -f "$plist"
            write_good "Removed: $name"
            ((count++))
        fi
    done

    if [[ $count -gt 0 ]]; then
        show_success "Jobs Removed" "Removed|$count"
    else
        write_bad "No scheduled jobs found"
    fi
}

list_jobs() {
    write_header "Scheduled Jobs"

    local found=false

    echo ""
    echo -e "    ${COLOR_DIM}+-------------------------------+-------+----------+${COLOR_RESET}"
    echo -e "    ${COLOR_BODY}| Job Name                      | Time  | Status   |${COLOR_RESET}"
    echo -e "    ${COLOR_DIM}+-------------------------------+-------+----------+${COLOR_RESET}"

    for plist in "$LAUNCHD_DIR"/${PLIST_PREFIX}*.plist; do
        if [[ -f "$plist" ]]; then
            found=true
            local name=$(basename "$plist" .plist)

            # Extract time from plist
            local hour=$(plutil -extract StartCalendarInterval.Hour raw "$plist" 2>/dev/null || echo "?")
            local minute=$(plutil -extract StartCalendarInterval.Minute raw "$plist" 2>/dev/null || echo "?")
            local time_str=$(printf "%02d:%02d" "$hour" "$minute" 2>/dev/null || echo "??:??")

            # Check if loaded
            local status="Ready"
            local status_color="$COLOR_SUCCESS"
            if ! launchctl list 2>/dev/null | grep -q "$name"; then
                status="Unloaded"
                status_color="$COLOR_DIM"
            fi

            # Truncate name if needed
            local display_name="$name"
            [[ ${#name} -gt 29 ]] && display_name="${name:0:26}..."

            printf "    ${COLOR_DIM}| %-29s | %s | ${status_color}%-8s${COLOR_DIM} |${COLOR_RESET}\n" \
                "$display_name" "$time_str" "$status"
        fi
    done

    echo -e "    ${COLOR_DIM}+-------------------------------+-------+----------+${COLOR_RESET}"

    if ! $found; then
        write_status "(no scheduled jobs)"
    fi
    echo ""
}

show_schedule_menu() {
    local config=$(get_configuration)

    write_header "Schedule Management"

    # Show existing jobs
    local existing_count=0
    for plist in "$LAUNCHD_DIR"/${PLIST_PREFIX}*.plist; do
        [[ -f "$plist" ]] && ((existing_count++))
    done

    if [[ $existing_count -gt 0 ]]; then
        write_step "Current scheduled jobs: $existing_count"
        list_jobs
    else
        write_status "No scheduled jobs configured yet."
    fi

    # Show folder schedules from config
    if [[ "$config" != "null" ]]; then
        local schedules=$(get_unique_schedules "$config")
        if [[ -n "$schedules" ]]; then
            echo ""
            write_step "Folder schedules (from config):"
            while IFS= read -r time; do
                local folders=$(echo "$config" | jq -r "[.folders[] | select(.enabled == true and .schedule == \"$time\") | .name] | join(\", \")")
                write_status "$time - $folders"
            done <<< "$schedules"
        fi
    fi

    show_menu_box "Schedule Options" \
        "1|Create/Update|Apply folder schedules" \
        "2|Remove All|Delete all scheduled jobs" \
        "3|Back|Return to main menu"

    get_user_choice "Select [1-3]:"
}

# Main logic
show_banner "compact"

# Handle list command
if $LIST; then
    list_jobs
    exit 0
fi

# Handle uninstall command
if $UNINSTALL; then
    uninstall_all_jobs
    exit 0
fi

# Ensure launchd directory exists
mkdir -p "$LAUNCHD_DIR"

# Load configuration
config=$(get_configuration)

if [[ "$config" == "null" ]]; then
    write_fail "No configuration found. Run 'tableau-scrubber' and select Configure first."
    exit 1
fi

# Interactive menu
choice=$(show_schedule_menu)

case "$choice" in
    1)
        # Create/Update schedules
        ;;
    2)
        uninstall_all_jobs
        exit 0
        ;;
    3)
        exit 0
        ;;
    *)
        write_bad "Invalid selection"
        exit 0
        ;;
esac

# Continue with schedule creation (option 1)
schedules=$(get_unique_schedules "$config")

if [[ -z "$schedules" ]]; then
    write_bad "No enabled folders found"
    exit 0
fi

write_header "Creating Schedules"

# Show what will be created
while IFS= read -r time; do
    local folders=$(echo "$config" | jq -r "[.folders[] | select(.enabled == true and .schedule == \"$time\") | .name] | join(\", \")")
    write_status "$time daily - $folders"
done <<< "$schedules"

echo ""

# Remove existing jobs first
for plist in "$LAUNCHD_DIR"/${PLIST_PREFIX}*.plist; do
    if [[ -f "$plist" ]]; then
        launchctl unload "$plist" 2>/dev/null
        rm -f "$plist"
    fi
done

# Create new jobs
write_step "Creating scheduled jobs..."
created_count=0

while IFS= read -r time; do
    install_launchd_job "$time"
    ((created_count++))
done <<< "$schedules"

all_times=$(echo "$schedules" | tr '\n' ', ' | sed 's/, $//')

show_success "Scheduled Jobs Created" \
    "Jobs Created|$created_count" \
    "Run Times|$all_times"

echo ""
write_info "View:    ./install-schedule.sh --list"
write_info "Remove:  ./install-schedule.sh --uninstall"
echo ""

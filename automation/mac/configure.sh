#!/bin/bash
# Tableau Workbook Scrubber - Configuration Script
# Manage multiple folders with individual schedules

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Import shared UI functions
source "$SCRIPT_DIR/lib/ui-helpers.sh"

# Configuration file path
CONFIG_DIR="$HOME/.iw-tableau-cleanup"
CONFIG_FILE="$CONFIG_DIR/config.json"

get_configuration() {
    if [[ -f "$CONFIG_FILE" ]]; then
        local config=$(cat "$CONFIG_FILE")
        local version=$(echo "$config" | jq -r '.version // 1')
        if [[ "$version" == "2" ]]; then
            echo "$config"
        else
            # Migrate v1 to v2
            local watch_folder=$(echo "$config" | jq -r '.watchFolder // ""')
            local backup_folder=$(echo "$config" | jq -r '.backupFolder // ""')
            local run_time=$(echo "$config" | jq -r '.runTime // "17:00"')
            echo "{
                \"version\": 2,
                \"default_backup_folder\": \"backups\",
                \"log_folder\": \"$CONFIG_DIR/logs\",
                \"folders\": [{
                    \"name\": \"Default\",
                    \"path\": \"$watch_folder\",
                    \"backup_folder\": \"$backup_folder\",
                    \"schedule\": \"$run_time\",
                    \"enabled\": true,
                    \"last_run\": null
                }]
            }"
        fi
    else
        echo "{
            \"version\": 2,
            \"default_backup_folder\": \"backups\",
            \"log_folder\": \"$CONFIG_DIR/logs\",
            \"folders\": []
        }"
    fi
}

save_configuration() {
    local config="$1"

    mkdir -p "$CONFIG_DIR"

    # Ensure log folder exists
    local log_folder=$(echo "$config" | jq -r '.log_folder')
    mkdir -p "$log_folder"

    echo "$config" | jq '.' > "$CONFIG_FILE"
    write_good "Configuration saved"
}

add_folder() {
    local config="$1"

    write_subheader "Add New Folder"

    # Get folder path
    write_step "Enter the path to the folder containing Tableau workbooks"
    local path=$(get_user_choice "Folder path:")

    if [[ -z "$path" ]]; then
        write_bad "Cancelled"
        echo "$config"
        return
    fi

    # Expand ~ to home directory
    path="${path/#\~/$HOME}"

    if [[ ! -d "$path" ]]; then
        write_bad "Directory does not exist: $path"
        echo "$config"
        return
    fi

    write_good "Selected: $path"

    # Get friendly name
    local default_name=$(basename "$path")
    local name=$(get_user_choice "Enter a friendly name:" "$default_name")

    # Get schedule time
    local schedule=$(get_user_choice "Enter daily schedule time (HH:MM):" "17:00")

    # Validate time format
    if [[ ! "$schedule" =~ ^[0-9]{1,2}:[0-9]{2}$ ]]; then
        write_bad "Invalid time format. Using 17:00"
        schedule="17:00"
    fi

    # Ask about backup folder
    local backup_folder=""
    if get_user_confirmation "Use custom backup folder?"; then
        backup_folder=$(get_user_choice "Backup folder path:")
        backup_folder="${backup_folder/#\~/$HOME}"
    fi

    # Create new folder entry and add to config
    local new_folder="{
        \"name\": \"$name\",
        \"path\": \"$path\",
        \"backup_folder\": $([ -n "$backup_folder" ] && echo "\"$backup_folder\"" || echo "null"),
        \"schedule\": \"$schedule\",
        \"enabled\": true,
        \"last_run\": null
    }"

    config=$(echo "$config" | jq ".folders += [$new_folder]")

    echo ""
    write_good "Folder added"
    write_status "Name:     $name"
    write_status "Path:     $path"
    write_status "Schedule: $schedule"

    echo "$config"
}

edit_folder() {
    local config="$1"

    local folder_count=$(echo "$config" | jq '.folders | length')

    if [[ "$folder_count" -eq 0 ]]; then
        write_bad "No folders configured"
        echo "$config"
        return
    fi

    write_subheader "Configured Folders"
    show_folder_list

    local selection=$(get_user_choice "Enter folder number to edit:")
    local index=$((selection - 1))

    if [[ $index -lt 0 ]] || [[ $index -ge $folder_count ]]; then
        write_fail "Invalid selection"
        echo "$config"
        return
    fi

    local folder=$(echo "$config" | jq ".folders[$index]")
    local name=$(echo "$folder" | jq -r '.name')
    local schedule=$(echo "$folder" | jq -r '.schedule')
    local enabled=$(echo "$folder" | jq -r '.enabled')

    write_subheader "Editing: $name"
    write_status "Press Enter to keep current value"

    # Edit name
    local new_name=$(get_user_choice "Name:" "$name")
    config=$(echo "$config" | jq ".folders[$index].name = \"$new_name\"")

    # Edit schedule
    local new_schedule=$(get_user_choice "Schedule (HH:MM):" "$schedule")
    if [[ "$new_schedule" =~ ^[0-9]{1,2}:[0-9]{2}$ ]]; then
        config=$(echo "$config" | jq ".folders[$index].schedule = \"$new_schedule\"")
    else
        write_bad "Invalid time format, keeping current"
    fi

    # Toggle enabled
    if [[ "$enabled" == "true" ]]; then
        if get_user_confirmation "Disable this folder?"; then
            config=$(echo "$config" | jq ".folders[$index].enabled = false")
            write_good "Folder disabled"
        fi
    else
        if get_user_confirmation "Enable this folder?" "true"; then
            config=$(echo "$config" | jq ".folders[$index].enabled = true")
            write_good "Folder enabled"
        fi
    fi

    # Edit path
    if get_user_confirmation "Change folder path?"; then
        local new_path=$(get_user_choice "New folder path:")
        new_path="${new_path/#\~/$HOME}"
        if [[ -d "$new_path" ]]; then
            config=$(echo "$config" | jq ".folders[$index].path = \"$new_path\"")
            write_good "Path updated: $new_path"
        else
            write_bad "Directory does not exist, keeping current"
        fi
    fi

    write_good "Folder updated"

    echo "$config"
}

remove_folder() {
    local config="$1"

    local folder_count=$(echo "$config" | jq '.folders | length')

    if [[ "$folder_count" -eq 0 ]]; then
        write_bad "No folders configured"
        echo "$config"
        return
    fi

    write_subheader "Configured Folders"
    show_folder_list

    local selection=$(get_user_choice "Enter folder number to remove:")
    local index=$((selection - 1))

    if [[ $index -lt 0 ]] || [[ $index -ge $folder_count ]]; then
        write_fail "Invalid selection"
        echo "$config"
        return
    fi

    local folder_name=$(echo "$config" | jq -r ".folders[$index].name")

    if get_user_confirmation "Remove '$folder_name'?"; then
        config=$(echo "$config" | jq "del(.folders[$index])")
        write_good "Folder removed"
    else
        write_bad "Cancelled"
    fi

    echo "$config"
}

show_menu() {
    clear
    show_banner "compact"

    write_header "Folder Configuration"
    show_folder_list

    show_menu_box "Actions" \
        "1|Add folder|Add a new watch folder" \
        "2|Edit folder|Modify an existing folder" \
        "3|Remove folder|Delete a folder" \
        "4|Save and exit|Save changes and return" \
        "5|Exit|Discard changes"

    get_user_choice "Select [1-5]:"
}

# Parse command line arguments
SILENT=false
ACTION=""
FOLDER_PATH=""
FOLDER_NAME=""
SCHEDULE=""
BACKUP_FOLDER=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --silent|-s)
            SILENT=true
            shift
            ;;
        --action|-a)
            ACTION="$2"
            shift 2
            ;;
        --path|-p)
            FOLDER_PATH="$2"
            shift 2
            ;;
        --name|-n)
            FOLDER_NAME="$2"
            shift 2
            ;;
        --schedule)
            SCHEDULE="$2"
            shift 2
            ;;
        --backup)
            BACKUP_FOLDER="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Main flow
config=$(get_configuration)

# Handle silent/scripted mode
if $SILENT || [[ -n "$ACTION" ]]; then
    case "$ACTION" in
        add)
            if [[ -z "$FOLDER_PATH" ]] || [[ ! -d "$FOLDER_PATH" ]]; then
                write_fail "Error: Valid --path required"
                exit 1
            fi
            name="${FOLDER_NAME:-$(basename "$FOLDER_PATH")}"
            schedule="${SCHEDULE:-17:00}"
            backup="${BACKUP_FOLDER:-null}"
            [[ "$backup" != "null" ]] && backup="\"$backup\""

            new_folder="{
                \"name\": \"$name\",
                \"path\": \"$FOLDER_PATH\",
                \"backup_folder\": $backup,
                \"schedule\": \"$schedule\",
                \"enabled\": true,
                \"last_run\": null
            }"
            config=$(echo "$config" | jq ".folders += [$new_folder]")
            save_configuration "$config"
            write_good "Folder added: $name"
            ;;
        list)
            show_banner "compact"
            write_header "Configured Folders"
            show_folder_list
            ;;
        remove)
            if [[ -z "$FOLDER_NAME" ]]; then
                write_fail "Error: --name required"
                exit 1
            fi
            config=$(echo "$config" | jq "del(.folders[] | select(.name == \"$FOLDER_NAME\"))")
            save_configuration "$config"
            write_good "Folder removed: $FOLDER_NAME"
            ;;
        *)
            write_fail "Unknown action. Use: add, list, remove"
            exit 1
            ;;
    esac
    exit 0
fi

# Interactive menu loop
modified=false

while true; do
    action=$(show_menu)

    case "$action" in
        1)
            config=$(add_folder "$config")
            modified=true
            sleep 1
            ;;
        2)
            config=$(edit_folder "$config")
            modified=true
            sleep 1
            ;;
        3)
            config=$(remove_folder "$config")
            modified=true
            sleep 1
            ;;
        4)
            save_configuration "$config"
            folder_count=$(echo "$config" | jq '.folders | length')
            show_success "Configuration Saved" "Folders|$folder_count"
            echo ""
            write_info "Next: Run 'tableau-scrubber' to clean workbooks"
            echo ""
            exit 0
            ;;
        5)
            if $modified; then
                if ! get_user_confirmation "Discard changes?"; then
                    continue
                fi
            fi
            write_bad "Exiting without saving"
            exit 0
            ;;
        *)
            write_fail "Invalid selection"
            sleep 1
            ;;
    esac
done

#!/bin/bash
# Tableau Workbook Scrubber - Unified CLI Entry Point
# Run this script to access all cleanup features from one menu

SCRIPT_VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Import shared UI functions
source "$SCRIPT_DIR/lib/ui-helpers.sh"

# Configuration
CONFIG_DIR="$HOME/.iw-tableau-cleanup"
CONFIG_FILE="$CONFIG_DIR/config.json"

get_configuration() {
    if [[ -f "$CONFIG_FILE" ]]; then
        cat "$CONFIG_FILE"
    else
        echo '{
            "version": 2,
            "default_backup_folder": "backups",
            "log_folder": "'"$CONFIG_DIR/logs"'",
            "folders": []
        }'
    fi
}

show_help() {
    echo ""
    echo -e "    ${COLOR_GOLD}TABLEAU WORKBOOK SCRUBBER${COLOR_RESET}"
    echo -e "    ${COLOR_BODY}Usage: tableau-scrubber [options]${COLOR_RESET}"
    echo ""
    echo -e "    ${COLOR_LIGHTBLUE}Options:${COLOR_RESET}"
    echo -e "    ${COLOR_DIM}  (no args)              Interactive menu${COLOR_RESET}"
    echo -e "    ${COLOR_DIM}  --action clean         Run cleanup on configured folders${COLOR_RESET}"
    echo -e "    ${COLOR_DIM}  --action configure     Open folder configuration${COLOR_RESET}"
    echo -e "    ${COLOR_DIM}  --action logs          View recent cleanup logs${COLOR_RESET}"
    echo -e "    ${COLOR_DIM}  --workbook PATH        Specify a workbook directly${COLOR_RESET}"
    echo -e "    ${COLOR_DIM}  --help                 Show this help${COLOR_RESET}"
    echo -e "    ${COLOR_DIM}  --version              Show version${COLOR_RESET}"
    echo ""
    echo -e "    ${COLOR_LIGHTBLUE}Examples:${COLOR_RESET}"
    echo -e "    ${COLOR_DIM}  tableau-scrubber${COLOR_RESET}"
    echo -e "    ${COLOR_DIM}  tableau-scrubber --action clean${COLOR_RESET}"
    echo -e "    ${COLOR_DIM}  tableau-scrubber --action clean --workbook '/path/to/workbook.twb'${COLOR_RESET}"
    echo ""
}

show_main_menu() {
    clear
    show_banner

    local config=$(get_configuration)
    local folder_count=$(echo "$config" | jq '[.folders[] | select(.enabled == true)] | length' 2>/dev/null || echo "0")

    # Show quick status
    echo -ne "    ${COLOR_DIM}Status: ${COLOR_RESET}"
    if [[ "$folder_count" -gt 0 ]]; then
        echo -e "${COLOR_SUCCESS}$folder_count folder(s) configured${COLOR_RESET}"
    else
        echo -e "${COLOR_WARNING}No folders configured${COLOR_RESET}"
    fi

    show_menu_box "What would you like to do?" \
        "1|Clean Workbooks|Run cleanup on configured folders" \
        "2|Configure Folders|Add, edit, remove watch folders" \
        "3|View Logs|Check recent cleanup history" \
        "Q|Quit|"

    get_user_choice "Select [1-3, Q]:"
}

invoke_cleanup() {
    local path="$1"
    if [[ -n "$path" ]]; then
        "$SCRIPT_DIR/run-cleanup.sh" --workbook "$path"
    else
        "$SCRIPT_DIR/run-cleanup.sh"
    fi
}

invoke_configure() {
    "$SCRIPT_DIR/configure.sh"
}

# Parse command line arguments
ACTION=""
WORKBOOK_PATH=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --version|-v)
            echo ""
            echo -e "    ${COLOR_BODY}Tableau Workbook Scrubber v$SCRIPT_VERSION${COLOR_RESET}"
            echo -e "    ${COLOR_DIM}Powered by InterWorks${COLOR_RESET}"
            echo ""
            exit 0
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        --action|-a)
            ACTION="$2"
            shift 2
            ;;
        --workbook|-w)
            WORKBOOK_PATH="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Non-interactive mode (for automation/scripting)
if [[ -n "$ACTION" ]]; then
    case "${ACTION,,}" in
        clean)
            invoke_cleanup "$WORKBOOK_PATH"
            ;;
        configure)
            invoke_configure
            ;;
        logs)
            show_banner "compact"
            show_logs
            ;;
        *)
            write_fail "Unknown action: $ACTION"
            echo ""
            echo -e "    ${COLOR_DIM}Valid actions: clean, configure, logs${COLOR_RESET}"
            exit 1
            ;;
    esac
    exit 0
fi

# Interactive menu loop
while true; do
    choice=$(show_main_menu)

    case "${choice^^}" in
        1)
            clear
            show_banner "compact"
            invoke_cleanup
            echo ""
            sleep 2
            ;;
        2)
            clear
            invoke_configure
            ;;
        3)
            clear
            show_banner "compact"
            show_logs "interactive"
            ;;
        Q)
            echo ""
            echo -e "    ${COLOR_LIGHTBLUE}Goodbye!${COLOR_RESET}"
            echo ""
            exit 0
            ;;
        *)
            write_bad "Invalid selection. Please enter 1-3 or Q."
            sleep 1
            ;;
    esac
done

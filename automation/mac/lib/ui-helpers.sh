#!/bin/bash
# Tableau Workbook Scrubber - Shared UI Helper Functions
# Provides consistent styling across all CLI scripts

# Colors (ANSI escape codes)
COLOR_GOLD="\033[33m"
COLOR_LIGHTBLUE="\033[36m"
COLOR_MEDIUMBLUE="\033[34m"
COLOR_SUCCESS="\033[32m"
COLOR_ERROR="\033[31m"
COLOR_WARNING="\033[33m"
COLOR_DIM="\033[90m"
COLOR_BODY="\033[37m"
COLOR_RESET="\033[0m"

# Get script directory
get_script_dir() {
    echo "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
}

show_banner() {
    local compact="$1"

    if [[ "$compact" == "compact" ]]; then
        echo ""
        echo -e "    ${COLOR_GOLD}TABLEAU WORKBOOK SCRUBBER${COLOR_RESET}"
        echo -e "    ${COLOR_DIM}Automated cleanup powered by Claude${COLOR_RESET}"
        echo ""
        return
    fi

    # Try to show image banner with chafa if available
    local script_dir=$(get_script_dir)
    local assets_path="$script_dir/../assets/banner.png"

    if command -v chafa &> /dev/null && [[ -f "$assets_path" ]]; then
        chafa --size=60x20 --symbols=block "$assets_path"
    fi

    echo ""
    echo -e "                                           ${COLOR_BODY}Powered by InterWorks${COLOR_RESET}"
    echo ""
}

show_menu_box() {
    local title="$1"
    shift
    local options=("$@")

    echo ""
    echo -e "    ${COLOR_DIM}+--------------------------------------------------------------+${COLOR_RESET}"
    printf "    ${COLOR_BODY}| %-60s |${COLOR_RESET}\n" "$title"
    echo -e "    ${COLOR_DIM}+--------------------------------------------------------------+${COLOR_RESET}"
    echo -e "    ${COLOR_DIM}|                                                              |${COLOR_RESET}"

    for opt in "${options[@]}"; do
        # Parse "key|label|desc" format
        IFS='|' read -r key label desc <<< "$opt"
        printf "    ${COLOR_DIM}| ${COLOR_GOLD}%s. ${COLOR_BODY}%-20s ${COLOR_DIM}%-36s |${COLOR_RESET}\n" "$key" "$label" "$desc"
    done

    echo -e "    ${COLOR_DIM}|                                                              |${COLOR_RESET}"
    echo -e "    ${COLOR_DIM}+--------------------------------------------------------------+${COLOR_RESET}"
}

write_header() {
    local text="$1"
    echo ""
    echo -e "    ${COLOR_GOLD}=== $text ===${COLOR_RESET}"
    echo ""
}

write_subheader() {
    local text="$1"
    local len=${#text}
    echo ""
    echo -e "    ${COLOR_LIGHTBLUE}$text${COLOR_RESET}"
    echo -e "    ${COLOR_DIM}$(printf '%*s' "$len" | tr ' ' '-')${COLOR_RESET}"
}

write_step() {
    local message="$1"
    echo -e "    ${COLOR_LIGHTBLUE}$message${COLOR_RESET}"
}

write_status() {
    local message="$1"
    echo -e "      ${COLOR_DIM}$message${COLOR_RESET}"
}

write_good() {
    local message="$1"
    echo -e "      ${COLOR_SUCCESS}[OK]${COLOR_RESET} $message"
}

write_bad() {
    local message="$1"
    echo -e "      ${COLOR_WARNING}[!]${COLOR_RESET} $message"
}

write_fail() {
    local message="$1"
    echo -e "      ${COLOR_ERROR}[X]${COLOR_RESET} $message"
}

write_info() {
    local message="$1"
    echo -e "      ${COLOR_LIGHTBLUE}[i]${COLOR_RESET} $message"
}

show_pass_header() {
    local current="$1"
    local max="$2"
    echo ""
    echo -e "    ${COLOR_GOLD}+------------------------+${COLOR_RESET}"
    printf "    ${COLOR_GOLD}|  PASS %d of %-11d|${COLOR_RESET}\n" "$current" "$max"
    echo -e "    ${COLOR_GOLD}+------------------------+${COLOR_RESET}"
}

show_error_table() {
    local caption_errors="$1"
    local comment_errors="$2"
    local folder_errors="$3"
    local xml_errors="$4"
    local total_errors="$5"

    echo ""
    echo -e "    ${COLOR_DIM}+------------+-----------+------------------+${COLOR_RESET}"
    echo -e "    ${COLOR_BODY}| Category   | # Issues  | Description      |${COLOR_RESET}"
    echo -e "    ${COLOR_DIM}+------------+-----------+------------------+${COLOR_RESET}"

    if [[ $caption_errors -gt 0 ]]; then
        local color=$([[ $caption_errors -gt 10 ]] && echo "$COLOR_ERROR" || echo "$COLOR_WARNING")
        printf "    ${COLOR_DIM}| %-10s | ${color}%9d${COLOR_DIM} | %-16s |${COLOR_RESET}\n" "Captions" "$caption_errors" "naming issues"
    fi
    if [[ $comment_errors -gt 0 ]]; then
        local color=$([[ $comment_errors -gt 10 ]] && echo "$COLOR_ERROR" || echo "$COLOR_WARNING")
        printf "    ${COLOR_DIM}| %-10s | ${color}%9d${COLOR_DIM} | %-16s |${COLOR_RESET}\n" "Comments" "$comment_errors" "bad comments"
    fi
    if [[ $folder_errors -gt 0 ]]; then
        local color=$([[ $folder_errors -gt 10 ]] && echo "$COLOR_ERROR" || echo "$COLOR_WARNING")
        printf "    ${COLOR_DIM}| %-10s | ${color}%9d${COLOR_DIM} | %-16s |${COLOR_RESET}\n" "Folders" "$folder_errors" "organization"
    fi
    if [[ $xml_errors -gt 0 ]]; then
        local color=$([[ $xml_errors -gt 10 ]] && echo "$COLOR_ERROR" || echo "$COLOR_WARNING")
        printf "    ${COLOR_DIM}| %-10s | ${color}%9d${COLOR_DIM} | %-16s |${COLOR_RESET}\n" "XML" "$xml_errors" "syntax errors"
    fi

    echo -e "    ${COLOR_DIM}+------------+-----------+------------------+${COLOR_RESET}"
    local total_color=$([[ $total_errors -eq 0 ]] && echo "$COLOR_SUCCESS" || echo "$COLOR_BODY")
    printf "    ${COLOR_DIM}| TOTAL      | ${total_color}%9d${COLOR_DIM} |                  |${COLOR_RESET}\n" "$total_errors"
    echo -e "    ${COLOR_DIM}+------------+-----------+------------------+${COLOR_RESET}"
}

show_success() {
    local title="$1"
    shift
    local stats=("$@")

    echo ""
    echo -e "    ${COLOR_SUCCESS}+--------------------------------------+${COLOR_RESET}"
    printf "    ${COLOR_SUCCESS}| %-36s |${COLOR_RESET}\n" "${title^^}"
    echo -e "    ${COLOR_SUCCESS}|                                      |${COLOR_RESET}"

    for stat in "${stats[@]}"; do
        IFS='|' read -r key value <<< "$stat"
        printf "    ${COLOR_BODY}| %-18s %14s   |${COLOR_RESET}\n" "$key" "$value"
    done

    echo -e "    ${COLOR_SUCCESS}|                                      |${COLOR_RESET}"
    echo -e "    ${COLOR_SUCCESS}+--------------------------------------+${COLOR_RESET}"
}

show_failure() {
    local title="$1"
    local message="$2"

    echo ""
    echo -e "    ${COLOR_ERROR}+--------------------------------------+${COLOR_RESET}"
    printf "    ${COLOR_ERROR}| %-36s |${COLOR_RESET}\n" "${title^^}"
    echo -e "    ${COLOR_ERROR}|                                      |${COLOR_RESET}"
    printf "    ${COLOR_BODY}| %-36s |${COLOR_RESET}\n" "$message"
    echo -e "    ${COLOR_ERROR}|                                      |${COLOR_RESET}"
    echo -e "    ${COLOR_ERROR}+--------------------------------------+${COLOR_RESET}"
}

show_logs() {
    local interactive="$1"
    local log_folder="$HOME/.iw-tableau-cleanup/logs"

    if [[ ! -d "$log_folder" ]]; then
        write_header "Recent Cleanup Logs"
        write_status "No logs found yet. Run a cleanup to generate logs."
        return
    fi

    local logs=($(ls -t "$log_folder"/*.log 2>/dev/null | head -10))

    if [[ ${#logs[@]} -eq 0 ]]; then
        write_header "Recent Cleanup Logs"
        write_status "No logs found yet. Run a cleanup to generate logs."
        return
    fi

    local keep_showing=true
    while $keep_showing; do
        write_header "Recent Cleanup Logs"
        echo ""
        echo -e "    ${COLOR_DIM}+----+------------------+----------------------------------+----------+--------------+${COLOR_RESET}"
        echo -e "    ${COLOR_BODY}| #  | Date             | Workbook                         | Status   | Issues Fixed |${COLOR_RESET}"
        echo -e "    ${COLOR_DIM}+----+------------------+----------------------------------+----------+--------------+${COLOR_RESET}"

        local i=1
        for log in "${logs[@]}"; do
            local date=$(stat -f "%Sm" -t "%b %d %H:%M" "$log" 2>/dev/null || date -r "$log" "+%b %d %H:%M" 2>/dev/null || echo "Unknown")
            local content=$(cat "$log" 2>/dev/null)
            local status="Unknown"
            local issues_fixed="-"
            local workbook="-"

            if [[ -n "$content" ]]; then
                # Extract workbook name
                if [[ "$content" =~ Found:\ *([^[:space:]]+\.twb) ]]; then
                    workbook="${BASH_REMATCH[1]}"
                    [[ ${#workbook} -gt 32 ]] && workbook="${workbook:0:29}..."
                fi

                # Determine status
                if echo "$content" | grep -q "Validation passed\|All Checks Passed"; then
                    status="Success"
                elif echo "$content" | grep -q "FAILED\|Error running"; then
                    status="Failed"
                else
                    status="Partial"
                fi
            fi

            local status_color
            case "$status" in
                "Success") status_color="$COLOR_SUCCESS" ;;
                "Failed") status_color="$COLOR_ERROR" ;;
                *) status_color="$COLOR_WARNING" ;;
            esac

            printf "    ${COLOR_DIM}| ${COLOR_GOLD}%-2d${COLOR_DIM} | %-16s | %-32s | ${status_color}%-8s${COLOR_DIM} | %12s |${COLOR_RESET}\n" \
                "$i" "$date" "$workbook" "$status" "$issues_fixed"
            ((i++))
        done

        echo -e "    ${COLOR_DIM}+----+------------------+----------------------------------+----------+--------------+${COLOR_RESET}"
        echo ""
        echo -e "    ${COLOR_DIM}Log folder: $log_folder${COLOR_RESET}"

        if [[ "$interactive" == "interactive" ]]; then
            echo ""
            echo -e "    ${COLOR_DIM}Enter # to view log, or B to go back${COLOR_RESET}"
            read -p "    Select: " choice

            if [[ "$choice" =~ ^[Bb]$ ]] || [[ -z "$choice" ]]; then
                keep_showing=false
            elif [[ "$choice" =~ ^[0-9]+$ ]]; then
                local idx=$((choice - 1))
                if [[ $idx -ge 0 ]] && [[ $idx -lt ${#logs[@]} ]]; then
                    local selected_log="${logs[$idx]}"

                    # Show preview
                    clear
                    show_banner "compact"
                    write_header "Log Preview: $(basename "$selected_log")"

                    echo ""
                    echo -e "    ${COLOR_DIM}--- Last 20 lines ---${COLOR_RESET}"
                    tail -20 "$selected_log" | while read -r line; do
                        local display_line="$line"
                        [[ ${#line} -gt 80 ]] && display_line="${line:0:77}..."
                        echo -e "    ${COLOR_BODY}$display_line${COLOR_RESET}"
                    done
                    echo -e "    ${COLOR_DIM}--- End preview ---${COLOR_RESET}"

                    echo ""
                    read -p "    Open full log? (Y/n) " open_choice
                    if [[ -z "$open_choice" ]] || [[ "$open_choice" =~ ^[Yy]$ ]]; then
                        if command -v open &> /dev/null; then
                            open -e "$selected_log"
                        elif command -v xdg-open &> /dev/null; then
                            xdg-open "$selected_log"
                        else
                            less "$selected_log"
                        fi
                        write_good "Opened log"
                    fi

                    echo ""
                    echo -e "    ${COLOR_DIM}Press Enter to continue...${COLOR_RESET}"
                    read
                    clear
                    show_banner "compact"
                else
                    write_bad "Invalid selection"
                    sleep 1
                fi
            else
                write_bad "Invalid selection"
                sleep 1
            fi
        else
            keep_showing=false
        fi
    done
}

show_folder_list() {
    local config_file="$HOME/.iw-tableau-cleanup/config.json"

    if [[ ! -f "$config_file" ]]; then
        write_status "(no folders configured)"
        return
    fi

    local folder_count=$(jq '.folders | length' "$config_file" 2>/dev/null || echo "0")

    if [[ "$folder_count" -eq 0 ]]; then
        write_status "(no folders configured)"
        return
    fi

    echo ""
    for ((i=0; i<folder_count; i++)); do
        local name=$(jq -r ".folders[$i].name" "$config_file")
        local path=$(jq -r ".folders[$i].path" "$config_file")
        local schedule=$(jq -r ".folders[$i].schedule" "$config_file")
        local enabled=$(jq -r ".folders[$i].enabled" "$config_file")
        local last_run=$(jq -r ".folders[$i].last_run // \"never\"" "$config_file")

        local status="[OFF]"
        local status_color="$COLOR_DIM"
        if [[ "$enabled" == "true" ]]; then
            status="[ON]"
            status_color="$COLOR_SUCCESS"
        fi

        echo -e "    ${COLOR_GOLD}$((i+1)). ${COLOR_BODY}$name  ${status_color}$status${COLOR_RESET}"
        echo -e "       ${COLOR_DIM}Path:     ${COLOR_BODY}$path${COLOR_RESET}"
        echo -e "       ${COLOR_DIM}Schedule: ${COLOR_BODY}$schedule${COLOR_RESET}"
        if [[ "$last_run" != "never" ]] && [[ "$last_run" != "null" ]]; then
            echo -e "       ${COLOR_DIM}Last Run: $last_run${COLOR_RESET}"
        fi
        echo ""
    done
}

get_user_choice() {
    local prompt="$1"
    local default="$2"

    if [[ -n "$default" ]]; then
        read -p "    $prompt [$default]: " user_input
        echo "${user_input:-$default}"
    else
        read -p "    $prompt " user_input
        echo "$user_input"
    fi
}

get_user_confirmation() {
    local prompt="$1"
    local default_yes="$2"

    local hint="(y/N)"
    [[ "$default_yes" == "true" ]] && hint="(Y/n)"

    read -p "    $prompt $hint " user_input

    if [[ -z "$user_input" ]]; then
        [[ "$default_yes" == "true" ]] && return 0 || return 1
    fi

    [[ "$user_input" =~ ^[Yy]$ ]] && return 0 || return 1
}

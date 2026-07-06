#!/bin/bash
# =============================================================================
# BTA Plugin Template
# =============================================================================
# Name:        plugin_template.sh
# Author:      Your Name
# Version:     1.0.0
# Description: A starting point for new BTA plugins.
#
# INSTALL: Drop this file into the plugins/ directory.
# The game will source it automatically on startup.
#
# MANUAL MENU INTEGRATION:
# To add your feature to the main menu, find the main while loop in
# bta_enhanced.sh and add:
#   In the echo block:  echo "22. My Feature     |"
#   In the case block:  22) my_plugin_main;;
# =============================================================================

# ── Guard: prevent double-sourcing ───────────────────────────────────────────
[[ -n "${PLUGIN_TEMPLATE_LOADED:-}" ]] && return
PLUGIN_TEMPLATE_LOADED=1

# ── Plugin State Variables ───────────────────────────────────────────────────
# Declare ALL variables your plugin uses here so they exist before load_game
# tries to populate them.

my_plugin_example_counter=0
declare -A my_plugin_data=()

# ── Initialize (called once, here at source time) ────────────────────────────
_my_plugin_init() {
    # Set default values. initialize_world_data may also reset these.
    my_plugin_example_counter=0
    my_plugin_data=()
}
_my_plugin_init

# ── Save Hook ────────────────────────────────────────────────────────────────
# Function name MUST be one of:
#   bounty_save_extra   (used by bounty board plugin)
#   economy_save_extra  (used by economy plugin)
# If both slots are taken by other plugins, you'll need to chain them or patch
# save_game directly.
#
# This template uses bounty_save_extra. Rename if that slot is occupied.

bounty_save_extra() {
    local save_path="$BASEDIR/$SAVE_DIR"
    mkdir -p "$save_path"

    # Save scalar variables
    {
        echo "my_plugin_example_counter@@@${my_plugin_example_counter}"
    } > "$save_path/plugin_template.sav"

    # Save associative arrays using the built-in helper
    # save_assoc_array "$save_path/plugin_template_data.sav" "my_plugin_data"
}

# ── Load Hook ────────────────────────────────────────────────────────────────
bounty_load_extra() {
    local save_path="$BASEDIR/$SAVE_DIR"
    local sav_file="$save_path/plugin_template.sav"

    # Reset to defaults first in case save is missing
    _my_plugin_init

    [[ -f "$sav_file" ]] || return

    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ -z "$line" ]] && continue
        local key="${line%%@@@*}"
        local value="${line#*@@@}"
        case "$key" in
            "my_plugin_example_counter") my_plugin_example_counter="$value";;
        esac
    done < "$sav_file"

    # Load associative arrays using the built-in helper
    # load_assoc_array "$save_path/plugin_template_data.sav" "my_plugin_data"
}

# ── Optional: Passive Tick ───────────────────────────────────────────────────
# Uncomment and rename to enable. This runs every main loop iteration.
# Keep it fast — avoid sleep or heavy logic here.
#
# passive_bounty_encounter() {
#     # Only fire occasionally
#     (( RANDOM % 100 < 5 )) || return
#
#     clear_screen
#     echo "A passive event from my plugin!"
#     read -r -p "Press Enter..."
# }

# ── Optional: Animation Hooks ────────────────────────────────────────────────
# working_animation() {
#     local job_type="$1"
#     echo "My custom animation for job: $job_type"
#     sleep 1
# }

# ── Main Feature Function ────────────────────────────────────────────────────
my_plugin_main() {
    run_clock 1
    while true; do
        clear_screen
        echo "--- My Plugin Feature ---"
        printf " Player: %-15s | Cash: \$%d\n" "$player_name" "$cash"
        printf " Counter: %d\n" "$my_plugin_example_counter"
        echo "================================"
        echo "1. Increment counter (+10 Respect)"
        echo "2. Reset counter"
        echo "3. Back"
        echo "================================"
        read -r -p "Choice: " choice
        case "$choice" in
            1) _my_plugin_increment;;
            2) _my_plugin_reset;;
            3) return;;
            *) echo "Invalid choice."; sleep 1;;
        esac
    done
}

_my_plugin_increment() {
    my_plugin_example_counter=$(( my_plugin_example_counter + 1 ))
    echo "Counter is now ${my_plugin_example_counter}."
    award_respect 10
    play_sfx_mpg "win"
    read -r -p "Press Enter..."
}

_my_plugin_reset() {
    read -r -p "Reset counter to 0? (y/n): " confirm
    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
        my_plugin_example_counter=0
        echo "Counter reset."
    fi
    read -r -p "Press Enter..."
}